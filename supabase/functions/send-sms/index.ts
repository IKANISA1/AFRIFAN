/**
 * Supabase Auth Send SMS Hook
 *
 * This edge function replaces Twilio (or any third-party SMS provider) and
 * delivers OTP codes via the WhatsApp Cloud API using the existing
 * "gikundiro" authentication template.
 *
 * Supabase Auth POSTs to this hook whenever it needs to send an SMS/OTP.
 * The payload shape is:
 *   { user: { phone: string }, sms: { otp: string } }
 *
 * The hook must respond with 200 OK to confirm delivery.
 *
 * Environment variables required:
 *   WHATSAPP_PHONE_NUMBER_ID  – Meta phone number ID
 *   WHATSAPP_ACCESS_TOKEN     – Meta access token
 */

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { hasActiveAdminAssignmentForAuthUser } from "../_shared/admin_access.ts";
import { sendOtpTemplate } from "../_shared/whatsapp.ts";
import { jsonOk, jsonError } from "../_shared/response.ts";

// ── Types ───────────────────────────────────────────────────────
interface SendSmsHookPayload {
  user: {
    phone: string;
    id?: string;
  };
  sms: {
    otp: string;
  };
}

// ── Handler ─────────────────────────────────────────────────────
async function handleRequest(req: Request) {
  // Only accept POST
  if (req.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    const payload: SendSmsHookPayload = await req.json();
    const phone = payload.user?.phone;
    const otp = payload.sms?.otp;

    if (!phone || !otp) {
      console.error("send-sms: missing phone or otp in payload", payload);
      return jsonError("Missing phone or otp", 400);
    }

    const isEligibleAdmin = await hasActiveAdminAssignmentForAuthUser({
      userId: payload.user?.id ?? null,
      phone,
    });
    if (!isEligibleAdmin) {
      console.warn(`send-sms: blocked OTP delivery for non-admin phone ${phone.slice(0, 6)}***`);
      return jsonError("Admin WhatsApp OTP is only available for approved admin numbers.", 403);
    }

    console.log(`send-sms: delivering OTP to ${phone.slice(0, 6)}***`);

    // Send via WhatsApp Cloud API using the "gikundiro" template
    await sendOtpTemplate({
      phone,
      code: otp,
      language: "en_US",
    });

    console.log(`send-sms: OTP delivered to ${phone.slice(0, 6)}***`);

    return jsonOk({ success: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("send-sms: failed to deliver OTP:", message);

    // Return 500 so Supabase Auth knows delivery failed
    return jsonError(message, 500);
  }
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
