import {
  validateRefundProjection,
  validateRefundReceipt,
} from "./refund_gateway.ts";
import {
  encode64,
  gatewayKey,
  readGatewaySignature,
  signatureBase,
  verifySignedGatewayJson,
} from "./trusted_sms.ts";
import {
  deliverGatewayRefundEvidence,
  signGatewayRefundEvidence,
} from "../sms-ingest/gateway_client.ts";
import { handleRequest } from "../sms-ingest/index.ts";
import {
  evidence,
  keyId,
  refundEvidence,
  secret,
  target,
} from "../sms-ingest/test_support.ts";
import { assertDeepEquals as compare } from "../parse-momo-sms/reconciliation_test_support.ts";
const assertEquals = (actual: unknown, expected: unknown) =>
  compare(actual, expected, "Expected refund contract value");
const compensationId = "99964000-0000-4000-8000-000000000104";
const receipt = {
  event_id: refundEvidence.eventId,
  refund_id: refundEvidence.refundId,
  instruction_id: refundEvidence.instructionId,
  currency: refundEvidence.currency,
  status: "partially_refunded",
  confirmed_amount: 1500,
  compensation_id: compensationId,
  replay: false,
};
function rejects(fn: () => unknown) {
  let rejected = false;
  try {
    fn();
  } catch {
    rejected = true;
  }
  assertEquals(rejected, true);
}
Deno.test("actual refund caller verifies signed protocol and deterministic original evidence across restart", async () => {
  const request = await signGatewayRefundEvidence(
    target,
    keyId,
    secret,
    refundEvidence,
  );
  const verified = await verifySignedGatewayJson(
    request.clone(),
    readGatewaySignature(request),
    secret,
    target,
  );
  assertEquals(validateRefundProjection(verified.data), refundEvidence);
  const reordered = Object.fromEntries(
    Object.entries(refundEvidence).reverse(),
  ) as typeof refundEvidence;
  const replay = await signGatewayRefundEvidence(
    target,
    keyId,
    secret,
    reordered,
  );
  assertEquals(
    replay.headers.get("content-digest"),
    request.headers.get("content-digest"),
  );
});
for (
  const [name, value] of [
    ["supporter payee", { ...refundEvidence, payerPhone: "250799966001" }],
    ["missing original payment", {
      ...refundEvidence,
      originalPaymentEventId: null,
    }],
    ["false settled zero", { ...refundEvidence, amount: 0 }],
    ["failed positive money", {
      ...refundEvidence,
      settlementStatus: "failed",
      amount: 1,
    }],
    ["unknown positive money", {
      ...refundEvidence,
      settlementStatus: "unknown",
      amount: 1,
    }],
    ["numeric receiver", { ...refundEvidence, receiver: 12345 }],
    ["ambiguous status", { ...refundEvidence, settlementStatus: "paid" }],
  ] as const
) {
  Deno.test(`refund projection rejects ${name}`, () =>
    rejects(() => validateRefundProjection(value)));
}
Deno.test("refund receipt preserves cumulative prior confirmations with failed or unknown current evidence", () => {
  assertEquals(
    validateRefundReceipt(receipt, refundEvidence).confirmedAmount,
    1500,
  );
  for (const settlementStatus of ["failed", "unknown"] as const) {
    const current = { ...refundEvidence, settlementStatus, amount: 0 };
    for (const status of ["partially_refunded", "refunded"]) {
      const prior = validateRefundReceipt({
        ...receipt,
        status,
        compensation_id: null,
      }, current);
      assertEquals(prior.confirmedAmount, 1500);
      assertEquals(prior.compensationId, null);
    }
    rejects(() => validateRefundReceipt(receipt, current));
  }
});
for (
  const [name, value] of [
    ["foreign event", { ...receipt, event_id: evidence.eventId }],
    ["foreign instruction", { ...receipt, instruction_id: evidence.eventId }],
    ["foreign currency", { ...receipt, currency: "USD" }],
    ["settled without compensation", { ...receipt, compensation_id: null }],
    ["settled below event amount", { ...receipt, confirmed_amount: 999 }],
    ["payment state", { ...receipt, status: "confirmed" }],
    ["positive amount in failed aggregate", {
      ...receipt,
      status: "failed",
      compensation_id: null,
    }],
    ["fractional confirmation", { ...receipt, confirmed_amount: 1.5 }],
  ] as const
) {
  Deno.test(`refund processing receipt rejects ${name}`, () =>
    rejects(() => validateRefundReceipt(value, refundEvidence)));
}
Deno.test("valid MAC cannot switch body protocol through the signed registry discriminator", async () => {
  const request = await signGatewayRefundEvidence(
    target,
    keyId,
    secret,
    refundEvidence,
  );
  const headers = new Headers(request.headers);
  headers.set("x-africlub-gateway-protocol", evidence.protocol);
  const parameters = headers.get("signature-input")!.slice(5);
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      await gatewayKey(secret),
      new TextEncoder().encode(
        signatureBase(
          target,
          headers.get("content-digest")!,
          parameters,
          evidence.protocol,
        ),
      ),
    ),
  );
  headers.set("signature", `sig1=:${encode64(signature)}:`);
  const input = new Request(target, {
    method: "POST",
    headers,
    body: await request.text(),
  });
  let status = 0;
  try {
    await verifySignedGatewayJson(
      input,
      readGatewaySignature(input),
      secret,
      target,
    );
  } catch (error) {
    status = (error as { status: number }).status;
  }
  assertEquals(status, 400);
});
Deno.test("management refund delivery rejects forged or premature processing acknowledgements", async () => {
  const admitted = {
    success: true,
    eventId: refundEvidence.eventId,
    refundId: refundEvidence.refundId,
    instructionId: refundEvidence.instructionId,
    currency: refundEvidence.currency,
    evidenceStatus: refundEvidence.settlementStatus,
    accepted: true,
    processing: "pending",
  };
  for (
    const body of [{ ...admitted, refundId: evidence.eventId }, {
      ...admitted,
      confirmedAmount: 1000,
    }, {
      ...admitted,
      processing: "processed",
      refundStatus: "refunded",
      confirmedAmount: 1000,
      compensationId: null,
      replay: false,
    }]
  ) {
    let rejected = false;
    try {
      await deliverGatewayRefundEvidence(
        target,
        keyId,
        secret,
        refundEvidence,
        async () =>
          new Response(JSON.stringify(body), {
            status: 202,
            headers: { "content-type": "application/json" },
          }),
      );
    } catch {
      rejected = true;
    }
    assertEquals(rejected, true);
  }
});
for (
  const scenario of [
    "accepted",
    "failed_after_partial",
    "unknown_after_partial",
    "invalid_ack",
    "processing_failed",
    "unprovisioned",
    "wrong_receiver",
    "tampered_protocol",
  ] as const
) {
  Deno.test(`actual signed refund dispatch ${scenario}`, async () => {
    const values = {
      SUPABASE_URL: "https://qa.invalid",
      TRUSTED_SMS_INGRESS_ENABLED: "true",
      SMS_GATEWAY_KEY_QA: secret,
    };
    const saved = Object.fromEntries(
      Object.keys(values).map((k) => [k, Deno.env.get(k)]),
    );
    for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
    const current =
      ["failed_after_partial", "unknown_after_partial"].includes(scenario)
        ? {
          ...refundEvidence,
          amount: 0,
          settlementStatus: scenario === "failed_after_partial"
            ? "failed" as const
            : "unknown" as const,
        }
        : refundEvidence;
    let admissions = 0, effects = 0;
    const names: string[] = [];
    const admin = {
      rpc(name: string, params: any) {
        names.push(name);
        if (
          name === "get_trusted_payment_refund_gateway_key" ||
          (scenario === "tampered_protocol" &&
            name === "get_trusted_sms_gateway_key")
        ) {
          return Promise.resolve({
            error: null,
            data: scenario === "unprovisioned" ? null : {
              gateway_id: keyId,
              club_id: 9996401,
              secret_env_name: "SMS_GATEWAY_KEY_QA",
            },
          });
        }
        if (name === "admit_trusted_payment_refund_evidence") {
          admissions++;
          assertEquals(params.p_projection, current);
          return Promise.resolve({
            error: scenario === "wrong_receiver"
              ? new Error("private receiver authority")
              : null,
            data: {
              event_id: current.eventId,
              refund_id: current.refundId,
              status: "pending",
              completed: false,
              replay: false,
            },
          });
        }
        if (name === "process_trusted_payment_refund_evidence") {
          effects++;
          assertEquals(params, { p_event_id: current.eventId });
          return Promise.resolve({
            error: scenario === "processing_failed"
              ? new Error("private SQL failure")
              : null,
            data: {
              ...receipt,
              event_id: scenario === "invalid_ack"
                ? evidence.eventId
                : current.eventId,
              compensation_id: current.settlementStatus === "settled"
                ? compensationId
                : null,
            },
          });
        }
        throw new Error(`Unexpected RPC ${name}`);
      },
    };
    try {
      let request = await signGatewayRefundEvidence(
        target,
        keyId,
        secret,
        current,
      );
      if (scenario === "tampered_protocol") {
        const headers = new Headers(request.headers);
        headers.set("x-africlub-gateway-protocol", evidence.protocol);
        request = new Request(target, {
          method: "POST",
          headers,
          body: await request.text(),
        });
      }
      const response = await handleRequest(request, {
        createAdminClient: () => admin,
        enforceRateLimit: async (_a, subject, name, limits) => {
          assertEquals(subject, keyId);
          assertEquals(name, "sms-ingest");
          assertEquals(limits.clubId, 9996401);
        },
        processEvidence: async () => {
          throw new Error("Refund must not enter payment/AI processor");
        },
      });
      const body = await response.json();
      assertEquals(
        response.status,
        ["tampered_protocol", "unprovisioned"].includes(scenario)
          ? 401
          : scenario === "wrong_receiver"
          ? 500
          : 202,
      );
      assertEquals(JSON.stringify(body).includes("private"), false);
      if (response.status === 202) {
        assertEquals(body.refundId, current.refundId);
        assertEquals(body.evidenceStatus, current.settlementStatus);
        assertEquals(
          body.processing,
          ["invalid_ack", "processing_failed"].includes(scenario)
            ? "pending"
            : "processed",
        );
        if (body.processing === "processed") {
          assertEquals(body.confirmedAmount, 1500);
          assertEquals(
            body.compensationId,
            current.settlementStatus === "settled" ? compensationId : null,
          );
        } else assertEquals(body.confirmedAmount, undefined);
      }
      if (["tampered_protocol", "unprovisioned"].includes(scenario)) {
        assertEquals(admissions, 0);
        assertEquals(effects, 0);
      }
      assertEquals(names.includes("admit_trusted_sms_gateway_evidence"), false);
    } finally {
      for (const [k, v] of Object.entries(saved)) {
        v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
      }
    }
  });
}
Deno.test("real Supabase SDK signed refund delivery recovers a lost committed effect with original immutable IDs", async () => {
  const values = {
    SUPABASE_URL: "https://qa.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "qa-service",
    SUPABASE_SECRET_KEYS: "",
    TRUSTED_SMS_INGRESS_ENABLED: "true",
    SMS_GATEWAY_KEY_QA: secret,
  };
  const saved = Object.fromEntries(
    Object.keys(values).map((k) => [k, Deno.env.get(k)]),
  );
  for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
  const originalFetch = globalThis.fetch;
  let admissions = 0, attempts = 0, effects = 0;
  const json = (value: unknown, status = 200) =>
    new Response(JSON.stringify(value), {
      status,
      headers: { "content-type": "application/json" },
    });
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    const params = JSON.parse(String(init?.body));
    assertEquals(url.origin, "https://qa.invalid");
    switch (url.pathname.split("/").at(-1)) {
      case "get_trusted_payment_refund_gateway_key":
        return json({
          gateway_id: keyId,
          club_id: 9996401,
          secret_env_name: "SMS_GATEWAY_KEY_QA",
        });
      case "consume_edge_rate_limit":
        return json([{ allowed: true, retry_after_seconds: 0 }]);
      case "admit_trusted_payment_refund_evidence":
        admissions++;
        assertEquals(params.p_projection, refundEvidence);
        return json({
          event_id: refundEvidence.eventId,
          refund_id: refundEvidence.refundId,
          status: effects ? "settled" : "pending",
          completed: effects > 0,
          replay: admissions > 1,
        });
      case "process_trusted_payment_refund_evidence":
        attempts++;
        assertEquals(params, { p_event_id: refundEvidence.eventId });
        if (attempts === 1) {
          effects++;
          return json({ message: "private lost receipt" }, 500);
        }
        return json({ ...receipt, replay: true });
      default:
        throw new Error(`Unexpected Auth/provider/table call ${url.pathname}`);
    }
  };
  const deliver: typeof fetch = async (input, init) =>
    await handleRequest(new Request(String(input), init));
  try {
    const first = await deliverGatewayRefundEvidence(
      target,
      keyId,
      secret,
      refundEvidence,
      deliver,
    );
    assertEquals(first.processing, "pending");
    assertEquals(first.confirmedAmount, undefined);
    const replay = await deliverGatewayRefundEvidence(
      target,
      keyId,
      secret,
      refundEvidence,
      deliver,
    );
    assertEquals(replay.processing, "processed");
    assertEquals(replay.replay, true);
    assertEquals(effects, 1);
    assertEquals(admissions, 2);
    assertEquals(attempts, 2);
  } finally {
    globalThis.fetch = originalFetch;
    for (const [k, v] of Object.entries(saved)) {
      v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
    }
  }
});
