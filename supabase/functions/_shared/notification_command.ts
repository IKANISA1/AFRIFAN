import { HttpError } from "./auth.ts";
import { createLifecycleUserClient } from "./account_lifecycle_client.ts";
import { parseNotificationRequest } from "./notifications.ts";

export const notificationOperationPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const notificationArgumentKeys = [
  "title",
  "body",
  "audience",
  "tier",
  "group_id",
  "group_name",
  "delivery_mode",
  "scheduled_at",
  "image_url",
] as const;

export type NotificationArguments = Record<
  typeof notificationArgumentKeys[number],
  string | null
>;
export interface NotificationCommand {
  operationId: string;
  clubId: number;
  action: "submit" | "status";
  arguments: NotificationArguments | null;
}
export interface NotificationCommandClient {
  rpc(name: string, args: Record<string, unknown>): PromiseLike<{
    data: unknown;
    error: { code?: string; message?: string } | null;
  }>;
}
export interface NotificationCommandReceipt {
  dispatch_proof_id?: string;
  command: {
    version: 1;
    operation_id: string;
    actor_id: string | null;
    club_id: number;
    arguments_sha256: string | null;
    notification_id: string | null;
    delivery_mode: "send_now" | "schedule" | null;
    state:
      | "not_admitted"
      | "admitted"
      | "scheduled"
      | "processing"
      | "completed"
      | "unknown"
      | "blocked";
  };
  notification: Record<string, unknown> | null;
  delivery: {
    status:
      | "scheduled"
      | "processing"
      | "sent"
      | "partial"
      | "failed"
      | "unknown";
    requested_recipient_count: number;
    successful_user_count: number;
    failed_user_count: number;
    sent_count: number;
    failed_count: number;
    cleaned_tokens: number;
    unknown_count: number;
    pending_count: number;
    scheduled_at: string | null;
  } | null;
}

export function parseNotificationCommand(
  raw: Record<string, unknown>,
): NotificationCommand {
  if (raw.action !== "submit" && raw.action !== "status") {
    throw new HttpError(
      400,
      "Use submit or status for the original notification command.",
    );
  }
  if (
    typeof raw.operation_id !== "string" ||
    !notificationOperationPattern.test(raw.operation_id)
  ) {
    throw new HttpError(
      400,
      "The original notification operation_id is required.",
    );
  }
  const clubId =
    typeof raw.club_id === "string" && /^[1-9][0-9]*$/.test(raw.club_id)
      ? Number(raw.club_id)
      : raw.club_id;
  if (
    !Number.isSafeInteger(clubId) || Number(clubId) < 1 ||
    Number(clubId) > 2147483647
  ) {
    throw new HttpError(400, "A valid selected club_id is required.");
  }
  const allowed = new Set<string>([
    "action",
    "operation_id",
    "club_id",
    ...(raw.action === "submit" ? notificationArgumentKeys : []),
  ]);
  if (Object.keys(raw).some((key) => !allowed.has(key))) {
    throw new HttpError(400, "Unexpected notification command fields.");
  }
  if (raw.action === "status") {
    return {
      action: "status",
      operationId: raw.operation_id,
      clubId: Number(clubId),
      arguments: null,
    };
  }
  const parsed = parseNotificationRequest(raw);
  if (
    (parsed.imageUrl?.length ?? 0) > 2048 ||
    (parsed.audience.groupName?.length ?? 0) > 160 ||
    (parsed.audience.type === "by_group" &&
      !uuid.test(parsed.audience.groupId ?? ""))
  ) {
    throw new HttpError(
      400,
      "Notification target fields exceed the command boundary.",
    );
  }
  const args: NotificationArguments = {
    title: parsed.title,
    body: parsed.body,
    audience: parsed.audience.type,
    tier: parsed.audience.type === "by_tier"
      ? parsed.audience.tier ?? null
      : null,
    group_id: parsed.audience.type === "by_group"
      ? parsed.audience.groupId ?? null
      : null,
    group_name: parsed.audience.type === "by_group"
      ? parsed.audience.groupName ?? null
      : null,
    delivery_mode: parsed.deliveryMode,
    scheduled_at: parsed.deliveryMode === "schedule"
      ? parsed.scheduledAt
      : null,
    image_url: parsed.imageUrl,
  };
  if (
    new TextEncoder().encode(canonicalNotificationArguments(args)).length > 4096
  ) {
    throw new HttpError(400, "Notification command is too large.");
  }
  return {
    action: "submit",
    operationId: raw.operation_id,
    clubId: Number(clubId),
    arguments: args,
  };
}

