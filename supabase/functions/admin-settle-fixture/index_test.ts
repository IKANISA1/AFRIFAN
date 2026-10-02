import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.208.0/assert/mod.ts";

import { createAdminSettleFixtureHandler } from "./index.ts";
import { requireGlobalAdminCaller } from "../_shared/auth.ts";
import { admitVerifiedStaffCommand } from "../_shared/staff_command.ts";
import { syntheticStaffJwt } from "../_shared/staff_auth_test_support.ts";

const fixtureId = "11111111-1111-4111-8111-111111111111";
const operationId = "22222222-2222-4222-8222-222222222222";

const localAdmission: typeof admitVerifiedStaffCommand = (
  authorization,
  actor,
  command,
) =>
  admitVerifiedStaffCommand(authorization, actor, command, {
    createUserClient: (original) => {
      assertEquals(original, authorization);
      return {
        rpc: async (name, args) => {
          assertEquals(name, "admit_verified_staff_command");
          assertEquals(args, {
            p_operation_id: operationId,
            p_action: "fixture_settle",
            p_resource_id: fixtureId,
            p_arguments: command.arguments,
          });
          return {
            data: {
              operation_id: operationId,
              actor_id: actor,
              action: "fixture_settle",
              resource_id: fixtureId,
              club_id: null,
              status: "admitted",
              expires_at: new Date(Date.now() + 60000).toISOString(),
            },
            error: null,
          };
        },
      };
    },
  });

function request(body: Record<string, unknown>, token = "test-token") {
  return new Request(
    "https://example.com/functions/v1/admin-settle-fixture",
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ operation_id: operationId, ...body }),
    },
  );
}

for (
  const scenario of [
    "fresh",
    "stale",
    "missing",
    "foreign",
    "provider_failure",
  ] as const
) {
  Deno.test(`actual settlement ${scenario} MFA reaches only authorized privileged RPC`, async () => {
    const now = Math.floor(Date.now() / 1000);
    const token = syntheticStaffJwt(
      "staff-1",
      scenario === "stale"
        ? { amr: [{ method: "totp", timestamp: now - 301 }] }
        : scenario === "missing"
        ? { amr: [] }
        : scenario === "foreign"
        ? { sub: "foreign-user" }
        : {},
    );
    let writes = 0, providerCalls = 0;
    const handler = createAdminSettleFixtureHandler({
      requireGlobalAdminCaller: (req) =>
        requireGlobalAdminCaller(req, {
          createUserClient: (authorization) => {
            assertEquals(authorization, `Bearer ${token}`);
            return {
              auth: {
                getUser: async (jwt) => {
                  providerCalls++;
                  assertEquals(jwt, token);
                  return {
                    data: {
                      user: {
                        id: "staff-1",
                        is_anonymous: false,
                        app_metadata: { is_admin: true, mfa_verified: true },
                      },
                    },
                    error: scenario === "provider_failure"
                      ? new Error("private provider reason")
                      : null,
                  };
                },
              },
            };
          },
          createAdminClient: () => ({
            from: () => ({
              select: () => ({
                eq: () => ({
                  eq: async () => ({
                    data: [{
                      role: "admin",
                      is_active: true,
                      revoked_at: null,
                    }],
                    error: null,
                  }),
                }),
              }),
            }),
          }),
        }),
      admitVerifiedStaffCommand: localAdmission,
      createAdminClient: () => ({
        rpc: async (name, params) => {
          writes++;
          assertEquals(name, "prediction_admin_settle_as_actor");
          assertEquals(params.p_actor_id, "staff-1");
          return {
            data: {
              status: "success",
              fixture_id: fixtureId,
              operation_id: operationId,
              settlement: {},
            },
            error: null,
          };
        },
      }),
    });
    const response = await handler(
      request({ fixture_id: fixtureId, home_score: 1, away_score: 0 }, token),
    );
    assertEquals(
      response.status,
      scenario === "fresh" ? 200 : scenario === "provider_failure" ? 401 : 403,
    );
    assertEquals(writes, scenario === "fresh" ? 1 : 0);
    assertEquals(providerCalls, 1);
    assertEquals(
      (await response.text()).includes("private provider reason"),
      false,
    );
  });
}

