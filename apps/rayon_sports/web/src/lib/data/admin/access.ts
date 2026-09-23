/**
 * Admin RBAC — role resolution, access derivation, and permission checks.
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

const assignmentRolePriority: Record<AdminRole, number> = {
  super_admin: 5,
  admin: 4,
  club_admin: 3,
  club_moderator: 2,
  fan: 1,
};

function strongestAssignmentRole(assignments: AdminAssignmentRow[]) {
  let strongest: AdminRole | null = null;
  for (const assignment of assignments) {
    const role = normalizeAdminRole(assignment.role);
    if (role && (!strongest || assignmentRolePriority[role] > assignmentRolePriority[strongest])) {
      strongest = role;
    }
  }
  return strongest;
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
  // Platform grants cover every club, as in the database authorization helpers.
  // A second local grant must not restrict or silently replace their selection.
  if (isPrivilegedRole(role)) {
    return requestedClubId ?? currentClubId ?? availableClubIds[0] ?? null;
  }

  if (requestedClubId != null) {
    return availableClubIds.includes(requestedClubId) ? requestedClubId : null;
  }

  if (currentClubId != null && availableClubIds.includes(currentClubId)) {
    return currentClubId;
  }

  return availableClubIds[0] ?? null;
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
  const matchingAssignmentRole = strongestAssignmentRole(matchingAssignments);
  const assignmentRole =
    matchingAssignmentRole ?? strongestAssignmentRole(assignments);
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
