type TableRow = Record<string, unknown>;
export type TableStore = Record<string, TableRow[]>;
type QueryResult = { data: unknown; error: unknown | null };
type RpcCall = { name: string; args: Record<string, unknown> | undefined };

export function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

export function assertEquals<T>(
  actual: T,
  expected: T,
  message: string,
): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

export function assertDeepEquals(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`${message}: expected ${expectedJson}, got ${actualJson}`);
  }
}

export class FakeAdminClient {
  readonly rpcCalls: RpcCall[] = [];

  constructor(
    private readonly tables: TableStore,
    private readonly options: {
      rpcFailures?: Record<string, string>;
    } = {},
  ) {}

  from(table: string): FakeQueryBuilder {
    return new FakeQueryBuilder(this.tables, table);
  }

  rpc(name: string, args?: Record<string, unknown>): Promise<QueryResult> {
    this.rpcCalls.push({ name, args });
    const failureMessage = this.options.rpcFailures?.[name];
    if (failureMessage) {
      return Promise.resolve({
        data: null,
        error: new Error(failureMessage),
      });
    }

    if (name === "consume_edge_rate_limit") {
      return Promise.resolve({
        data: [{ allowed: true, retry_after_seconds: 0 }],
        error: null,
      });
    }

    // Result stub only. The maintained SQL contract and lock-observed race
    // suite establish transaction semantics against actual Postgres.
    if (name === "confirm_club_commerce_payment") {
      const kind = args?.p_kind;
      const ids = args?.p_record_ids as string[];
      const rows =
        (this.tables[kind === "ticket" ? "rs_tickets" : "rs_shop_orders"] ?? [])
          .filter((row) =>
            ids.includes(String(row.id)) && row.user_id === args?.p_user_id &&
            row.momo_reference === args?.p_reference
          );
      if (rows.length !== ids.length) {
        return Promise.resolve({
          data: { status: "manual_review" },
          error: null,
        });
      }
      const pending = rows.filter((row) => row.status === "pending");
      const points = !args?.p_partner_id
        ? 0
        : kind === "ticket"
        ? pending.length * 50
        : pending.length
        ? Math.floor(Number(args?.p_amount) / 100)
        : 0;
      for (const row of pending) {
        row.status = kind === "ticket" ? "valid" : "paid";
      }
      return Promise.resolve({
        data: {
          status: "confirmed",
          record_ids: ids,
          parsed_sms_id: args?.p_parsed_sms_id,
          newly_confirmed: pending.length > 0,
          points_awarded: points,
          referral_activated: false,
          applied_status: kind === "ticket" ? "valid" : String(rows[0].status),
        },
        error: null,
      });
    }

    if (name === "confirm_club_initiative_contribution") {
      const row = this.tables.rs_initiative_contributions?.find((row) =>
        row.id === args?.p_contribution_id && row.user_id === args?.p_user_id
      );
      if (
        !row || row.momo_reference !== args?.p_reference ||
        row.amount !== args?.p_amount ||
        !["pending", "confirmed"].includes(String(row.status))
      ) {
        return Promise.resolve({
          data: { status: "manual_review" },
          error: null,
        });
      }
      const newlyConfirmed = row.status === "pending";
      row.status = "confirmed";
      const campaign = this.tables.rs_initiatives?.find((c) =>
        c.id === row.initiative_id
      );
      if (newlyConfirmed && campaign) {
        campaign.raised_amount = Number(campaign.raised_amount) +
          Number(row.amount);
        campaign.supporter_count = Number(campaign.supporter_count) + 1;
      }
      return Promise.resolve({
        data: {
          status: "confirmed",
          contribution_id: row.id,
          newly_confirmed: newlyConfirmed,
          points_awarded: newlyConfirmed
            ? Math.floor(Number(row.amount) / 100) * 2
            : 0,
          referral_activated: false,
        },
        error: null,
      });
    }

    if (name === "confirm_contribution") {
      const contributionId = typeof args?.p_contribution_id === "string"
        ? args.p_contribution_id
        : null;
      const contributions = this.tables.group_contributions ?? [];
      const contribution = contributionId
        ? contributions.find((row) => row.id === contributionId)
        : null;

      if (!contribution) {
        return Promise.resolve({
          data: {
            status: "error",
            message: "Contribution not found",
          },
          error: null,
        });
      }

      const normalizedStatus = String(contribution.status ?? "")
        .trim()
        .toLowerCase();
      if (normalizedStatus !== "confirmed") {
        contribution.status = "confirmed";
        contribution.confirmed_at = contribution.confirmed_at ??
          new Date().toISOString();

        const groupId = typeof contribution.group_id === "string"
          ? contribution.group_id
          : null;
        const amount = typeof contribution.amount === "number"
          ? contribution.amount
          : Number(contribution.amount ?? 0);
        const group = groupId
          ? (this.tables.groups ?? []).find((row) => row.id === groupId)
          : null;
        if (group) {
          const currentAmount = typeof group.amount === "number"
            ? group.amount
            : Number(group.amount ?? 0);
          group.amount = currentAmount + amount;
        }
      }

      return Promise.resolve({
        data: {
          status: normalizedStatus === "confirmed" ? "already_confirmed" : "ok",
        },
        error: null,
      });
    }

    return Promise.resolve({ data: null, error: null });
  }
}

