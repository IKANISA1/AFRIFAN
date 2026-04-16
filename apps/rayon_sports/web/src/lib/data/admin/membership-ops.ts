/**
 * Admin membership operations — supporter registry and application review.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminMembershipApplication, AdminSupporter } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

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

  return (data ?? []).map((row: any) => ({
    id: toIdString(row.id, ""),
    userId: row.user_id,
    displayName: safeString(row.display_name, "Anonymous Supporter"),
    phone: safeString(row.profiles?.phone, null),
    tier: row.tier,
    status: row.status || "active",
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
    .select(`
      *,
      profiles:user_id (full_name, phone)
    `)
    .eq("club_id", clubId)
    .order("application_date", { ascending: false });

  if (error) throw new Error(error.message);

  return (data ?? []).map((row: any) => ({
    ...row,
    id: toIdString(row.id, ""),
    applicationDate: safeString(row.application_date, row.created_at),
    userName: safeString(row.profiles?.full_name, "Unknown"),
    userPhone: safeString(row.profiles?.phone, "—"),
  }));
}

export async function reviewMembershipApplication(
  client: SupabaseClient,
  access: AdminAccess,
  applicationId: string,
  decision: "approved" | "rejected",
  notes?: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("membership-applications/review", {
      method: "POST",
      body: { applicationId, decision, notes },
    });
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
      reviewer_id: access.userId,
    })
    .eq("id", applicationId);

  if (updateError) throw new Error(updateError.message);

  if (decision === "approved") {
    // Upsert or update fan_membership
    const { error: membershipError } = await client.rpc("apply_membership_points", {
      p_user_id: app.user_id,
      p_partner_id: null, // Should be resolved if needed, but rpc handles central
      p_points: 0,
      p_chapter: app.metadata?.chapter || "Central",
    });
    
    // Also explicitly set the tier
    await client
      .from("fan_memberships")
      .update({ tier: app.tier, status: "active" })
      .eq("user_id", app.user_id)
      .eq("club_id", clubId);
  }
}
