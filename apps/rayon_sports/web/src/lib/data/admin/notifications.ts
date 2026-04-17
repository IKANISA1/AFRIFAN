/**
 * Admin notifications — push notification context + delivery.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminNotificationContext, AdminNotificationRecord } from "@/lib/types";
import { serverSupabaseConfig } from "@/lib/config";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

function mapNotification(row: Record<string, unknown>): AdminNotificationRecord {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, "Notification"),
    body: safeString(row.body, "No content."),
    audienceType: safeString(row.audience_type) === "by_tier" ? "by_tier" : safeString(row.audience_type) === "by_group" ? "by_group" : "all_fans",
    audienceTier: safeString(row.audience_tier) || null,
    audienceGroupId: safeString(row.audience_group_id) || null,
    audienceGroupName: safeString(row.audience_group_name) || null,
    deliveryMode: safeString(row.delivery_mode) === "schedule" ? "schedule" : "send_now",
    status: safeString(row.status, "scheduled"),
    scheduledAt: safeString(row.scheduled_at) || null,
    sentAt: safeString(row.sent_at) || null,
    requestedRecipientCount: safeNumber(row.requested_recipient_count, 0),
    sentCount: safeNumber(row.sent_count, 0),
    failedCount: safeNumber(row.failed_count, 0),
    createdAt: safeString(row.created_at, new Date().toISOString()),
    lastError: safeString(row.last_error) || null,
  };
}

export async function getAdminNotificationContext(client: SupabaseClient, access: AdminAccess): Promise<AdminNotificationContext> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminNotificationContext>("notifications");
  }
  const clubId = requireAdminClubId(access, "load notification context");
  const [groupsResult, historyResult] = await Promise.all([
    client.from("contribution_groups").select("id, name").eq("is_closed", false).eq("club_id", clubId).order("name", { ascending: true }).limit(50),
    client.from("notifications").select("*").eq("club_id", clubId).order("created_at", { ascending: false }).limit(10),
  ]);
  if (groupsResult.error) throw new Error(groupsResult.error.message);
  if (historyResult.error) throw new Error(historyResult.error.message);
  return {
    groups: Array.isArray(groupsResult.data) ? groupsResult.data.map((row) => ({ id: safeString((row as Record<string, unknown>).id), name: safeString((row as Record<string, unknown>).name, "Group") })) : [],
    history: Array.isArray(historyResult.data) ? historyResult.data.map((row) => mapNotification(row as Record<string, unknown>)) : [],
  };
}

export async function sendAdminNotification(
  client: SupabaseClient,
  payload: { title: string; body: string; audience: "all_fans" | "by_tier" | "by_group"; tier?: string | null; groupId?: string | null; groupName?: string | null; deliveryMode: "send_now" | "schedule"; scheduledAt?: string | null; imageUrl?: string | null },
  access?: AdminAccess,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<unknown>("notifications", {
      method: "POST",
      body: payload,
    });
  }
  const clubId = requireAdminClubId(
    access ?? { clubId: null },
    "send notifications",
  );
  const { data: sessionData, error: sessionError } =
    await client.auth.getSession();
  if (sessionError) {
    throw new Error(sessionError.message);
  }

  const accessToken = sessionData.session?.access_token;
  if (!accessToken) {
    throw new Error("Admin authentication is required to send notifications.");
  }

  const supabaseUrl = serverSupabaseConfig.url;
  const supabaseAnonKey = serverSupabaseConfig.anonKey;
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Supabase server configuration is not available.");
  }

  const functionResponse = await fetch(
    `${supabaseUrl}/functions/v1/admin-send-notification`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: supabaseAnonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        club_id: clubId,
        title: payload.title,
        body: payload.body,
        audience: payload.audience,
        tier: payload.tier,
        group_id: payload.groupId,
        group_name: payload.groupName,
        delivery_mode: payload.deliveryMode,
        scheduled_at: payload.scheduledAt,
        image_url: payload.imageUrl,
      }),
      cache: "no-store",
    },
  );

  const responseText = await functionResponse.text();
  let raw: { success?: boolean; message?: string; error?: string; data?: unknown } | null = null;
  if (responseText.trim().length > 0) {
    try {
      raw = JSON.parse(responseText) as {
        success?: boolean;
        message?: string;
        error?: string;
        data?: unknown;
      };
    } catch {
      raw = null;
    }
  }

  if (!functionResponse.ok) {
    throw new Error(
      raw?.error ||
        raw?.message ||
        responseText.trim() ||
        "Notification delivery failed.",
    );
  }

  if (raw && typeof raw === "object") {
    if (raw.success === true) {
      return raw.data ?? {};
    }
    if (raw.message) {
      throw new Error(raw.message);
    }
    if (raw.error) {
      throw new Error(raw.error);
    }
  }

  throw new Error(
    "Notification delivery failed. The edge function returned an unexpected response.",
  );
}