class FakeQueryBuilder implements PromiseLike<QueryResult> {
  private action: "select" | "update" | "insert" = "select";
  private filters: Array<
    | { kind: "eq"; column: string; value: unknown }
    | { kind: "in"; column: string; values: unknown[] }
    | { kind: "ilike"; column: string; value: string }
  > = [];
  private limitCount: number | null = null;
  private orderColumn: string | null = null;
  private ascending = true;
  private unexpiredAfter: string | null = null;
  private updatePayload: Record<string, unknown> | null = null;
  private insertPayload: Record<string, unknown>[] = [];
  private insertedRows: TableRow[] | null = null;

  constructor(
    private readonly tables: TableStore,
    private readonly table: string,
  ) {}

  select(_columns: string): this {
    // PostgREST select() after insert/update requests returned rows; it does
    // not turn the mutation back into a read.
    return this;
  }

  update(values: Record<string, unknown>): this {
    this.action = "update";
    this.updatePayload = values;
    return this;
  }

  insert(values: Record<string, unknown> | Record<string, unknown>[]): this {
    this.action = "insert";
    this.insertPayload = Array.isArray(values) ? values : [values];
    return this;
  }

  eq(column: string, value: unknown): this {
    this.filters.push({ kind: "eq", column, value });
    return this;
  }

  in(column: string, values: unknown[]): this {
    this.filters.push({ kind: "in", column, values });
    return this;
  }

  ilike(column: string, value: string): this {
    this.filters.push({ kind: "ilike", column, value });
    return this;
  }

  order(column: string, options?: { ascending?: boolean }): this {
    this.orderColumn = column;
    this.ascending = options?.ascending ?? true;
    return this;
  }

  limit(count: number): this {
    this.limitCount = count;
    return this;
  }

  or(filter: string): this {
    const prefix = "expires_at.is.null,expires_at.gt.";
    if (
      !filter.startsWith(prefix) ||
      !Number.isFinite(Date.parse(filter.slice(prefix.length)))
    ) {
      throw new Error(`Unsupported fake query filter: ${filter}`);
    }
    this.unexpiredAfter = filter.slice(prefix.length);
    return this;
  }

  maybeSingle(): Promise<QueryResult> {
    return Promise.resolve(this.execute(true));
  }

  single(): Promise<QueryResult> {
    return Promise.resolve(this.execute(true));
  }

  then<TResult1 = QueryResult, TResult2 = never>(
    onfulfilled?:
      | ((value: QueryResult) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?:
      | ((reason: unknown) => TResult2 | PromiseLike<TResult2>)
      | null,
  ): Promise<TResult1 | TResult2> {
    return Promise.resolve(this.execute(false)).then(onfulfilled, onrejected);
  }

  private execute(expectSingle: boolean): QueryResult {
    if (this.action === "insert") {
      if (this.insertedRows == null) {
        const target = this.tables[this.table] ??= [];
        this.insertedRows = this.insertPayload.map((row, index) => {
          const payload = { ...row };
          payload.id ??= `${this.table}-${target.length + index + 1}`;
          return payload;
        });
        target.push(...this.insertedRows);
      }

      const limitedInserted = this.limitCount == null
        ? this.insertedRows
        : this.insertedRows.slice(0, this.limitCount);
      return {
        data: expectSingle ? (limitedInserted[0] ?? null) : limitedInserted,
        error: null,
      };
    }

    const rows = [...(this.tables[this.table] ?? [])].filter((row) =>
      this.matches(row)
    );

    if (this.orderColumn) {
      rows.sort((left, right) => {
        const leftValue = String(left[this.orderColumn!] ?? "");
        const rightValue = String(right[this.orderColumn!] ?? "");
        return this.ascending
          ? leftValue.localeCompare(rightValue)
          : rightValue.localeCompare(leftValue);
      });
    }

    const limitedRows = this.limitCount == null
      ? rows
      : rows.slice(0, this.limitCount);

    if (this.action === "update") {
      for (const row of limitedRows) {
        Object.assign(row, this.updatePayload);
      }
      return {
        data: expectSingle ? (limitedRows[0] ?? null) : limitedRows,
        error: null,
      };
    }

    return {
      data: expectSingle ? (limitedRows[0] ?? null) : limitedRows,
      error: null,
    };
  }

  private matches(row: TableRow): boolean {
    if (
      this.unexpiredAfter && row.expires_at != null &&
      Date.parse(String(row.expires_at)) <= Date.parse(this.unexpiredAfter)
    ) return false;
    return this.filters.every((filter) => {
      const value = row[filter.column];
      switch (filter.kind) {
        case "eq":
          return value === filter.value;
        case "in":
          return filter.values.includes(value);
        case "ilike":
          return String(value ?? "").toLowerCase().includes(
            filter.value.replaceAll("%", "").toLowerCase(),
          );
      }
    });
  }
}
