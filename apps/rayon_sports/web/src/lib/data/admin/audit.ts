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
  targetTable?: string;
  targetId?: string;
  oldData: Record<string, unknown>;
  newData: Record<string, unknown>;
  metadata: Record<string, unknown>;
  notes?: string;
  createdAt: string;
}

interface AdminAuditRow extends Record<string, unknown> {
  id?: unknown;
  user_id?: unknown;
  actor_id?: unknown;
  action?: unknown;
  target_table?: unknown;
  target_id?: unknown;
  old_data?: unknown;
  new_data?: unknown;
  metadata?: unknown;
  notes?: unknown;
  created_at?: unknown;
  profiles?: { full_name?: unknown } | null;
}

export async function getAdminAuditLogs(
  client: SupabaseClient,
  access: AdminAccess,
  limit = 500,
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
      actor_id,
      action,
      target_table,
      target_id,
      old_data,
      new_data,
      metadata,
      notes,
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

  return ((data ?? []) as AdminAuditRow[]).map((row) => ({
    id: toIdString(row.id, ""),
    userId: safeString(row.user_id) || safeString(row.actor_id, ""),
    userName: safeString(row.profiles?.full_name, "System / Unknown"),
    action: safeString(row.action, "Operation"),
    targetTable: safeString(row.target_table, ""),
    targetId: safeString(row.target_id, ""),
    oldData: isRecord(row.old_data) ? row.old_data : {},
    newData: isRecord(row.new_data) ? row.new_data : {},
    metadata: isRecord(row.metadata) ? row.metadata : {},
    notes: safeString(row.notes, ""),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  }));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
