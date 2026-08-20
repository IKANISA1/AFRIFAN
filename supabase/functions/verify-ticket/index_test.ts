import { createVerifyTicketHandler } from "./index.ts";

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

const credentialId = "11111111-1111-4111-8111-111111111111";
const operationId = "22222222-2222-4222-8222-222222222222";

function request(body: Record<string, unknown>) {
  return new Request("https://example.com/functions/v1/verify-ticket", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("passes the authenticated actor to the atomic redemption RPC", async () => {
  let rpcCall: { name: string; params: Record<string, unknown> } | null = null;
  const handler = createVerifyTicketHandler({
    requireAuthenticatedCaller: async () => ({ userId: "verifier-1" }) as never,
    enforceRateLimit: async () => {},
    getEnv: () => "a-secure-test-master-secret-that-is-long-enough",
    verifyRotatingBarcode: async () => ({
      credentialId,
      credentialVersion: 4,
      timestampSeconds: 1_800_000_000,
      totp: "12345678",
    }),
    createAdminClient: () => ({
      rpc: async (name, params) => {
        rpcCall = { name, params };
        return {
          data: {
            status: "admitted",
            code: "admitted",
            ticket_id: "33333333-3333-4333-8333-333333333333",
          },
          error: null,
        };
      },
    }),
  });
  const response = await handler(request({
    ticket_code: `AFC1.${credentialId}.4.1800000000.12345678`,
    operation_id: operationId,
    gate_code: "north_1",
  }));
  const payload = await response.json();
  assertEquals(response.status, 200);
  assertEquals(payload.data.result.code, "admitted");
  assertEquals(rpcCall, {
    name: "redeem_ticket_for_verifier",
    params: {
      p_actor_id: "verifier-1",
      p_credential_id: credentialId,
      p_credential_version: 4,
      p_operation_id: operationId,
      p_gate_code: "NORTH_1",
    },
  });
});

Deno.test("returns a rejected scan result without converting it to an HTTP error", async () => {
  const handler = createVerifyTicketHandler({
    requireAuthenticatedCaller: async () => ({ userId: "verifier-1" }) as never,
    enforceRateLimit: async () => {},
    getEnv: () => "a-secure-test-master-secret-that-is-long-enough",
    verifyRotatingBarcode: async () => ({
      credentialId,
      credentialVersion: 1,
      timestampSeconds: 1_800_000_000,
      totp: "12345678",
    }),
    createAdminClient: () => ({
      rpc: async () => ({
        data: { status: "rejected", code: "permission_denied" },
        error: null,
      }),
    }),
  });
  const response = await handler(request({
    ticket_code: `AFC1.${credentialId}.1.1800000000.12345678`,
    operation_id: operationId,
  }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).data.result.code, "permission_denied");
});

Deno.test("rejects a malformed operation id before barcode verification", async () => {
  const handler = createVerifyTicketHandler({
    requireAuthenticatedCaller: async () => ({ userId: "verifier-1" }) as never,
    createAdminClient: () => ({
      rpc: async () => ({ data: null, error: null }),
    }),
    verifyRotatingBarcode: async () => {
      throw new Error("must not verify");
    },
  });
  const response = await handler(request({
    ticket_code: `AFC1.${credentialId}.1.1800000000.12345678`,
    operation_id: "bad",
  }));
  assertEquals(response.status, 400);
  assertMatch((await response.json()).error, /operation_id/);
});
