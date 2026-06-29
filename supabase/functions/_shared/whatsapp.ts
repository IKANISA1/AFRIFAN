import {
  normalizePhone,
  toOtpTemplateLanguage,
  toWhatsAppRecipient,
} from "./phone.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }

  return value;
}

function optionalEnv(name: string): string | undefined {
  const value = Deno.env.get(name)?.trim();
  return value && value.length > 0 ? value : undefined;
}

function requireAnyEnv(names: string[]): string {
  for (const name of names) {
    const value = optionalEnv(name);
    if (value) return value;
  }

  throw new Error(`Missing environment variable: ${names.join(" or ")}`);
}

function whatsappGraphApiVersion(): string {
  const configured = optionalEnv("WHATSAPP_GRAPH_API_VERSION") ??
    optionalEnv("WHATSAPP_CLOUD_API_VERSION") ??
    "v25.0";
  return configured.startsWith("v") ? configured : `v${configured}`;
}

async function postWhatsAppMessage(payload: Record<string, unknown>) {
  const phoneNumberId = requireEnv("WHATSAPP_PHONE_NUMBER_ID");
  const accessToken = requireAnyEnv([
    "WHATSAPP_CLOUD_API_TOKEN",
    "WHATSAPP_CLOUD_ACCESS_TOKEN",
    "WHATSAPP_ACCESS_TOKEN",
  ]);
  const response = await fetch(
    `https://graph.facebook.com/${whatsappGraphApiVersion()}/${phoneNumberId}/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  );

  if (response.ok) {
    return;
  }

  const errorBody = await response.text();
  throw new Error(
    `WhatsApp API request failed with ${response.status}: ${errorBody}`,
  );
}

export async function sendTextMessage(options: {
  phone: string;
  body: string;
}) {
  const normalizedPhone = normalizePhone(options.phone);
  await postWhatsAppMessage({
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to: toWhatsAppRecipient(normalizedPhone),
    type: "text",
    text: {
      preview_url: false,
      body: options.body,
    },
  });
}

/**
 * Sends a WhatsApp OTP using the "gikundiro" Authentication template.
 *
 * Template format (with Copy Code button):
 *   "{{1}} is your verification code. Expires in 10 minutes."
 *   [Copy code]
 *
 * For WhatsApp Authentication templates with copy_code, the OTP goes in
 * a `button` component with sub_type `url` and the code as parameter,
 * AND in the `body` component as the {{1}} placeholder.
 */
export async function sendOtpTemplate(options: {
  phone: string;
  code: string;
  language: string;
}) {
  const templateName = optionalEnv("WHATSAPP_AUTH_TEMPLATE_NAME") ??
    "gikundiro";
  const language = optionalEnv("WHATSAPP_AUTH_TEMPLATE_LANGUAGE") ??
    options.language;

  await postWhatsAppMessage({
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to: toWhatsAppRecipient(options.phone),
    type: "template",
    template: {
      name: templateName,
      language: {
        code: toOtpTemplateLanguage(language),
      },
      components: [
        {
          type: "body",
          parameters: [
            {
              type: "text",
              text: options.code,
            },
          ],
        },
        {
          type: "button",
          sub_type: "url",
          index: "0",
          parameters: [
            {
              type: "text",
              text: options.code,
            },
          ],
        },
      ],
    },
  });
}

export async function sendContributionConfirmation(options: {
  phone: string;
  amount: number;
  reference: string;
  groupName: string;
}) {
  await sendTextMessage({
    phone: options.phone,
    body:
      `✅ Your contribution of RWF ${options.amount} to ${options.groupName}\n` +
      `has been confirmed. Reference: ${options.reference}`,
  });
}
