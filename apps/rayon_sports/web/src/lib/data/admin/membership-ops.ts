/**
 * Admin membership operations — supporter registry and application review.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminMembershipApplication, AdminSupporter } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId, resolveClubFootballPartnerId } from "./helpers";

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
    tier: row.tier ?? "fan",
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
      tier: safeString(row.tier, "fan") as AdminMembershipApplication["tier"],
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
    };
  });
}

export async function reviewMembershipApplication(
  client: SupabaseClient,
  access: AdminAccess,
  applicationId: string,
  decision: "approved" | "rejected",
  notes?: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi("membership-applications/review", {
      method: "POST",
      body: { applicationId, decision, notes },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "review application");

  const { data: app, error: fetchError } = await client
    .from("membership_applications")
    .select("*")
    .eq("id", applicationId)
    .single();

  if (fetchError) throw new Error(fetchError.message);

  const { error: updateError } = await client
    .from("membership_applications")
    .update({
      status: decision,
      notes,
      review_date: new Date().toISOString(),
      reviewer_id: access.userId ?? null,
    })
    .eq("id", applicationId);

  if (updateError) throw new Error(updateError.message);

  const application = app as MembershipApplicationRow;

  if (decision === "approved") {
    const applicationUserId = safeString(application.user_id, "");
    if (!applicationUserId) {
      throw new Error("Membership application is missing a user id.");
    }
    if (safeString(application.payment_status, "unpaid") !== "paid") {
      throw new Error("Only paid membership applications can be approved.");
    }
    const partnerId = await resolveClubFootballPartnerId(client, clubId);
    const { data: seededMembership, error: seedError } = await client.rpc(
      "apply_membership_points",
      {
        p_user_id: applicationUserId,
        p_partner_id: partnerId,
        p_points: 0,
        p_chapter: application.metadata?.chapter || "Central",
      },
    );

    if (seedError) throw new Error(seedError.message);

    const { data: updatedMembership, error: membershipUpdateError } = await client
      .from("fan_memberships")
      .update({
        tier: application.tier,
        status: "active",
        club_id: clubId,
        chapter: application.metadata?.chapter || "Central",
      })
      .eq("user_id", applicationUserId)
      .eq("partner_id", partnerId)
      .select("id")
      .maybeSingle();

    if (membershipUpdateError) throw new Error(membershipUpdateError.message);
    if (!safeString(updatedMembership?.id) && !safeString(seededMembership?.id)) {
      throw new Error("Membership approval did not materialize a supporter membership row.");
    }
  }
}
