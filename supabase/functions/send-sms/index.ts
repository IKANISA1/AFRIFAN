/**
 * Supabase Auth phone OTP delivery hook.
 *
 * The current delivery path uses the WhatsApp Cloud API with the existing
 * "gikundiro" authentication template. The hook must stay generic so both
 * supporter and admin verification flows can receive phone OTPs.
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

    console.log(`send-sms: delivering OTP to ${phone.slice(0, 6)}***`);

    // Deliver via the active WhatsApp OTP template.
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
