/**
 * Admin RBAC — role resolution, access derivation, and permission checks.
 * Extracted from admin-legacy.ts for focused domain ownership.
 */
import type { SupabaseClient, User } from "@supabase/supabase-js";
import { siteConfig } from "@/lib/config";
import type { AdminAccess, AdminRole } from "@/lib/types";
import { safeString } from "@/lib/utils";

export const emptyAdminAccess: AdminAccess = {
  hasAccess: false,
  isAuthenticated: false,
  isSuperAdmin: false,
  userId: null,
  role: null,
  clubId: null,
  availableClubIds: [],
  canSelectClub: false,
  assignmentCount: 0,
};

type AdminAssignmentRow = Record<string, unknown>;
type AdminUserClaims = {
  app_metadata?: Record<string, unknown>;
  user_metadata?: Record<string, unknown>;
} | null;

function normalizeClubId(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value.toString();
  }
  const text = safeString(value);
  if (!text) {
    return null;
  }
  if (text === siteConfig.defaultClubSlug) {
    return siteConfig.defaultClubId.toString();
  }
  const parsed = Number(text);
  if (Number.isFinite(parsed)) {
    return parsed.toString();
  }
  return text;
}

function matchClubScope(
  assignment: AdminAssignmentRow,
  scopeClubId: string | null,
) {
  const role = normalizeAdminRole(assignment.role);
  if (role === "super_admin" || role === "admin") {
    return true;
  }
  if (role !== "club_admin" && role !== "club_moderator") {
    return false;
  }
  const assignmentClubId = normalizeClubId(assignment.club_id);
  return scopeClubId == null || assignmentClubId === scopeClubId;
}

function userClubId(user: AdminUserClaims) {
  return normalizeClubId(
    user?.app_metadata?.club_id ??
      user?.user_metadata?.club_id ??
      user?.user_metadata?.clubId ??
      user?.app_metadata?.clubId,
  );
}

function metadataRole(user: AdminUserClaims) {
  return normalizeAdminRole(
    user?.app_metadata?.role ?? user?.user_metadata?.role ?? null,
  );
}

function assignmentClubIds(assignments: AdminAssignmentRow[]) {
  return [...new Set(
    assignments
      .map((assignment) => normalizeClubId(assignment.club_id))
      .filter((value): value is string => value != null),
  )];
}

function isPrivilegedRole(role: AdminRole | null) {
  return role === "super_admin" || role === "admin";
}

function resolveEffectiveClubId({
  role,
  requestedClubId,
  currentClubId,
  availableClubIds,
}: {
  role: AdminRole | null;
  requestedClubId: string | null;
  currentClubId: string | null;
  availableClubIds: string[];
}) {
  const clubIdsAreRestricted = availableClubIds.length > 0;
  const hasInvalidRequestedClub =
    requestedClubId != null &&
    clubIdsAreRestricted &&
    !availableClubIds.includes(requestedClubId) &&
    !isPrivilegedRole(role);

  const canUse = (candidate: string | null) => {
    if (candidate == null) {
      return false;
    }
    if (!clubIdsAreRestricted) {
      return isPrivilegedRole(role);
    }
    return availableClubIds.includes(candidate);
  };

  if (hasInvalidRequestedClub) {
    return null;
  }

  if (canUse(requestedClubId)) {
    return requestedClubId;
  }

  if (canUse(currentClubId)) {
    return currentClubId;
  }

  if (availableClubIds.length > 0) {
    return availableClubIds[0] ?? null;
  }

  return isPrivilegedRole(role) ? currentClubId : null;
}

export function normalizeAdminRole(value: unknown): AdminRole | null {
  const role = safeString(value).toLowerCase();
  switch (role) {
    case "super_admin":
      return "super_admin";
    case "admin":
      return "admin";
    case "rayon_sport":
    case "club_admin":
      return "club_admin";
    case "bank":
    case "club_moderator":
      return "club_moderator";
    case "fan":
      return "fan";
    default:
      return null;
  }
}

export function formatAdminRoleLabel(role: AdminRole | null) {
  return (role ?? "fan").replaceAll("_", " ");
}

export function deriveAdminAccess(
  user: AdminUserClaims,
  assignments: AdminAssignmentRow[],
  options?: {
    requestedClubId?: string | null;
  },
): AdminAccess {
  if (user == null) {
    return emptyAdminAccess;
  }

  const currentClubId = userClubId(user);
  const requestedClubId = normalizeClubId(options?.requestedClubId ?? null);
  const scopedClubId = requestedClubId ?? currentClubId;
  const availableClubIds = assignmentClubIds(assignments);
  const matchingAssignments = assignments.filter((assignment) =>
    matchClubScope(assignment, scopedClubId),
  );
  const matchingAssignmentRole = normalizeAdminRole(matchingAssignments[0]?.role);
  const assignmentRole =
    matchingAssignmentRole ?? normalizeAdminRole(assignments[0]?.role);
  const fallbackRole = metadataRole(user);
  // Effective role for display, but only assignment-backed roles grant access.
  const role = assignmentRole ?? fallbackRole;
  const hasMatchingAssignment = matchingAssignments.length > 0;
  const hasAssignment = assignments.length > 0;
  // Fail-closed: metadata-only role never grants admin access.
  const hasAccess =
    hasMatchingAssignment &&
    (role === "super_admin" ||
      role === "admin" ||
      role === "club_admin" ||
      role === "club_moderator");

  return {
    hasAccess,
    isAuthenticated: user != null,
    isSuperAdmin:
      hasMatchingAssignment && (role === "super_admin" || role === "admin"),
    userId: safeString((user as { id?: unknown } | null)?.id) || null,
    role,
    clubId: resolveEffectiveClubId({
      role,
      requestedClubId,
      currentClubId,
      availableClubIds,
    }),
    availableClubIds,
    canSelectClub:
      hasAssignment &&
      (isPrivilegedRole(role) || availableClubIds.length > 1),
    assignmentCount: assignments.length,
  };
}

export async function resolveAdminAccess(
  client: SupabaseClient,
  user: User | null,
  options?: {
    requestedClubId?: string | null;
  },
) {
  if (user == null) {
    return emptyAdminAccess;
  }

  try {
    const { data, error } = await client
      .from("admin_role_assignments")
      .select("role, club_id, is_active")
      .eq("user_id", user.id)
      .eq("is_active", true);

    if (error) {
      throw error;
    }

    return deriveAdminAccess(
      user,
      Array.isArray(data) ? (data as AdminAssignmentRow[]) : [],
      options,
    );
  } catch {
    // Fail-closed: assignment lookup failure denies access.
    return emptyAdminAccess;
  }
}
