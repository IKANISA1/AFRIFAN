import { HttpError } from "./auth.ts";
import {
  canonicalNotificationArguments,
  notificationArgumentKeys,
  type NotificationArguments,
  notificationArgumentsSha256,
  type NotificationCommandClient,
  type NotificationCommandReceipt,
  validateNotificationReceipt,
} from "./notification_command.ts";

export interface NotificationDevice {
  operation_id: string;
  lease_token: string;
  delivery_id: string;
  token_id: string;
  target_user_id: string;
  notification_id: string;
  club_id: number;
  audience_type: "all_fans" | "by_tier" | "by_group";
  audience_tier: string | null;
  audience_group_id: string | null;
  token: string;
  title: string;
  body: string;
  image_url: string | null;
  deadline_at: string;
}
export interface NotificationDeviceResult {
  outcome: "accepted" | "rejected" | "unknown";
  provider_message_name?: string;
  error_code?: "UNREGISTERED" | "NOT_FOUND" | "UNKNOWN";
}
export type NotificationDeviceSender = (
  device: NotificationDevice,
  deadlineAt: number,
) => Promise<NotificationDeviceResult>;
export interface NotificationDispatchDependencies {
  prepareSender: (deadlineAt: number) => Promise<NotificationDeviceSender>;
  now?: () => number;
  leaseToken?: () => string;
}
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

async function rpc(
  client: NotificationCommandClient,
  name: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const result = await client.rpc(name, args);
  if (result.error) {
    throw new HttpError(
      502,
      "Notification dispatch ownership could not be confirmed.",
    );
  }
  return result.data;
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(502, "Invalid notification dispatch receipt.");
  }
  return value as Record<string, unknown>;
}

