import { AsyncLocalStorage } from "node:async_hooks";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./auth.ts";
import { createLifecycleUserClient } from "./account_lifecycle_client.ts";
import { getSupabaseSecretKey, getSupabaseUrl } from "./supabase.ts";
import { readBoundedBytes } from "./http.ts";

const operationPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const footballCommands = [
  "discover-leagues",
  "register-league",
  "sync-fixtures",
  "sync-standings",
  "sync-live",
  "sync-history",
  "download-logos",
  "seed-leagues",
  "status",
  "full-sync",
  "auto-settle",
] as const;
const fields: Record<string, string[]> = {
  "discover-leagues": ["search", "country", "id"],
  "register-league": [
    "api_league_id",
    "season_year",
    "league_name",
    "sync_fixtures",
    "sync_standings",
    "sync_live",
    "sync_squads",
  ],
  "sync-history": ["league_id", "season_year"],
  "seed-leagues": ["dry_run"],
};
export interface FootballCommand {
  action: "submit" | "status";
  operationId: string;
  arguments: Record<string, unknown> | null;
}
export interface FootballRpcClient {
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): PromiseLike<
    { data: unknown; error: { code?: string; message?: string } | null }
  >;
}
export function parseFootballCommand(
  raw: Record<string, unknown>,
): FootballCommand {
  if (
    (raw.action !== "submit" && raw.action !== "status") ||
    typeof raw.operation_id !== "string" ||
    !operationPattern.test(raw.operation_id)
  ) {
    throw new HttpError(
      400,
      "Use the original operation_id and submit or status action.",
    );
  }
  const allowed = new Set([
    "action",
    "operation_id",
    ...(raw.action === "submit"
      ? ["command", ...(fields[String(raw.command)] ?? [])]
      : []),
  ]);
  if (Object.keys(raw).some((key) => !allowed.has(key))) {
    throw new HttpError(400, "Unexpected global football command fields.");
  }
  if (raw.action === "status") {
    return { action: "status", operationId: raw.operation_id, arguments: null };
  }
  if (
    !footballCommands.includes(raw.command as typeof footballCommands[number])
  ) throw new HttpError(400, "Unknown football command.");
  const args: Record<string, unknown> = { command: raw.command };
  for (const key of fields[String(raw.command)] ?? []) {
    const value = raw[key];
    if (value === undefined || value === null) continue;
    if (["id", "api_league_id", "league_id", "season_year"].includes(key)) {
      if (
        !Number.isSafeInteger(value) || Number(value) < 1 ||
        Number(value) > 2147483647 ||
        (key === "season_year" &&
          (Number(value) < 1900 || Number(value) > 2200))
      ) throw new HttpError(400, "Invalid original football target.");
    } else if (key.startsWith("sync_") || key === "dry_run") {
      if (typeof value !== "boolean") {
        throw new HttpError(400, "Invalid original sync flag.");
      }
    } else if (
      typeof value !== "string" || !value.trim() || value.length > 160
    ) throw new HttpError(400, "Invalid original football search.");
    args[key] = typeof value === "string" ? value.trim() : value;
  }
  if (raw.command === "register-league" && args.api_league_id === undefined) {
    throw new HttpError(400, "api_league_id is required.");
  }
  return { action: "submit", operationId: raw.operation_id, arguments: args };
}
export async function footballRpc(
  client: FootballRpcClient,
  name: string,
  args: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const result = await client.rpc(name, args);
  if (result.error) {
    throw new HttpError(
      result.error.code === "42501" ? 403 : 409,
      "Check the original global football command; dispatch authority is unavailable.",
    );
  }
  if (
    !result.data || typeof result.data !== "object" ||
    Array.isArray(result.data)
  ) throw new HttpError(502, "Invalid football command receipt.");
  return result.data as Record<string, unknown>;
}
const hashPattern = /^[0-9a-f]{64}$/;
const resultStrings = new Set([
  "league",
  "name",
  "type",
  "country",
  "country_code",
  "competition_slug",
  "league_name",
  "status",
  "sync_status",
  "sync_type",
  "started_at",
  "completed_at",
  "last_synced_at",
  "last_standings_synced_at",
  "last_live_synced_at",
]);
const resultNumbers = new Set([
  "api_league_id",
  "current_season",
  "season_year",
  "fixtures_fetched",
  "fixtures_upserted",
  "teams_upserted",
  "standings_fetched",
  "standings_upserted",
  "fixtures_processed",
  "stats_synced",
  "events_synced",
  "lineups_synced",
  "api_requests_used",
  "fixtures_checked",
  "fixtures_settled",
  "total_predictions_won",
  "total_predictions_lost",
  "total_fet_awarded",
  "predict_pools_locked",
  "teams_downloaded",
  "leagues_downloaded",
  "flags_downloaded",
  "skipped",
  "total",
  "registered",
  "records_fetched",
  "records_upserted",
  "dailyLimit",
  "dailyRemaining",
  "minuteLimit",
  "minuteRemaining",
  "error_count",
  "reconciled_storage_count",
]);
const resultContainers = new Set([
  "data",
  "rate_limit",
  "sync",
  "settlement",
  "live",
  "fixtures",
  "standings",
  "history",
  "leagues",
  "tracked_leagues",
  "recent_logs",
]);
/** Public operator results preserve bounded discovery/progress, never raw provider/account JSON. */
export function publicFootballResult(raw: unknown, depth = 0): unknown {
  if (depth > 6) {
    throw new HttpError(502, "Football result exceeds its public boundary.");
  }
  if (raw === null) return null;
  if (Array.isArray(raw)) {
    if (raw.length > 512) {
      throw new HttpError(502, "Football result exceeds its public boundary.");
    }
    return raw.map((value) => publicFootballResult(value, depth + 1));
  }
  if (!raw || typeof raw !== "object") {
    throw new HttpError(502, "Invalid public football result.");
  }
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw)) {
    if (resultContainers.has(key)) {
      out[key] = publicFootballResult(value, depth + 1);
    } else if (
      resultStrings.has(key) &&
      (value === null || typeof value === "string" && value.length <= 160)
    ) out[key] = value;
    else if (
      resultNumbers.has(key) &&
      (value === null ||
        Number.isSafeInteger(value) && Number(value) >= 0 &&
          Number(value) <= 1000000000)
    ) out[key] = value;
    else if (
      ["id", "competition_id", "sync_config_id"].includes(key) &&
      (value === null ||
        typeof value === "string" && /^[0-9a-f-]{36}$/.test(value))
    ) out[key] = value;
    else if (
      [
        "success",
        "is_active",
        "sync_fixtures",
        "sync_standings",
        "sync_live",
        "sync_squads",
      ].includes(key) && typeof value === "boolean"
    ) out[key] = value;
    else if (
      key === "seasons_available" && Array.isArray(value) &&
      value.length <= 100 && value.every((y) =>
        Number.isSafeInteger(y) && y >= 1900 && y <= 2200
      )
    ) out[key] = value;
    else if (
      key === "logo" && typeof value === "string" && value.length <= 2048 &&
      /^https:\/\//.test(value)
    ) out[key] = value;
    else if (key === "error") {
      out.error = "Football synchronization needs attention.";
    } else if (key === "errors" && Array.isArray(value)) {
      out.error_count = value.length;
    }
  }
  if (new TextEncoder().encode(JSON.stringify(out)).length > 65536) {
    throw new HttpError(502, "Football result exceeds its public boundary.");
  }
  return out;
}
export function publicFootballReceipt(
  raw: Record<string, unknown>,
  operationId: string,
  actorId: string,
  expected?: { argumentsSha256: string; snapshotSha256: string },
): Record<string, unknown> {
  const c = raw.command as Record<string, unknown> | undefined;
  if (
    !c || c.version !== 1 || c.operation_id !== operationId ||
    c.actor_id !== actorId || c.scope !== "global" ||
    ![
      "not_admitted",
      "admitted",
      "processing",
      "completed",
      "unknown",
      "blocked",
    ].includes(String(c.state))
  ) {
    throw new HttpError(
      502,
      "Football receipt does not match the original global operation.",
    );
  }
  const command: Record<string, unknown> = {
    version: 1,
    operation_id: operationId,
    actor_id: actorId,
    scope: "global",
    state: c.state,
  };
  if (c.state === "not_admitted") {
    if (
      raw.requests != null || raw.result != null || c.command != null ||
      c.arguments_sha256 != null || c.snapshot_sha256 != null
    ) throw new HttpError(502, "Invalid unadmitted football receipt.");
    return { command, requests: null, result: null };
  }
  if (
    !footballCommands.includes(c.command as typeof footballCommands[number]) ||
    typeof c.arguments_sha256 !== "string" ||
    !hashPattern.test(c.arguments_sha256) ||
    typeof c.snapshot_sha256 !== "string" ||
    !hashPattern.test(c.snapshot_sha256) ||
    expected &&
      (c.arguments_sha256 !== expected.argumentsSha256 ||
        c.snapshot_sha256 !== expected.snapshotSha256)
  ) {
    throw new HttpError(
      502,
      "Football receipt changed its original payload or snapshot.",
    );
  }
  Object.assign(command, {
    command: c.command,
    arguments_sha256: c.arguments_sha256,
    snapshot_sha256: c.snapshot_sha256,
  });
  const counts = raw.requests as Record<string, unknown> | undefined;
  if (!counts) throw new HttpError(502, "Invalid football request totals.");
  const requests: Record<string, number> = {};
  for (const k of ["accepted", "rejected", "unknown", "started"]) {
    if (
      !Number.isSafeInteger(counts[k]) || Number(counts[k]) < 0 ||
      Number(counts[k]) > 100
    ) throw new HttpError(502, "Invalid football request totals.");
    requests[k] = Number(counts[k]);
  }
  if (Object.values(requests).reduce((a, b) => a + b, 0) > 100) {
    throw new HttpError(502, "Invalid football request totals.");
  }
  return {
    command,
    requests,
    result: raw.result == null ? null : publicFootballResult(raw.result),
  };
}

