import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { HttpError } from "./auth.ts";
import { notificationArgumentsSha256 } from "./notification_command.ts";
import {
  dispatchNotificationCommand as actualDispatchNotificationCommand,
  type NotificationDevice,
} from "./notification_dispatch.ts";
const op = "99002900-0000-4000-8000-000000000001";
const actor = "99002900-0000-4000-8000-000000000002";
const nid = "99002900-0000-4000-8000-000000000003";
const lease = "99002900-0000-4000-8000-000000000004";
const did = "99002900-0000-4000-8000-000000000005";
const tid = "99002900-0000-4000-8000-000000000006";
const proof = "99002900-0000-4000-8000-000000000007";
function dispatchNotificationCommand(
  ...args: Parameters<typeof actualDispatchNotificationCommand>
) {
  return actualDispatchNotificationCommand(args[0], args[1], args[2], {
    ...args[3],
    proofId: proof,
  });
}
const now = Date.parse("2026-10-02T10:00:00Z");
const original = {
  title: "Alert",
  body: "Matchday",
  audience: "all_fans",
  tier: null,
  group_id: null,
  group_name: null,
  delivery_mode: "send_now",
  scheduled_at: null,
  image_url: null,
};
const originalHash = await notificationArgumentsSha256(original);
const claimed = {
  claimed: true,
  notification_id: nid,
  arguments: original,
  arguments_sha256: originalHash,
  operation_id: op,
  actor_id: actor,
  club_id: 24,
  lease_token: lease,
  lease_expires_at: new Date(now + 60000).toISOString(),
  authority_kind: "human_immediate",
  lease_proof_id: proof,
};
const device: NotificationDevice = {
  operation_id: op,
  lease_token: lease,
  delivery_id: did,
  token_id: tid,
  target_user_id: actor,
  token: "mock-device-token",
  title: "Alert",
  body: "Matchday",
  notification_id: nid,
  club_id: 24,
  audience_type: "all_fans",
  audience_tier: null,
  audience_group_id: null,
  image_url: null,
  deadline_at: new Date(now + 60000).toISOString(),
};
function receipt(status = "unknown") {
  return {
    command: {
      version: 1,
      operation_id: op,
      actor_id: actor,
      club_id: 24,
      arguments_sha256: originalHash,
      notification_id: nid,
      delivery_mode: "send_now",
      state: status === "unknown" ? "unknown" : "completed",
    },
    notification: { id: nid, club_id: 24, created_by: actor },
    delivery: {
      status,
      requested_recipient_count: 1,
      successful_user_count: status === "sent" ? 1 : 0,
      failed_user_count: 0,
      sent_count: status === "sent" ? 1 : 0,
      failed_count: 0,
      cleaned_tokens: 0,
      unknown_count: status === "unknown" ? 1 : 0,
      pending_count: 0,
      scheduled_at: null,
    },
  };
}

Deno.test("notification worker starts device through committed RPC before FCM; lost response becomes terminal unknown", async () => {
  const events: string[] = [];
  let offered = false;
  const result = await dispatchNotificationCommand(
    {
      rpc: async (name, args) => {
        events.push(name);
        assertEquals(args.p_operation_id, op);
        assertEquals(args.p_lease_token, lease);
        if (name === "claim_admin_notification_command") {
          return {
            data: claimed,
            error: null,
          };
        }
        if (name === "claim_admin_notification_device") {
          const data = offered ? null : device;
          offered = true;
          return { data, error: null };
        }
        if (name === "complete_admin_notification_device") {
          assertEquals(args.p_delivery_id, did);
          assertEquals(args.p_outcome, "unknown");
          assertEquals(args.p_provider_message_name, null);
          return { data: { recorded: true }, error: null };
        }
        assertEquals(name, "finish_admin_notification_command");
        return { data: receipt(), error: null };
      },
    },
    op,
    {
      now: () => now,
      leaseToken: () => lease,
      prepareSender: async () => async (_, deadline) => {
        events.push("FCM");
        assertEquals(deadline, now + 5000);
        throw new Error("response lost");
      },
    },
  );
  assertEquals(result?.delivery?.status, "unknown");
  assertEquals(events, [
    "claim_admin_notification_command",
    "claim_admin_notification_device",
    "FCM",
    "complete_admin_notification_device",
    "claim_admin_notification_device",
    "finish_admin_notification_command",
  ]);
});