/** Flat, fixed ASCII keys; shared by the Web/native journal and SQL29. */
export function canonicalNotificationArguments(
  args: NotificationArguments,
): string {
  return JSON.stringify(
    Object.fromEntries(
      Object.keys(args).sort().map((
        key,
      ) => [key, args[key as keyof NotificationArguments]]),
    ),
  );
}

export async function notificationArgumentsSha256(
  args: NotificationArguments,
): Promise<string> {
  const bytes = new TextEncoder().encode(canonicalNotificationArguments(args));
  return Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
  )
    .map((value) => value.toString(16).padStart(2, "0")).join("");
}

export function notificationRpcError(
  error: { code?: string; message?: string } | null,
): void {
  if (!error) return;
  if (error.code === "42501") {
    throw new HttpError(
      403,
      "Current staff verification is required for this notification command.",
    );
  }
  if (["22023", "P0001", "23505"].includes(error.code ?? "")) {
    throw new HttpError(
      409,
      "Check the original notification command before retrying.",
    );
  }
  throw new HttpError(
    502,
    "Notification command status could not be confirmed.",
  );
}

export function validateNotificationReceipt(raw: unknown, expected: {
  operationId: string;
  actorId: string | null;
  clubId: number;
  argumentsSha256?: string;
}): NotificationCommandReceipt {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpError(502, "Invalid notification command receipt.");
  }
  const data = raw as NotificationCommandReceipt;
  const c = data.command;
  if (
    !c || c.version !== 1 || c.operation_id !== expected.operationId ||
    c.actor_id !== expected.actorId || c.club_id !== expected.clubId ||
    ![
      "not_admitted",
      "admitted",
      "scheduled",
      "processing",
      "completed",
      "unknown",
      "blocked",
    ].includes(c.state)
  ) {
    throw new HttpError(
      502,
      "Notification receipt does not match the original command.",
    );
  }
  if (c.state === "not_admitted") {
    if (
      c.notification_id !== null || c.arguments_sha256 !== null ||
      c.delivery_mode !== null ||
      data.notification !== null || data.delivery !== null
    ) throw new HttpError(502, "Invalid notification command receipt.");
    return data;
  }
  const d = data.delivery;
  const n = data.notification;
  if (
    !uuid.test(c.notification_id ?? "") ||
    !/^[0-9a-f]{64}$/.test(c.arguments_sha256 ?? "") ||
    (expected.argumentsSha256 &&
      c.arguments_sha256 !== expected.argumentsSha256) ||
    (c.delivery_mode !== "send_now" && c.delivery_mode !== "schedule") ||
    !n || n.id !== c.notification_id || n.club_id !== c.club_id ||
    (n.created_by !== c.actor_id && n.created_by !== null) ||
    !d ||
    !["scheduled", "processing", "sent", "partial", "failed", "unknown"]
      .includes(d.status)
  ) {
    throw new HttpError(502, "Invalid notification command receipt.");
  }
  for (
    const key of [
      "requested_recipient_count",
      "successful_user_count",
      "failed_user_count",
      "sent_count",
      "failed_count",
      "cleaned_tokens",
      "unknown_count",
      "pending_count",
    ] as const
  ) {
    if (!Number.isSafeInteger(d[key]) || d[key] < 0 || d[key] > 500) {
      throw new HttpError(502, "Invalid notification delivery counters.");
    }
  }
  if (
    d.scheduled_at !== null &&
    (typeof d.scheduled_at !== "string" ||
      !Number.isFinite(Date.parse(d.scheduled_at)))
  ) {
    throw new HttpError(502, "Invalid notification schedule receipt.");
  }
  return data;
}

export async function resolveNotificationCommand(
  authorization: string,
  actorId: string,
  command: NotificationCommand,
  client?: NotificationCommandClient,
): Promise<NotificationCommandReceipt> {
  const user = client ?? createLifecycleUserClient(authorization);
  const result = command.action === "submit"
    ? await user.rpc("admit_admin_notification", {
      p_operation_id: command.operationId,
      p_club_id: command.clubId,
      p_arguments: command.arguments,
    })
    : await user.rpc("recover_admin_notification", {
      p_operation_id: command.operationId,
      p_club_id: command.clubId,
    });
  notificationRpcError(result.error);
  const receipt = validateNotificationReceipt(result.data, {
    operationId: command.operationId,
    actorId,
    clubId: command.clubId,
    ...(command.arguments
      ? {
        argumentsSha256: await notificationArgumentsSha256(command.arguments),
      }
      : {}),
  });
  if (
    command.action === "submit" &&
    receipt.command.delivery_mode === "send_now" &&
    ["admitted", "processing"].includes(receipt.command.state) &&
    !uuid.test(receipt.dispatch_proof_id ?? "")
  ) {
    throw new HttpError(
      502,
      "Original notification dispatch proof was not confirmed.",
    );
  }
  return receipt;
}
