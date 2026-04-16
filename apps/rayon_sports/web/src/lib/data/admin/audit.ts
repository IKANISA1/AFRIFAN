/**
 * Admin audit logs — track actions performed by administrators.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId, hasColumn } from "./helpers";

export interface AdminAuditRecord {
  id: string;
  userId: string;
  userName?: string;
  action: string;
  metadata: Record<string, any>;
  createdAt: string;
}

export async function getAdminAuditLogs(
  client: SupabaseClient,
  access: AdminAccess,
  limit = 100
): Promise<AdminAuditRecord[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminAuditRecord[]>("audit-logs");
  }
  
  const clubId = requireAdminClubId(access, "load audit logs");
  const auditHasClubId = await hasColumn(client, "admin_audit_log", "club_id");

  let query = client
    .from("admin_audit_log")
    .select(`
      id,
      user_id,
      action,
      metadata,
      created_at,
      profiles:user_id (full_name)
    `)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (auditHasClubId) {
    query = query.eq("club_id", clubId);
  }

  const { data, error } = await query;

  if (error) throw new Error(error.message);

  return (data ?? []).map((row: any) => ({
    id: toIdString(row.id, ""),
    userId: row.user_id,
    userName: safeString(row.profiles?.full_name, "System / Unknown"),
    action: safeString(row.action, "Operation"),
    metadata: row.metadata || {},
    createdAt: safeString(row.created_at, new Date().toISOString()),
  }));
}
