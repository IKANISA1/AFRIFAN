import type { SupabaseClient } from "@supabase/supabase-js";
import { normalizeAdminPhone } from "@/lib/admin-auth";
import type {
  AdminAccess,
  AdminAssignableRole,
  AdminRoleAssignment,
  AdminUserCandidate,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import { safeNumber, safeString, toIdString } from "./helpers";

function requirePlatformAdmin(
  access: Pick<AdminAccess, "isSuperAdmin">,
  action: string,
) {
  if (!access.isSuperAdmin) {
    throw new Error(`Platform admin access is required to ${action}.`);
  }
}

function normalizeAssignableRole(value: unknown): AdminAssignableRole {
  const normalized = safeString(value).toLowerCase();
  switch (normalized) {
    case "super_admin":
      return "super_admin";
    case "admin":
      return "admin";
    case "club_admin":
      return "club_admin";
    case "club_moderator":
      return "club_moderator";
    default:
      throw new Error("Choose a valid admin role.");
  }
}

function requiresClubScope(role: AdminAssignableRole) {
  return role === "club_admin" || role === "club_moderator";
}

async function getAuthEmailMap(
  client: SupabaseClient,
  userIds: string[],
) {
  const entries = await Promise.all(
    userIds.map(async (userId) => {
      try {
        const { data, error } = await client.auth.admin.getUserById(userId);
        if (error) {
          return [userId, null] as const;
        }
        return [userId, safeString(data.user?.email) || null] as const;
      } catch {
        return [userId, null] as const;
      }
    }),
  );

  return new Map(entries);
}

function mapRoleAssignment(
  row: Record<string, unknown>,
  usersById: Map<string, Record<string, unknown>>,
  clubsById: Map<string, string>,
  partnersById: Map<string, string>,
  authEmails: Map<string, string | null>,
): AdminRoleAssignment {
  const userId = toIdString(row.user_id, crypto.randomUUID());
  const grantedBy = safeString(row.granted_by) || null;
  const parsedClubId = safeNumber(row.club_id, Number.NaN);
  const clubId = Number.isFinite(parsedClubId) ? parsedClubId.toString() : null;
  const partnerScopeId = safeString(row.partner_scope_id) || null;
  const profile = usersById.get(userId);
  const grantedByProfile = grantedBy ? usersById.get(grantedBy) : undefined;

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    userId,
    userName: safeString(profile?.full_name, "Unnamed admin"),
    userPhone: safeString(profile?.phone) || null,
    userEmail: authEmails.get(userId) ?? null,
    publicUserId: safeString(profile?.public_user_id) || null,
    role: normalizeAssignableRole(row.role),
    clubId,
    clubName: clubId ? clubsById.get(clubId) ?? null : null,
    partnerScopeId,
    partnerName: partnerScopeId ? partnersById.get(partnerScopeId) ?? null : null,
    grantedBy,
    grantedByName: safeString(grantedByProfile?.full_name) || null,
    grantedAt: safeString(row.granted_at, new Date().toISOString()),
    revokedAt: safeString(row.revoked_at) || null,
    isActive: row.is_active !== false,
    notes: safeString(row.notes) || null,
  };
}

export async function getAdminRoleAssignments(
  client: SupabaseClient,
  access: AdminAccess,
  options: { activeOnly?: boolean } = {},
): Promise<AdminRoleAssignment[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminRoleAssignment[]>("access", {
      query: {
        active_only: options.activeOnly ?? true,
      },
    });
  }

  requirePlatformAdmin(access, "view admin access");

  const { data, error } = await client
    .from("admin_role_assignments")
    .select(
      "id, user_id, role, club_id, partner_scope_id, granted_by, granted_at, revoked_at, is_active, notes",
    )
    .order("granted_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  const rows = (Array.isArray(data) ? data : []).filter((row) =>
    options.activeOnly === false ? true : row.is_active !== false,
  ) as Record<string, unknown>[];

  const userIds = [...new Set(
    rows.flatMap((row) => [safeString(row.user_id), safeString(row.granted_by)]).filter(Boolean),
  )];
  const clubIds = [...new Set(
    rows
      .map((row) => safeNumber(row.club_id, Number.NaN))
      .filter(Number.isFinite)
      .map((value) => value.toString()),
  )];
  const partnerIds = [...new Set(rows.map((row) => safeString(row.partner_scope_id)).filter(Boolean))];

  const [usersResponse, clubsResponse, partnersResponse, authEmails] = await Promise.all([
    userIds.length > 0
      ? client
          .from("users")
          .select("id, full_name, phone, public_user_id")
          .in("id", userIds)
      : Promise.resolve({ data: [], error: null }),
    clubIds.length > 0
      ? client
          .from("african_football_clubs")
          .select("id, club_name")
          .in("id", clubIds.map((value) => Number(value)))
      : Promise.resolve({ data: [], error: null }),
    partnerIds.length > 0
      ? client.from("partners").select("id, name").in("id", partnerIds)
      : Promise.resolve({ data: [], error: null }),
    getAuthEmailMap(client, userIds),
  ]);

  if (usersResponse.error) {
    throw new Error(usersResponse.error.message);
  }
  if (clubsResponse.error) {
    throw new Error(clubsResponse.error.message);
  }
  if (partnersResponse.error) {
    throw new Error(partnersResponse.error.message);
  }

  const usersById = new Map(
    (usersResponse.data ?? []).map((row) => [toIdString(row.id, crypto.randomUUID()), row as Record<string, unknown>]),
  );
  const clubsById = new Map(
    (clubsResponse.data ?? []).map((row) => [
      safeNumber(row.id, Number.NaN).toString(),
      safeString(row.club_name, "Club"),
    ]),
  );
  const partnersById = new Map(
    (partnersResponse.data ?? []).map((row) => [
      safeString(row.id),
      safeString(row.name, "Partner"),
    ]),
  );

  return rows.map((row) =>
    mapRoleAssignment(row, usersById, clubsById, partnersById, authEmails),
  );
}