/** The database commits started before this module receives a device token. */
export async function dispatchNotificationCommand(
  client: NotificationCommandClient,
  operationId: string,
  dependencies: NotificationDispatchDependencies,
  options: { deadlineAt?: number; proofId?: string } = {},
): Promise<NotificationCommandReceipt | null> {
  const now = dependencies.now ?? Date.now;
  const leaseToken = (dependencies.leaseToken ?? (() => crypto.randomUUID()))();
  const workerDeadline = Math.min(
    options.deadlineAt ?? now() + 45000,
    now() + 45000,
  );
  const claimed = object(
    await rpc(client, "claim_admin_notification_command", {
      p_operation_id: operationId,
      p_lease_token: leaseToken,
      p_proof_id: options.proofId ?? null,
    }),
  );
  if (claimed.claimed === false) return null;
  if (
    claimed.claimed !== true || claimed.operation_id !== operationId ||
    claimed.lease_token !== leaseToken ||
    !(uuid.test(String(claimed.actor_id)) ||
      (claimed.authority_kind === "legacy_scheduled" &&
        claimed.actor_id === null)) ||
    !uuid.test(String(claimed.notification_id)) ||
    !/^[0-9a-f]{64}$/.test(String(claimed.arguments_sha256)) ||
    !Number.isSafeInteger(claimed.club_id) || Number(claimed.club_id) < 1 ||
    !["human_immediate", "scheduled", "legacy_scheduled"].includes(
      String(claimed.authority_kind),
    )
  ) {
    throw new HttpError(502, "Invalid notification worker ownership.");
  }
  if (
    claimed.authority_kind === "human_immediate"
      ? !uuid.test(options.proofId ?? "") ||
        claimed.lease_proof_id !== options.proofId
      : claimed.lease_proof_id !== null
  ) {
    throw new HttpError(502, "Invalid notification original proof ownership.");
  }
  const original = object(claimed.arguments) as NotificationArguments;
  if (
    Object.keys(original).length !== notificationArgumentKeys.length ||
    Object.keys(original).some((key) =>
      !notificationArgumentKeys.includes(key as keyof NotificationArguments)
    ) ||
    Object.values(original).some((value) =>
      value !== null && typeof value !== "string"
    ) ||
    new TextEncoder().encode(canonicalNotificationArguments(original)).length >
      4096 ||
    await notificationArgumentsSha256(original) !== claimed.arguments_sha256
  ) {
    throw new HttpError(502, "Invalid notification original command payload.");
  }
  const expiresAt = Date.parse(String(claimed.lease_expires_at));
  if (!Number.isFinite(expiresAt)) {
    throw new HttpError(502, "Invalid notification worker deadline.");
  }
  const deadlineAt = Math.min(workerDeadline, expiresAt);
  // OAuth preparation can wait. Device admission rechecks authority after it.
  const send = await dependencies.prepareSender(deadlineAt);
  let started = 0;
  while (now() < deadlineAt && started < 500) {
    const raw = await rpc(client, "claim_admin_notification_device", {
      p_operation_id: operationId,
      p_lease_token: leaseToken,
    });
    if (raw === null) break;
    const item = object(raw);
    const device = item as unknown as NotificationDevice;
    const deviceDeadline = Date.parse(device.deadline_at);
    if (
      device.operation_id !== operationId ||
      device.lease_token !== leaseToken ||
      !uuid.test(device.delivery_id) || !uuid.test(device.token_id) ||
      !uuid.test(device.target_user_id) ||
      device.notification_id !== claimed.notification_id ||
      device.club_id !== claimed.club_id ||
      device.title !== original.title || device.body !== original.body ||
      device.image_url !== original.image_url ||
      device.audience_type !== original.audience ||
      device.audience_tier !== original.tier ||
      device.audience_group_id !== original.group_id ||
      !["all_fans", "by_tier", "by_group"].includes(device.audience_type) ||
      (device.audience_tier !== null &&
        !["fan", "bronze", "gold", "platinum"].includes(
          device.audience_tier,
        )) ||
      (device.audience_group_id !== null &&
        !uuid.test(device.audience_group_id)) ||
      typeof device.token !== "string" || device.token.length < 1 ||
      device.token.length > 4096 ||
      typeof device.title !== "string" || device.title.length < 1 ||
      device.title.length > 120 ||
      typeof device.body !== "string" || device.body.length < 1 ||
      device.body.length > 500 ||
      (device.image_url !== null &&
        (typeof device.image_url !== "string" ||
          device.image_url.length > 2048)) ||
      !Number.isFinite(deviceDeadline)
    ) {
      throw new HttpError(502, "Invalid notification device ownership.");
    }
    started++;
    let result: NotificationDeviceResult = {
      outcome: "unknown",
      error_code: "UNKNOWN",
    };
    const sendDeadline = Math.min(deadlineAt, deviceDeadline, now() + 5000);
    if (now() < sendDeadline) {
      try {
        result = await send(device, sendDeadline);
      } catch (_) {
        // A lost provider response is never evidence that the device was unsent.
      }
    }
    if (
      !["accepted", "rejected", "unknown"].includes(result.outcome) ||
      (result.outcome === "accepted" &&
        (typeof result.provider_message_name !== "string" ||
          result.provider_message_name.length < 1 ||
          result.provider_message_name.length > 512)) ||
      (result.error_code !== undefined &&
        !["UNREGISTERED", "NOT_FOUND", "UNKNOWN"].includes(result.error_code))
    ) {
      result = { outcome: "unknown", error_code: "UNKNOWN" };
    }
    const completed = object(
      await rpc(client, "complete_admin_notification_device", {
        p_operation_id: operationId,
        p_lease_token: leaseToken,
        p_delivery_id: device.delivery_id,
        p_outcome: result.outcome,
        p_provider_message_name: result.outcome === "accepted"
          ? result.provider_message_name
          : null,
        p_error_code: result.outcome === "accepted"
          ? null
          : result.error_code ?? "UNKNOWN",
      }),
    );
    if (completed.recorded !== true) {
      throw new HttpError(
        502,
        "Notification device result ownership was lost.",
      );
    }
  }
  const receipt = await rpc(client, "finish_admin_notification_command", {
    p_operation_id: operationId,
    p_lease_token: leaseToken,
  });
  return validateNotificationReceipt(receipt, {
    operationId,
    actorId: claimed.actor_id === null ? null : String(claimed.actor_id),
    clubId: Number(claimed.club_id),
    argumentsSha256: String(claimed.arguments_sha256),
  });
}
