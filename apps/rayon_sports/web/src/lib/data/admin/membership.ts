/**
 * Admin membership — tier packages CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess, AdminMembershipPackage } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { membershipTable, mutateRecordWithVariants } from "./helpers";

function mapAdminMembershipPackage(row: Record<string, unknown>): AdminMembershipPackage {
  const title = safeString(row.title, "Membership tier");
  const description = safeString(row.description, "Priority access and supporter benefits.");
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    tier:
      safeString(row.tier).toLowerCase() === "platinum" ? "platinum"
        : safeString(row.tier).toLowerCase() === "gold" ? "gold"
        : safeString(row.tier).toLowerCase() === "bronze" ? "bronze"
        : "fan",
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
  };
}

export async function getAdminMembershipPackages(client: SupabaseClient): Promise<AdminMembershipPackage[]> {
  const scoped = await client.from(membershipTable).select("*").eq("club_id", rayonClub.numericId).order("sort_order", { ascending: true });
  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row) => mapAdminMembershipPackage(row as Record<string, unknown>));
  }
  const fallback = await client.from(membershipTable).select("*").order("sort_order", { ascending: true });
  if (fallback.error) throw new Error(fallback.error.message);
  return Array.isArray(fallback.data) && fallback.data.length > 0
    ? fallback.data.map((row) => mapAdminMembershipPackage(row as Record<string, unknown>))
    : [];
}

export async function saveAdminMembershipPackage(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; tier: AdminMembershipPackage["tier"]; title: string; description: string; annualPrice: number; sortOrder: number; perks: string[]; isActive: boolean },
) {
  const basePayload = {
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    tier: input.tier, title: input.title.trim(), description: input.description.trim(),
    sort_order: safeNumber(input.sortOrder, 0), is_active: input.isActive,
  };
  return mutateRecordWithVariants(client, membershipTable, input.id, [
    { ...basePayload, annual_price: safeNumber(input.annualPrice, 0), price: safeNumber(input.annualPrice, 0), benefits: input.perks },
    { ...basePayload, annual_price: safeNumber(input.annualPrice, 0), benefits: input.perks },
    { ...basePayload, price: safeNumber(input.annualPrice, 0), benefits: input.perks },
    { ...basePayload, annual_price: safeNumber(input.annualPrice, 0) },
  ]);
}

export async function deleteAdminMembershipPackage(client: SupabaseClient, packageId: string) {
  const { error } = await client.from(membershipTable).delete().eq("id", packageId);
  if (error) throw new Error(error.message);
}
