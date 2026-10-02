import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  errorResponse,
  jsonError,
  jsonOk,
  withEdgeBoundary,
} from "../_shared/response.ts";
import { createLifecycleAdminClient } from "../_shared/account_lifecycle_client.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { HttpError } from "../_shared/http_error.ts";
import {
  readGatewaySignature,
  refundGatewayProtocol,
  uuid,
  validateProjection,
  verifySignedGatewayJson,
} from "../_shared/trusted_sms.ts";
import {
  validateRefundProjection,
  validateRefundReceipt,
} from "../_shared/refund_gateway.ts";
import { handleRequest as processEvidence } from "../parse-momo-sms/index.ts";

type Dependencies = {
  createAdminClient: () => any;
  enforceRateLimit: typeof enforceRateLimit;
  processEvidence: typeof processEvidence;
};
export async function handleRequest(
  request: Request,
  dependencies: Partial<Dependencies> = {},
) {
  const deps = {
    createAdminClient: createLifecycleAdminClient,
    enforceRateLimit,
    processEvidence,
    ...dependencies,
  };
  try {
    if (request.method !== "POST") return jsonError("Method not allowed", 405);
    // Bearer authentication never grants this separate management capability.
    const signature = readGatewaySignature(request);
    if (Deno.env.get("TRUSTED_SMS_INGRESS_ENABLED") !== "true") {
      throw new HttpError(503, "Trusted payment ingress is disabled.");
    }
    const admin = deps.createAdminClient();
    const isRefund = signature.protocol === refundGatewayProtocol;
    const key = await admin.rpc(
      isRefund
        ? "get_trusted_payment_refund_gateway_key"
        : "get_trusted_sms_gateway_key",
      {
        p_key_id: signature.keyId,
      },
    );
    if (key.error) throw key.error;
    if (
      !key.data || !uuid.test(key.data.gateway_id) ||
      !Number.isSafeInteger(key.data.club_id) ||
      !/^SMS_GATEWAY_KEY_[A-Z0-9_]{1,80}$/.test(key.data.secret_env_name)
    ) throw new HttpError(401, "Gateway authentication required.");
    const secret = Deno.env.get(key.data.secret_env_name);
    const target = `${
      (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "")
    }/functions/v1/sms-ingest`;
    if (!secret) {
      throw new HttpError(503, "Gateway authentication is unavailable.");
    }
    const verified = await verifySignedGatewayJson(
      request,
      signature,
      secret,
      target,
    );
    const projection = isRefund
      ? validateRefundProjection(verified.data)
      : validateProjection(verified.data);
    await deps.enforceRateLimit(admin, key.data.gateway_id, "sms-ingest", {
      maxRequests: 100,
      windowSeconds: 3600,
      clubId: key.data.club_id,
    });
    const admitted = await admin.rpc(
      isRefund
        ? "admit_trusted_payment_refund_evidence"
        : "admit_trusted_sms_gateway_evidence",
      {
        p_key_id: signature.keyId,
        p_nonce: signature.nonce,
        p_created_at: new Date(signature.created * 1000).toISOString(),
        p_expires_at: new Date(signature.expires * 1000).toISOString(),
        p_body_digest: verified.digest,
        p_projection: projection,
      },
    );
    if (admitted.error) throw admitted.error;
    if (
      admitted.data?.event_id !== projection.eventId ||
      (!isRefund && !uuid.test(admitted.data?.raw_sms_id ?? ""))
    ) throw new Error("Invalid ingress receipt");
    if (isRefund) {
      const refund = validateRefundProjection(projection);
      if (
        admitted.data.refund_id !== refund.refundId ||
        !["pending", "settled", "failed", "unknown"].includes(
          admitted.data.status,
        ) || typeof admitted.data.completed !== "boolean" ||
        typeof admitted.data.replay !== "boolean"
      ) throw new Error("Invalid refund admission receipt");
      let receipt: ReturnType<typeof validateRefundReceipt> | undefined;
      try {
        const result = await admin.rpc(
          "process_trusted_payment_refund_evidence",
          { p_event_id: refund.eventId },
        );
        if (result.error) throw result.error;
        receipt = validateRefundReceipt(result.data, refund);
      } catch {
        // Admission is durable. Unknown worker effects must recover through the same event.
      }
      return jsonOk({
        success: true,
        eventId: refund.eventId,
        refundId: refund.refundId,
        instructionId: refund.instructionId,
        currency: refund.currency,
        accepted: true,
        processing: receipt ? "processed" : "pending",
        evidenceStatus: refund.settlementStatus,
        ...(receipt
          ? {
            refundStatus: receipt.status,
            confirmedAmount: receipt.confirmedAmount,
            compensationId: receipt.compensationId,
            replay: receipt.replay,
          }
          : {}),
      }, 202);
    }
    // The durable admission commits first. A lost/failed processing response is a
    // pending receipt; redelivery of the same signed event resumes it.
    let processing = "pending";
    const processorSecret = Deno.env.get("SMS_PROCESSOR_SECRET") ?? "";
    if (processorSecret) {
      try {
        const response = await deps.processEvidence(
          new Request(`${target.replace(/sms-ingest$/, "parse-momo-sms")}`, {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "x-sms-processor-secret": processorSecret,
            },
            body: JSON.stringify({ eventId: projection.eventId }),
          }),
        );
        if (response.ok) processing = "processed";
      } catch {
        // A durable admission remains pending when the worker cannot acknowledge.
      }
    }
    return jsonOk({
      success: true,
      eventId: projection.eventId,
      accepted: true,
      processing,
    }, 202);
  } catch (error) {
    return errorResponse(error);
  }
}
if (import.meta.main) Deno.serve(withEdgeBoundary(handleRequest));
