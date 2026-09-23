import { type AuthenticatedCaller, HttpError } from "./auth.ts";
import { resolveClubIdFromMetadata } from "./club.ts";
import { sendToUser } from "./fcm.ts";
import { createAdminClient } from "./supabase.ts";

type AdminClientLike = ReturnType<typeof createAdminClient>;

export type NotificationAudienceType = "all_fans" | "by_tier" | "by_group";
export type NotificationDeliveryMode = "send_now" | "schedule";
export type NotificationStatus =
  | "scheduled"
  | "processing"
  | "sent"
  | "partial"
  | "failed";

export type NotificationAudience = {
  type: NotificationAudienceType;
  tier?: string | null;
  groupId?: string | null;
  groupName?: string | null;
};

export type ParsedNotificationRequest = {
  title: string;
  body: string;
  imageUrl: string | null;
  audience: NotificationAudience;
  deliveryMode: NotificationDeliveryMode;
  scheduledAt: string | null;
};

export type NotificationDispatchResult = {
  status: NotificationStatus;
  requestedRecipientCount: number;
  successfulUserCount: number;
  failedUserCount: number;
  sentCount: number;
  failedCount: number;
  cleanedTokens: number;
  errors: string[];
};

type NotificationRecord = {
  id: string;
  club_id: number;
  title: string;
  body: string;
  image_url?: string | null;
  audience_type: string;
  audience_tier?: string | null;
  audience_group_id?: string | null;
  audience_group_name?: string | null;
};

type UserIdRow = {
  user_id: string | null;
};

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function parseIsoTimestamp(value: unknown): string | null {
  const text = asTrimmedString(value);
  if (text == null) {
    return null;
  }

  const timestamp = Date.parse(text);
  if (Number.isNaN(timestamp)) {
    throw new HttpError(
      400,
      "scheduled_at must be a valid ISO-8601 timestamp.",
    );
  }

  return new Date(timestamp).toISOString();
}

function normalizeAudienceType(value: unknown): NotificationAudienceType {
  const normalized = asTrimmedString(value)?.toLowerCase().replaceAll(" ", "_");
  switch (normalized) {
    case "all":
    case "all_fans":
    case "all_fan":
      return "all_fans";
    case "by_tier":
    case "tier":
      return "by_tier";
    case "by_group":
    case "group":
      return "by_group";
    default:
      throw new HttpError(
        400,
        "audience must be ALL FANS, BY TIER, or BY GROUP.",
      );
  }
}

function normalizeTier(value: unknown): string | null {
  const normalized = asTrimmedString(value)?.toLowerCase().replaceAll(" ", "_");
  if (normalized == null) {
    return null;
  }

  switch (normalized) {
    case "fan":
      return "fan";
    case "bronze":
    case "silver":
      return "bronze";
    case "gold":
      return "gold";
    case "platinum":
    case "legend":
      return "platinum";
    default:
      throw new HttpError(
        400,
        "tier must be one of FAN, BRONZE, GOLD, or PLATINUM.",
      );
  }
}

function normalizeDeliveryMode(value: unknown): NotificationDeliveryMode {
  const normalized = asTrimmedString(value)?.toLowerCase().replaceAll(" ", "_");
  switch (normalized) {
    case "send_now":
    case "send":
    case "now":
      return "send_now";
    case "schedule":
    case "scheduled":
      return "schedule";
    default:
      throw new HttpError(400, "delivery_mode must be SEND NOW or SCHEDULE.");
  }
}

function validateImageUrl(value: unknown): string | null {
  const text = asTrimmedString(value);
  if (text == null) {
    return null;
  }

  try {
    const parsed = new URL(text);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      throw new Error("unsupported");
    }
    return parsed.toString();
  } catch (_) {
    throw new HttpError(400, "image_url must be a valid absolute URL.");
  }
}

function collectUserIds(rows: unknown): Set<string> {
  const ids = new Set<string>();
  const items = Array.isArray(rows) ? rows as UserIdRow[] : [];
  for (const row of items) {
    const userId = asTrimmedString(row.user_id);
    if (userId != null) {
      ids.add(userId);
    }
  }
  return ids;
}

async function queryUserIds(
  query: PromiseLike<{ data: unknown; error: unknown }>,
  failureMessage: string,
): Promise<Set<string>> {
  const { data, error } = await query;
  if (error) {
    throw new HttpError(500, failureMessage);
  }
  return collectUserIds(data);
}

