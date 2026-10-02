import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { createAdminSendNotificationHandler } from "./index.ts";
import { syntheticStaffJwt } from "../_shared/staff_auth_test_support.ts";

function buildRequest() {
  return new Request(
    "https://example.com/functions/v1/admin-send-notification",
    {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "submit",
        operation_id: "99002900-0000-4000-8000-000000000001",
        club_id: 24,
        title: "Matchday alert",
        body: "Kickoff in 30 minutes.",
        audience: "all_fans",
        delivery_mode: "send_now",
      }),
    },
  );
}

Deno.test("admin-send-notification fails closed when notifications are disabled", async () => {
  const handler = createAdminSendNotificationHandler({
    validateRequest: async () =>
      ({
        userId: "admin-1",
        clubId: "24",
        roles: ["club_admin"],
        supabase: {},
      }) as never,
    enforceFeature: async () =>
      new Response(JSON.stringify({ error: "notifications disabled" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      }),
    createAdminClient: () => {
      throw new Error(
        "Admin client should not be created when notifications are disabled.",
      );
    },
  });

  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 403);
  assertEquals(payload.error, "notifications disabled");
});

const operation = "99002900-0000-4000-8000-000000000001";
const actor = "99002900-0000-4000-8000-000000000002";
const notification = "99002900-0000-4000-8000-000000000003";
const proof = "99002900-0000-4000-8000-000000000007";
function commandReceipt(
  state: "admitted" | "unknown" | "completed",
  mode = "send_now",
) {
  return {
    dispatch_proof_id: proof,
    command: {
      version: 1,
      operation_id: operation,
      actor_id: actor,
      club_id: 24,
      notification_id: notification,
      arguments_sha256: "a".repeat(64),
      delivery_mode: mode,
      state,
    },
    notification: { id: notification, club_id: 24, created_by: actor },
    delivery: { status: state === "unknown" ? "unknown" : "processing" },
  } as never;
}
function commandDependencies() {
  return {
    validateRequest: async () => ({
      userId: actor,
      clubId: "25",
      roles: ["admin"],
      supabase: {},
    } as never),
    enforceFeature: async (_: unknown, args: { clubId?: number | null }) => {
      assertEquals(args.clubId, 24);
      return null;
    },
    createAdminClient: () => ({} as never),
    enforceRateLimit: async () => {},
    prepareSender: async () => {
      throw new Error("Mock dispatch owns provider call");
    },
  };
}

Deno.test("actual immediate handler admits original caller command, dispatches once, and recovers status", async () => {
  const events: string[] = [];
  const handler = createAdminSendNotificationHandler({
    ...commandDependencies(),
    resolveCommand: async (bearer, subject, command) => {
      assertEquals(bearer, "Bearer test-token");
      assertEquals(subject, actor);
      assertEquals(command.operationId, operation);
      assertEquals(command.clubId, 24);
      events.push(command.action);
      return commandReceipt(
        command.action === "submit" ? "admitted" : "unknown",
      );
    },
    dispatchCommand: async (_, original, __, options) => {
      assertEquals(original, operation);
      assertEquals(options?.proofId, proof);
      events.push("dispatch");
      return null;
    },
  });
  const response = await handler(buildRequest());
  assertEquals(response.status, 200);
  assertEquals((await response.json()).data.command.state, "unknown");
  assertEquals(events, ["submit", "dispatch", "status"]);
});

for (
  const scenario of ["status", "scheduled", "completed", "unknown"] as const
) {
  Deno.test(`actual notification ${scenario} never starts provider delivery`, async () => {
    const handler = createAdminSendNotificationHandler({
      ...commandDependencies(),
      resolveCommand: async (_, __, command) => {
        assertEquals(
          command.action,
          scenario === "status" ? "status" : "submit",
        );
        return commandReceipt(
          scenario === "completed"
            ? "completed"
            : scenario === "unknown"
            ? "unknown"
            : "admitted",
          scenario === "scheduled" ? "schedule" : "send_now",
        );
      },
      dispatchCommand: async () => {
        throw new Error("No delivery in this state");
      },
    });
    const request = scenario === "status"
      ? new Request("https://qa.invalid/notification", {
        method: "POST",
        headers: {
          authorization: "Bearer test-token",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          action: "status",
          operation_id: operation,
          club_id: 24,
        }),
      })
      : buildRequest();
    assertEquals((await handler(request)).status, 200);
  });
}

