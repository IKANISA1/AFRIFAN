import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { prepareNotificationDeviceSender } from "./notification_fcm.ts";
import { type NotificationDevice } from "./notification_dispatch.ts";

Deno.test("actual per-device FCM adapter preserves provider message defaults and never retries uncertain requests", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...pkcs8))
  }\n-----END PRIVATE KEY-----`;
  const names = ["FIREBASE_SERVICE_ACCOUNT_JSON", "FIREBASE_PROJECT_ID"];
  const saved = names.map((name) => Deno.env.get(name));
  Deno.env.set(
    names[0],
    JSON.stringify({
      project_id: "africlub-test",
      client_email: "test@example.invalid",
      private_key: pem,
    }),
  );
  Deno.env.set(names[1], "africlub-test");
  const originalFetch = globalThis.fetch;
  let sends = 0, mode = "accepted";
  const device = {
    token: "synthetic-device",
    title: "Alert",
    body: "Matchday",
    image_url: null,
    notification_id: "99002900-0000-4000-8000-000000000003",
    club_id: 24,
    audience_type: "all_fans",
    audience_tier: null,
    audience_group_id: null,
  } as NotificationDevice;
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "oauth2.googleapis.com") {
      return Response.json({
        access_token: "synthetic-oauth",
        expires_in: 3600,
      });
    }
    assertEquals(
      url.href,
      "https://fcm.googleapis.com/v1/projects/africlub-test/messages:send",
    );
    sends++;
    const body = JSON.parse(String(init?.body));
    assertEquals(body.message, {
      token: device.token,
      notification: { title: "Alert", body: "Matchday" },
      android: {
        priority: "high",
        notification: {
          channel_id: "cool_default",
          default_sound: true,
          default_vibrate_timings: true,
        },
      },
      data: {
        notification_id: device.notification_id,
        club_id: "24",
        audience_type: "all_fans",
      },
    });
    if (mode === "lost") throw new Error("synthetic connection lost");
    if (mode === "rejected") {
      return Response.json({ error: { status: "NOT_FOUND" } }, { status: 404 });
    }
    return Response.json({ name: "projects/africlub-test/messages/original" });
  };
  try {
    const sender = await prepareNotificationDeviceSender(Date.now() + 30000);
    assertEquals(await sender(device, Date.now() + 5000), {
      outcome: "accepted",
      provider_message_name: "projects/africlub-test/messages/original",
    });
    mode = "rejected";
    assertEquals(await sender(device, Date.now() + 5000), {
      outcome: "rejected",
      error_code: "NOT_FOUND",
    });
    mode = "lost";
    try {
      await sender(device, Date.now() + 5000);
    } catch (_) { /* dispatcher persists unknown */ }
    assertEquals(sends, 3);
    assertEquals(await sender(device, Date.now() - 1), {
      outcome: "unknown",
      error_code: "UNKNOWN",
    });
    assertEquals(sends, 3);
  } finally {
    globalThis.fetch = originalFetch;
    names.forEach((name, i) =>
      saved[i] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, saved[i]!)
    );
  }
});
