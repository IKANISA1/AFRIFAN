import type {
  AdminAssignableRole,
  AdminRoleAssignment,
} from "@/lib/types";

const assignableRoles = new Set<AdminAssignableRole>([
  "super_admin",
  "admin",
  "club_admin",
  "club_moderator",
]);

function normalizedText(
  value: unknown,
  maxLength: number,
  fallback = "",
) {
  if (typeof value !== "string") {
    return fallback;
  }
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : fallback;
}

function nullableText(value: unknown, maxLength: number) {
  return normalizedText(value, maxLength) || null;
}

export function normalizeAdminRoleAssignments(
  value: unknown,
): AdminRoleAssignment[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = normalizedText(record.id, 128);
    const userId = normalizedText(record.userId, 128);
    const userName = normalizedText(record.userName, 120);
    const role = normalizedText(record.role, 40) as AdminAssignableRole;
    const grantedAt = normalizedText(record.grantedAt, 64);

    if (
      !id ||
      !userId ||
      !userName ||
      !assignableRoles.has(role) ||
      !grantedAt ||
      !Number.isFinite(Date.parse(grantedAt))
    ) {
      return [];
    }

    return [{
      id,
      userId,
      userName,
      userPhone: nullableText(record.userPhone, 40),
      userEmail: nullableText(record.userEmail, 254),
      publicUserId: nullableText(record.publicUserId, 128),
      role,
      clubId: nullableText(record.clubId, 128),
      clubName: nullableText(record.clubName, 120),
      partnerScopeId: nullableText(record.partnerScopeId, 128),
      partnerName: nullableText(record.partnerName, 120),
      grantedBy: nullableText(record.grantedBy, 128),
      grantedByName: nullableText(record.grantedByName, 120),
      grantedAt,
      revokedAt: nullableText(record.revokedAt, 64),
      isActive: record.isActive === true,
      notes: nullableText(record.notes, 500),
    }];
  });
}
