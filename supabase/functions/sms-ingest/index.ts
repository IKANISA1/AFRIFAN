import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { normalizePhone, PhoneValidationError } from "../_shared/phone.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import {
  asString,
  buildDeviceMessageKey,
  isApprovedSender,
  normalizeIngestionSource,
  normalizeWhitespace,
  parseReceivedAt,
} from "./rules.ts";

type SmsIngestRequest = {
  sender?: string;
  smsBody?: string;
  smsReceivedAt?: string;
  deviceMessageKey?: string;
  ingestionSource?: string;
  countryCode?: string;
};

const parseSkippedStatuses = new Set(["processing", "parsed", "ignored"]);

function normalizeOptionalPhone(value: unknown): string | null {
  const raw = asString(value);
  if (!raw) {
    return null;
  }

  try {
    return normalizePhone(raw);
  } catch (error) {
    if (error instanceof PhoneValidationError) {
      return null;
    }
    throw error;
  }
}

async function queueParseIfNeeded(options: {
  rawSmsId: string;
  parseStatus?: string | null;
  userClient: any;
}) {
  const normalizedParseStatus = (options.parseStatus ?? "pending").trim()
    .toLowerCase();
  if (parseSkippedStatuses.has(normalizedParseStatus)) {
    return false;
  }

  const result = await options.userClient.functions.invoke("parse-momo-sms", {
    body: { rawSmsId: options.rawSmsId },
  });

  const payload = result.data;
  if (result.error) {
    throw result.error;
  }
  if (payload && typeof payload === "object" && "success" in payload) {
    if ((payload as { success?: boolean }).success === false) {
      throw new Error(
        ((payload as { message?: string }).message ?? "Failed to parse SMS")
          .toString(),
      );
    }
  }

  return true;
}

async function handleRequest(request: Request) {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  const validated = await validateRequest(request);
  if (isErrorResponse(validated)) return validated;
  const { userId, supabase: userClient } = validated;

  const adminClient = createAdminClient();
  const RATE_LIMIT_PER_HOUR = 100;

  try {
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return jsonError("Authentication required", 401);

    // --- Per-user rate limiting (G3) ---
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count: recentCount, error: countError } = await adminClient
      .from("momo_sms_raw")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", oneHourAgo);
    if (countError) {
      throw countError;
    }
    if ((recentCount ?? 0) >= RATE_LIMIT_PER_HOUR) {
      return jsonError(
        "Rate limit exceeded. Max " + RATE_LIMIT_PER_HOUR + " SMS per hour.",
        429,
      );
    }

    const body = await request.json() as SmsIngestRequest;
    const sender = asString(body.sender);
    const smsBody = normalizeWhitespace(body.smsBody?.trim() ?? "");
    if (!sender || smsBody.length === 0) {
      return jsonError("sender and smsBody are required", 400);
    }
    if (!isApprovedSender(sender)) {
      return jsonError("Unsupported SMS sender", 400);
    }

    const smsReceivedAt = parseReceivedAt(asString(body.smsReceivedAt));
    const deviceMessageKey = await buildDeviceMessageKey({
      sender,
      smsBody,
      smsReceivedAt,
    });
    const ingestionSource = normalizeIngestionSource(body.ingestionSource);
    const countryCode = asString(body.countryCode)?.toUpperCase() || null;

    const appUserResult = await adminClient
      .from("user_private_contacts")
      .select("momo_number, whatsapp_number")
      .eq("user_id", userId)
      .maybeSingle();
    if (appUserResult.error) {
      throw appUserResult.error;
    }

    const otpWhatsAppNumber = normalizeOptionalPhone(
      appUserResult.data?.whatsapp_number ??
        appUserResult.data?.momo_number ??
        user.user_metadata?.phone ??
        user.phone,
    );

    const existingResult = await adminClient
      .from("momo_sms_raw")
      .select("id, parse_status, otp_whatsapp_number")
      .eq("user_id", userId)
      .eq("device_message_key", deviceMessageKey)
      .maybeSingle();
    if (existingResult.error) {
      throw existingResult.error;
    }

    if (existingResult.data) {
      if (
        otpWhatsAppNumber &&
        !asString(existingResult.data.otp_whatsapp_number)
      ) {
        await adminClient
          .from("momo_sms_raw")
          .update({ otp_whatsapp_number: otpWhatsAppNumber })
          .eq("id", existingResult.data.id as string);
      }

      let parseQueued = false;
      try {
        parseQueued = await queueParseIfNeeded({
          rawSmsId: existingResult.data.id as string,
          parseStatus: asString(existingResult.data.parse_status),
          userClient,
        });
      } catch (error) {
        await recordOperationalHealthEvent(adminClient, {
          service: "sms_ingest",
          component: "sms-ingest",
          status: "warn",
          severity: "warning",
          issueCode: "parse_queue_failed",
          message: "SMS was already stored, but parse queueing failed.",
          functionName: "sms-ingest",
          userId,
          subjectType: "momo_sms_raw",
          subjectId: existingResult.data.id as string,
          metadata: {
            sender,
            ingestion_source: ingestionSource,
            error: error instanceof Error ? error.message : String(error),
          },
        });
      }

      return jsonOk({
        success: true,
        rawSmsId: existingResult.data.id,
        inserted: false,
        parseQueued,
        otpWhatsAppNumber: asString(existingResult.data.otp_whatsapp_number) ??
          otpWhatsAppNumber,
      });
    }

    const insertResult = await adminClient
      .from("momo_sms_raw")
      .insert({
        user_id: userId,
        device_message_key: deviceMessageKey,
        sender,
        sms_body: smsBody,
        sms_received_at: smsReceivedAt,
        ingestion_source: ingestionSource,
        otp_whatsapp_number: otpWhatsAppNumber,
        country_code: countryCode,
        parse_status: "pending",
      })
      .select("id")
      .single();
    if (insertResult.error) {
      throw insertResult.error;
    }

    const rawSmsId = insertResult.data.id as string;
    let parseQueued = false;
    try {
      parseQueued = await queueParseIfNeeded({
        rawSmsId,
        parseStatus: "pending",
        userClient,
      });
    } catch (error) {
      await recordOperationalHealthEvent(adminClient, {
        service: "sms_ingest",
        component: "sms-ingest",
        status: "warn",
        severity: "warning",
        issueCode: "parse_queue_failed",
        message: "SMS was stored, but parse queueing failed.",
        functionName: "sms-ingest",
        userId,
        subjectType: "momo_sms_raw",
        subjectId: rawSmsId,
        metadata: {
          sender,
          ingestion_source: ingestionSource,
          error: error instanceof Error ? error.message : String(error),
        },
      });
    }

    return jsonOk({
      success: true,
      rawSmsId,
      inserted: true,
      parseQueued,
      otpWhatsAppNumber,
    });
  } catch (error) {
    console.error("sms-ingest failed", error);
    await recordEdgeFunctionFailure(adminClient, {
      functionName: "sms-ingest",
      error,
      issueCode: "sms_ingest_failed",
    });
    return jsonError(
      error instanceof Error ? error.message : "Failed to ingest SMS",
      500,
    );
  }
}

if (import.meta.main) {
  Deno.serve((req: Request) => handleRequest(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
