import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { HttpError } from "../_shared/auth.ts";
import {
  type BiopayCreateLivenessChallengeDependencies,
  createBiopayCreateLivenessChallengeHandler,
} from "./index.ts";

function buildRequest(body: Record<string, unknown> = { mode: "enrollment" }) {
  return new Request(
    "https://example.com/functions/v1/biopay-create-liveness-challenge",
    {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
        "x-firebase-appcheck": "fresh-token",
      },
      body: JSON.stringify(body),
    },
  );
}

function buildDependencies(): {
  deps: BiopayCreateLivenessChallengeDependencies;
  state: {
    insertedRow: Record<string, unknown> | null;
    signedPayload: Record<string, unknown> | null;
  };
} {
  const state = {
    insertedRow: null as Record<string, unknown> | null,
    signedPayload: null as Record<string, unknown> | null,
  };

  const deps: BiopayCreateLivenessChallengeDependencies = {
    createAdminClient: () =>
      ({
        rpc: async (fn: string) => {
          if (fn == "normalize_club_id") {
            return {
              data: 24,
              error: null,
            };
          }
          throw new Error(`Unexpected RPC call in liveness challenge test: ${fn}`);
        },
        from: (table: string) => {
          if (table != "biopay_liveness_challenges") {
            throw new Error(`Unexpected table in liveness challenge test: ${table}`);
          }
          return {
            insert: (row: Record<string, unknown>) => {
              state.insertedRow = row;
              return {
                select: () => ({
                  single: async () => ({
                    data: { id: "challenge-1" },
                    error: null,
                  }),
                }),
              };
            },
          };
        },
      }) as unknown as ReturnType<
        BiopayCreateLivenessChallengeDependencies["createAdminClient"]
      >,
    createUserClient: () =>
      ({
        auth: {
          getUser: async () => ({
            data: {
              user: {
                id: "user-1",
                app_metadata: { club_id: "rayon_sports_rw" },
              },
            },
            error: null,
          }),
        },
      }) as unknown as ReturnType<
        BiopayCreateLivenessChallengeDependencies["createUserClient"]
      >,
    requireAppCheckToken: async () => "fresh-token",
    signBiopayToken: async (payload) => {
      state.signedPayload = payload;
      return "signed-liveness-token";
    },
    recordOperationalHealthEvent: async () => undefined,
    recordEdgeFunctionFailure: async () => undefined,
    now: () => new Date("2026-03-31T12:00:00.000Z"),
  };

  return { deps, state };
}

Deno.test("biopay-create-liveness-challenge rejects requests without valid App Check attestation", async () => {
  const { deps } = buildDependencies();
  const handler = createBiopayCreateLivenessChallengeHandler({
    ...deps,
    requireAppCheckToken: async () => {
      throw new HttpError(401, "Device attestation required.");
    },
  });

  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 401);
  assertEquals(payload.message, "Device attestation required.");
});

Deno.test("biopay-create-liveness-challenge issues a signed challenge bound to the user and club", async () => {
  const { deps, state } = buildDependencies();
  const handler = createBiopayCreateLivenessChallengeHandler(deps);

  const response = await handler(buildRequest({ mode: "enrollment" }));
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.success, true);
  assertEquals(payload.data.token, "signed-liveness-token");
  assertEquals(payload.data.mode, "enrollment");
  assertEquals(payload.data.expires_at, "2026-03-31T12:05:00.000Z");
  assertEquals(state.insertedRow?.["user_id"], "user-1");
  assertEquals(state.insertedRow?.["club_id"], 24);
  assertEquals(state.insertedRow?.["mode"], "enrollment");
  assertEquals(state.signedPayload?.["kind"], "liveness_challenge");
  assertEquals(state.signedPayload?.["challenge_id"], "challenge-1");
  assertEquals(state.signedPayload?.["requester_user_id"], "user-1");
  assertEquals(state.signedPayload?.["club_id"], 24);
  assertEquals(state.signedPayload?.["mode"], "enrollment");
});