Deno.test("admin notification atomic admission rejects before job writes or delivery", async () => {
  let writes = 0;
  const handler = createAdminSendNotificationHandler({
    validateRequest: async () => ({
      userId: "verified-actor",
      clubId: "24",
      roles: [],
      supabase: {},
    } as never),
    enforceFeature: async () => null,
    createAdminClient: () => ({
      rpc: async (name: string, parameters: Record<string, unknown>) => {
        assertEquals(name, "consume_edge_rate_limit");
        assertEquals(
          parameters.p_bucket_key,
          '["verified-actor","admin-send-notification",24]',
        );
        return {
          data: [{ allowed: false, retry_after_seconds: 23 }],
          error: null,
        };
      },
      from: () => {
        writes++;
        throw new Error("No writes before admission");
      },
    } as never),
  });
  const response = await handler(buildRequest());
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("retry-after"), "23");
  assertEquals(writes, 0);
});

for (
  const scenario of ["stale", "missing", "foreign", "provider_failure"] as const
) {
  Deno.test(`actual notification ${scenario} staff MFA reaches no feature RPC or delivery`, async () => {
    const now = Math.floor(Date.now() / 1000);
    const token = syntheticStaffJwt(
      "verified-actor",
      scenario === "stale"
        ? { amr: [{ method: "totp", timestamp: now - 301 }] }
        : scenario === "missing"
        ? { amr: [] }
        : scenario === "foreign"
        ? { sub: "foreign" }
        : {},
    );
    const values = {
      SUPABASE_URL: "https://qa.invalid",
      SUPABASE_ANON_KEY: "qa-publishable",
      SUPABASE_SERVICE_ROLE_KEY: "qa-service",
      SUPABASE_PUBLISHABLE_KEYS: "",
      SUPABASE_SECRET_KEYS: "",
    };
    const saved = Object.fromEntries(
      Object.keys(values).map((k) => [k, Deno.env.get(k)]),
    );
    for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
    const originalFetch = globalThis.fetch;
    let assignmentReads = 0, features = 0, privileged = 0;
    globalThis.fetch = async (input, init) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      assertEquals(url.origin, "https://qa.invalid");
      if (url.pathname === "/auth/v1/user") {
        assertEquals(
          new Headers(init?.headers).get("authorization"),
          `Bearer ${token}`,
        );
        return Response.json({
          id: "verified-actor",
          is_anonymous: false,
          app_metadata: { club_id: 24, is_admin: true, mfa_verified: true },
        }, { status: scenario === "provider_failure" ? 401 : 200 });
      }
      assertEquals(url.pathname, "/rest/v1/admin_role_assignments");
      assertEquals(url.searchParams.get("user_id"), "eq.verified-actor");
      assignmentReads++;
      return Response.json([{
        role: "admin",
        is_active: true,
        revoked_at: null,
      }]);
    };
    try {
      const handler = createAdminSendNotificationHandler({
        enforceFeature: async () => {
          features++;
          throw new Error("No feature RPC without recent MFA");
        },
        createAdminClient: () => {
          privileged++;
          throw new Error("No job writes/delivery without recent MFA");
        },
      });
      const response = await handler(
        new Request("https://qa.invalid/edge", {
          method: "POST",
          headers: {
            authorization: `Bearer ${token}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            title: "Synthetic",
            body: "Synthetic",
            audience: "all_fans",
            deliveryMode: "send_now",
          }),
        }),
      );
      assertEquals(
        response.status,
        scenario === "provider_failure" ? 401 : 403,
      );
      assertEquals(features, 0);
      assertEquals(privileged, 0);
      assertEquals(assignmentReads, scenario === "provider_failure" ? 0 : 1);
    } finally {
      globalThis.fetch = originalFetch;
      for (const [k, v] of Object.entries(saved)) {
        v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
      }
    }
  });
}

Deno.test("current authorized status recovery remains read-only when new notification creation is disabled", async () => {
  let featureChecks = 0;
  const handler = createAdminSendNotificationHandler({
    ...commandDependencies(),
    enforceFeature: async () => {
      featureChecks++;
      return new Response(null, { status: 403 });
    },
    resolveCommand: async () => commandReceipt("unknown"),
    dispatchCommand: async () => {
      throw new Error("Status cannot send");
    },
  });
  const response = await handler(
    new Request("https://qa.invalid/notification", {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "status",
        operation_id: operation,
        club_id: 24,
      }),
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(featureChecks, 0);
});
