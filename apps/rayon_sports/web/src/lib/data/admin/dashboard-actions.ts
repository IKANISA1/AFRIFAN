/**
 * Admin dashboard actions are database-owned so clubs can configure the
 * control-center surface without a web release.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminDashboardAction } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { adminClubIdOrNull } from "./helpers";

function mapDashboardAction(row: Record<string, unknown>): AdminDashboardAction {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    actionKey: safeString(row.action_key),
    title: safeString(row.title, "Admin action"),
    subtitle: row.subtitle == null ? null : safeString(row.subtitle),
    route: safeString(row.route, "/admin"),
    iconKey: safeString(row.icon_key, "settings"),
    category: safeString(row.category, "operations"),
    clubId: row.club_id == null ? null : safeNumber(row.club_id, 0),
    requiredRole:
      row.required_role == null
        ? null
        : (safeString(row.required_role) as AdminDashboardAction["requiredRole"]),
    sortOrder: safeNumber(row.sort_order, 0),
  };
}

export async function getAdminDashboardActions(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminDashboardAction[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminDashboardAction[]>("dashboard-actions");
  }

  const { data, error } = await client.rpc("get_admin_dashboard_actions", {
    p_club_id: adminClubIdOrNull(access),
    p_role: access.role,
    p_is_super_admin: access.isSuperAdmin,
  });

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) => mapDashboardAction(row as Record<string, unknown>))
    : [];
}
