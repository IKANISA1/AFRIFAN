import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { HttpError } from "../_shared/auth.ts";
import {
  type BiopayCreateHandoffTokenDependencies,
  createBiopayCreateHandoffTokenHandler,
} from "./index.ts";

function buildRequest() {
  return new Request(
    "https://example.com/functions/v1/biopay-create-handoff-token",
    {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
        "x-firebase-appcheck": "fresh-token",
      },
      body: JSON.stringify({
        channel: "qr",
        amount: 2500,
        reference: "matchday",
      }),
    },
  );
}

function buildDependencies(): {
  deps: BiopayCreateHandoffTokenDependencies;
  state: {
    signedPayload: Record<string, unknown> | null;
  };
} {
  const state = {
    signedPayload: null as Record<string, unknown> | null,
  };

  const deps: BiopayCreateHandoffTokenDependencies = {
    createAdminClient: () =>
      ({
        rpc: async (fn: string) => {
          if (fn == "normalize_club_id") {
            return {
              data: 24,
              error: null,
            };
          }
          throw new Error(`Unexpected RPC call in handoff test: ${fn}`);
        },
        from: (table: string) => {
          if (table != "biopay_profiles") {
            throw new Error(`Unexpected table in handoff test: ${table}`);
          }
          return {
            select: () => ({
              eq: (_column: string, _value: unknown) => ({
                eq: (_clubColumn: string, _clubValue: unknown) => ({
                  eq: () => ({
                    maybeSingle: async () => ({
                      data: {
                        id: "profile-1",
                        club_id: 24,
                        public_id: "public-1",
                        display_name: "Marie",
                        route_type: "phone_number",
                        recipient_value: "0781234567",
                        country_code: "RW",
                      },
                      error: null,
                    }),
                  }),
                }),
              }),
            }),
          };
        },
      }) as unknown as ReturnType<
        BiopayCreateHandoffTokenDependencies["createAdminClient"]
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
        BiopayCreateHandoffTokenDependencies["createUserClient"]
      >,
    requireAppCheckToken: async () => "fresh-token",
    signBiopayToken: async (payload) => {
      state.signedPayload = payload;
      return "signed-handoff-token";
    },
    resolvePaymentRouting: async () => ({
      countryCode: "RW",
      currencyCode: "RWF",
      currencySymbol: "FRw",
      paymentMethod: "ussd_dial",
      paymentTemplate: "*182*1*1*{momo}*{amount}#",
      senderName: "MTN MoMo",
    }),
    recordOperationalHealthEvent: async () => undefined,
    recordEdgeFunctionFailure: async () => undefined,
    buildResolverUrl: (token) => `https://example.com/resolve?token=${token}`,
    now: () => new Date("2026-03-30T12:00:00.000Z"),
  };

  return { deps, state };
}

Deno.test("biopay-create-handoff-token rejects requests without valid App Check attestation", async () => {
  const { deps } = buildDependencies();
  const handler = createBiopayCreateHandoffTokenHandler({
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

Deno.test("biopay-create-handoff-token creates a signed QR handoff token", async () => {
  const { deps, state } = buildDependencies();
  const handler = createBiopayCreateHandoffTokenHandler(deps);

  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.success, true);
  assertEquals(payload.data.token, "signed-handoff-token");
  assertEquals(
    payload.data.resolver_url,
    "https://example.com/resolve?token=signed-handoff-token",
  );
  assertEquals(state.signedPayload?.["channel"], "qr");
  assertEquals(state.signedPayload?.["amount"], 2500);
  assertEquals(state.signedPayload?.["club_id"], 24);
  assertEquals(state.signedPayload?.["public_id"], "public-1");
  assertEquals(payload.data.currency_code, "RWF");
  assertEquals(payload.data.currency_symbol, "FRw");
});