export function createFootballCallerClient(
  authorization: string,
): FootballRpcClient {
  return createLifecycleUserClient(authorization);
}
const ownership = new AsyncLocalStorage<FootballSyncContext>();
export function currentFootballSyncContext(): FootballSyncContext | undefined {
  return ownership.getStore();
}
export function withFootballSyncContext<T>(
  context: FootballSyncContext,
  work: () => Promise<T>,
): Promise<T> {
  return ownership.run(context, work);
}
function bytesToBase64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 8192) {
    s += String.fromCharCode(...bytes.subarray(i, i + 8192));
  }
  return btoa(s);
}
function base64ToBytes(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
}

/** All request-local ownership is private and immutable; cron has no context. */
export class FootballSyncContext {
  readonly headers: Record<string, string>;
  constructor(
    readonly client: FootballRpcClient,
    readonly operationId: string,
    readonly leaseToken: string,
    readonly proofId: string,
    readonly deadlineAt: number,
    readonly snapshot: Record<string, unknown>,
    readonly transport: typeof fetch = fetch,
    readonly mode: "dispatch" | "reconcile_storage" = "dispatch",
  ) {
    this.headers = {
      "x-africlub-football-operation": operationId,
      "x-africlub-football-lease": leaseToken,
      "x-africlub-football-proof": proofId,
    };
  }
  async assert(): Promise<void> {
    await footballRpc(this.client, "assert_manual_football_sync", {
      p_operation_id: this.operationId,
      p_lease_token: this.leaseToken,
    });
    if (!Number.isFinite(this.deadlineAt) || this.deadlineAt <= Date.now()) {
      throw new HttpError(403, "Original football assurance expired.");
    }
  }
  async providerFetch(
    input: string | URL,
    init: RequestInit = {},
  ): Promise<Response> {
    if (this.mode !== "dispatch") {
      throw new HttpError(
        403,
        "Storage reconciliation cannot start a provider request.",
      );
    }
    const url = new URL(input);
    if (url.protocol !== "https:" || init.method && init.method !== "GET") {
      throw new HttpError(
        400,
        "Only the original HTTPS provider GET is allowed.",
      );
    }
    if (
      url.username || url.password || url.port && url.port !== "443" ||
      ![
        "v3.football.api-sports.io",
        "media.api-sports.io",
        "media-3.api-sports.io",
        "media.api-football.com",
      ].includes(url.hostname)
    ) {
      throw new HttpError(
        400,
        "The original provider asset origin is unavailable.",
      );
    }
    if (url.hostname === "v3.football.api-sports.io") url.searchParams.sort();
    const start = await footballRpc(
      this.client,
      "start_manual_football_request",
      {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_url: url.toString(),
      },
    );
    if (start.cached === true) {
      await this.assert();
      return new Response(
        new Uint8Array(base64ToBytes(String(start.response_body))).buffer,
        {
          status: Number(start.response_status),
          headers: {
            "content-type": String(
              (start.response_headers as Record<string, string>)[
                "content-type"
              ] ?? "application/json",
            ),
          },
        },
      );
    }
    if (
      typeof start.request_id !== "string" ||
      !operationPattern.test(start.request_id)
    ) throw new HttpError(502, "Invalid original provider barrier.");
    // The started transaction commits before the last authority check and GET.
    await this.assert();
    try {
      const response = await this.transport(url.toString(), {
        ...init,
        redirect: "error",
        signal: AbortSignal.any([
          AbortSignal.timeout(
            Math.max(1, Math.min(15000, this.deadlineAt - Date.now())),
          ),
          ...(init.signal ? [init.signal] : []),
        ]),
      });
      const bytes = await readBoundedBytes(response, {
        maxBytes: 4 * 1024 * 1024,
        timeoutMs: 5000,
      });
      const headers = Object.fromEntries(
        [...response.headers].filter(([k]) =>
          [
            "content-type",
            "x-ratelimit-requests-limit",
            "x-ratelimit-requests-remaining",
            "x-ratelimit-limit",
            "x-ratelimit-remaining",
          ].includes(k.toLowerCase())
        ),
      );
      await footballRpc(this.client, "complete_manual_football_request", {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_request_id: start.request_id,
        p_status: response.status,
        p_headers: headers,
        p_body: bytesToBase64(bytes),
      });
      await this.assert();
      return new Response(new Uint8Array(bytes).buffer, {
        status: response.status,
        headers,
      });
    } catch (error) {
      // Failure after started remains uncertain, even if its recording response is lost.
      await footballRpc(this.client, "complete_manual_football_request", {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_request_id: start.request_id,
        p_status: null,
        p_headers: {},
        p_body: null,
      }).catch(() => {});
      throw new HttpError(
        409,
        "Provider outcome is unknown. Recover the original command before any further work.",
      );
    }
  }
  async uploadLogo(
    client: SupabaseClient,
    path: string,
    blob: Blob,
  ): Promise<boolean> {
    if (this.mode !== "dispatch") {
      throw new HttpError(403, "Reconciliation cannot upload.");
    }
    const start = await footballRpc(
      this.client,
      "start_manual_football_request",
      {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_url: `storage:football-assets/${path}`,
      },
    );
    if (start.cached === true) {
      await this.assert();
      return true;
    }
    const bytes = new Uint8Array(await blob.arrayBuffer());
    const hash = await footballContentSha256(bytes);
    if (
      start.content_sha256 !== hash || start.byte_length !== bytes.length ||
      start.content_type !== blob.type ||
      typeof start.request_id !== "string" ||
      !operationPattern.test(start.request_id)
    ) throw new HttpError(502, "Original Storage byte binding changed.");
    await this.assert();
    try {
      const result = await client.storage.from("football-assets").upload(
        path,
        blob,
        {
          contentType: blob.type,
          upsert: true,
          metadata: {
            manual_football_operation: this.operationId,
            manual_football_lease: this.leaseToken,
            manual_football_proof: this.proofId,
            manual_football_request: start.request_id,
            content_sha256: hash,
          },
        },
      );
      if (result.error) {
        throw new HttpError(
          409,
          "Original Storage upload could not be confirmed.",
        );
      }
      await this.assert();
      const original = await client.storage.from("football-assets").download(
        path,
      );
      if (
        original.error || !original.data ||
        original.data.size !== bytes.length ||
        await footballContentSha256(
            new Uint8Array(await original.data.arrayBuffer()),
          ) !== hash
      ) {
        throw new HttpError(
          409,
          "Original Storage bytes could not be confirmed.",
        );
      }
      await footballRpc(this.client, "complete_manual_football_request", {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_request_id: start.request_id,
        p_status: 200,
        p_headers: { "content-type": blob.type },
        p_body: bytesToBase64(bytes),
      });
      return true;
    } catch (error) {
      await footballRpc(this.client, "complete_manual_football_request", {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_request_id: start.request_id,
        p_status: null,
        p_headers: {},
        p_body: null,
      }).catch(() => {});
      throw new HttpError(
        409,
        "Storage outcome is unknown. Reconcile this original upload before any further work.",
      );
    }
  }
  async reconcileStorageUploads(
    client: SupabaseClient,
    uploads: unknown,
  ): Promise<number> {
    if (
      this.mode !== "reconcile_storage" || !Array.isArray(uploads) ||
      uploads.length < 1 || uploads.length > 100
    ) throw new HttpError(502, "Invalid original Storage recovery.");
    let reconciled = 0;
    for (const value of uploads) {
      const u = value as Record<string, unknown>;
      if (
        !u || typeof u.request_id !== "string" ||
        !operationPattern.test(u.request_id) || typeof u.path !== "string" ||
        !/^(teams|leagues|flags)\/[a-z0-9-]+\.(png|svg)$/.test(u.path) ||
        typeof u.content_sha256 !== "string" ||
        !hashPattern.test(u.content_sha256) ||
        !Number.isSafeInteger(u.byte_length) || Number(u.byte_length) < 1 ||
        Number(u.byte_length) > 2097152
      ) throw new HttpError(502, "Invalid original Storage recovery binding.");
      await this.assert();
      const original = await client.storage.from("football-assets").download(
        u.path,
      );
      if (
        original.error || !original.data ||
        original.data.size !== u.byte_length ||
        original.data.type !== u.content_type
      ) {
        throw new HttpError(
          409,
          "Original Storage object is still unconfirmed.",
        );
      }
      const bytes = new Uint8Array(await original.data.arrayBuffer());
      if (await footballContentSha256(bytes) !== u.content_sha256) {
        throw new HttpError(409, "Original Storage bytes differ.");
      }
      await footballRpc(this.client, "complete_manual_football_request", {
        p_operation_id: this.operationId,
        p_lease_token: this.leaseToken,
        p_request_id: u.request_id,
        p_status: 200,
        p_headers: { "content-type": u.content_type },
        p_body: bytesToBase64(bytes),
      });
      reconciled++;
    }
    return reconciled;
  }
  /** Actual SDK calls carry the private context to post-row-wait SQL guards. */
  async sdkFetch(
    input: RequestInfo | URL,
    init: RequestInit = {},
  ): Promise<Response> {
    await this.assert();
    const url = new URL(
      typeof input === "string"
        ? input
        : input instanceof URL
        ? input
        : input.url,
    );
    if (
      url.pathname.endsWith("/football_sync_config") &&
      (init.method ?? "GET") === "GET"
    ) {
      const ids = (this.snapshot.configs as Record<string, unknown>[] ?? [])
        .map((c) => String(c.id));
      url.searchParams.set(
        "id",
        `in.(${ids.join(",") || "00000000-0000-0000-0000-000000000000"})`,
      );
    }
    if (
      this.mode === "reconcile_storage" &&
      ((init.method ?? "GET") !== "GET" ||
        !url.pathname.startsWith("/storage/v1/object/"))
    ) throw new HttpError(403, "Storage reconciliation is read-only.");
    const headers = new Headers(init.headers);
    for (const [key, value] of Object.entries(this.headers)) {
      headers.set(key, value);
    }
    const response = await this.transport(url, { ...init, headers });
    const bytes = await readBoundedBytes(response, {
      maxBytes: 4 * 1024 * 1024,
      timeoutMs: Math.max(1, Math.min(15000, this.deadlineAt - Date.now())),
    });
    await this.assert();
    const boundedHeaders = new Headers(response.headers);
    boundedHeaders.delete("content-encoding");
    boundedHeaders.delete("content-length");
    return new Response(new Uint8Array(bytes).buffer, {
      status: response.status,
      statusText: response.statusText,
      headers: boundedHeaders,
    });
  }
  createServiceClient(): SupabaseClient {
    return createClient(getSupabaseUrl(), getSupabaseSecretKey(), {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { fetch: (input, init) => this.sdkFetch(input, init) },
    });
  }
}
export function footballProviderFetch(
  input: string | URL,
  init: RequestInit = {},
): Promise<Response> {
  return currentFootballSyncContext()?.providerFetch(input, init) ??
    fetch(input, init);
}

export async function footballContentSha256(
  bytes: Uint8Array,
): Promise<string> {
  return Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new Uint8Array(bytes).buffer),
    ),
  ).map((v) => v.toString(16).padStart(2, "0")).join("");
}
