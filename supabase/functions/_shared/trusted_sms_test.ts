import {
  type GatewayProjection,
  readGatewaySignature,
  validateProjection,
  verifyGatewayRequest,
} from "./trusted_sms.ts";
import {
  deliverGatewayEvidence,
  payerAccountDigest,
  signGatewayEvidence,
} from "../sms-ingest/gateway_client.ts";
import { HttpError } from "./http_error.ts";
import { assertEquals as compare } from "../parse-momo-sms/reconciliation_test_support.ts";
const assertEquals = (
  actual: unknown,
  expected: unknown,
  message = "Expected contract value",
) => compare(actual, expected, message);
import { evidence, keyId, secret, target } from "../sms-ingest/test_support.ts";
Deno.test("management caller and verifier agree on fixed signed method, audience, digest and fresh nonce", async () => {
  const request = await signGatewayEvidence(target, keyId, secret, evidence);
  const signature = readGatewaySignature(request);
  const verified = await verifyGatewayRequest(
    request,
    signature,
    secret,
    target,
  );
  assertEquals(JSON.stringify(verified.projection), JSON.stringify(evidence));
});
for (
  const change of [
    "body",
    "audience",
    "key",
    "digest",
    "multiple",
    "expired",
    "future",
    "origin",
    "encoding",
    "unsigned",
    "protocol",
  ] as const
) {
  Deno.test(`gateway profile rejects ${change} without accepting evidence`, async () => {
    const now = Math.floor(Date.now() / 1000);
    const request = await signGatewayEvidence(target, keyId, secret, evidence, {
      created: change === "expired"
        ? now - 301
        : change === "future"
        ? now + 31
        : now,
    });
    const headers = new Headers(request.headers);
    if (change === "digest") {
      headers.set("content-digest", `sha-256=:${btoa("z".repeat(32))}:`);
    }
    if (change === "multiple") {
      headers.append("signature-input", headers.get("signature-input")!);
    }
    if (change === "origin") headers.set("origin", "https://supporter.invalid");
    if (change === "encoding") headers.set("content-encoding", "gzip");
    if (change === "unsigned") headers.delete("signature");
    if (change === "protocol") {
      headers.set(
        "x-africlub-gateway-protocol",
        "africlub.receiver-refund-settlement.v1",
      );
    }
    const input = new Request(target, {
      method: "POST",
      headers,
      body: change === "body" ? "{}" : JSON.stringify(evidence),
    });
    let rejected = false;
    try {
      await verifyGatewayRequest(
        input,
        readGatewaySignature(input),
        change === "key" ? btoa("b".repeat(32)) : secret,
        change === "audience"
          ? "https://other.invalid/functions/v1/sms-ingest"
          : target,
      );
    } catch (error) {
      rejected = error instanceof HttpError;
    }
    assertEquals(rejected, true);
  });
}
for (
  const [label, body] of [
    ["supporter identity", { ...evidence, userId: "foreign" }],
    ["AI draft", { ...evidence, amount: 2.5 }],
    ["unsettled", { ...evidence, settlementStatus: "pending" }],
    ["missing receiver", { ...evidence, receiver: null }],
    ["missing corroboration", { ...evidence, settlementRecordDigest: null }],
  ] as const
) {
  Deno.test(`receiver projection rejects ${label}`, () => {
    let rejected = false;
    try {
      validateProjection(body);
    } catch {
      rejected = true;
    }
    assertEquals(rejected, true);
  });
}
Deno.test("gateway signer emits deterministic content bytes after object reordering on restart", async () => {
  const reversed = Object.fromEntries(
    Object.entries(evidence).reverse(),
  ) as unknown as GatewayProjection;
  const first = await signGatewayEvidence(target, keyId, secret, evidence);
  const second = await signGatewayEvidence(target, keyId, secret, reversed);
  assertEquals(
    first.headers.get("content-digest"),
    second.headers.get("content-digest"),
  );
});
Deno.test("management delivery rejects a foreign or unconfirmed admission receipt", async () => {
  for (
    const reply of [{
      success: true,
      eventId: "foreign",
      accepted: true,
      processing: "processed",
    }, {
      success: true,
      eventId: evidence.eventId,
      accepted: false,
      processing: "pending",
    }]
  ) {
    let rejected = false;
    try {
      await deliverGatewayEvidence(
        target,
        keyId,
        secret,
        evidence,
        async () =>
          new Response(JSON.stringify(reply), {
            headers: { "content-type": "application/json" },
            status: 202,
          }),
      );
    } catch {
      rejected = true;
    }
    assertEquals(rejected, true);
  }
});

Deno.test("management payer projection matches independently calculated provider/country-specific digest", async () => {
  assertEquals(
    await payerAccountDigest("mtn_rwanda", "RW", "+250799966001"),
    evidence.payerAccountDigest,
  );
  assertEquals(
    await payerAccountDigest("mtn_rwanda", "UG", "+250799966001") ===
      evidence.payerAccountDigest,
    false,
  );
});
