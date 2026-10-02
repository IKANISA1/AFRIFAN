import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  errorResponse,
  jsonError,
  jsonOk,
  withEdgeBoundary,
} from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { createLifecycleAdminClient } from "../_shared/account_lifecycle_client.ts";
import { HttpError } from "../_shared/http_error.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { uuid } from "../_shared/trusted_sms.ts";

export function requireSmsProcessor(request: Request): void {
  const expected = Deno.env.get("SMS_PROCESSOR_SECRET") ?? "";
  const supplied = request.headers.get("x-sms-processor-secret") ?? "";
  if (!/^[A-Za-z0-9+/]{43,86}={0,2}$/.test(expected)) {
    throw new HttpError(503, "Payment processing is unavailable.");
  }
  let difference = expected.length ^ supplied.length;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ (supplied.charCodeAt(i) || 0);
  }
  if (difference || request.headers.has("origin")) {
    throw new HttpError(401, "Processor authentication required.");
  }
}
type Dependencies = {
  createAdminClient: () => any;
  enforceRateLimit: typeof enforceRateLimit;
};
export async function handleRequest(
  request: Request,
  dependencies: Partial<Dependencies> = {},
) {
  const deps = {
    createAdminClient: createLifecycleAdminClient,
    enforceRateLimit,
    ...dependencies,
  };
  try {
    if (request.method !== "POST") return jsonError("Method not allowed", 405);
    requireSmsProcessor(request);
    if (Deno.env.get("TRUSTED_SMS_INGRESS_ENABLED") !== "true") {
      throw new HttpError(503, "Trusted payment ingress is disabled.");
    }
    const body = await readBoundedJson(request, { maxBytes: 1024 });
    if (
      Object.keys(body).join() !== "eventId" ||
      typeof body.eventId !== "string" || !uuid.test(body.eventId)
    ) throw new HttpError(400, "A gateway event receipt is required.");
    const admin = deps.createAdminClient();
    const event = await admin.rpc("get_trusted_sms_gateway_event", {
      p_event_id: body.eventId,
    });
    if (event.error) throw event.error;
    if (
      !event.data || !uuid.test(event.data.gateway_id) ||
      !Number.isSafeInteger(event.data.club_id)
    ) throw new HttpError(404, "Gateway evidence not found.");
    await deps.enforceRateLimit(
      admin,
      event.data.gateway_id,
      "parse-momo-sms",
      { maxRequests: 60, windowSeconds: 300, clubId: event.data.club_id },
    );
    // SQL deterministically interprets the immutable receiver settlement projection
    // and calls the existing fenced parse and exact-target money writers atomically.
    // AI output never selects a beneficiary, amount, receiver or business target.
    const result = await admin.rpc("process_trusted_sms_gateway_evidence", {
      p_event_id: body.eventId,
    });
    if (result.error) throw result.error;
    if (
      result.data?.event_id !== body.eventId ||
      !["confirmed", "allocated", "manual_review"].includes(result.data?.status)
    ) throw new Error("Invalid payment processing receipt");
    return jsonOk({
      success: true,
      eventId: body.eventId,
      status: result.data.status,
      replay: result.data.replay === true,
    });
  } catch (error) {
    return errorResponse(error);
  }
}
if (import.meta.main) Deno.serve(withEdgeBoundary(handleRequest));
