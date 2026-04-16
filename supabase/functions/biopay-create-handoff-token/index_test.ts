import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { HttpError } from "../_shared/auth.ts";
import {
  type BioPayCreateHandoffTokenDependencies,
  createBioPayCreateHandoffTokenHandler,
} from "./index.ts";

function buildRequest(overrides: Record<string, unknown> = {}) {
  return new Request(
    "https://example.com/functions/v1/BioPay-create-handoff-token",
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
        ...overrides,
      }),
    },
  );
}

function buildDependencies(options: {
  profile?: Record<string, unknown> | null;
  identity?: Record<string, unknown> | null;
} = {}): {
  deps: BioPayCreateHandoffTokenDependencies;
  state: {
    signedPayload: Record<string, unknown> | null;
  };
} {
  const state = {
    signedPayload: null as Record<string, unknown> | null,
  };

  const profile = options.profile === undefined
    ? {
      id: "profile-1",
      club_id: 24,
      public_id: "public-1",
      display_name: "Marie",
      route_type: "phone_number",
      recipient_value: "0781234567",
      country_code: "RW",
    }
    : options.profile;
  const identity = options.identity === undefined
    ? {
      id: "user-1",
      club_id: 24,
      public_user_id: "public-1",
      display_name: "Marie",
      country_code: "RW",
    }
    : options.identity;

  const deps: BioPayCreateHandoffTokenDependencies = {
    createAdminClient: () =>
      ({
        from: (table: string) => {
          const data = table == "BioPay_profiles"
            ? profile
            : table == "profiles"
              ? identity
              : null;
          if (
            data === null && table != "BioPay_profiles" && table != "profiles"
          ) {
            throw new Error(`Unexpected table in handoff test: ${table}`);
          }
          const query = {
            eq: (_column: string, _value: unknown) => query,
            maybeSingle: async () => ({ data, error: null }),
          };
          return {
            select: () => query,
          };
        },
      }) as unknown as ReturnType<
        BioPayCreateHandoffTokenDependencies["createAdminClient"]
      >,
    validateRequest: async () =>
      ({
        userId: "user-1",
        clubId: "24",
        supabase: {},
      }) as never,
    requireAppCheckToken: async () => "fresh-token",
    signBioPayToken: async (payload) => {
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

Deno.test("BioPay-create-handoff-token rejects requests without valid App Check attestation", async () => {
  const { deps } = buildDependencies();
  const handler = createBioPayCreateHandoffTokenHandler({
    ...deps,
    requireAppCheckToken: async () => {
      throw new HttpError(401, "Device attestation required.");
    },
  });

  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 401);
  assertEquals(payload.error, "Device attestation required.");
});

Deno.test("BioPay-create-handoff-token creates a signed QR handoff token", async () => {
  const { deps, state } = buildDependencies();
  const handler = createBioPayCreateHandoffTokenHandler(deps);

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

Deno.test("BioPay-create-handoff-token accepts a manual route when no enrollment exists", async () => {
  const { deps, state } = buildDependencies({
    profile: null,
    identity: {
      id: "user-1",
      club_id: 24,
      public_user_id: "fan-24",
      display_name: "Manual Fan",
      country_code: "RW",
    },
  });
  const handler = createBioPayCreateHandoffTokenHandler(deps);

  const response = await handler(buildRequest({
    route_type: "code",
    recipient_value: "123456",
    country_code: "RW",
  }));
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.success, true);
  assertEquals(state.signedPayload?.["profile_id"], null);
  assertEquals(state.signedPayload?.["route_type"], "code");
  assertEquals(state.signedPayload?.["recipient_value"], "123456");
  assertEquals(state.signedPayload?.["public_id"], "fan-24");
  assertEquals(payload.data.public_id, "fan-24");
});
