/**
 * Admin notifications — push notification context + delivery.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminNotificationContext, AdminNotificationRecord } from "@/lib/types";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

const MAX_NOTIFICATION_GROUPS = 50;
const MAX_NOTIFICATION_HISTORY = 100;
const notificationStatuses = new Set([
  "pending",
  "scheduled",
  "sent",
  "delivered",
  "failed",
  "cancelled",
  "processing",
  "partial",
  "unknown",
]);

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength);
}

function boundedInteger(value: unknown, maximum: number) {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    value >= 0 &&
    value <= maximum
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function nullableDate(value: unknown) {
  if (value == null || value === "") return null;
  return boundedDate(value);
}

function mapNotification(
  row: Record<string, unknown>,
): AdminNotificationRecord | null {
  const id = boundedText(row.id, 128);
  const title = boundedText(row.title, 120);
  const body = boundedText(row.body, 500);
  const audienceValue = row.audienceType ?? row.audience_type;
  const audienceType =
    audienceValue === "all_fans" ||
    audienceValue === "by_tier" ||
    audienceValue === "by_group"
      ? audienceValue
      : null;
  const audienceTier = nullableText(
    row.audienceTier ?? row.audience_tier,
    80,
  );
  const audienceGroupId = nullableText(
    row.audienceGroupId ?? row.audience_group_id,
    128,
  );
  const audienceGroupName = nullableText(
    row.audienceGroupName ?? row.audience_group_name,
    160,
  );
  const deliveryValue = row.deliveryMode ?? row.delivery_mode;
  const deliveryMode =
    deliveryValue === "send_now" || deliveryValue === "schedule"
      ? deliveryValue
      : null;
  const statusValue = boundedText(row.status, 32);
  const status =
    statusValue != null && notificationStatuses.has(statusValue)
      ? statusValue
      : null;
  const scheduledAt = nullableDate(row.scheduledAt ?? row.scheduled_at);
  const sentAt = nullableDate(row.sentAt ?? row.sent_at);
  const requestedRecipientCount = boundedInteger(
    row.requestedRecipientCount ?? row.requested_recipient_count,
    10_000_000,
  );
  const sentCount = boundedInteger(row.sentCount ?? row.sent_count, 10_000_000);
  const failedCount = boundedInteger(
    row.failedCount ?? row.failed_count,
    10_000_000,
  );
  const createdAt = boundedDate(row.createdAt ?? row.created_at);
  const rawLastError = nullableText(row.lastError ?? row.last_error, 2_000);

  if (
    id == null ||
    title == null ||
    body == null ||
    audienceType == null ||
    audienceTier === undefined ||
    audienceGroupId === undefined ||
    audienceGroupName === undefined ||
    deliveryMode == null ||
    status == null ||
    scheduledAt === undefined ||
    sentAt === undefined ||
    requestedRecipientCount == null ||
    sentCount == null ||
    failedCount == null ||
    createdAt == null ||
    rawLastError === undefined ||
    (audienceType === "by_tier" && audienceTier == null) ||
    (audienceType === "by_group" &&
      (audienceGroupId == null || audienceGroupName == null)) ||
    (deliveryMode === "schedule" && scheduledAt == null)
  ) {
    return null;
  }

  return {
    id,
    title,
    body,
    audienceType,
    audienceTier,
    audienceGroupId,
    audienceGroupName,
    deliveryMode,
    status,
    scheduledAt,
    sentAt,
    requestedRecipientCount,
    sentCount,
    failedCount,
    createdAt,
    lastError:
      rawLastError == null ? null : "Delivery requires operator review.",
  };
}

export function normalizeAdminNotificationContext(
  value: unknown,
): AdminNotificationContext {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return { groups: [], history: [] };
  }
  const raw = value as Record<string, unknown>;
  const groups: AdminNotificationContext["groups"] = [];
  const groupIds = new Set<string>();
  if (Array.isArray(raw.groups)) {
    for (const entry of raw.groups.slice(0, MAX_NOTIFICATION_GROUPS)) {
      if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
        continue;
      }
      const row = entry as Record<string, unknown>;
      const id = boundedText(row.id, 128);
      const name = boundedText(row.name, 160);
      if (id != null && name != null && !groupIds.has(id)) {
        groups.push({ id, name });
        groupIds.add(id);
      }
    }
  }

  const history: AdminNotificationRecord[] = [];
  const notificationIds = new Set<string>();
  if (Array.isArray(raw.history)) {
    for (const entry of raw.history.slice(0, MAX_NOTIFICATION_HISTORY)) {
      if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
        continue;
      }
      const notification = mapNotification(entry as Record<string, unknown>);
      if (
        notification != null &&
        !notificationIds.has(notification.id)
      ) {
        history.push(notification);
        notificationIds.add(notification.id);
      }
    }
  }
  return { groups, history };
}

export async function getAdminNotificationContext(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminNotificationContext> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("notifications", {
      signal: options.signal,
    });
    return normalizeAdminNotificationContext(result);
  }
  const clubId = requireAdminClubId(access, "load notification context");
  const [groupsResult, historyResult] = await Promise.all([
    client
      .from("contribution_groups")
      .select("id, name")
      .eq("is_closed", false)
      .eq("club_id", clubId)
      .order("name", { ascending: true })
      .limit(MAX_NOTIFICATION_GROUPS),
    client
      .from("notifications")
      .select(
        "id, title, body, audience_type, audience_tier, audience_group_id, audience_group_name, delivery_mode, status, scheduled_at, sent_at, requested_recipient_count, sent_count, failed_count, created_at, last_error",
      )
      .eq("club_id", clubId)
      .order("created_at", { ascending: false })
      .limit(MAX_NOTIFICATION_HISTORY),
  ]);
  if (groupsResult.error) throw new Error(groupsResult.error.message);
  if (historyResult.error) throw new Error(historyResult.error.message);
  return normalizeAdminNotificationContext({
    groups: groupsResult.data,
    history: historyResult.data,
  });
}

export { sendAdminNotification, checkAdminNotificationStatus, readPendingAdminNotification } from "./notification-command";
export type { AdminNotificationReceipt, AdminNotificationPayload } from "./notification-command";
