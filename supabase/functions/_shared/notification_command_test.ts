import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { HttpError } from "./auth.ts";
import {
  canonicalNotificationArguments,
  notificationArgumentsSha256,
  parseNotificationCommand,
  resolveNotificationCommand,
  validateNotificationReceipt,
} from "./notification_command.ts";

const operation = "99002900-0000-4000-8000-000000000001";
const actor = "99002900-0000-4000-8000-000000000002";
const notification = "99002900-0000-4000-8000-000000000003";
const body = {
  action: "submit",
  operation_id: operation,
  club_id: 24,
  title: "Matchday alert",
  body: "Kickoff soon.",
  audience: "all_fans",
  delivery_mode: "send_now",
};

Deno.test("notification command requires the original UUID and explicit action; actor spoof is rejected", () => {
  for (
    const invalid of [
      { ...body, operation_id: undefined },
      { ...body, operation_id: "99002900-0000-1000-8000-000000000001" },
      { ...body, action: undefined },
      { ...body, actor_id: actor },
      { ...body, club_id: -1 },
      { ...body, club_id: 2.5 },
    ]
  ) {
    assertThrows(() => parseNotificationCommand(invalid), HttpError);
  }
});

Deno.test("notification normalization freezes irrelevant fields and hashes fixed UTF8 JSON", async () => {
  const parsed = parseNotificationCommand({
    ...body,
    title: "  Matchday alert  ",
    tier: "gold",
    scheduled_at: "2026-10-03T12:00:00Z",
  });
  assertEquals(parsed.arguments?.tier, null);
  assertEquals(parsed.arguments?.scheduled_at, null);
  assertEquals(
    canonicalNotificationArguments(parsed.arguments!),
    '{"audience":"all_fans","body":"Kickoff soon.","delivery_mode":"send_now","group_id":null,"group_name":null,"image_url":null,"scheduled_at":null,"tier":null,"title":"Matchday alert"}',
  );
  assertEquals(
    await notificationArgumentsSha256(parsed.arguments!),
    "c33bcee02a35aa9aaf21b2d42c475b68316e248c970b4db4e8e8eeebaa67ec6b",
  );
  const changed = parseNotificationCommand({ ...body, body: "Kickoff now." });
  assertEquals(
    await notificationArgumentsSha256(parsed.arguments!) ===
      await notificationArgumentsSha256(changed.arguments!),
    false,
  );
});

Deno.test("notification status cannot carry a new payload or scheduling action", () => {
  assertThrows(
    () => parseNotificationCommand({ ...body, action: "status" }),
    HttpError,
  );
  assertEquals(
    parseNotificationCommand({
      action: "status",
      operation_id: operation,
      club_id: "24",
    }),
    { action: "status", operationId: operation, clubId: 24, arguments: null },
  );
});

Deno.test("actual notification recovery RPC is original-ID/caller/club bound and never admission", async () => {
  let calls = 0;
  const receipt = {
    command: {
      version: 1,
      operation_id: operation,
      actor_id: actor,
      club_id: 24,
      state: "not_admitted",
      notification_id: null,
      arguments_sha256: null,
      delivery_mode: null,
    },
    notification: null,
    delivery: null,
  } as const;
  const result = await resolveNotificationCommand(
    "Bearer original",
    actor,
    parseNotificationCommand({
      action: "status",
      operation_id: operation,
      club_id: 24,
    }),
    {
      rpc: async (name, args) => {
        calls++;
        assertEquals(name, "recover_admin_notification");
        assertEquals(args, { p_operation_id: operation, p_club_id: 24 });
        return { data: receipt, error: null };
      },
    },
  );
  assertEquals(result, receipt);
  assertEquals(calls, 1);
  assertThrows(
    () =>
      validateNotificationReceipt({
        ...receipt,
        command: { ...receipt.command, actor_id: notification },
      }, { operationId: operation, actorId: actor, clubId: 24 }),
    HttpError,
  );
});

Deno.test("notification admission rejects changed receipt binding and revoked proof", async () => {
  const command = parseNotificationCommand(body);
  await assertRejects(
    () =>
      resolveNotificationCommand("Bearer original", actor, command, {
        rpc: async () => ({ data: null, error: { code: "42501" } }),
      }),
    HttpError,
    "Current staff verification",
  );
  await assertRejects(
    () =>
      resolveNotificationCommand("Bearer original", actor, command, {
        rpc: async () => ({
          data: { command: { version: 1, operation_id: notification } },
          error: null,
        }),
      }),
    HttpError,
    "does not match",
  );
});
