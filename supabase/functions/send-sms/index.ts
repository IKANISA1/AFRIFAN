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

import { sendOtpTemplate } from "../_shared/whatsapp.ts";

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
Deno.serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload: SendSmsHookPayload = await req.json();
    const phone = payload.user?.phone;
    const otp = payload.sms?.otp;

    if (!phone || !otp) {
      console.error("send-sms: missing phone or otp in payload", payload);
      return new Response(
        JSON.stringify({ error: "Missing phone or otp" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log(`send-sms: delivering OTP to ${phone.slice(0, 6)}***`);

    // Send via WhatsApp Cloud API using the "gikundiro" template
    await sendOtpTemplate({
      phone,
      code: otp,
      language: "en_US",
    });

    console.log(`send-sms: OTP delivered to ${phone.slice(0, 6)}***`);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("send-sms: failed to deliver OTP:", message);

    // Return 500 so Supabase Auth knows delivery failed
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
