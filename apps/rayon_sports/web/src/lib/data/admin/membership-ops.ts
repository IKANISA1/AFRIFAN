/**
 * Admin membership operations — supporter registry and application review.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminMembershipApplication,
  AdminSupporter,
  MembershipTierSlug,
} from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  AdminMutationConflictError,
  requireAdminClubId,
  requireExpectedUpdatedAt,
  resolveClubFootballPartnerId,
} from "./helpers";

type SupporterRegistryRow = {
  id: unknown;
  user_id: string | null;
  display_name: string | null;
  tier: AdminSupporter["tier"] | null;
  status: string | null;
  points: number | null;
  chapter: string | null;
  membership_number: string | null;
  joined_at: string | null;
  profiles?: { phone?: string | null } | null;
};

type MembershipApplicationRow = {
  id: unknown;
  user_id: string | null;
  tier: string | null;
  status: string | null;
  payment_status: string | null;
  application_date: string | null;
  created_at: string | null;
  review_date: string | null;
  reviewer_id: string | null;
  notes: string | null;
  updated_at: string | null;
  metadata?:
    | {
        chapter?: string | null;
        applicant_name?: string | null;
        applicant_phone?: string | null;
        full_name?: string | null;
        phone?: string | null;
      }
    | null;
};

function normalizeMembershipTier(value: string | null | undefined): MembershipTierSlug {
  switch ((value ?? "").trim().toLowerCase()) {
    case "ingenzi-imanzi":
    case "ingenzi_imanzi":
    case "ingenzi":
    case "imanzi":
      return "ingenzi-imanzi";
    case "inyamibwa":
      return "inyamibwa";
    case "imena":
      return "imena";
    case "bronze":
      return "bronze";
    case "silver":
      return "silver";
    case "gold":
      return "gold";
    default:
      return "imena";
  }
}

type ProfileRow = {
  id: string | null;
  full_name?: string | null;
  phone?: string | null;
};

type UserRow = {
  id: string | null;
  full_name?: string | null;
  phone?: string | null;
};

export async function getAdminSupporterRegistry(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminSupporter[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSupporter[]>("membership-supporters");
  }
  const clubId = requireAdminClubId(access, "load supporters");
  
  const { data, error } = await client
    .from("fan_memberships")
    .select(`
      id,
      user_id,
      display_name,
      tier,
      status,
      points,
      chapter,
      membership_number,
      joined_at,
      profiles:user_id (phone)
    `)
    .eq("club_id", clubId)
    .order("joined_at", { ascending: false });

  if (error) throw new Error(error.message);

  const rows = (data ?? []) as SupporterRegistryRow[];

  return rows.map((row) => ({
    id: toIdString(row.id, ""),
    userId: safeString(row.user_id, toIdString(row.id, "")),
    displayName: safeString(row.display_name, "Anonymous Supporter"),
    phone: safeString(row.profiles?.phone) || null,
    tier: normalizeMembershipTier(row.tier),
    status: (safeString(row.status, "active") as AdminSupporter["status"]),
    points: row.points || 0,
    chapter: safeString(row.chapter, "General"),
    membershipNumber: safeString(row.membership_number, ""),
    joinedAt: safeString(row.joined_at, new Date().toISOString()),
  }));
}

export async function getAdminMembershipApplications(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminMembershipApplication[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminMembershipApplication[]>("membership-applications");
  }
  const clubId = requireAdminClubId(access, "load applications");

  const { data, error } = await client
    .from("membership_applications")
    .select("*")
    .eq("club_id", clubId)
    .order("application_date", { ascending: false });

  if (error) throw new Error(error.message);

  const applicationRows = (data ?? []) as MembershipApplicationRow[];
  const userIds = Array.from(
    new Set(
      applicationRows
        .map((row) => safeString(row.user_id, ""))
        .filter((value) => value.length > 0),
    ),
  );

  let profilesById = new Map<string, { full_name?: string | null; phone?: string | null }>();
  let usersById = new Map<string, { full_name?: string | null; phone?: string | null }>();
  if (userIds.length > 0) {
    const { data: profiles, error: profilesError } = await client
      .from("profiles")
      .select("id, full_name, phone")
      .in("id", userIds);

    if (profilesError) throw new Error(profilesError.message);

    profilesById = new Map(
      ((profiles ?? []) as ProfileRow[]).map((profile) => [
        safeString(profile.id, ""),
        {
          full_name: safeString(profile.full_name) || null,
          phone: safeString(profile.phone) || null,
        },
      ]),
    );

    const { data: users, error: usersError } = await client
      .from("users")
      .select("id, full_name, phone")
      .in("id", userIds);

    if (usersError) throw new Error(usersError.message);

    usersById = new Map(
      ((users ?? []) as UserRow[]).map((user) => [
        safeString(user.id, ""),
        {
          full_name: safeString(user.full_name) || null,
          phone: safeString(user.phone) || null,
        },
      ]),
    );
  }

  return applicationRows.map((row) => {
    const userId = safeString(row.user_id, "");
    const profile = userId ? profilesById.get(userId) : undefined;
    const user = userId ? usersById.get(userId) : undefined;
    const metadataName =
      safeString(row.metadata?.applicant_name) || safeString(row.metadata?.full_name);
    const metadataPhone =
      safeString(row.metadata?.applicant_phone) || safeString(row.metadata?.phone);

    return {
      id: toIdString(row.id, ""),
      userId,
      clubId,
      tier: normalizeMembershipTier(safeString(row.tier, "imena")),
      status: safeString(row.status, "pending") as AdminMembershipApplication["status"],
      paymentStatus: safeString(
        row.payment_status,
        "unpaid",
      ) as AdminMembershipApplication["paymentStatus"],
      applicationDate: safeString(row.application_date, row.created_at ?? undefined),
      reviewDate: safeString(row.review_date) || null,
      reviewerId: safeString(row.reviewer_id) || null,
      notes: safeString(row.notes) || null,
      userName: safeString(
        profile?.full_name,
        safeString(user?.full_name, metadataName || "Unknown"),
      ),
      userPhone: safeString(
        profile?.phone,
        safeString(user?.phone, metadataPhone || "—"),
      ),
      updatedAt: safeString(row.updated_at),
    };
  });
}

export async function reviewMembershipApplication(
  client: SupabaseClient,
  access: AdminAccess,
  applicationId: string,
  expectedUpdatedAt: string,
  decision: "approved" | "rejected",
  notes?: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi("membership-applications/review", {
      method: "POST",
      body: { applicationId, expectedUpdatedAt, decision, notes },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "review application");
  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  const partnerId = await resolveClubFootballPartnerId(client, clubId);
  const { error } = await client.rpc(
    "admin_review_membership_application_if_unchanged",
    {
      p_application_id: applicationId,
      p_expected_updated_at: loadedVersion,
      p_decision: decision,
      p_notes: notes ?? null,
      p_club_id: clubId,
      p_partner_id: partnerId,
      p_actor_id: access.userId ?? null,
    },
  );

  if (error) {
    const message = error.message.toLowerCase();
    if (
      message.includes("changed after it was loaded") ||
      message.includes("no longer pending")
    ) {
      throw new AdminMutationConflictError(error.message);
    }
    throw new Error(error.message);
  }
}
