import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.208.0/assert/mod.ts";

import { createAdminSettleFixtureHandler } from "./index.ts";

const fixtureId = "11111111-1111-4111-8111-111111111111";

function request(body: Record<string, unknown>) {
  return new Request(
    "https://example.com/functions/v1/admin-settle-fixture",
    {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
}

Deno.test("settles through the service boundary after admin verification", async () => {
  let calledWith: Record<string, unknown> | null = null;
  const handler = createAdminSettleFixtureHandler({
    requireAdminCaller: async () => ({ userId: "admin-1" }) as never,
    createAdminClient: () => ({
      rpc: async (name, params) => {
        assertEquals(name, "prediction_admin_settle");
        calledWith = params;
        return {
          data: {
            status: "success",
            fixture_id: fixtureId,
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
    p_status: "finished",
    p_ht_home_score: 1,
    p_ht_away_score: 0,
  });
  assertEquals(payload, {
    success: true,
    data: {
      receipt: {
        status: "success",
        fixture_id: fixtureId,
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
    requireAdminCaller: async () => ({ userId: "admin-1" }) as never,
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
    requireAdminCaller: async () => ({ userId: "admin-1" }) as never,
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
    requireAdminCaller: async () => ({ userId: "admin-1" }) as never,
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
