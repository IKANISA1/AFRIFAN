/**
 * Admin partner WDW pools — strict, club-scoped operations for fixed-outcome
 * partner-funded prediction pools.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

const MAX_PARTNER_OPTIONS = 500;
const MAX_PARTNER_POOLS = 100;
const MAX_FET_VALUE = 1_000_000_000;

const poolOutcomes = ["home_win", "draw", "away_win"] as const;
const eligibilityModes = [
  "open_to_all",
  "partner_earn_required",
  "initiative_earn_required",
] as const;
const poolStatuses = [
  "open",
  "locked",
  "settled",
  "void",
  "cancelled",
] as const;

export type AdminPartnerPoolOutcome = (typeof poolOutcomes)[number];
export type AdminPartnerPoolEligibilityMode = (typeof eligibilityModes)[number];
export type AdminPartnerPoolStatus = (typeof poolStatuses)[number];

export interface AdminPartnerPredictionPoolSettlement {
  officialOutcome: AdminPartnerPoolOutcome | null;
  logicalWinners: number;
  eligibleWinners: number;
  ineligibleWinners: number;
  totalPaidFet: number;
  totalRefundedFet: number;
  unawardedPartnerFet: number;
  settlementMode: string;
  settledAt: string;
}

export interface AdminPartnerPredictionPool {
  id: string;
  clubId: number;
  partnerId: string;
  partnerName: string;
  partnerSlug: string;
  initiativeId: string | null;
  fixtureId: string;
  title: string;
  predictionKind: "wdw";
  partnerStakeFet: number;
  fanEntryFet: number;
  eligibilityMode: AdminPartnerPoolEligibilityMode;
  status: AdminPartnerPoolStatus;
  lockAt: string;
  totalEntries: number;
  totalFanEntryFet: number;
  settlement: AdminPartnerPredictionPoolSettlement | null;
}

export interface AdminPartnerPredictionPoolInput {
  partnerId: string;
  fixtureId: string;
  title: string;
  partnerStakeFet: number;
  fanEntryFet: number;
  initiativeId?: string | null;
  eligibilityMode?: AdminPartnerPoolEligibilityMode;
  maxEntries?: number | null;
  idempotencyKey?: string | null;
}

export interface AdminPartnerOption {
  id: string;
  name: string;
  slug: string;
  category: string;
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength) ?? undefined;
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

function enumValue<T extends readonly string[]>(
  value: unknown,
  values: T,
): T[number] | null {
  const text = boundedText(value, 80);
  return text != null && values.includes(text) ? (text as T[number]) : null;
}

function normalizeSettlement(
  value: unknown,
): AdminPartnerPredictionPoolSettlement | null | undefined {
  if (value == null) return null;
  if (typeof value !== "object" || Array.isArray(value)) return undefined;
  const row = value as Record<string, unknown>;
  const rawOutcome = row.officialOutcome ?? row.official_outcome;
  const officialOutcome =
    rawOutcome == null ? null : enumValue(rawOutcome, poolOutcomes);
  const logicalWinners = boundedInteger(
    row.logicalWinners ?? row.logical_winners,
    0,
    MAX_FET_VALUE,
  );
  const eligibleWinners = boundedInteger(
    row.eligibleWinners ?? row.eligible_winners,
    0,
    MAX_FET_VALUE,
  );
  const ineligibleWinners = boundedInteger(
    row.ineligibleWinners ?? row.ineligible_winners,
    0,
    MAX_FET_VALUE,
  );
  const totalPaidFet = boundedInteger(
    row.totalPaidFet ?? row.total_paid_fet,
    0,
    MAX_FET_VALUE,
  );
  const totalRefundedFet = boundedInteger(
    row.totalRefundedFet ?? row.total_refunded_fet,
    0,
    MAX_FET_VALUE,
  );
  const unawardedPartnerFet = boundedInteger(
    row.unawardedPartnerFet ?? row.unawarded_partner_fet,
    0,
    MAX_FET_VALUE,
  );
  const settlementMode = boundedText(
    row.settlementMode ?? row.settlement_mode,
    80,
  );
  const settledAt = boundedDate(row.settledAt ?? row.settled_at);
  if (
    (rawOutcome != null && officialOutcome == null) ||
    logicalWinners == null ||
    eligibleWinners == null ||
    ineligibleWinners == null ||
    totalPaidFet == null ||
    totalRefundedFet == null ||
    unawardedPartnerFet == null ||
    settlementMode == null ||
    settledAt == null
  ) {
    return undefined;
  }
  return {
    officialOutcome,
    logicalWinners,
    eligibleWinners,
    ineligibleWinners,
    totalPaidFet,
    totalRefundedFet,
    unawardedPartnerFet,
    settlementMode,
    settledAt,
  };
}

export function normalizeAdminPartnerOption(
  value: unknown,
): AdminPartnerOption | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const name = boundedText(row.name, 160);
  const slug = boundedText(row.slug, 160);
  const category = boundedText(row.category, 80);
  return id != null && name != null && slug != null && category != null
    ? { id, name, slug, category }
    : null;
}

export function normalizeAdminPartnerOptions(value: unknown) {
  if (!Array.isArray(value)) return [] as AdminPartnerOption[];
  const options: AdminPartnerOption[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_PARTNER_OPTIONS)) {
    const option = normalizeAdminPartnerOption(entry);
    if (option != null && !seen.has(option.id)) {
      options.push(option);
      seen.add(option.id);
    }
  }
  return options;
}

export function normalizeAdminPartnerPredictionPool(
  value: unknown,
): AdminPartnerPredictionPool | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const clubId = boundedInteger(
    row.clubId ?? row.club_id,
    1,
    Number.MAX_SAFE_INTEGER,
  );
  const partnerId = boundedText(row.partnerId ?? row.partner_id, 128);
  const partnerName = boundedText(row.partnerName ?? row.partner_name, 160);
  const partnerSlug = boundedText(row.partnerSlug ?? row.partner_slug, 160);
  const initiativeId = nullableText(row.initiativeId ?? row.initiative_id, 128);
  const fixtureId = boundedText(row.fixtureId ?? row.fixture_id, 128);
  const title = boundedText(row.title, 160);
  const predictionKind = boundedText(
    row.predictionKind ?? row.prediction_kind,
    32,
  );
  const partnerStakeFet = boundedInteger(
    row.partnerStakeFet ?? row.partner_stake_fet,
    1,
    MAX_FET_VALUE,
  );
  const fanEntryFet = boundedInteger(
    row.fanEntryFet ?? row.fan_entry_fet,
    1,
    MAX_FET_VALUE,
  );
  const eligibilityMode = enumValue(
    row.eligibilityMode ?? row.eligibility_mode,
    eligibilityModes,
  );
  const status = enumValue(row.status, poolStatuses);
  const lockAt = boundedDate(row.lockAt ?? row.lock_at);
  const totalEntries = boundedInteger(
    row.totalEntries ?? row.total_entries,
    0,
    MAX_FET_VALUE,
  );
  const totalFanEntryFet = boundedInteger(
    row.totalFanEntryFet ?? row.total_fan_entry_fet,
    0,
    MAX_FET_VALUE,
  );
  const settlement = normalizeSettlement(row.settlement);
  if (
    id == null ||
    clubId == null ||
    partnerId == null ||
    partnerName == null ||
    partnerSlug == null ||
    initiativeId === undefined ||
    fixtureId == null ||
    title == null ||
    predictionKind !== "wdw" ||
    partnerStakeFet == null ||
    fanEntryFet == null ||
    eligibilityMode == null ||
    status == null ||
    lockAt == null ||
    totalEntries == null ||
    totalFanEntryFet == null ||
    settlement === undefined
  ) {
    return null;
  }
  return {
    id,
    clubId,
    partnerId,
    partnerName,
    partnerSlug,
    initiativeId,
    fixtureId,
    title,
    predictionKind: "wdw",
    partnerStakeFet,
    fanEntryFet,
    eligibilityMode,
    status,
    lockAt,
    totalEntries,
    totalFanEntryFet,
    settlement,
  };
}

export function normalizeAdminPartnerPredictionPools(value: unknown) {
  if (!Array.isArray(value)) return [] as AdminPartnerPredictionPool[];
  const pools: AdminPartnerPredictionPool[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_PARTNER_POOLS)) {
    const pool = normalizeAdminPartnerPredictionPool(entry);
    if (pool != null && !seen.has(pool.id)) {
      pools.push(pool);
      seen.add(pool.id);
    }
  }
  return pools;
}

function requireText(value: unknown, label: string, maxLength: number) {
  const text = boundedText(value, maxLength);
  if (text == null) {
    throw new Error(
      `${label} is required and must be within ${maxLength} characters.`,
    );
  }
  return text;
}

function requireInteger(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
) {
  const number = boundedInteger(value, minimum, maximum);
  if (number == null) {
    throw new Error(
      `${label} must be a whole number from ${minimum} to ${maximum}.`,
    );
  }
  return number;
}

export async function getAdminPartnerOptions(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminPartnerOption[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("partner-options");
    return normalizeAdminPartnerOptions(result);
  }
  const { data, error } = await client
    .from("partners")
    .select("id,name,slug,category")
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .order("name", { ascending: true })
    .limit(MAX_PARTNER_OPTIONS);
  if (error) throw new Error(error.message);
  return normalizeAdminPartnerOptions(data);
}

export async function getAdminPartnerPredictionPools(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminPartnerPredictionPool[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("partner-prediction-pools");
    return normalizeAdminPartnerPredictionPools(result);
  }
  const clubId = requireAdminClubId(access, "load partner prediction pools");
  const { data, error } = await client.rpc("partner_prediction_pool_feed", {
    p_club_id: clubId,
    p_statuses: [...poolStatuses],
    p_limit: MAX_PARTNER_POOLS,
    p_offset: 0,
  });
  if (error) throw new Error(error.message);
  return normalizeAdminPartnerPredictionPools(data);
}

export async function saveAdminPartnerPredictionPool(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminPartnerPredictionPoolInput,
): Promise<AdminPartnerPredictionPool> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("partner-prediction-pools", {
      method: "POST",
      body: input,
    });
    const pool = normalizeAdminPartnerPredictionPool(result);
    if (pool == null) {
      throw new Error("The saved partner pool could not be confirmed.");
    }
    return pool;
  }
  const clubId = requireAdminClubId(access, "create partner prediction pools");
  const partnerId = requireText(input.partnerId, "Partner", 128);
  const fixtureId = requireText(input.fixtureId, "Fixture", 128);
  const title = requireText(input.title, "Pool title", 160);
  const partnerStakeFet = requireInteger(
    input.partnerStakeFet,
    "Partner-funded FET",
    1,
    MAX_FET_VALUE,
  );
  const fanEntryFet = requireInteger(
    input.fanEntryFet,
    "Fan entry FET",
    1,
    MAX_FET_VALUE,
  );
  const initiativeId = nullableText(input.initiativeId, 128);
  const eligibilityMode = input.eligibilityMode ?? "open_to_all";
  const maxEntries =
    input.maxEntries == null
      ? null
      : requireInteger(input.maxEntries, "Entry limit", 1, MAX_FET_VALUE);
  const idempotencyKey = nullableText(input.idempotencyKey, 240);
  if (initiativeId === undefined || idempotencyKey === undefined) {
    throw new Error("Partner-pool identifiers are invalid.");
  }
  if (!eligibilityModes.includes(eligibilityMode)) {
    throw new Error("Choose a supported eligibility mode.");
  }
  if (eligibilityMode === "initiative_earn_required" && initiativeId == null) {
    throw new Error("Initiative eligibility requires an initiative.");
  }
  const { data, error } = await client.rpc("partner_prediction_pool_create", {
    p_partner_id: partnerId,
    p_fixture_id: fixtureId,
    p_title: title,
    p_partner_stake_fet: partnerStakeFet,
    p_fan_entry_fet: fanEntryFet,
    p_initiative_id: initiativeId,
    p_eligibility_mode: eligibilityMode,
    p_max_entries: maxEntries,
    p_idempotency_key: idempotencyKey,
    p_metadata: {},
    p_club_id: clubId,
  });
  if (error) throw new Error(error.message);
  const pool = normalizeAdminPartnerPredictionPool(data);
  if (pool == null) {
    throw new Error("The saved partner pool could not be confirmed.");
  }
  return pool;
}

export async function settleAdminPartnerPredictionPool(
  client: SupabaseClient,
  _access: AdminAccess,
  poolId: string,
): Promise<AdminPartnerPredictionPool> {
  const id = requireText(poolId, "Partner pool", 128);
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>(
      "partner-prediction-pool-settlement",
      { method: "POST", body: { poolId: id } },
    );
    const pool = normalizeAdminPartnerPredictionPool(result);
    if (pool == null) {
      throw new Error("The partner-pool settlement could not be confirmed.");
    }
    return pool;
  }
  const { data, error } = await client.rpc("partner_prediction_pool_settle", {
    p_pool_id: id,
  });
  if (error) throw new Error(error.message);
  const pool = normalizeAdminPartnerPredictionPool(data);
  if (pool == null) {
    throw new Error("The partner-pool settlement could not be confirmed.");
  }
  return pool;
}
