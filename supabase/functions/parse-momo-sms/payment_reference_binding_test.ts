import { confirmRayonReferenceMatch } from "../_shared/payments.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import {
  assertDeepEquals,
  assertEquals,
  FakeAdminClient,
  type TableStore,
} from "./reconciliation_test_support.ts";

type Kind = "ticket" | "shop" | "support";
function fixture(kind: Kind, overrides: Record<string, unknown> = {}) {
  const table = {
    ticket: "rs_tickets",
    shop: "rs_shop_orders",
    support: "rs_initiative_contributions",
  }[kind];
  const reference = `RS-${kind.toUpperCase()}-QA-BINDING`;
  const row = {
    id: "record-1",
    user_id: "payer-1",
    club_id: 24,
    momo_reference: reference,
    status: "pending",
    amount: 1000,
    amount_paid: 1000,
    total: 1000,
    ...overrides,
  };
  const tables: TableStore = {
    [table]: [row],
    pending_transactions: [{
      id: "checkout-1",
      user_id: "payer-1",
      reference,
      recipient_momo: "250788111222",
      amount: 1000,
      provider: "mtn_rwanda",
      status: "pending",
    }],
    african_football_clubs: [{
      id: 24,
      currency_code: "RWF",
      country_iso_code: "RW",
    }],
  };
  const client = new FakeAdminClient(tables);
  const confirm = (
    user_id: string | null = "payer-1",
    amount: number | null = 1000,
  ) =>
    confirmRayonReferenceMatch(
      client as unknown as ReturnType<typeof createAdminClient>,
      { reference, user_id },
      {
        source: "parse-momo-sms",
        timestamp: "2026-09-17T19:00:00Z",
        provider: "mtn_rwanda",
        amount,
        currency: "RWF",
        country: "RW",
        payeeNumberOrCode: "250788111222",
        transactionId: "SYNTHETIC-REFERENCE",
      },
    );
  return { table, tables, row, client, confirm };
}

for (const kind of ["ticket", "shop", "support"] as const) {
  for (const payer of [null, "", "another-payer"]) {
    Deno.test(`${kind} confirmation rejects missing or foreign payer ${JSON.stringify(payer)}`, async () => {
      const { tables, client, confirm } = fixture(kind);
      const before = structuredClone(tables);
      const result = await confirm(payer);
      assertEquals(
        result.matchStatus,
        "manual_review",
        "payer mismatch requires review",
      );
      assertDeepEquals(
        tables,
        before,
        "payer mismatch must not mutate records",
      );
      assertEquals(
        client.rpcCalls.length,
        0,
        "payer mismatch cannot award points or referrals",
      );
    });
  }
  for (const amount of [null, 0, -1, 1, 999, 1001, 1000.5, NaN, Infinity]) {
    Deno.test(`${kind} confirmation rejects invalid or mismatched amount ${amount}`, async () => {
      const { tables, client, confirm } = fixture(kind);
      const before = structuredClone(tables);
      const result = await confirm("payer-1", amount);
      assertEquals(
        result.matchStatus,
        "manual_review",
        "amount mismatch requires review",
      );
      assertDeepEquals(
        tables,
        before,
        "amount mismatch must not mutate records",
      );
      assertEquals(
        client.rpcCalls.length,
        0,
        "amount mismatch cannot award points or referrals",
      );
    });
  }
  for (
    const status of [
      "cancelled",
      "failed",
      "refunded",
      "void",
      "",
      "unrecognized",
    ]
  ) {
    Deno.test(`${kind} confirmation preserves terminal or unknown status ${status}`, async () => {
      const { tables, client, confirm } = fixture(kind, { status });
      const before = structuredClone(tables);
      const result = await confirm();
      assertEquals(
        result.matchStatus,
        "manual_review",
        "terminal evidence requires review",
      );
      assertDeepEquals(
        tables,
        before,
        "terminal evidence must not reopen records",
      );
      assertEquals(
        client.rpcCalls.length,
        0,
        "terminal evidence cannot award points or referrals",
      );
    });
  }
}

