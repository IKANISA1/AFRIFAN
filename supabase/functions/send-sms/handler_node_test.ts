import assert from "node:assert/strict";
import test from "node:test";

import { createSendSmsHandler } from "./handler.ts";
import { verifyStandardWebhook } from "../_shared/standard_webhook.ts";

const webhookId = "msg_send_sms_test";
const timestamp = 1_785_312_000;
const secretBytes = new TextEncoder().encode(
  "0123456789abcdef0123456789abcdef",
);
const secret = `v1,whsec_${btoa(String.fromCharCode(...secretBytes))}`;
const validPayload = JSON.stringify({
  user: { phone: "+250788000001" },
  sms: { otp: "123456" },
});

async function signatureFor(payload: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    secretBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(`${webhookId}.${timestamp}.${payload}`),
    ),
  );
  return `v1,${btoa(String.fromCharCode(...signature))}`;
}

async function signedRequest(
  payload = validPayload,
  overrides: Record<string, string> = {},
) {
  return new Request("https://example.test/functions/v1/send-sms", {
    method: "POST",
    headers: {
      "webhook-id": webhookId,
      "webhook-timestamp": String(timestamp),
      "webhook-signature": await signatureFor(payload),
      ...overrides,
    },
    body: payload,
  });
}

test("verifies a current Standard Webhooks signature", async () => {
  const request = await signedRequest();
  assert.equal(
    await verifyStandardWebhook({
      payload: validPayload,
      headers: request.headers,
      secret,
      nowSeconds: timestamp,
    }),
    true,
  );
});

test("rejects stale and malformed Standard Webhooks signatures", async () => {
  const request = await signedRequest(validPayload, {
    "webhook-signature": "v1,invalid",
  });
  assert.equal(
    await verifyStandardWebhook({
      payload: validPayload,
      headers: request.headers,
      secret,
      nowSeconds: timestamp,
    }),
    false,
  );
  const staleRequest = await signedRequest();
  assert.equal(
    await verifyStandardWebhook({
      payload: validPayload,
      headers: staleRequest.headers,
      secret,
      nowSeconds: timestamp + 301,
    }),
    false,
  );
});

test("delivers only a valid signed payload and returns an empty 200", async () => {
  const deliveries: Array<Record<string, unknown>> = [];
  const handler = createSendSmsHandler({
    sendOtpTemplate: async (options) => {
      deliveries.push(options);
    },
    getHookSecret: () => secret,
    nowSeconds: () => timestamp,
  });

  const response = await handler(await signedRequest());

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(await response.text(), "");
  assert.equal(deliveries.length, 1);
  assert.equal(deliveries[0]?.phone, "+250788000001");
  assert.equal(deliveries[0]?.code, "123456");
});

test("fails closed when the hook secret is absent", async () => {
  let deliveryCalled = false;
  const handler = createSendSmsHandler({
    sendOtpTemplate: async () => {
      deliveryCalled = true;
    },
    getHookSecret: () => undefined,
    nowSeconds: () => timestamp,
  });

  const response = await handler(await signedRequest());
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(deliveryCalled, false);
  assert.equal(payload.code, "SEND_SMS_HOOK_NOT_CONFIGURED");
  assert.equal(payload.change_confirmed, false);
});

test("rejects unsigned and invalid payloads before delivery", async () => {
  let deliveryCalled = false;
  const handler = createSendSmsHandler({
    sendOtpTemplate: async () => {
      deliveryCalled = true;
    },
    getHookSecret: () => secret,
    nowSeconds: () => timestamp,
  });

  const unsignedResponse = await handler(
    new Request("https://example.test/functions/v1/send-sms", {
      method: "POST",
      body: validPayload,
    }),
  );
  const invalidPayload = JSON.stringify({
    user: { phone: "private-phone" },
    sms: { otp: "secret-otp" },
  });
  const invalidResponse = await handler(await signedRequest(invalidPayload));

  assert.equal(unsignedResponse.status, 401);
  assert.equal(invalidResponse.status, 400);
  assert.equal(deliveryCalled, false);
  assert.doesNotMatch(
    JSON.stringify(await invalidResponse.json()),
    /private-phone|secret-otp/,
  );
});

test("aborts a stalled delivery before the HTTP Hook deadline", async () => {
  let signal: AbortSignal | undefined;
  const handler = createSendSmsHandler({
    sendOtpTemplate: async (options) => {
      signal = options.signal;
      await new Promise<never>(() => {});
    },
    getHookSecret: () => secret,
    nowSeconds: () => timestamp,
    deliveryTimeoutMs: 10,
  });

  const response = await handler(await signedRequest());
  const payload = await response.json();

  assert.equal(response.status, 504);
  assert.equal(signal?.aborted, true);
  assert.equal(payload.code, "OTP_DELIVERY_TIMEOUT");
  assert.equal(payload.change_confirmed, false);
});

test("sanitizes delivery failures without exposing phone, OTP, or provider data", async () => {
  const handler = createSendSmsHandler({
    sendOtpTemplate: async () => {
      throw new Error(
        "token=provider-secret phone=+250788000001 otp=123456",
      );
    },
    getHookSecret: () => secret,
    nowSeconds: () => timestamp,
  });

  const response = await handler(await signedRequest());
  const payload = await response.json();
  const encoded = JSON.stringify(payload);

  assert.equal(response.status, 502);
  assert.equal(payload.code, "OTP_DELIVERY_FAILED");
  assert.equal(payload.change_confirmed, false);
  assert.doesNotMatch(
    encoded,
    /provider-secret|\+250788000001|123456/,
  );
});
