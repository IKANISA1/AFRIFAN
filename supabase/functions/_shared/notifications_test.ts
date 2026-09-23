import { assertEquals, assertThrows } from "jsr:@std/assert";

import {
  buildDeliveryUpdate,
  parseNotificationRequest,
} from "./notifications.ts";

Deno.test("parseNotificationRequest normalizes legacy admin screen payload values", () => {
  const parsed = parseNotificationRequest({
    audience: "BY TIER",
    tier: "LEGEND",
    title: "Matchday update",
    body: "Kickoff in one hour.",
    delivery_mode: "SEND NOW",
    image_url: "https://example.com/hero.png",
  });

  assertEquals(parsed.audience.type, "by_tier");
  assertEquals(parsed.audience.tier, "platinum");
  assertEquals(parsed.deliveryMode, "send_now");
  assertEquals(parsed.imageUrl, "https://example.com/hero.png");
});

Deno.test("parseNotificationRequest requires scheduled_at for queued sends", () => {
  assertThrows(
    () =>
      parseNotificationRequest({
        audience: "ALL FANS",
        title: "Queued notice",
        body: "This should be queued.",
        delivery_mode: "SCHEDULE",
      }),
    Error,
    "scheduled_at is required",
  );
});

Deno.test("buildDeliveryUpdate serializes delivery metrics for persistence", () => {
  const update = buildDeliveryUpdate({
    status: "partial",
    requestedRecipientCount: 14,
    successfulUserCount: 11,
    failedUserCount: 3,
    sentCount: 18,
    failedCount: 4,
    cleanedTokens: 2,
    errors: ["Token expired."],
  });

  assertEquals(update["status"], "partial");
  assertEquals(update["requested_recipient_count"], 14);
  assertEquals(update["successful_user_count"], 11);
  assertEquals(update["failed_user_count"], 3);
  assertEquals(update["sent_count"], 18);
  assertEquals(update["failed_count"], 4);
  assertEquals(update["cleaned_tokens"], 2);

  const summary = update["delivery_summary"] as Record<string, unknown>;
  assertEquals(summary["errors"], ["Token expired."]);
});