for (const kind of ["shop", "support"] as const) {
  Deno.test(`${kind} duplicate own reference is ambiguous and does not choose the newest row`, async () => {
    const { table, tables, row, confirm } = fixture(kind);
    tables[table].push({
      ...row,
      id: "record-2",
      created_at: "2026-09-17T19:01:00Z",
    });
    const before = structuredClone(tables);
    assertEquals(
      (await confirm()).matchStatus,
      "manual_review",
      "duplicate reference requires review",
    );
    assertDeepEquals(
      tables,
      before,
      "ambiguous reference cannot confirm either record",
    );
  });
}

Deno.test("ticket confirmation requires the full owned ticket bundle amount", async () => {
  const { table, tables, row, confirm } = fixture("ticket");
  tables[table].push({ ...row, id: "record-2" });
  const before = structuredClone(tables);
  assertEquals(
    (await confirm()).matchStatus,
    "manual_review",
    "single-ticket amount cannot confirm the bundle",
  );
  assertDeepEquals(
    tables,
    before,
    "underpayment leaves the whole bundle pending",
  );
});

Deno.test("ticket confirmation rejects a mixed active and cancelled bundle before any mutation", async () => {
  const { table, tables, row, confirm } = fixture("ticket");
  tables[table].push({ ...row, id: "record-2", status: "cancelled" });
  const before = structuredClone(tables);
  assertEquals(
    (await confirm("payer-1", 2000)).matchStatus,
    "manual_review",
    "mixed bundle requires review",
  );
  assertDeepEquals(tables, before, "mixed bundle must not partially confirm");
});

for (
  const response of [
    { data: null, error: new Error("Synthetic RPC failure") },
    { data: null, error: null },
    {
      data: {
        status: "confirmed",
        contribution_id: "different-record",
        newly_confirmed: true,
        points_awarded: 20,
        referral_activated: false,
      },
      error: null,
    },
    {
      data: {
        status: "confirmed",
        contribution_id: "record-1",
        newly_confirmed: "true",
        points_awarded: 20,
        referral_activated: false,
      },
      error: null,
    },
  ]
) {
  Deno.test(`support confirmation fails closed on RPC failure or malformed result ${JSON.stringify(response.data)}`, async () => {
    const { tables, client, confirm } = fixture("support");
    const before = structuredClone(tables);
    let calls = 0;
    client.rpc = async (name, args) => {
      calls++;
      assertEquals(
        name,
        "confirm_club_initiative_contribution",
        "atomic transition is the only mutation",
      );
      assertDeepEquals(args, {
        p_contribution_id: "record-1",
        p_user_id: "payer-1",
        p_reference: "RS-SUPPORT-QA-BINDING",
        p_amount: 1000,
      }, "RPC carries the verified binding");
      return response;
    };
    let rejected = false;
    try {
      await confirm();
    } catch {
      rejected = true;
    }
    assertEquals(
      rejected,
      true,
      "an unverified RPC outcome cannot report a matched payment",
    );
    assertEquals(
      calls,
      1,
      "no secondary rewards or referrals after failed confirmation",
    );
    assertDeepEquals(
      tables,
      before,
      "no fallback HTTP writes after RPC failure",
    );
  });
}

Deno.test("support confirmation preserves a database binding rejection after preflight", async () => {
  const { tables, client, confirm } = fixture("support");
  const before = structuredClone(tables);
  client.rpc = async () => ({
    data: {
      status: "manual_review",
      reason: "contribution_payment_binding_mismatch",
    },
    error: null,
  });
  assertEquals(
    (await confirm()).matchStatus,
    "manual_review",
    "locked state wins over the earlier HTTP read",
  );
  assertDeepEquals(
    tables,
    before,
    "no fallback writes when the database rejects a changed binding",
  );
});
