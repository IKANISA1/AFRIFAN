/**
 * Admin membership — tier packages CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminMembershipPackage,
  MembershipTierSlug,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  membershipTable,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

function mapAdminMembershipPackage(row: Record<string, unknown>): AdminMembershipPackage {
  const title = safeString(row.title, "Membership tier");
  const description = safeString(row.description, "Priority access and supporter benefits.");
  const tier = normalizeMembershipTier(safeString(row.tier));
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    tier,
    title,
    description,
    sortOrder: safeNumber(row.sort_order, 0),
    annualPrice: safeNumber(row.annual_price, safeNumber(row.price, 0)),
    perks: Array.isArray(row.benefits)
      ? row.benefits.map((entry) => safeString(entry)).filter(Boolean)
      : Array.isArray(row.perks)
        ? row.perks.map((entry) => safeString(entry)).filter(Boolean)
        : description.split(/[.;]/).map((item) => item.trim()).filter((item) => item.length > 2).slice(0, 4),
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    updatedAt: safeString(row.updated_at, new Date(0).toISOString()),
  };
}

function normalizeMembershipTier(value: string): MembershipTierSlug {
  switch (value.trim().toLowerCase()) {
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

export async function getAdminMembershipPackages(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminMembershipPackage[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminMembershipPackage[]>("membership");
  }
  const clubId = requireAdminClubId(access, "load membership packages");
  const { data, error } = await client
    .from(membershipTable)
    .select("*")
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row) => mapAdminMembershipPackage(row as Record<string, unknown>))
    : [];
}

export async function saveAdminMembershipPackage(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; expectedUpdatedAt?: string | null; tier: AdminMembershipPackage["tier"]; title: string; description: string; annualPrice: number; sortOrder: number; perks: string[]; isActive: boolean },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("membership", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save membership packages");
  const basePayload = {
    club_id: clubId,
    tier: input.tier, title: input.title.trim(), description: input.description.trim(),
    sort_order: safeNumber(input.sortOrder, 0), is_active: input.isActive,
  };
  return mutateRecordWithVariantsIfUnchanged(client, membershipTable, input.id, input.expectedUpdatedAt, [
    { ...basePayload, annual_price: safeNumber(input.annualPrice, 0), price: safeNumber(input.annualPrice, 0), benefits: input.perks },
    { ...basePayload, annual_price: safeNumber(input.annualPrice, 0), benefits: input.perks },
    { ...basePayload, price: safeNumber(input.annualPrice, 0), benefits: input.perks },
    { ...basePayload, annual_price: safeNumber(input.annualPrice, 0) },
  ], { club_id: clubId });
}

export async function deleteAdminMembershipPackage(
  client: SupabaseClient,
  access: AdminAccess,
  packageId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("membership", {
      method: "DELETE",
      query: { id: packageId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete membership packages");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    membershipTable,
    packageId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_membership_tier",
      source: "admin_membership",
    },
  );
}
