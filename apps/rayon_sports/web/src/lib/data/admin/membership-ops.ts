/**
 * Admin membership operations — supporter registry.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminSupporter,
  MembershipTierSlug,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  requireAdminClubId,
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

const MAX_SUPPORTERS = 500;

function boundedText(
  value: unknown,
  maxLength: number,
  allowEmpty = false,
) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (text.length > maxLength || (!allowEmpty && text.length === 0)) return null;
  return text;
}

function boundedInteger(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    value >= minimum &&
    value <= maximum
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength);
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

function normalizeSupporterStatus(value: unknown): AdminSupporter["status"] | null {
  return value === "active" ||
    value === "pending" ||
    value === "suspended" ||
    value === "expired"
    ? value
    : null;
}

function mapAdminSupporter(
  row: Record<string, unknown>,
): AdminSupporter | null {
  const id = boundedText(row.id, 128);
  const userId = boundedText(row.userId ?? row.user_id, 128);
  const displayName = boundedText(
    row.displayName ?? row.display_name,
    160,
  );
  const phone = nullableText(
    row.phone ??
      ((row.profiles as { phone?: unknown } | null | undefined)?.phone ?? null),
    32,
  );
  const tier = normalizeMembershipTier(row.tier);
  const status = normalizeSupporterStatus(row.status);
  const points = boundedInteger(row.points, 0, 1_000_000_000);
  const chapter = boundedText(row.chapter, 120);
  const membershipNumber = boundedText(
    row.membershipNumber ?? row.membership_number,
    80,
  );
  const joinedAt = boundedDate(row.joinedAt ?? row.joined_at);
  if (
    id == null ||
    userId == null ||
    displayName == null ||
    phone === undefined ||
    tier == null ||
    status == null ||
    points == null ||
    chapter == null ||
    membershipNumber == null ||
    joinedAt == null
  ) {
    return null;
  }
  return {
    id,
    userId,
    displayName,
    phone,
    tier,
    status,
    points,
    chapter,
    membershipNumber,
    joinedAt,
  };
}

export function normalizeAdminSupporters(value: unknown): AdminSupporter[] {
  if (!Array.isArray(value)) return [];
  const supporters: AdminSupporter[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_SUPPORTERS)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const supporter = mapAdminSupporter(entry as Record<string, unknown>);
    if (supporter != null && !seen.has(supporter.id)) {
      supporters.push(supporter);
      seen.add(supporter.id);
    }
  }
  return supporters;
}

export async function getAdminSupporterRegistry(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSupporter[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("membership-supporters", {
      signal: options.signal,
    });
    return normalizeAdminSupporters(result);
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
    .order("joined_at", { ascending: false })
    .limit(MAX_SUPPORTERS);

  if (error) throw new Error(error.message);

  const rows = (data ?? []) as SupporterRegistryRow[];

  return normalizeAdminSupporters(rows);
}
