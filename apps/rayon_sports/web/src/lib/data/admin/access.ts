/**
 * Admin RBAC — role resolution, access derivation, and permission checks.
 * Extracted from admin-legacy.ts for focused domain ownership.
 */
import type { SupabaseClient, User } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess, AdminRole } from "@/lib/types";
import { safeString } from "@/lib/utils";

export const emptyAdminAccess: AdminAccess = {
  hasAccess: false,
  isAuthenticated: false,
  isSuperAdmin: false,
  role: null,
  clubId: null,
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
  if (text === rayonClub.slug) {
    return rayonClub.numericId.toString();
  }
  const parsed = Number(text);
  if (Number.isFinite(parsed)) {
    return parsed.toString();
  }
  return text;
}

function matchClubScope(
  assignment: AdminAssignmentRow,
  currentClubId: string | null,
) {
  const role = normalizeAdminRole(assignment.role);
  if (role === "super_admin" || role === "admin") {
    return true;
  }
  if (role !== "club_admin" && role !== "club_moderator") {
    return false;
  }
  const assignmentClubId = normalizeClubId(assignment.club_id);
  return currentClubId == null || assignmentClubId === currentClubId;
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
): AdminAccess {
  if (user == null) {
    return emptyAdminAccess;
  }

  const currentClubId = userClubId(user);
  const matchingAssignments = assignments.filter((assignment) =>
    matchClubScope(assignment, currentClubId),
  );
  const assignmentRole = normalizeAdminRole(matchingAssignments[0]?.role);
  const fallbackRole = metadataRole(user);
  // Effective role for display, but only assignment-backed roles grant access.
  const role = assignmentRole ?? fallbackRole;
  const hasAssignment = matchingAssignments.length > 0;
  // Fail-closed: metadata-only role never grants admin access.
  const hasAccess =
    hasAssignment &&
    (role === "super_admin" ||
      role === "admin" ||
      role === "club_admin" ||
      role === "club_moderator");

  return {
    hasAccess,
    isAuthenticated: user != null,
    isSuperAdmin:
      hasAssignment && (role === "super_admin" || role === "admin"),
    role,
    clubId: currentClubId,
    assignmentCount: matchingAssignments.length,
  };
}

export async function resolveAdminAccess(
  client: SupabaseClient,
  user: User | null,
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
    );
  } catch {
    // Fail-closed: assignment lookup failure denies access.
    return emptyAdminAccess;
  }
}
