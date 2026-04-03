import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { HttpError } from "../_shared/auth.ts";
import {
  signBiopayToken,
  verifyBiopayToken,
} from "../_shared/biopay_signed_token.ts";
import {
  type BiopayCreatePaymentIntentDependencies,
  createBiopayCreatePaymentIntentHandler,
} from "./index.ts";

const signingSecret = "test-biopay-signing-key";

function buildRequest(matchReceipt: string, amount?: number) {
  return new Request(
    "https://example.com/functions/v1/biopay-create-payment-intent",
    {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
        "x-firebase-appcheck": "fresh-token",
      },
      body: JSON.stringify({
        match_receipt: matchReceipt,
        ...(amount != null ? { amount } : {}),
      }),
    },
  );
}

async function buildMatchReceipt(overrides: Record<string, unknown> = {}) {
  const now = new Date();
  return await signBiopayToken({
    kind: "match_receipt",
    v: 1,
    iat: now.toISOString(),
    exp: new Date(now.getTime() + 45 * 1000).toISOString(),
    nonce: "abc123",
    requester_user_id: "user-1",
    profile_public_id: "public-1",
    profile_id: "profile-1",
    score: 0.93,
    ...overrides,
  }, {
    secret: signingSecret,
  });
}

function buildDependencies(): {
  deps: BiopayCreatePaymentIntentDependencies;
  state: {
    cancelledFilters: Record<string, unknown>;
    insertedRow: Record<string, unknown> | null;
  };
} {
  const state = {
    cancelledFilters: {} as Record<string, unknown>,
    insertedRow: null as Record<string, unknown> | null,
  };

  const deps: BiopayCreatePaymentIntentDependencies = {
    createAdminClient: () =>
      ({
        from: (table: string) => {
          if (table == "biopay_profiles") {
            return {
              select: () => ({
                eq: (_column: string, _value: unknown) => ({
                  eq: () => ({
                    maybeSingle: async () => ({
                      data: {
                        id: "profile-1",
                        club_id: 24,
                        recipient_value: "0781234567",
                        route_type: "phone_number",
                        display_name: "Marie",
                        public_id: "public-1",
                        country_code: "RW",
                      },
                      error: null,
                    }),
                  }),
                }),
              }),
            };
          }

          if (table == "biopay_payment_intents") {
            return {
              update: (_values: Record<string, unknown>) => ({
                eq: (column: string, value: unknown) => ({
                  eq: (statusColumn: string, statusValue: unknown) => {
                    state.cancelledFilters = {
                      [column]: value,
                      [statusColumn]: statusValue,
                    };
                    return Promise.resolve({ data: null, error: null });
                  },
                }),
              }),
              insert: (row: Record<string, unknown>) => {
                state.insertedRow = row;
                return {
                  select: () => ({
                    single: async () => ({
                      data: {
                        id: "intent-1",
                        nonce: "nonce-1",
                        payment_code: row["payment_code"] ?? "*182*1*1*0781234567#",
                        payment_method: "ussd_dial",
                        expires_at: "2026-03-30T12:05:00.000Z",
                        amount: row["amount"] ?? null,
                      },
                      error: null,
                    }),
                  }),
                };
              },
            };
          }

          throw new Error(`Unexpected table in payment-intent test: ${table}`);
        },
      }) as unknown as ReturnType<
        BiopayCreatePaymentIntentDependencies["createAdminClient"]
      >,
    createUserClient: () =>
      ({
        auth: {
          getUser: async () => ({
            data: {
              user: { id: "user-1" },
            },
            error: null,
          }),
        },
      }) as unknown as ReturnType<
        BiopayCreatePaymentIntentDependencies["createUserClient"]
      >,
    requireAppCheckToken: async () => "fresh-token",
    verifyBiopayToken: (token, options) =>
      verifyBiopayToken(token, {
        secret: signingSecret,
        expectedKind: options.expectedKind,
      }),
    resolvePaymentRouting: async () => ({
      countryCode: "RW",
      currencyCode: "RWF",
      currencySymbol: "FRw",
      paymentMethod: "ussd_dial",
      paymentTemplate: "*182*1*1*{momo}*{amount}#",
      senderName: "MTN MoMo",
    }),
    buildPaymentCode: ({ routeType, recipientValue, amount }) =>
      routeType == "phone_number"
        ? amount != null
          ? `*182*1*1*${recipientValue}*${amount}#`
          : `*182*1*1*${recipientValue}#`
        : amount != null
        ? `*182*8*1*${amount}*${recipientValue}#`
        : `*182*8*1*${recipientValue}#`,
    recordOperationalHealthEvent: async () => undefined,
    recordEdgeFunctionFailure: async () => undefined,
    generateNonce: () => "nonce-1",
    now: () => new Date("2026-03-30T12:00:00.000Z"),
  };

  return { deps, state };
}

Deno.test("biopay-create-payment-intent rejects requests without valid App Check attestation", async () => {
  const receipt = await buildMatchReceipt();
  const { deps } = buildDependencies();
  const handler = createBiopayCreatePaymentIntentHandler({
    ...deps,
    requireAppCheckToken: async () => {
      throw new HttpError(401, "Device attestation required.");
    },
  });

  const response = await handler(buildRequest(receipt));
  const payload = await response.json();

  assertEquals(response.status, 401);
  assertEquals(payload.message, "Device attestation required.");
});

Deno.test("biopay-create-payment-intent creates an intent from a signed match receipt", async () => {
  const receipt = await buildMatchReceipt();
  const { deps, state } = buildDependencies();
  const handler = createBiopayCreatePaymentIntentHandler(deps);

  const response = await handler(buildRequest(receipt));
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.success, true);
  assertEquals(payload.data.intent_id, "intent-1");
  assertEquals(payload.data.ussd_code, "*182*1*1*0781234567#");
  assertEquals(payload.data.payment_code, "*182*1*1*0781234567#");
  assertEquals(state.cancelledFilters["user_id"], "user-1");
  assertEquals(state.cancelledFilters["status"], "pending");
  assertEquals(state.insertedRow?.["profile_id"], "profile-1");
  assertEquals(state.insertedRow?.["match_score"], 0.93);
  assertEquals(state.insertedRow?.["club_id"], 24);
  assertEquals(state.insertedRow?.["nonce"], "nonce-1");
});

Deno.test("biopay-create-payment-intent binds the requested amount into the payment code", async () => {
  const receipt = await buildMatchReceipt();
  const { deps, state } = buildDependencies();
  const handler = createBiopayCreatePaymentIntentHandler(deps);

  const response = await handler(buildRequest(receipt, 6500));
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.data.ussd_code, "*182*1*1*0781234567*6500#");
  assertEquals(payload.data.payment_code, "*182*1*1*0781234567*6500#");
  assertEquals(payload.data.amount, 6500);
  assertEquals(state.insertedRow?.["payment_code"], "*182*1*1*0781234567*6500#");
  assertEquals(state.insertedRow?.["amount"], 6500);
  assertEquals(payload.data.currency_code, "RWF");
  assertEquals(payload.data.currency_symbol, "FRw");
});

Deno.test("biopay-create-payment-intent rejects a receipt owned by another user", async () => {
  const receipt = await buildMatchReceipt({
    requester_user_id: "user-2",
  });
  const { deps } = buildDependencies();
  const handler = createBiopayCreatePaymentIntentHandler(deps);

  const response = await handler(buildRequest(receipt));
  const payload = await response.json();

  assertEquals(response.status, 403);
  assertEquals(
    payload.message,
    "This BioPay match receipt does not belong to the current user.",
  );
});