function intersection(
  base: Set<string>,
  ...candidates: Set<string>[]
): string[] {
  const result: string[] = [];
  for (const value of base) {
    if (candidates.every((candidate) => candidate.has(value))) {
      result.push(value);
    }
  }
  return result;
}

function uniqueErrors(errors: string[], limit = 10): string[] {
  const result: string[] = [];
  for (const error of errors) {
    const trimmed = error.trim();
    if (trimmed.length === 0 || result.includes(trimmed)) {
      continue;
    }
    result.push(trimmed);
    if (result.length >= limit) {
      break;
    }
  }
  return result;
}

export function parseNotificationRequest(
  rawBody: Record<string, unknown>,
): ParsedNotificationRequest {
  const title = asTrimmedString(rawBody["title"]);
  if (title == null) {
    throw new HttpError(400, "title is required.");
  }
  if (title.length > 120) {
    throw new HttpError(400, "title must be 120 characters or fewer.");
  }

  const body = asTrimmedString(rawBody["body"]);
  if (body == null) {
    throw new HttpError(400, "body is required.");
  }
  if (body.length > 500) {
    throw new HttpError(400, "body must be 500 characters or fewer.");
  }

  const audienceType = normalizeAudienceType(rawBody["audience"]);
  const tier = normalizeTier(rawBody["tier"]);
  const groupId = asTrimmedString(rawBody["group_id"]);
  const groupName = asTrimmedString(rawBody["group_name"]);

  if (audienceType === "by_tier" && tier == null) {
    throw new HttpError(400, "tier is required when audience is BY TIER.");
  }
  if (audienceType === "by_group" && groupId == null) {
    throw new HttpError(400, "group_id is required when audience is BY GROUP.");
  }

  const deliveryMode = normalizeDeliveryMode(rawBody["delivery_mode"]);
  const scheduledAt = parseIsoTimestamp(rawBody["scheduled_at"]);
  if (deliveryMode === "schedule" && scheduledAt == null) {
    throw new HttpError(
      400,
      "scheduled_at is required when delivery_mode is SCHEDULE.",
    );
  }

  return {
    title,
    body,
    imageUrl: validateImageUrl(rawBody["image_url"]),
    audience: {
      type: audienceType,
      tier,
      groupId,
      groupName,
    },
    deliveryMode,
    scheduledAt,
  };
}

export async function resolveCallerClubId(
  adminClient: AdminClientLike,
  caller: AuthenticatedCaller,
): Promise<number> {
  try {
    return await resolveClubIdFromMetadata(adminClient, caller.appMetadata);
  } catch (_) {
    const { data, error } = await adminClient
      .from("profiles")
      .select("club_id")
      .eq("id", caller.userId)
      .maybeSingle();

    if (error) {
      throw new HttpError(500, "Failed to resolve club context.");
    }

    const clubId = Number((data as { club_id?: unknown } | null)?.club_id);
    if (!Number.isFinite(clubId)) {
      throw new HttpError(400, "Club context required.");
    }

    return clubId;
  }
}

export async function selectRecipientUserIds(
  adminClient: AdminClientLike,
  clubId: number,
  audience: NotificationAudience,
): Promise<string[]> {
  const enabledUsers = await queryUserIds(
    adminClient
      .from("user_notification_settings")
      .select("user_id")
      .eq("club_id", clubId)
      .eq("push_enabled", true),
    "Failed to load notification settings recipients.",
  );

  const tokenUsers = await queryUserIds(
    adminClient
      .from("user_fcm_tokens")
      .select("user_id")
      .eq("club_id", clubId),
    "Failed to load registered push tokens.",
  );

  if (enabledUsers.size == 0 || tokenUsers.size == 0) {
    return [];
  }

  switch (audience.type) {
    case "all_fans":
      return intersection(enabledUsers, tokenUsers);
    case "by_tier": {
      const tierUsers = await queryUserIds(
        adminClient
          .from("fan_memberships")
          .select("user_id")
          .eq("club_id", clubId)
          .eq("tier", audience.tier ?? "fan"),
        "Failed to load membership tier recipients.",
      );
      return intersection(enabledUsers, tokenUsers, tierUsers);
    }
    case "by_group": {
      const groupUsers = await queryUserIds(
        adminClient
          .from("group_members")
          .select("user_id")
          .eq("club_id", clubId)
          .eq("group_id", audience.groupId ?? ""),
        "Failed to load group recipients.",
      );
      return intersection(enabledUsers, tokenUsers, groupUsers);
    }
  }
}

