/**
 * Admin dashboard — metrics snapshot and activity feed.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminActivityRecord,
  AdminDashboardMetrics,
  AdminDashboardSnapshot,
} from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  adminClubIdOrNull,
  hasColumn,
  metadataSnippet,
  resolveNewsTable,
  safeCount,
} from "./helpers";

function mapDashboardActivity(row: Record<string, unknown>): AdminActivityRecord {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.action, "Admin update").replaceAll("_", " "),
    detail: metadataSnippet(row.metadata) || "Club activity recorded.",
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

interface DashboardAnalyticsRow {
  total_fans?: number | null;
  total_tickets_sold?: number | null;
  ticket_revenue?: number | null;
}

export async function getAdminDashboardSnapshot(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminDashboardSnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminDashboardSnapshot>("dashboard");
  }
  const newsTable = await resolveNewsTable(client);
  const clubId = adminClubIdOrNull(access);
  
  if (clubId == null) {
    return {
      metrics: {
        activeUsers: 0,
        pendingVerifications: 0,
        activeSupportCircles: 0,
        recentTicketSales: 0,
        totalFans: 0,
        ticketRevenue: 0,
      },
      activity: [],
    };
  }

  const auditHasClubId = await hasColumn(client, "admin_audit_log", "club_id");

  const [analyticsResponse, activeGroupsCount, pendingTicketsCount, auditFeed, recentNews] =
    await Promise.all([
      client.rpc("get_club_fan_analytics", { p_club_id: clubId }),
      safeCount(
        client
          .from("contribution_groups")
          .select("id", { count: "exact", head: true })
          .eq("is_closed", false)
          .eq("club_id", clubId),
      ),
      safeCount(
        client
          .from("tickets")
          .select("id", { count: "exact", head: true })
          .eq("status", "pending")
          .eq("club_id", clubId),
      ),
      auditHasClubId
        ? client
            .from("admin_audit_log")
            .select("id, action, metadata, created_at")
            .eq("club_id", clubId)
            .order("created_at", { ascending: false })
            .limit(4)
        : Promise.resolve({ data: [], error: null }),
      client
        .from(newsTable)
        .select("id, title, created_at")
        .eq("club_id", clubId)
        .order("created_at", { ascending: false })
        .limit(3),
    ]);

  const analytics = analyticsResponse.data as DashboardAnalyticsRow | null;
  const metrics: AdminDashboardMetrics = {
    activeUsers: analytics?.total_fans ?? 0,
    pendingVerifications: pendingTicketsCount, // fallback for now
    activeSupportCircles: activeGroupsCount,
    recentTicketSales: analytics?.total_tickets_sold ?? 0,
    totalFans: analytics?.total_fans ?? 0,
    ticketRevenue: analytics?.ticket_revenue ?? 0,
  };

  const activity: AdminActivityRecord[] = [];

  if (!auditFeed.error && Array.isArray(auditFeed.data)) {
    activity.push(
      ...auditFeed.data.map((row) =>
        mapDashboardActivity(row as Record<string, unknown>),
      ),
    );
  }

  if (!recentNews.error && Array.isArray(recentNews.data)) {
    activity.push(
      ...recentNews.data.map((row) => ({
        id: `news-${toIdString((row as Record<string, unknown>).id, crypto.randomUUID())}`,
        title: "CMS update",
        detail: safeString(
          (row as Record<string, unknown>).title,
          "Recent article update.",
        ),
        createdAt: safeString(
          (row as Record<string, unknown>).created_at,
          new Date().toISOString(),
        ),
      })),
    );
  }

  return {
    metrics,
    activity: activity.slice(0, 6),
  };
}
