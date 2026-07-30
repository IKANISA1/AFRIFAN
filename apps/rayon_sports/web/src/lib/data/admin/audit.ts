/**
 * Admin audit logs — bounded, club-scoped, privacy-safe operator history.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import { hasColumn, requireAdminClubId } from "./helpers";

const MAX_AUDIT_RECORDS = 500;
const MAX_OBJECT_KEYS = 50;
const MAX_ARRAY_ITEMS = 50;
const MAX_OBJECT_DEPTH = 4;
const sensitiveKey =
  /(?:authorization|cookie|credential|email|ip_address|password|phone|secret|session|token)/i;

export interface AdminAuditRecord {
  id: string;
  actorKind: "administrator" | "system";
  userName: string;
  action: string;
  targetTable: string;
  targetId: string | null;
  oldData: Record<string, unknown>;
  newData: Record<string, unknown>;
  metadata: Record<string, unknown>;
  notes: string | null;
  createdAt: string;
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength) ?? undefined;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function sanitizeAuditValue(value: unknown, depth = 0): unknown {
  if (depth >= MAX_OBJECT_DEPTH) return "[truncated]";
  if (value == null || typeof value === "boolean") return value;
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    return value.length <= 500 ? value : `${value.slice(0, 500)}…`;
  }
  if (Array.isArray(value)) {
    return value
      .slice(0, MAX_ARRAY_ITEMS)
      .map((entry) => sanitizeAuditValue(entry, depth + 1));
  }
  if (typeof value !== "object") return null;

  const safe: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value).slice(0, MAX_OBJECT_KEYS)) {
    const normalizedKey = boundedText(key, 80);
    if (normalizedKey == null) continue;
    safe[normalizedKey] = sensitiveKey.test(normalizedKey)
      ? "[redacted]"
      : sanitizeAuditValue(entry, depth + 1);
  }
  return safe;
}

function sanitizeAuditObject(value: unknown) {
  const safe = sanitizeAuditValue(value);
  return safe != null && typeof safe === "object" && !Array.isArray(safe)
    ? (safe as Record<string, unknown>)
    : {};
}

function normalizeAuditRecord(value: unknown): AdminAuditRecord | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const actorId = boundedText(row.actorId ?? row.actor_id ?? row.user_id, 128);
  const profile =
    row.profiles != null &&
    typeof row.profiles === "object" &&
    !Array.isArray(row.profiles)
      ? (row.profiles as Record<string, unknown>)
      : null;
  const actorKindValue = boundedText(row.actorKind, 32);
  const actorKind =
    actorKindValue === "administrator" || actorKindValue === "system"
      ? actorKindValue
      : actorId == null
        ? "system"
        : "administrator";
  const userName =
    boundedText(row.userName ?? profile?.full_name, 160) ??
    (actorKind === "system" ? "System action" : "Administrator");
  const action = boundedText(row.action, 160);
  const targetTable = boundedText(
    row.targetTable ?? row.target_table ?? row.entity_type,
    160,
  );
  const targetId = nullableText(
    row.targetId ?? row.target_id ?? row.entity_id,
    256,
  );
  const notes = nullableText(row.notes, 1_000);
  const createdAt = boundedDate(row.createdAt ?? row.created_at);
  if (
    id == null ||
    action == null ||
    targetTable == null ||
    targetId === undefined ||
    notes === undefined ||
    createdAt == null
  ) {
    return null;
  }

  return {
    id,
    actorKind,
    userName,
    action,
    targetTable,
    targetId,
    oldData: sanitizeAuditObject(row.oldData ?? row.old_data),
    newData: sanitizeAuditObject(row.newData ?? row.new_data),
    metadata: sanitizeAuditObject(row.metadata),
    notes,
    createdAt,
  };
}

export function normalizeAdminAuditLogs(value: unknown): AdminAuditRecord[] {
  if (!Array.isArray(value)) return [];
  const records: AdminAuditRecord[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_AUDIT_RECORDS)) {
    const record = normalizeAuditRecord(entry);
    if (record != null && !seen.has(record.id)) {
      records.push(record);
      seen.add(record.id);
    }
  }
  return records;
}

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