Deno.test("settles through the service boundary after admin verification", async () => {
  let calledWith: Record<string, unknown> | null = null;
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () => ({ userId: "admin-1" }) as never,
    admitVerifiedStaffCommand: localAdmission,
    createAdminClient: () => ({
      rpc: async (name, params) => {
        assertEquals(name, "prediction_admin_settle_as_actor");
        calledWith = params;
        return {
          data: {
            status: "success",
            fixture_id: fixtureId,
            operation_id: params.p_operation_id,
            markets_settled: 4,
            settlement: { total_won: 12, total_lost: 8 },
            private_diagnostics: "omitted",
          },
          error: null,
        };
      },
    }),
  });

  const response = await handler(request({
    fixture_id: fixtureId,
    home_score: 2,
    away_score: 1,
    half_time_home_score: 1,
    half_time_away_score: 0,
  }));
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(calledWith, {
    p_fixture_id: fixtureId,
    p_home_score: 2,
    p_away_score: 1,
    p_actor_id: "admin-1",
    p_operation_id: operationId,
    p_ht_home_score: 1,
    p_ht_away_score: 0,
  });
  assertEquals(payload, {
    success: true,
    data: {
      receipt: {
        status: "success",
        fixture_id: fixtureId,
        operation_id: operationId,
        score: "2 - 1",
        markets_settled: 4,
        total_won: 12,
        total_lost: 8,
      },
    },
  });
});

Deno.test("rejects malformed scores before creating the admin client", async () => {
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () => ({ userId: "admin-1" }) as never,
    admitVerifiedStaffCommand: localAdmission,
    createAdminClient: () => {
      throw new Error("must not create an admin client");
    },
  });

  const response = await handler(request({
    fixture_id: fixtureId,
    home_score: -1,
    away_score: 0,
  }));
  assertEquals(response.status, 400);
  assertMatch((await response.json()).error, /home score/i);
});

Deno.test("rejects an incomplete half-time score pair", async () => {
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () => ({ userId: "admin-1" }) as never,
    admitVerifiedStaffCommand: localAdmission,
    createAdminClient: () => {
      throw new Error("must not create an admin client");
    },
  });

  const response = await handler(request({
    fixture_id: fixtureId,
    home_score: 2,
    away_score: 1,
    half_time_home_score: 1,
  }));
  assertEquals(response.status, 400);
});

Deno.test("returns a private failure when the service result is not confirmed", async () => {
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () => ({ userId: "admin-1" }) as never,
    admitVerifiedStaffCommand: localAdmission,
    createAdminClient: () => ({
      rpc: async () => ({
        data: { status: "error", message: "private database detail" },
        error: null,
      }),
    }),
  });

  const response = await handler(request({
    fixture_id: fixtureId,
    home_score: 2,
    away_score: 1,
  }));
  const text = await response.text();
  assertEquals(response.status, 409);
  assertEquals(text.includes("private database detail"), false);
});

for (const role of ["club_admin", "club_moderator", "supporter", "revoked"]) {
  Deno.test(`actual settlement handler rejects ${role} before privileged RPC`, async () => {
    let mutations = 0;
    const handler = createAdminSettleFixtureHandler({
      requireGlobalAdminCaller: (req) =>
        requireGlobalAdminCaller(req, {
          createUserClient: () => ({
            auth: {
              getUser: async () => ({
                data: {
                  user: {
                    id: "staff-1",
                    app_metadata: { role: "super_admin", is_admin: true },
                  },
                },
                error: null,
              }),
            },
          }),
          createAdminClient: () => ({
            from: () => ({
              select: () => ({
                eq: () => ({
                  eq: async () => ({
                    data: [{
                      role: role === "revoked" ? "admin" : role,
                      club_id: 7,
                      is_active: role !== "revoked",
                    }],
                    error: null,
                  }),
                }),
              }),
            }),
          }),
        }),
      createAdminClient: () => ({
        rpc: async () => {
          mutations++;
          return { data: null, error: null };
        },
      }),
    });
    const response = await handler(
      request({
        fixture_id: fixtureId,
        home_score: 2,
        away_score: 1,
        actor_id: "forged-global-actor",
        club_id: 7,
      }),
    );
    assertEquals(response.status, 403);
    assertEquals(mutations, 0);
  });
}
Deno.test("revocation at the database mutation boundary remains forbidden", async () => {
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () =>
      ({ userId: "verified-actor" }) as never,
    admitVerifiedStaffCommand: localAdmission,
    createAdminClient: () => ({
      rpc: async (name, args) => {
        assertEquals(name, "prediction_admin_settle_as_actor");
        assertEquals(args.p_actor_id, "verified-actor");
        return {
          data: null,
          error: { code: "42501", message: "private grant detail" },
        };
      },
    }),
  });
  const response = await handler(
    request({
      fixture_id: fixtureId,
      home_score: 2,
      away_score: 1,
      actor_id: "forged-actor",
    }),
  );
  assertEquals(response.status, 403);
  assertEquals((await response.text()).includes("private grant detail"), false);
});

