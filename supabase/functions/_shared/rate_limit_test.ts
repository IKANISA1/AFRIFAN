import { assertEquals, assertRejects } from "jsr:@std/assert";
import { enforceRateLimit } from "./rate_limit.ts";
import { HttpError } from "./auth.ts";

const config = { maxRequests: 1, windowSeconds: 60 };

Deno.test("admission uses one atomic RPC bound to verified subject and trusted tenant", async () => {
  const calls: Record<string, unknown>[] = [];
  await enforceRateLimit(
    {
      rpc: async (name, args) => {
        assertEquals(name, "consume_edge_rate_limit");
        calls.push(args);
        return {
          data: [{ allowed: true, retry_after_seconds: 0 }],
          error: null,
        };
      },
    },
    "actor-1",
    "paid-ai",
    { ...config, clubId: 7 },
  );
  assertEquals(calls, [{
    p_bucket_key: '["actor-1","paid-ai",7]',
    p_limit: 1,
    p_window_seconds: 60,
  }]);
});

Deno.test("concurrent callers share one admission decision and only one reaches paid work", async () => {
  // A serialized RPC substitute tests client integration. Actual lock/concurrency
  // semantics are tested separately against the isolated PostgreSQL migration.
  let admitted = 0;
  const client = {
    rpc: async () => ({
      data: [{
        allowed: ++admitted <= 1,
        retry_after_seconds: admitted <= 1 ? 0 : 60,
      }],
      error: null,
    }),
  };
  const decisions = await Promise.allSettled(
    Array.from(
      { length: 20 },
      () => enforceRateLimit(client, "actor-1", "paid-ai", config),
    ),
  );
  assertEquals(
    decisions.filter((decision) => decision.status === "fulfilled").length,
    1,
  );
  for (
    const decision of decisions.filter((decision) =>
      decision.status === "rejected"
    )
  ) {
    assertEquals((decision as PromiseRejectedResult).reason.status, 429);
    assertEquals(
      (decision as PromiseRejectedResult).reason.headers["Retry-After"],
      "60",
    );
  }
});

Deno.test("subject, operation and tenant produce distinct collision-free buckets", async () => {
  const keys: unknown[] = [];
  const client = {
    rpc: async (_name: string, args: Record<string, unknown>) => {
      keys.push(args.p_bucket_key);
      return { data: [{ allowed: true, retry_after_seconds: 0 }], error: null };
    },
  };
  for (
    const [actor, operation, club] of [
      ["actor-1", "sms-ingest", 1],
      ["actor-2", "sms-ingest", 1],
      ["actor-1", "parse-momo-sms", 1],
      ["actor-1", "sms-ingest", 2],
    ] as const
  ) {
    await enforceRateLimit(client, actor, operation, {
      ...config,
      clubId: club,
    });
  }
  assertEquals(new Set(keys).size, 4);
});

for (
  const result of [
    { data: null, error: new Error("private DB detail") },
    { data: [], error: null },
    { data: [{ allowed: true }], error: null },
    { data: [{ allowed: "true", retry_after_seconds: 0 }], error: null },
    { data: [{ allowed: false, retry_after_seconds: 0 }], error: null },
    { data: [{ allowed: true, retry_after_seconds: 3 }], error: null },
  ]
) {
  Deno.test(`store error or malformed receipt fails closed: ${JSON.stringify(result.data)}`, async () => {
    const error = await assertRejects(
      () =>
        enforceRateLimit(
          { rpc: async () => result },
          "actor-1",
          "paid-ai",
          config,
        ),
      HttpError,
    );
    assertEquals(error.status, 503);
    assertEquals(error.message.includes("private DB"), false);
    assertEquals(error.headers["Retry-After"], "5");
  });
}
Deno.test("thrown store failures cannot admit paid work", async () => {
  const error = await assertRejects(() =>
    enforceRateLimit(
      {
        rpc: () => {
          throw new Error("connection failed");
        },
      },
      "actor-1",
      "paid-ai",
      config,
    ), HttpError);
  assertEquals(error.status, 503);
});
Deno.test("invalid budgets never reach the store", async () => {
  for (
    const invalid of [
      { maxRequests: 0, windowSeconds: 60 },
      { maxRequests: 1001, windowSeconds: 60 },
      { maxRequests: 1, windowSeconds: 0 },
      { maxRequests: 1, windowSeconds: 86401 },
      { ...config, clubId: 0 },
    ]
  ) {
    const error = await assertRejects(() =>
      enforceRateLimit(
        {
          rpc: () => {
            throw new Error("must not reach store");
          },
        },
        "actor-1",
        "paid-ai",
        invalid,
      ), HttpError);
    assertEquals(error.status, 503);
  }
});
