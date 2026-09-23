/**
 * Admin membership — tier packages CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminMembershipPackage,
  MembershipTierSlug,
} from "@/lib/types";
import { safeNumber } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  membershipTable,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const MAX_MEMBERSHIP_PACKAGES = 100;

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function boundedInteger(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    value >= minimum &&
    value <= maximum
    ? value
    : null;
}

function boundedAmount(value: unknown, maximum: number) {
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value >= 0 &&
    value <= maximum
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function mapAdminMembershipPackage(
  row: Record<string, unknown>,
): AdminMembershipPackage | null {
  const id = boundedText(row.id, 128);
  const clubValue = row.club_id ?? row.clubId;
  const clubId =
    clubValue == null ? null : boundedInteger(clubValue, 1, 2_147_483_647);
  const tier = normalizeMembershipTier(row.tier);
  const title = boundedText(row.title, 160);
  const description = boundedText(row.description, 2_000);
  const sortOrder = boundedInteger(
    row.sort_order ?? row.sortOrder,
    0,
    1_000_000,
  );
  const annualPrice = boundedAmount(
    row.annual_price ?? row.annualPrice ?? row.price,
    1_000_000_000,
  );
  const rawPerks = row.benefits ?? row.perks;
  const perks =
    Array.isArray(rawPerks) && rawPerks.length <= 20
      ? rawPerks.map((entry) => boundedText(entry, 240))
      : null;
  const isActive = row.is_active ?? row.isActive;
  const createdAt = boundedDate(row.created_at ?? row.createdAt);
  const updatedAt = boundedDate(row.updated_at ?? row.updatedAt);

  if (
    id == null ||
    (clubValue != null && clubId == null) ||
    tier == null ||
    title == null ||
    description == null ||
    sortOrder == null ||
    annualPrice == null ||
    perks == null ||
    perks.some((item) => item == null) ||
    typeof isActive !== "boolean" ||
    createdAt == null ||
    updatedAt == null
  ) {
    return null;
  }

  return {
    id,
    clubId,
    tier,
    title,
    description,
    sortOrder,
    annualPrice,
    perks: perks as string[],
    isActive,
    createdAt,
    updatedAt,
  };
}

function normalizeMembershipTier(value: unknown): MembershipTierSlug | null {
  if (typeof value !== "string") return null;
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
      return null;
  }
}

export function normalizeAdminMembershipPackages(
  value: unknown,
): AdminMembershipPackage[] {
  if (!Array.isArray(value)) return [];
  const packages: AdminMembershipPackage[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_MEMBERSHIP_PACKAGES)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const membershipPackage = mapAdminMembershipPackage(
      entry as Record<string, unknown>,
    );
    if (membershipPackage != null && !seen.has(membershipPackage.id)) {
      packages.push(membershipPackage);
      seen.add(membershipPackage.id);
    }
  }
  return packages;
}

export async function getAdminMembershipPackages(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminMembershipPackage[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("membership", {
      signal: options.signal,
    });
    return normalizeAdminMembershipPackages(result);
  }
  const clubId = requireAdminClubId(access, "load membership packages");
  const { data, error } = await client
    .from(membershipTable)
    .select("*")
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true })
    .limit(MAX_MEMBERSHIP_PACKAGES);
  if (error) throw new Error(error.message);
  return normalizeAdminMembershipPackages(data);
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
