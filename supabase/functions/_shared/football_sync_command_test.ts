import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert";
import {
  footballProviderFetch,
  type FootballRpcClient,
  FootballSyncContext,
  parseFootballCommand,
  publicFootballReceipt,
  withFootballSyncContext,
} from "./football_sync_command.ts";
import { createFootballSyncHandler } from "../football-sync/index.ts";
import { HttpError } from "./auth.ts";
const op = "99969700-0000-4000-8000-000000000701",
  actor = "99969700-0000-4000-8000-000000000001",
  proof = "99969700-0000-4000-8000-000000000501",
  lease = "99969700-0000-4000-8000-000000000801",
  requestId = "99969700-0000-4000-8000-000000000901";
function rpcClient(
  call: (
    name: string,
    args: Record<string, unknown>,
  ) => unknown | Promise<unknown>,
): FootballRpcClient {
  return {
    rpc: async (name, args) => ({ data: await call(name, args), error: null }),
  };
}
function context(
  client: FootballRpcClient,
  transport: typeof fetch,
  deadline = Date.now() + 30000,
) {
  return new FootballSyncContext(client, op, lease, proof, deadline, {
    configs: [{ id: "99969700-0000-4000-8000-000000000601" }],
    live: [],
  }, transport);
}
Deno.test("manual parser binds original UUID and finite global command fields", () => {
  assertEquals(
    parseFootballCommand({
      action: "submit",
      operation_id: op,
      command: "sync-history",
      league_id: 39,
      season_year: 2025,
    }).arguments,
    { command: "sync-history", league_id: 39, season_year: 2025 },
  );
  for (
    const raw of [
      { command: "status" },
      {
        action: "submit",
        operation_id: op,
        command: "status",
        actor_id: actor,
      },
      {
        action: "submit",
        operation_id: op,
        command: "status",
        assurance_club_id: 7,
      },
      { action: "status", operation_id: op, command: "status" },
      { action: "submit", operation_id: op, command: "register-league" },
      {
        action: "submit",
        operation_id: op,
        command: "sync-history",
        season_year: NaN,
      },
    ]
  ) assertThrows(() => parseFootballCommand(raw), HttpError);
});
Deno.test("public receipt binds actor/global original ID and strips all dispatch context", () => {
  const raw = {
    command: {
      version: 1,
      operation_id: op,
      actor_id: actor,
      scope: "global",
      state: "admitted",
      command: "status",
      arguments_sha256: "a".repeat(64),
      snapshot_sha256: "b".repeat(64),
      dispatch_proof_id: proof,
      bearer: "hidden",
    },
    requests: { accepted: 0, rejected: 0, unknown: 0, started: 0 },
    dispatch_proof_id: proof,
    lease_token: lease,
    snapshot: { private: true },
  };
  assertEquals(Object.keys(publicFootballReceipt(raw, op, actor)), [
    "command",
    "requests",
    "result",
  ]);
  assertThrows(
    () =>
      publicFootballReceipt(
        { ...raw, command: { ...raw.command, scope: "club" } },
        op,
        actor,
      ),
    HttpError,
  );
  assertThrows(() => publicFootballReceipt(raw, op, "other"), HttpError);
});
Deno.test("provider barrier commits before GET and completion uses original lease", async () => {
  const events: string[] = [];
  const c = context(
    rpcClient((n, a) => {
      events.push(n);
      assertEquals(a.p_operation_id, op);
      assertEquals(a.p_lease_token, lease);
      return n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true };
    }),
    async () => {
      events.push("GET");
      return Response.json({ response: [] });
    },
  );
  const response = await withFootballSyncContext(
    c,
    () => footballProviderFetch("https://v3.football.api-sports.io/status"),
  );
  assertEquals(response.status, 200);
  assertEquals(events, [
    "start_manual_football_request",
    "assert_manual_football_sync",
    "GET",
    "complete_manual_football_request",
    "assert_manual_football_sync",
  ]);
});
Deno.test("actual started wait ending in revoked authority makes zero provider calls", async () => {
  let calls = 0;
  const c = context(
    rpcClient((n) => {
      if (n === "assert_manual_football_sync") {
        throw new HttpError(403, "revoked after wait");
      }
      return { request_id: requestId, cached: false };
    }),
    () => {
      calls++;
      return Promise.resolve(Response.json({}));
    },
  );
  await assertRejects(
    () => c.providerFetch("https://v3.football.api-sports.io/status"),
    HttpError,
  );
  assertEquals(calls, 0);
});
Deno.test("expired immutable local deadline cannot borrow an allowed newer server proof", async () => {
  let calls = 0;
  const c = context(
    rpcClient((n) =>
      n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true }
    ),
    () => {
      calls++;
      return Promise.resolve(Response.json({}));
    },
    Date.now() - 1,
  );
  await assertRejects(
    () => c.providerFetch("https://v3.football.api-sports.io/status"),
    HttpError,
  );
  assertEquals(calls, 0);
});
Deno.test("lost provider response records unknown once and never auto retries", async () => {
  let calls = 0;
  const events: Record<string, unknown>[] = [];
  const c = context(
    rpcClient((n, a) => {
      if (n === "complete_manual_football_request") events.push(a);
      return n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true };
    }),
    () => {
      calls++;
      throw new TypeError("response lost");
    },
  );
  await assertRejects(
    () => c.providerFetch("https://v3.football.api-sports.io/status"),
    HttpError,
  );
  assertEquals(calls, 1);
  assertEquals(events[0].p_status, null);
  assertEquals(events[0].p_request_id, requestId);
});
Deno.test("accepted original GET is recovered from private bytes without another request", async () => {
  let calls = 0;
  const c = context(
    rpcClient((n) =>
      n === "start_manual_football_request"
        ? {
          cached: true,
          response_status: 200,
          response_headers: { "content-type": "application/json" },
          response_body: btoa('{"response":[]}'),
        }
        : { allowed: true }
    ),
    () => {
      calls++;
      throw new Error("no repeat");
    },
  );
  assertEquals(
    await (await c.providerFetch("https://v3.football.api-sports.io/status"))
      .json(),
    { response: [] },
  );
  assertEquals(calls, 0);
});
Deno.test("response-loss after completion never converts its original request into a retry", async () => {
  let calls = 0;
  const c = context(
    rpcClient((n) => {
      if (n === "complete_manual_football_request") {
        throw new Error("receipt lost");
      }
      return n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true };
    }),
    () => {
      calls++;
      return Promise.resolve(Response.json({ response: [] }));
    },
  );
  await assertRejects(
    () => c.providerFetch("https://v3.football.api-sports.io/status"),
    HttpError,
  );
  assertEquals(calls, 1);
});
Deno.test("request-local ownership stays isolated during overlapping manual commands", async () => {
  const seen: string[] = [];
  let release!: () => void;
  const wait = new Promise<void>((r) => release = r);
  const a = context(
    rpcClient((n) => {
      seen.push("a:" + n);
      return n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true };
    }),
    async () => {
      await wait;
      return Response.json({ response: [] });
    },
  );
  const b = context(
    rpcClient((n) => {
      seen.push("b:" + n);
      return n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true };
    }),
    async () => Response.json({ response: [] }),
  );
  const first = withFootballSyncContext(
    a,
    () => footballProviderFetch("https://v3.football.api-sports.io/status"),
  );
  await withFootballSyncContext(
    b,
    () => footballProviderFetch("https://v3.football.api-sports.io/status"),
  );
  release();
  await first;
  assertEquals(
    seen.filter((v) => v === "a:start_manual_football_request").length,
    1,
  );
  assertEquals(
    seen.filter((v) => v === "b:start_manual_football_request").length,
    1,
  );
});
Deno.test("actual Supabase SDK carries private operation headers and frozen config filter", async () => {
  const savedUrl = Deno.env.get("SUPABASE_URL"),
    savedKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://supabase.test");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "synthetic-service");
  let observed = "", headers = new Headers();
  const c = context(
    rpcClient(() => ({ allowed: true })),
    async (input, init) => {
      observed = String(input);
      headers = new Headers(init?.headers);
      return Response.json([]);
    },
  );
  try {
    const result = await c.createServiceClient().from("football_sync_config")
      .select("*").eq("is_active", true);
    assertEquals(result.error, null);
    assertEquals(headers.get("x-africlub-football-proof"), proof);
    assertEquals(headers.get("x-africlub-football-operation"), op);
    assertEquals(
      new URL(observed).searchParams.get("id"),
      "in.(99969700-0000-4000-8000-000000000601)",
    );
  } finally {
    if (savedUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", savedUrl);
    if (savedKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", savedKey);
  }
});
Deno.test("manual old GET and missing original key fail before service or provider", async () => {
  const handler = createFootballSyncHandler({
    requireCronSecret: () => {
      throw new HttpError(401, "not cron");
    },
    requireGlobalAdminCaller: async () => ({ userId: actor } as Awaited<
      ReturnType<typeof import("./auth.ts").requireGlobalAdminCaller>
    >),
    createAdminClient: () => {
      throw new Error("no service work");
    },
  });
  assertEquals(
    (await handler(new Request("https://test/football-sync?command=status")))
      .status,
    400,
  );
  assertEquals(
    (await handler(
      new Request("https://test/football-sync", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ command: "status" }),
      }),
    )).status,
    400,
  );
});
Deno.test("manual recovery is read-only and cannot claim service/provider authority", async () => {
  const names: string[] = [];
  const handler = createFootballSyncHandler({
    requireCronSecret: () => {
      throw new HttpError(401, "not cron");
    },
    requireGlobalAdminCaller: async () => ({ userId: actor } as Awaited<
      ReturnType<typeof import("./auth.ts").requireGlobalAdminCaller>
    >),
    createFootballCallerClient: () =>
      rpcClient((n) => {
        names.push(n);
        return {
          command: {
            version: 1,
            operation_id: op,
            actor_id: actor,
            scope: "global",
            state: "unknown",
            command: "status",
            arguments_sha256: "a".repeat(64),
            snapshot_sha256: "b".repeat(64),
          },
          requests: { unknown: 1, accepted: 0, rejected: 0, started: 0 },
        };
      }),
    createAdminClient: () => {
      throw new Error("recovery must not dispatch");
    },
  });
  const response = await handler(
    new Request("https://test/football-sync", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action: "status", operation_id: op }),
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(names, ["recover_manual_football_sync"]);
});
Deno.test("hostile nested receipt fields and raw provider/account result keys never cross public boundary", () => {
  const receipt = {
    command: {
      version: 1,
      operation_id: op,
      actor_id: actor,
      scope: "global",
      state: "completed",
      command: "status",
      arguments_sha256: "a".repeat(64),
      snapshot_sha256: "b".repeat(64),
      dispatch_proof_id: proof,
      jwt: "secret",
    },
    requests: {
      accepted: 1,
      rejected: 0,
      unknown: 0,
      started: 0,
      jwt: "secret",
    },
    result: {
      success: true,
      data: {
        api_status: { account: { email: "secret" } },
        tracked_leagues: [{
          league_name: "League",
          jwt: "secret",
          metadata: { private: true },
        }],
      },
    },
  };
  const text = JSON.stringify(publicFootballReceipt(receipt, op, actor));
  assertEquals(text.includes("secret"), false);
  assertEquals(text.includes("private"), false);
  assertEquals(text.includes("dispatch_proof_id"), false);
  assertThrows(
    () =>
      publicFootballReceipt(
        {
          ...receipt,
          command: { ...receipt.command, arguments_sha256: "changed" },
        },
        op,
        actor,
      ),
    HttpError,
  );
  assertThrows(
    () =>
      publicFootballReceipt(
        {
          ...receipt,
          requests: { accepted: 101, rejected: 0, unknown: 0, started: 0 },
        },
        op,
        actor,
      ),
    HttpError,
  );
});
Deno.test("manual provider cannot follow redirects or use an unapproved snapshot origin", async () => {
  let calls = 0;
  const c = context(
    rpcClient((n) =>
      n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true }
    ),
    async (_input, init) => {
      calls++;
      assertEquals(init?.redirect, "error");
      return Response.json({ response: [] });
    },
  );
  await assertRejects(
    () => c.providerFetch("https://127.0.0.1/private"),
    HttpError,
  );
  assertEquals(calls, 0);
  await c.providerFetch("https://media.api-sports.io/football/teams/123.png");
  assertEquals(calls, 1);
});
Deno.test("manual missing configured football-assets bucket fails before any GET or creation", async () => {
  const { downloadLogos } = await import("../football-sync/download-logos.ts");
  let created = 0;
  const fake = {
    storage: {
      getBucket: async () => ({ data: null }),
      createBucket: () => {
        created++;
        throw new Error("no create");
      },
    },
  } as unknown as import("npm:@supabase/supabase-js@2").SupabaseClient;
  const c = context(rpcClient(() => ({ allowed: true })), () => {
    throw new Error("no GET");
  });
  await assertRejects(
    () => withFootballSyncContext(c, () => downloadLogos(fake)),
    Error,
    "configured football-assets bucket",
  );
  assertEquals(created, 0);
});
Deno.test("actual Storage SDK uploads original bytes+metadata once and verifies downloaded hash", async () => {
  const { footballContentSha256 } = await import("./football_sync_command.ts");
  const bytes = new Uint8Array([1, 2, 3]);
  const sha = await footballContentSha256(bytes);
  const savedUrl = Deno.env.get("SUPABASE_URL"),
    savedKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://supabase.test");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "synthetic-service");
  const calls: string[] = [];
  let metadata: Record<string, unknown> = {};
  const c = context(
    rpcClient((n, a) => {
      calls.push(n);
      if (n === "start_manual_football_request") {
        assertEquals(a.p_url, "storage:football-assets/teams/123.png");
        return {
          cached: false,
          request_id: requestId,
          content_sha256: sha,
          byte_length: 3,
          content_type: "image/png",
        };
      }
      return { allowed: true };
    }),
    async (input, init) => {
      calls.push(init?.method ?? "GET");
      if (init?.method === "POST") {
        const body = init.body as FormData;
        metadata = JSON.parse(String(body.get("metadata")));
        return Response.json({
          Key: "football-assets/teams/123.png",
          Id: "object-1",
        });
      }
      return new Response(bytes, { headers: { "content-type": "image/png" } });
    },
  );
  try {
    assertEquals(
      await c.uploadLogo(
        c.createServiceClient(),
        "teams/123.png",
        new Blob([bytes], { type: "image/png" }),
      ),
      true,
    );
    assertEquals(metadata.manual_football_operation, op);
    assertEquals(metadata.manual_football_request, requestId);
    assertEquals(metadata.content_sha256, sha);
    assertEquals(calls.filter((x) => x === "POST").length, 1);
    assertEquals(calls.filter((x) => x === "GET").length, 1);
    assertEquals(calls.at(-1), "complete_manual_football_request");
  } finally {
    if (savedUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", savedUrl);
    if (savedKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", savedKey);
  }
});
Deno.test("unknown Storage ACK is retained once and never auto uploads again", async () => {
  const { footballContentSha256 } = await import("./football_sync_command.ts");
  const bytes = new Uint8Array([1, 2, 3]),
    sha = await footballContentSha256(bytes);
  let uploads = 0;
  const completions: Record<string, unknown>[] = [];
  const c = context(
    rpcClient((n, a) => {
      if (n === "complete_manual_football_request") completions.push(a);
      return n === "start_manual_football_request"
        ? {
          request_id: requestId,
          cached: false,
          content_sha256: sha,
          byte_length: 3,
          content_type: "image/png",
        }
        : { allowed: true };
    }),
    fetch,
  );
  const fake = {
    storage: {
      from: () => ({
        upload: () => {
          uploads++;
          throw new TypeError("ACK lost");
        },
      }),
    },
  } as unknown as import("npm:@supabase/supabase-js@2").SupabaseClient;
  await assertRejects(
    () =>
      c.uploadLogo(
        fake,
        "teams/123.png",
        new Blob([bytes], { type: "image/png" }),
      ),
    HttpError,
  );
  assertEquals(uploads, 1);
  assertEquals(completions[0].p_status, null);
});
Deno.test("fresh Storage reconciliation reads only the exact original bytes and cannot start provider/publication", async () => {
  const { footballContentSha256 } = await import("./football_sync_command.ts");
  const bytes = new Uint8Array([1, 2, 3]),
    sha = await footballContentSha256(bytes);
  let reads = 0;
  const names: string[] = [];
  const c = new FootballSyncContext(
    rpcClient((n) => {
      names.push(n);
      return { allowed: true };
    }),
    op,
    lease,
    proof,
    Date.now() + 30000,
    { configs: [] },
    fetch,
    "reconcile_storage",
  );
  const fake = {
    storage: {
      from: () => ({
        download: async (path: string) => {
          assertEquals(path, "teams/123.png");
          reads++;
          return {
            error: null,
            data: new Blob([bytes], { type: "image/png" }),
          };
        },
      }),
    },
  } as unknown as import("npm:@supabase/supabase-js@2").SupabaseClient;
  assertEquals(
    await c.reconcileStorageUploads(fake, [{
      request_id: requestId,
      path: "teams/123.png",
      content_sha256: sha,
      byte_length: 3,
      content_type: "image/png",
    }]),
    1,
  );
  assertEquals(reads, 1);
  await assertRejects(
    () => c.providerFetch("https://v3.football.api-sports.io/status"),
    HttpError,
  );
  await assertRejects(
    () =>
      c.sdkFetch("https://supabase.test/rest/v1/football_sync_config", {
        method: "PATCH",
      }),
    HttpError,
  );
  assertEquals(names.includes("start_manual_football_request"), false);
});
Deno.test("API budget wait cannot extend revoked original assurance or auto retry an unknown GET", async () => {
  const { getApiStatus } = await import(
    "../football-sync/api-football-client.ts"
  );
  const savedKey = Deno.env.get("API_FOOTBALL_KEY"),
    savedFetch = globalThis.fetch,
    savedTimer = globalThis.setTimeout;
  Deno.env.set("API_FOOTBALL_KEY", "synthetic-provider-key");
  let allowed = true, calls = 0, release!: () => void;
  const waiting = new Promise<void>((r) => release = r);
  let waited!: () => void;
  const entered = new Promise<void>((r) => waited = r);
  const c = context(
    rpcClient((n) => {
      if (n === "assert_manual_football_sync" && !allowed) {
        throw new HttpError(403, "revoked during budget wait");
      }
      return n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true };
    }),
    async () => {
      calls++;
      return Response.json({ response: [] }, {
        headers: { "x-ratelimit-remaining": "0" },
      });
    },
  );
  globalThis.setTimeout = ((
    handler: Parameters<typeof setTimeout>[0],
    timeout?: number,
    ...args: unknown[]
  ) => {
    if (timeout === 60000) {
      waited();
      void waiting.then(() => {
        if (typeof handler === "function") handler();
      });
      return 1;
    }
    return savedTimer(handler, timeout);
  }) as typeof setTimeout;
  try {
    await withFootballSyncContext(c, () => getApiStatus());
    const second = withFootballSyncContext(c, () => getApiStatus());
    await entered;
    allowed = false;
    release();
    await assertRejects(() => second, HttpError);
    assertEquals(calls, 1);
    // Restore the actual module quota from a distinct independent response.
    globalThis.fetch = () =>
      Promise.resolve(
        Response.json({ response: [] }, {
          headers: { "x-ratelimit-remaining": "10" },
        }),
      );
    allowed = true;
    await getApiStatus();
  } finally {
    globalThis.fetch = savedFetch;
    globalThis.setTimeout = savedTimer;
    if (savedKey === undefined) Deno.env.delete("API_FOOTBALL_KEY");
    else Deno.env.set("API_FOOTBALL_KEY", savedKey);
  }
});
Deno.test("independent cron status keeps its existing command/provider path without original human operation", async () => {
  const savedKey = Deno.env.get("API_FOOTBALL_KEY"),
    savedFetch = globalThis.fetch;
  Deno.env.set("API_FOOTBALL_KEY", "synthetic-provider-key");
  let provider = 0;
  globalThis.fetch = () => {
    provider++;
    return Promise.resolve(Response.json({ response: [] }));
  };
  const chain = {
    select() {
      return this;
    },
    eq() {
      return this;
    },
    order() {
      return this;
    },
    limit() {
      return this;
    },
    then(resolve: (v: unknown) => void) {
      resolve({ data: [], error: null });
    },
  };
  const handler = createFootballSyncHandler({
    requireCronSecret: () => {},
    requireGlobalAdminCaller: () => {
      throw new Error("cron must be independent");
    },
    createAdminClient: () => ({
      from: () => chain,
    } as unknown as ReturnType<
      typeof import("./supabase.ts").createAdminClient
    >),
    enforceRateLimit: async () => {},
  });
  try {
    const response = await handler(
      new Request("https://test/football-sync?command=status"),
    );
    assertEquals(response.status, 200);
    assertEquals(provider, 1);
  } finally {
    globalThis.fetch = savedFetch;
    if (savedKey === undefined) Deno.env.delete("API_FOOTBALL_KEY");
    else Deno.env.set("API_FOOTBALL_KEY", savedKey);
  }
});
Deno.test("actual API client never retries a manual unknown GET", async () => {
  const { getApiStatus } = await import(
    "../football-sync/api-football-client.ts"
  );
  const savedKey = Deno.env.get("API_FOOTBALL_KEY");
  Deno.env.set("API_FOOTBALL_KEY", "synthetic-provider-key");
  let calls = 0;
  const c = context(
    rpcClient((n) =>
      n === "start_manual_football_request"
        ? { request_id: requestId, cached: false }
        : { allowed: true }
    ),
    () => {
      calls++;
      throw new TypeError("response lost");
    },
  );
  try {
    await assertRejects(
      () => withFootballSyncContext(c, () => getApiStatus()),
      HttpError,
    );
    assertEquals(calls, 1);
  } finally {
    if (savedKey === undefined) Deno.env.delete("API_FOOTBALL_KEY");
    else Deno.env.set("API_FOOTBALL_KEY", savedKey);
  }
});
