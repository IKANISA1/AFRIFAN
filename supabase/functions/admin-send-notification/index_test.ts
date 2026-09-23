import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { createAdminSendNotificationHandler } from "./index.ts";

function buildRequest() {
  return new Request(
    "https://example.com/functions/v1/admin-send-notification",
    {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        title: "Matchday alert",
        body: "Kickoff in 30 minutes.",
        audience: "all_fans",
        deliveryMode: "send_now",
      }),
    },
  );
}

Deno.test("admin-send-notification fails closed when notifications are disabled", async () => {
  const handler = createAdminSendNotificationHandler({
    validateRequest: async () =>
      ({
        userId: "admin-1",
        clubId: "24",
        roles: ["club_admin"],
        supabase: {},
      }) as never,
    enforceFeature: async () =>
      new Response(JSON.stringify({ error: "notifications disabled" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      }),
    createAdminClient: () => {
      throw new Error(
        "Admin client should not be created when notifications are disabled.",
      );
    },
  });

  const response = await handler(buildRequest());
  const payload = await response.json();

  assertEquals(response.status, 403);
  assertEquals(payload.error, "notifications disabled");
});
