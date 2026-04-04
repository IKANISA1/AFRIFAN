/**
 * Admin dashboard — metrics snapshot and activity feed.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminActivityRecord,
  AdminDashboardMetrics,
  AdminDashboardSnapshot,
} from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { metadataSnippet, resolveNewsTable, safeCount } from "./helpers";

function mapDashboardActivity(row: Record<string, unknown>): AdminActivityRecord {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.action, "Admin update").replaceAll("_", " "),
    detail: metadataSnippet(row.metadata) || "Club activity recorded.",
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminDashboardSnapshot(
  client: SupabaseClient,
): Promise<AdminDashboardSnapshot> {
  const now = new Date();
  const startOfDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  ).toISOString();
  const endOfDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
  ).toISOString();
  const newsTable = await resolveNewsTable(client);

  const [totalUsers, activeGroups, transactionsToday, ticketsSold, auditFeed, recentNews] =
    await Promise.all([
      safeCount(client.from("profiles").select("id", { count: "exact", head: true })),
      safeCount(
        client
          .from("contribution_groups")
          .select("id", { count: "exact", head: true })
          .eq("is_closed", false),
      ),
      safeCount(
        client
          .from("contributions")
          .select("id", { count: "exact", head: true })
          .gte("created_at", startOfDay)
          .lt("created_at", endOfDay),
      ),
      safeCount(client.from("tickets").select("id", { count: "exact", head: true })),
      client
        .from("admin_audit_log")
        .select("id, action, metadata, created_at")
        .order("created_at", { ascending: false })
        .limit(4),
      client
        .from(newsTable)
        .select("id, title, created_at")
        .order("created_at", { ascending: false })
        .limit(3),
    ]);

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
    metrics: {
      totalUsers,
      activeGroups,
      transactionsToday,
      ticketsSold,
    } satisfies AdminDashboardMetrics,
    activity: activity.slice(0, 6),
  };
}
