import {
  encode64,
  gatewayKey,
  type GatewayProjection,
  type GatewayProtocol,
  sha256,
  signatureBase,
  signatureParameters,
  uuid,
  validateProjection,
} from "../_shared/trusted_sms.ts";
import {
  refundGatewayFields,
  type RefundGatewayProjection,
  validateRefundProjection,
  validateRefundReceipt,
} from "../_shared/refund_gateway.ts";
import { fetchBoundedJson } from "../_shared/http.ts";

/** Server-side management gateway caller. Never ship provisioning secrets in a supporter application. */
export async function signGatewayEvidence(
  targetUri: string,
  keyId: string,
  secret: string,
  evidence: GatewayProjection,
  options: { nonce?: string; created?: number } = {},
): Promise<Request> {
  validateProjection(evidence);
  // Fixed member order preserves the signed body across process restarts.
  const body = JSON.stringify({
    protocol: evidence.protocol,
    eventId: evidence.eventId,
    checkoutReference: evidence.checkoutReference,
    providerTransactionId: evidence.providerTransactionId,
    receiver: evidence.receiver,
    provider: evidence.provider,
    country: evidence.country,
    currency: evidence.currency,
    amount: evidence.amount,
    settledAt: evidence.settledAt,
    settlementStatus: evidence.settlementStatus,
    payerAccountDigest: evidence.payerAccountDigest,
    settlementRecordId: evidence.settlementRecordId,
    settlementRecordDigest: evidence.settlementRecordDigest,
  });
  return await signProjection(
    targetUri,
    keyId,
    secret,
    body,
    evidence.protocol,
    options,
  );
}
export async function signGatewayRefundEvidence(
  targetUri: string,
  keyId: string,
  secret: string,
  evidence: RefundGatewayProjection,
  options: { nonce?: string; created?: number } = {},
): Promise<Request> {
  validateRefundProjection(evidence);
  const body = JSON.stringify(
    Object.fromEntries(
      refundGatewayFields.map((field) => [field, evidence[field]]),
    ),
  );
  return await signProjection(
    targetUri,
    keyId,
    secret,
    body,
    evidence.protocol,
    options,
  );
}
async function signProjection(
  targetUri: string,
  keyId: string,
  secret: string,
  body: string,
  protocol: GatewayProtocol,
  options: { nonce?: string; created?: number },
): Promise<Request> {
  if (
    !uuid.test(keyId) || !targetUri.startsWith("https://") ||
    new URL(targetUri).search
  ) throw new Error("Invalid gateway configuration");
  const nonce = options.nonce ?? crypto.randomUUID();
  if (!uuid.test(nonce)) throw new Error("Invalid gateway nonce");
  const created = options.created ?? Math.floor(Date.now() / 1000);
  const parameters = signatureParameters(keyId, nonce, created, created + 120);
  const digest = `sha-256=:${
    encode64(await sha256(new TextEncoder().encode(body)))
  }:`;
  const signed = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      await gatewayKey(secret),
      new TextEncoder().encode(
        signatureBase(targetUri, digest, parameters, protocol),
      ),
    ),
  );
  return new Request(targetUri, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "content-digest": digest,
      "x-africlub-gateway-protocol": protocol,
      "signature-input": `sig1=${parameters}`,
      signature: `sig1=:${encode64(signed)}:`,
    },
    body,
  });
}
/** Reuse the same event and settlement identity after response loss; a new nonce may reauthenticate it. */
export async function deliverGatewayEvidence(
  targetUri: string,
  keyId: string,
  secret: string,
  evidence: GatewayProjection,
  fetchFn: typeof fetch = fetch,
) {
  const request = await signGatewayEvidence(targetUri, keyId, secret, evidence);
  const receipt = await fetchBoundedJson(fetchFn, targetUri, {
    method: "POST",
    headers: request.headers,
    body: await request.arrayBuffer(),
  }, { maxBytes: 8192, timeoutMs: 15000 });
  if (
    receipt.eventId !== evidence.eventId || receipt.accepted !== true ||
    receipt.success !== true ||
    !["pending", "processed"].includes(String(receipt.processing))
  ) {
    throw new Error(
      "Gateway admission could not be verified; retain the original event for recovery.",
    );
  }
  return receipt;
}
/** The provider queue retains the original refund event/instruction after an unknown response. */
export async function deliverGatewayRefundEvidence(
  targetUri: string,
  keyId: string,
  secret: string,
  evidence: RefundGatewayProjection,
  fetchFn: typeof fetch = fetch,
) {
  const request = await signGatewayRefundEvidence(
    targetUri,
    keyId,
    secret,
    evidence,
  );
  const receipt = await fetchBoundedJson(fetchFn, targetUri, {
    method: "POST",
    headers: request.headers,
    body: await request.arrayBuffer(),
  }, { maxBytes: 8192, timeoutMs: 15000 });
  if (
    receipt.eventId !== evidence.eventId ||
    receipt.refundId !== evidence.refundId ||
    receipt.instructionId !== evidence.instructionId ||
    receipt.currency !== evidence.currency ||
    receipt.evidenceStatus !== evidence.settlementStatus ||
    receipt.success !== true || receipt.accepted !== true ||
    !["pending", "processed"].includes(String(receipt.processing))
  ) {
    throw new Error(
      "Refund admission could not be verified; retain the original event for recovery.",
    );
  }
  if (receipt.processing === "processed") {
    validateRefundReceipt({
      event_id: receipt.eventId,
      refund_id: receipt.refundId,
      instruction_id: receipt.instructionId,
      status: receipt.refundStatus,
      confirmed_amount: receipt.confirmedAmount,
      currency: receipt.currency,
      compensation_id: receipt.compensationId,
      replay: receipt.replay,
    }, evidence);
  }
  if (
    receipt.processing === "pending" &&
    ["refundStatus", "confirmedAmount", "compensationId", "replay"].some(
      (field) => field in receipt,
    )
  ) {
    throw new Error(
      "Pending refund admission cannot acknowledge unverified processing.",
    );
  }
  return receipt;
}

/** Derive from the receiver/provider record's actual payer, never a supporter declaration. */
export async function payerAccountDigest(
  provider: string,
  country: string,
  verifiedPayerPhone: string,
): Promise<string> {
  if (
    !/^[a-z][a-z0-9_]{1,39}$/.test(provider) || !/^[A-Z]{2}$/.test(country) ||
    !/^[+]?[0-9]{8,15}$/.test(verifiedPayerPhone)
  ) throw new Error("Unsupported payer account identity");
  const digits = verifiedPayerPhone.replace(/^\+/, "");
  const bytes = await sha256(
    new TextEncoder().encode(
      `africlub-payer-v1:${provider}:${country}:${digits}`,
    ),
  );
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