Deno.test("other worker cannot obtain provider credentials or send without a claimed job", async () => {
  let prepared = 0;
  const result = await dispatchNotificationCommand(
    { rpc: async () => ({ data: { claimed: false }, error: null }) },
    op,
    {
      now: () => now,
      leaseToken: () => lease,
      prepareSender: async () => {
        prepared++;
        throw new Error("no claim");
      },
    },
  );
  assertEquals(result, null);
  assertEquals(prepared, 0);
});

Deno.test("foreign lease/device binding fails before provider send", async () => {
  let sends = 0;
  await assertRejects(
    () =>
      dispatchNotificationCommand(
        {
          rpc: async (name) => ({
            data: name === "claim_admin_notification_command"
              ? claimed
              : { ...device, lease_token: nid },
            error: null,
          }),
        },
        op,
        {
          now: () => now,
          leaseToken: () => lease,
          prepareSender: async () => async () => {
            sends++;
            return { outcome: "unknown" };
          },
        },
      ),
    HttpError,
    "device ownership",
  );
  assertEquals(sends, 0);
});

Deno.test("post-provider ownership loss halts without retry or false success", async () => {
  let sends = 0;
  await assertRejects(
    () =>
      dispatchNotificationCommand(
        {
          rpc: async (name) => ({
            data: name === "claim_admin_notification_command"
              ? claimed
              : name === "claim_admin_notification_device"
              ? device
              : null,
            error: name === "complete_admin_notification_device"
              ? { code: "42501" }
              : null,
          }),
        },
        op,
        {
          now: () => now,
          leaseToken: () => lease,
          prepareSender: async () => async () => {
            sends++;
            return {
              outcome: "accepted",
              provider_message_name: "projects/mock/messages/original",
            };
          },
        },
      ),
    HttpError,
    "ownership could not be confirmed",
  );
  assertEquals(sends, 1);
});

Deno.test("worker rejects an original payload hash mismatch before provider preparation", async () => {
  let prepared = 0;
  await assertRejects(
    () =>
      dispatchNotificationCommand(
        {
          rpc: async () => ({
            data: { ...claimed, arguments: { ...original, body: "changed" } },
            error: null,
          }),
        },
        op,
        {
          now: () => now,
          leaseToken: () => lease,
          prepareSender: async () => {
            prepared++;
            throw new Error("No provider preparation");
          },
        },
      ),
    HttpError,
    "original command payload",
  );
  assertEquals(prepared, 0);
});
Deno.test("matching device UUID cannot send changed original notification content", async () => {
  let sends = 0;
  await assertRejects(
    () =>
      dispatchNotificationCommand(
        {
          rpc: async (name) => ({
            data: name === "claim_admin_notification_command"
              ? claimed
              : { ...device, body: "changed" },
            error: null,
          }),
        },
        op,
        {
          now: () => now,
          leaseToken: () => lease,
          prepareSender: async () => async () => {
            sends++;
            return { outcome: "unknown" };
          },
        },
      ),
    HttpError,
    "device ownership",
  );
  assertEquals(sends, 0);
});

Deno.test("old immediate request cannot borrow a newer admission proof from worker response", async () => {
  let prepared = 0;
  await assertRejects(
    () =>
      actualDispatchNotificationCommand(
        {
          rpc: async (_, args) => {
            assertEquals(args.p_proof_id, proof);
            return { data: { ...claimed, lease_proof_id: nid }, error: null };
          },
        },
        op,
        {
          now: () => now,
          leaseToken: () => lease,
          prepareSender: async () => {
            prepared++;
            throw new Error("No provider preparation");
          },
        },
        { proofId: proof },
      ),
    HttpError,
    "original proof ownership",
  );
  assertEquals(prepared, 0);
});
