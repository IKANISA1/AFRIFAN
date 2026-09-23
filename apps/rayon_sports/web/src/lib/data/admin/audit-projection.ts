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

export interface AdminAuditDetailProjection {
  previousValues: string;
  newValues: string;
  metadata: string;
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

/** Formats only the sanitized fields rendered by the audit detail drawer. */
export function projectAdminAuditDetail(
  record: Pick<AdminAuditRecord, "oldData" | "newData" | "metadata">,
): AdminAuditDetailProjection {
  return {
    previousValues: JSON.stringify(record.oldData, null, 2),
    newValues: JSON.stringify(record.newData, null, 2),
    metadata: JSON.stringify(record.metadata, null, 2),
  };
}