Deno.test("requires the saved original UUID before any admission or service mutation", async () => {
  let calls = 0;
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () =>
      ({ userId: "verified-actor" }) as never,
    admitVerifiedStaffCommand: async () => {
      calls++;
      throw new Error("unreachable");
    },
    createAdminClient: () => {
      calls++;
      throw new Error("unreachable");
    },
  });
  for (
    const original of [
      undefined,
      "not-a-uuid",
      "22222222-2222-1222-8222-222222222222",
    ]
  ) {
    const response = await handler(
      request({
        operation_id: original,
        fixture_id: fixtureId,
        home_score: 2,
        away_score: 1,
      }),
    );
    assertEquals(response.status, 400);
  }
  assertEquals(calls, 0);
});

Deno.test("actual caller admission rejection prevents the service financial RPC", async () => {
  let mutations = 0;
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () =>
      ({ userId: "verified-actor" }) as never,
    admitVerifiedStaffCommand: (authorization, actor, command) =>
      admitVerifiedStaffCommand(authorization, actor, command, {
        createUserClient: () => ({
          rpc: async () => ({
            data: null,
            error: { code: "42501", message: "private session revoked" },
          }),
        }),
      }),
    createAdminClient: () => ({
      rpc: async () => {
        mutations++;
        return { data: null, error: null };
      },
    }),
  });
  const response = await handler(
    request({ fixture_id: fixtureId, home_score: 2, away_score: 1 }),
  );
  assertEquals(response.status, 403);
  assertEquals(mutations, 0);
  assertEquals((await response.text()).includes("private session"), false);
});

Deno.test("captures the same provider-verified Bearer before an asynchronous header change", async () => {
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async (req) => {
      req.headers.set("authorization", "Bearer substituted-token");
      return { userId: "verified-actor" } as never;
    },
    admitVerifiedStaffCommand: (authorization, actor, command) => {
      assertEquals(authorization, "Bearer original-token");
      return localAdmission(authorization, actor, command);
    },
    createAdminClient: () => ({
      rpc: async () => ({
        data: {
          status: "success",
          fixture_id: fixtureId,
          operation_id: operationId,
        },
        error: null,
      }),
    }),
  });
  assertEquals(
    (await handler(
      request(
        { fixture_id: fixtureId, home_score: 2, away_score: 1 },
        "original-token",
      ),
    )).status,
    200,
  );
});

Deno.test("lost committed service response retries only the same saved operation and original receipt", async () => {
  let attempts = 0, effects = 0;
  const durable = new Map<string, unknown>();
  const handler = createAdminSettleFixtureHandler({
    requireGlobalAdminCaller: async () =>
      ({ userId: "verified-actor" }) as never,
    admitVerifiedStaffCommand: localAdmission,
    createAdminClient: () => ({
      rpc: async (_name, args) => {
        attempts++;
        if (!durable.has(String(args.p_operation_id))) {
          effects++;
          durable.set(String(args.p_operation_id), {
            status: "success",
            fixture_id: fixtureId,
            operation_id: operationId,
          });
          return {
            data: null,
            error: { code: "08006", message: "private lost acknowledgement" },
          };
        }
        return { data: durable.get(String(args.p_operation_id)), error: null };
      },
    }),
  });
  const body = { fixture_id: fixtureId, home_score: 2, away_score: 1 };
  assertEquals((await handler(request(body))).status, 502);
  const replay = await handler(request(body));
  assertEquals(replay.status, 200);
  assertEquals((await replay.json()).data.receipt.operation_id, operationId);
  assertEquals([attempts, effects], [2, 1]);
});
