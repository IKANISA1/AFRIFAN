import { GoogleWalletApiError } from "../_shared/ticket_wallet.ts";
import { HttpError } from "../_shared/auth.ts";
import { createSyncGoogleWalletTicketStateHandler } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, received ${actualJson}`);
  }
}

const claimToken = "11111111-1111-4111-8111-111111111111";
const item = {
  id: "22222222-2222-4222-8222-222222222222",
  pass_id: "33333333-3333-4333-8333-333333333333",
  object_id: "123456789012345678.africlub_ticket_abc",
  desired_state: "COMPLETED",
  attempts: 1,
  claim_token: claimToken,
};

function request() {
  return new Request(
    "https://example.com/functions/v1/sync-google-wallet-ticket-state",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-cron-secret": "test-secret",
      },
      body: JSON.stringify({ limit: 100 }),
    },
  );
}

function serviceAccount() {
  return JSON.stringify({
    client_email: "wallet@example.iam.gserviceaccount.com",
    private_key: "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----",
  });
}

Deno.test("claims, patches, and completes Wallet state work", async () => {
  const rpcCalls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const patches: Array<Record<string, unknown>> = [];
  const handler = createSyncGoogleWalletTicketStateHandler({
    requireCronSecret: () => {},
    getEnv: () => serviceAccount(),
    randomUuid: () => claimToken,
    createAdminClient: () => ({
      rpc: async (name, params) => {
        rpcCalls.push({ name, params });
        if (name === "claim_google_wallet_ticket_outbox") {
          return { data: [item], error: null };
        }
        return { data: "completed", error: null };
      },
    }),
    updateGoogleWalletTicketState: async (options) => {
      patches.push(options as unknown as Record<string, unknown>);
    },
  });

  const response = await handler(request());
  const payload = await response.json();
  assertEquals(response.status, 200);
  assertEquals(payload.data, {
    claimed: 1,
    synced: 1,
    retrying: 0,
    dead_lettered: 0,
  });
  assertEquals(rpcCalls[0], {
    name: "claim_google_wallet_ticket_outbox",
    params: { p_claim_token: claimToken, p_limit: 50 },
  });
  assertEquals(rpcCalls[1].name, "complete_google_wallet_ticket_outbox");
  assertEquals(patches[0].objectId, item.object_id);
  assertEquals(patches[0].state, "COMPLETED");
});

Deno.test("records retryable Google API failures without leaking details", async () => {
  const completions: Array<Record<string, unknown>> = [];
  const handler = createSyncGoogleWalletTicketStateHandler({
    requireCronSecret: () => {},
    getEnv: () => serviceAccount(),
    randomUuid: () => claimToken,
    createAdminClient: () => ({
      rpc: async (name, params) => {
        if (name === "claim_google_wallet_ticket_outbox") {
          return { data: [item], error: null };
        }
        completions.push(params);
        return { data: "failed", error: null };
      },
    }),
    updateGoogleWalletTicketState: async () => {
      throw new GoogleWalletApiError("state_update", 503);
    },
  });

  const response = await handler(request());
  const payload = await response.json();
  assertEquals(response.status, 200);
  assertEquals(payload.data.retrying, 1);
  assertEquals(
    completions[0]["p_error_code"],
    "google_wallet_state_update_503",
  );
});

Deno.test("rejects calls without the governed cron secret", async () => {
  const handler = createSyncGoogleWalletTicketStateHandler({
    requireCronSecret: () => {
      throw new HttpError(401, "Unauthorized.");
    },
  });
  const response = await handler(request());
  assertEquals(response.status, 401);
});
