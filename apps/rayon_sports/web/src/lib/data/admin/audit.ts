/**
 * Admin audit logs — bounded, club-scoped, privacy-safe operator history.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import { hasColumn, requireAdminClubId } from "./helpers";
import {
  normalizeAdminAuditLogs,
  type AdminAuditRecord,
} from "./audit-projection";

export {
  normalizeAdminAuditLogs,
  projectAdminAuditDetail,
  type AdminAuditDetailProjection,
  type AdminAuditRecord,
} from "./audit-projection";

const MAX_AUDIT_RECORDS = 500;

export async function getAdminAuditLogs(
  client: SupabaseClient,
  access: AdminAccess,
  options: { limit?: number; signal?: AbortSignal } = {},
): Promise<AdminAuditRecord[]> {
  const limit = Math.min(
    MAX_AUDIT_RECORDS,
    Math.max(1, Math.trunc(options.limit ?? MAX_AUDIT_RECORDS)),
  );
  if (typeof window !== "undefined") {
    return normalizeAdminAuditLogs(
      await requestAdminApi<unknown>("audit-logs", {
        query: { limit },
        signal: options.signal,
      }),
    );
  }

  const clubId = requireAdminClubId(access, "load audit logs");
  const auditHasClubId = await hasColumn(client, "admin_audit_log", "club_id");
  if (!auditHasClubId && !access.isSuperAdmin) {
    throw new Error("Club-scoped audit history is unavailable.");
  }

  let query = client
    .from("admin_audit_log")
    .select(
      "id, user_id, actor_id, action, target_table, target_id, entity_type, entity_id, old_data, new_data, metadata, notes, created_at, profiles:user_id (full_name)",
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (auditHasClubId) {
    query = query.eq("club_id", clubId);
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return normalizeAdminAuditLogs(data);
}
