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
 *   WHATSAPP_PHONE_NUMBER_ID       – Meta phone number ID
 *   WHATSAPP_CLOUD_API_TOKEN       – Meta Cloud API token
 *     or WHATSAPP_CLOUD_ACCESS_TOKEN / WHATSAPP_ACCESS_TOKEN
 *   WHATSAPP_AUTH_TEMPLATE_NAME    – optional, defaults to "gikundiro"
 *   WHATSAPP_AUTH_TEMPLATE_LANGUAGE – optional, defaults to "en_US"
 *   WHATSAPP_GRAPH_API_VERSION     – optional, defaults to "v25.0"
 */

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { sendOtpTemplate } from "../_shared/whatsapp.ts";
import { createSendSmsHandler } from "./handler.ts";

export const handleRequest = createSendSmsHandler({
  sendOtpTemplate,
  getHookSecret: () =>
    Deno.env.get("AUTH_HOOK_SEND_SMS_SECRET")?.trim(),
});

if (import.meta.main) {
  Deno.serve(handleRequest);
}
