import { createSendNotificationHandler } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

const userId = "11111111-1111-4111-8111-111111111111";
const success = {
  success: true,
  sent_count: 1,
  failed_count: 0,
  cleaned_tokens: 0,
  errors: [],
};

Deno.test("send-notification requires an internal secret", async () => {
  const handler = createSendNotificationHandler({
    getSecretKeys: () => ["current", "legacy"],
    sendToUser: async () => success,
    sendToTopic: async () => success,
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({ user_id: userId, title: "Title", body: "Body" }),
    }),
  );
  assertEquals(response.status, 401, "status");
});

Deno.test("send-notification accepts a controlled current or legacy key", async () => {
  const deliveries: string[] = [];
  const handler = createSendNotificationHandler({
    getSecretKeys: () => ["current", "legacy"],
    sendToUser: async (id) => {
      deliveries.push(id);
      return success;
    },
    sendToTopic: async () => success,
  });
  for (const token of ["current", "legacy"]) {
    const response = await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: JSON.stringify({ user_id: userId, title: "Title", body: "Body" }),
      }),
    );
    assertEquals(response.status, 200, `status for ${token}`);
  }
  assertEquals(deliveries.length, 2, "deliveries");
});

Deno.test("send-notification rejects invalid targeting before delivery", async () => {
  let called = false;
  const handler = createSendNotificationHandler({
    getSecretKeys: () => ["internal"],
    sendToUser: async () => {
      called = true;
      return success;
    },
    sendToTopic: async () => success,
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer internal" },
      body: JSON.stringify({
        user_id: "not-a-user",
        title: "Title",
        body: "Body",
      }),
    }),
  );
  assertEquals(response.status, 400, "status");
  assertEquals(called, false, "delivery called");
});
