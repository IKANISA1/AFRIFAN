/**
 * Admin membership — tier packages CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminMembershipPackage,
  MembershipTierSlug,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  AdminMutationAuthorizationError,
  AdminMutationConflictError,
  membershipTable,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";
import { getAdminPartnerOptions } from "./partner-pools";

const MAX_MEMBERSHIP_PACKAGES = 100;
// membership_tiers is a SELECT-only security-invoker view. Staff writes target
// its canonical package table so SQL can enforce role, scope and step-up.
const membershipWriteTable = "membership_packages";
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export class AdminMembershipValidationError extends Error {
  readonly code = "ADMIN_MEMBERSHIP_INPUT_INVALID";
  constructor(message = "Review the membership package fields before retrying.") { super(message); this.name = "AdminMembershipValidationError"; }
}
export function canConfigureAdminMembership(access: AdminAccess) {
  return access.hasAccess && access.isAuthenticated && !!access.userId && !!access.clubId &&
    (access.isSuperAdmin || (access.role === "club_admin" && access.availableClubIds.includes(access.clubId)));
}
function requireConfigurationAccess(access: AdminAccess) {
  if (!canConfigureAdminMembership(access)) throw new AdminMutationAuthorizationError("Current platform or selected club administrator access is required.");
  return requireAdminClubId(access, "configure membership packages");
}
export interface AdminMembershipPackageInput {
  id?: string | null; creationId?: string | null; expectedUpdatedAt?: string | null;
  partnerId: string; tier: AdminMembershipPackage["tier"]; title: string; subtitle: string; description: string;
  annualPrice: number; sortOrder: number; perks: string[]; isActive: boolean;
}
function normalizePackageInput(value: AdminMembershipPackageInput): AdminMembershipPackageInput {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).some(key =>
    !["id", "creationId", "expectedUpdatedAt", "partnerId", "tier", "title", "subtitle", "description", "annualPrice", "sortOrder", "perks", "isActive"].includes(key))) throw new AdminMembershipValidationError();
  const title = boundedText(value.title, 160); const subtitle = boundedText(value.subtitle, 240); const description = boundedText(value.description, 2_000);
  const tier = normalizeMembershipTier(value.tier);
  if (!title || !subtitle || !description || !tier || !uuidPattern.test(value.partnerId) ||
    boundedInteger(value.annualPrice, 1, 1_000_000_000) == null || boundedInteger(value.sortOrder, 0, 1_000_000) == null ||
    !Array.isArray(value.perks) || value.perks.length > 20 || value.perks.some(perk => boundedText(perk, 240) == null) ||
    typeof value.isActive !== "boolean" || (value.id ? !uuidPattern.test(value.id) || boundedDate(value.expectedUpdatedAt) == null : !value.creationId || !uuidPattern.test(value.creationId))) throw new AdminMembershipValidationError();
  return { ...value, id: value.id?.toLowerCase() ?? null, creationId: value.creationId?.toLowerCase() ?? null,
    partnerId: value.partnerId.toLowerCase(), title, subtitle, description, tier, perks: value.perks.map(perk => perk.trim()) };
}

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
  const rawPartner = row.partner_id ?? row.partnerId;
  const rawSubtitle = row.subtitle;
  const partnerId = rawPartner == null ? null : boundedText(rawPartner, 128);
  const subtitle = rawSubtitle == null ? null : boundedText(rawSubtitle, 240);
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
    (rawPartner != null && (partnerId == null || !uuidPattern.test(partnerId))) ||
    (rawSubtitle != null && subtitle == null) ||
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
    ...(rawPartner != null ? { partnerId } : {}),
    ...(rawSubtitle != null ? { subtitle: subtitle! } : {}),
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
  value: AdminMembershipPackageInput,
) {
  const clubId = requireConfigurationAccess(access);
  const input = normalizePackageInput(value);
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("membership", {
      method: "POST",
      body: input,
    });
  }
  const partners = await getAdminPartnerOptions(client, access);
  if (!partners.some(partner => partner.id === input.partnerId)) throw new AdminMembershipValidationError("Choose an active partner configured for the selected club.");
  const basePayload = {
    club_id: clubId,
    partner_id: input.partnerId, tier: input.tier, title: input.title, subtitle: input.subtitle, description: input.description,
    sort_order: input.sortOrder, is_active: input.isActive,
    annual_price: input.annualPrice, price: input.annualPrice, benefits: input.perks,
  };
  if (input.id) return mutateRecordWithVariantsIfUnchanged(client, membershipWriteTable, input.id, input.expectedUpdatedAt, [basePayload], { club_id: clubId });
  // One retained creation reference survives a lost response. Existing rows are
  // recovered only when every submitted field and the current club still match.
  const creationId = input.creationId!;
  async function recoverCreation() {
    const found = await client.from(membershipWriteTable).select("*").eq("club_id", clubId).eq("id", creationId).maybeSingle();
    if (found.error) throw new Error(found.error.message);
    if (found.data == null) return null;
    if (Object.entries(basePayload).some(([key, expected]) => JSON.stringify(found.data[key]) !== JSON.stringify(expected))) throw new AdminMutationConflictError("The retained creation reference belongs to a different package. Review its current fields before continuing.");
    return creationId;
  }
  const existing = await recoverCreation(); if (existing) return existing;
  const inserted = await client.from(membershipWriteTable).insert({ id: creationId, ...basePayload }).select("id").single();
  if (inserted.error) { const recovered = await recoverCreation(); if (recovered) return recovered; throw new Error(inserted.error.message); }
  if (inserted.data?.id !== creationId) throw new Error("The original membership creation reference was not confirmed.");
  return creationId;
}

export async function deleteAdminMembershipPackage(
  client: SupabaseClient,
  access: AdminAccess,
  packageId: string,
  expectedUpdatedAt: string,
) {
  const clubId = requireConfigurationAccess(access);
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("membership", {
      method: "DELETE",
      query: { id: packageId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    membershipWriteTable,
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
