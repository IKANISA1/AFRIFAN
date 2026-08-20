import { createGoogleWalletTicketPassHandler } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, received ${actualJson}`);
  }
}

function assertMatch(actual: string, expected: RegExp) {
  if (!expected.test(actual)) {
    throw new Error(`Expected ${JSON.stringify(actual)} to match ${expected}.`);
  }
}

const ticketId = "22222222-2222-4222-8222-222222222222";
const credentialId = "11111111-1111-4111-8111-111111111111";

function request(body: Record<string, unknown>) {
  return new Request(
    "https://example.com/functions/v1/google-wallet-ticket-pass",
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

Deno.test("issues only after the user-scoped eligibility RPC succeeds", async () => {
  const rpcCalls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const handler = createGoogleWalletTicketPassHandler({
    requireAuthenticatedCaller: async () => ({ userId: "fan-1" }) as never,
    enforceRateLimit: async () => {},
    getEnv: (name) =>
      name === "GOOGLE_WALLET_SERVICE_ACCOUNT_JSON"
        ? JSON.stringify({
          client_email: "wallet@example.iam.gserviceaccount.com",
          private_key:
            "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----",
        })
        : "a-secure-test-master-secret-that-is-long-enough",
    createUserClient: () => ({
      rpc: async (name, params) => {
        rpcCalls.push({ name, params });
        return {
          data: {
            status: "success",
            code: "ready",
            ticket_id: ticketId,
            ticket_number: "222222222222",
            credential_id: credentialId,
            credential_version: 1,
            ticket_event_id: "33333333-3333-4333-8333-333333333333",
            organization_id: "44444444-4444-4444-8444-444444444444",
            organization_name: "Rayon Sports",
            issuer_id: "123456789012345678",
            entry_opens_at: "2026-08-13T14:00:00Z",
            entry_closes_at: "2026-08-13T20:00:00Z",
            seat_type: "general",
            match_id: "55555555-5555-4555-8555-555555555555",
            home_team: "Rayon Sports",
            away_team: "Visitors",
            competition: "League",
            venue: "Stadium",
            venue_address: "Kigali",
            venue_country_code: "RW",
            venue_timezone: "Africa/Kigali",
            match_date: "2026-08-13",
            kickoff_time: "18:00:00",
          },
          error: null,
        };
      },
    }),
    provisionGoogleWalletTicket: async () => ({
      classId: "123456789012345678.class",
      objectId: "123456789012345678.object",
      saveJwt: "signed-save-jwt",
      saveUrl: "https://pay.google.com/gp/v/save/signed-save-jwt",
    }),
    createAdminClient: () => ({
      rpc: async (name, params) => {
        rpcCalls.push({ name, params });
        return {
          data: "66666666-6666-4666-8666-666666666666",
          error: null,
        };
      },
    }),
  });

  const response = await handler(request({ ticket_id: ticketId }));
  const payload = await response.json();
  assertEquals(response.status, 200);
  assertEquals(payload.success, true);
  assertEquals(payload.data.save_jwt, "signed-save-jwt");
  assertEquals(rpcCalls[0], {
    name: "prepare_google_wallet_ticket",
    params: { p_ticket_id: ticketId },
  });
  assertEquals(rpcCalls[1].name, "record_google_wallet_ticket_pass");
});

Deno.test("does not provision a pending-payment ticket", async () => {
  let provisioned = false;
  const handler = createGoogleWalletTicketPassHandler({
    requireAuthenticatedCaller: async () => ({ userId: "fan-1" }) as never,
    enforceRateLimit: async () => {},
    createAdminClient: () => ({
      rpc: async () => ({ data: null, error: null }),
    }),
    createUserClient: () => ({
      rpc: async () => ({
        data: { status: "error", code: "payment_pending" },
        error: null,
      }),
    }),
    provisionGoogleWalletTicket: async () => {
      provisioned = true;
      throw new Error("must not provision");
    },
  });
  const response = await handler(request({ ticket_id: ticketId }));
  assertEquals(response.status, 409);
  assertEquals(provisioned, false);
  assertMatch((await response.json()).error, /payment_pending/);
});