export async function findAdminUserCandidate(
  client: SupabaseClient,
  access: AdminAccess,
  identifier: string,
): Promise<AdminUserCandidate> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminUserCandidate>("access-users", {
      query: { q: identifier },
    });
  }

  requirePlatformAdmin(access, "look up admin users");

  const trimmed = safeString(identifier);
  if (!trimmed) {
    throw new Error("Enter a phone number, email, or user id.");
  }

  let userId = "";
  const isUuid = /^[0-9a-f-]{36}$/i.test(trimmed);
  const emailCandidate = trimmed.includes("@") ? trimmed.toLowerCase() : null;
  const phoneCandidate =
    !emailCandidate && !isUuid ? normalizeAdminPhone(trimmed) : null;

  if (isUuid) {
    userId = trimmed;
  } else {
    const { data, error } = await client.rpc("find_auth_user_by_phone_or_email", {
      p_phone: phoneCandidate,
      p_email: emailCandidate,
    });
    if (error) {
      throw new Error(error.message);
    }
    const match = Array.isArray(data) ? (data[0] as { user_id?: string } | undefined) : undefined;
    userId = safeString(match?.user_id);
  }

  if (!userId) {
    throw new Error("No registered user matched that identifier.");
  }

  const [{ data: profile, error: profileError }, authLookup] = await Promise.all([
    client
      .from("users")
      .select("id, full_name, phone, public_user_id, is_admin")
      .eq("id", userId)
      .maybeSingle(),
    client.auth.admin.getUserById(userId).catch(() => ({ data: { user: null }, error: null })),
  ]);

  if (profileError) {
    throw new Error(profileError.message);
  }

  const authUser = "data" in authLookup ? authLookup.data.user : null;

  return {
    userId,
    fullName: safeString(profile?.full_name, safeString(authUser?.user_metadata?.full_name, "Registered user")),
    phone: safeString(profile?.phone, phoneCandidate ?? safeString(authUser?.phone)) || null,
    email: safeString(authUser?.email, emailCandidate ?? "") || null,
    publicUserId: safeString(profile?.public_user_id) || null,
    isPlatformAdmin: profile?.is_admin === true,
    hasProfile: profile != null,
  };
}

export async function assignAdminRole(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    userId: string;
    role: AdminAssignableRole;
    clubId?: string | null;
    notes?: string | null;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("access", {
      method: "POST",
      body: input,
    });
  }

  requirePlatformAdmin(access, "assign admin roles");

  const role = normalizeAssignableRole(input.role);
  const clubId = requiresClubScope(role)
    ? safeNumber(input.clubId, Number.NaN)
    : null;

  if (requiresClubScope(role) && !Number.isFinite(clubId)) {
    throw new Error("Club-scoped roles require a club selection.");
  }

  const { data, error } = await client.rpc("assign_admin_role", {
    p_target_user_id: input.userId,
    p_role: role,
    p_club_id: Number.isFinite(clubId) ? clubId : null,
    p_partner_scope_id: null,
    p_notes: safeString(input.notes) || null,
  });

  if (error) {
    throw new Error(error.message);
  }

  return safeString(
    (data as { assignment_id?: unknown } | null)?.assignment_id,
    crypto.randomUUID(),
  );
}

export async function revokeAdminRole(
  client: SupabaseClient,
  access: AdminAccess,
  assignmentId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("access", {
      method: "DELETE",
      query: { id: assignmentId },
    });
    return;
  }

  requirePlatformAdmin(access, "revoke admin roles");

  const { error } = await client.rpc("revoke_admin_role", {
    p_assignment_id: assignmentId,
    p_notes: null,
  });

  if (error) {
    throw new Error(error.message);
  }
}