export function audienceColumns(audience: NotificationAudience) {
  return {
    audience_type: audience.type,
    audience_tier: audience.type === "by_tier" ? audience.tier : null,
    audience_group_id: audience.type === "by_group" ? audience.groupId : null,
    audience_group_name: audience.type === "by_group"
      ? audience.groupName
      : null,
  };
}

export function audienceFromRecord(
  record: NotificationRecord,
): NotificationAudience {
  return {
    type: normalizeAudienceType(record.audience_type),
    tier: normalizeTier(record.audience_tier),
    groupId: asTrimmedString(record.audience_group_id),
    groupName: asTrimmedString(record.audience_group_name),
  };
}

export async function dispatchNotification(
  adminClient: AdminClientLike,
  notification: NotificationRecord,
): Promise<NotificationDispatchResult> {
  const audience = audienceFromRecord(notification);
  const recipientUserIds = await selectRecipientUserIds(
    adminClient,
    notification.club_id,
    audience,
  );

  if (recipientUserIds.length == 0) {
    return {
      status: "failed",
      requestedRecipientCount: 0,
      successfulUserCount: 0,
      failedUserCount: 0,
      sentCount: 0,
      failedCount: 0,
      cleanedTokens: 0,
      errors: ["No eligible recipients found for this notification."],
    };
  }

  let successfulUserCount = 0;
  let failedUserCount = 0;
  let sentCount = 0;
  let failedCount = 0;
  let cleanedTokens = 0;
  const errors: string[] = [];

  for (let index = 0; index < recipientUserIds.length; index += 10) {
    const batch = recipientUserIds.slice(index, index + 10);
    const batchResults = await Promise.all(
      batch.map(async (userId) => {
        try {
          const result = await sendToUser(
            userId,
            {
              title: notification.title,
              body: notification.body,
              ...(notification.image_url
                ? { image: notification.image_url }
                : {}),
            },
            {
              notification_id: notification.id,
              club_id: notification.club_id.toString(),
              audience_type: audience.type,
              ...(audience.tier ? { audience_tier: audience.tier } : {}),
              ...(audience.groupId
                ? { audience_group_id: audience.groupId }
                : {}),
            },
          );
          return { userId, result, error: null };
        } catch (error) {
          return {
            userId,
            result: null,
            error: error instanceof Error ? error.message : String(error),
          };
        }
      }),
    );

    for (const entry of batchResults) {
      if (entry.error != null || entry.result == null) {
        failedUserCount++;
        errors.push(entry.error ?? "Unknown notification delivery failure.");
        continue;
      }

      sentCount += entry.result.sent_count;
      failedCount += entry.result.failed_count;
      cleanedTokens += entry.result.cleaned_tokens;
      errors.push(...entry.result.errors);

      if (entry.result.success) {
        successfulUserCount++;
      } else {
        failedUserCount++;
      }
    }
  }

  const status: NotificationStatus = successfulUserCount == 0
    ? "failed"
    : failedUserCount == 0
    ? "sent"
    : "partial";

  return {
    status,
    requestedRecipientCount: recipientUserIds.length,
    successfulUserCount,
    failedUserCount,
    sentCount,
    failedCount,
    cleanedTokens,
    errors: uniqueErrors(errors),
  };
}

export function buildDeliveryUpdate(result: NotificationDispatchResult) {
  return {
    status: result.status,
    requested_recipient_count: result.requestedRecipientCount,
    successful_user_count: result.successfulUserCount,
    failed_user_count: result.failedUserCount,
    sent_count: result.sentCount,
    failed_count: result.failedCount,
    cleaned_tokens: result.cleanedTokens,
    sent_at: new Date().toISOString(),
    last_error: result.errors.length > 0 ? result.errors[0] : null,
    delivery_summary: {
      requested_recipient_count: result.requestedRecipientCount,
      successful_user_count: result.successfulUserCount,
      failed_user_count: result.failedUserCount,
      sent_count: result.sentCount,
      failed_count: result.failedCount,
      cleaned_tokens: result.cleanedTokens,
      errors: result.errors,
    },
  };
}
