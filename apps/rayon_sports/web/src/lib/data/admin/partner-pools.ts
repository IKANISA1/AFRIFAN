/**
 * Admin partner WDW pools — partner-funded football prediction pool operations.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

export type AdminPartnerPoolOutcome = "home_win" | "draw" | "away_win";

export interface AdminPartnerPredictionPoolEntry {
  id: string;
  selectedOutcome: AdminPartnerPoolOutcome;
  eligibilityStatus: string;
  status: string;
  payoutFet: number;
  refundedFet: number;
  joinedAt: string;
}

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
  eligibilityMode: "open_to_all" | "partner_earn_required" | "initiative_earn_required";
  status: string;
  lockAt: string;
  totalEntries: number;
  totalFanEntryFet: number;
  viewerEntry: AdminPartnerPredictionPoolEntry | null;
  settlement: AdminPartnerPredictionPoolSettlement | null;
}

export interface AdminPartnerPredictionPoolInput {
  partnerId: string;
  fixtureId: string;
  title: string;
  partnerStakeFet: number;
  fanEntryFet: number;
  initiativeId?: string | null;
  eligibilityMode?: "open_to_all" | "partner_earn_required" | "initiative_earn_required";
  maxEntries?: number | null;
  idempotencyKey?: string | null;
  metadata?: Record<string, unknown>;
}

export interface AdminPartnerOption {
  id: string;
  name: string;
  slug: string;
  category: string;
}

function mapPartnerOption(row: Record<string, unknown>): AdminPartnerOption {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Partner"),
    slug: safeString(row.slug),
    category: safeString(row.category, "partner"),
  };
}

function mapEntry(value: unknown): AdminPartnerPredictionPoolEntry | null {
  if (value == null || typeof value !== "object") {
    return null;
  }

  const row = value as Record<string, unknown>;
  const selectedOutcome = safeString(row.selected_outcome) as AdminPartnerPoolOutcome;

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    selectedOutcome,
    eligibilityStatus: safeString(row.eligibility_status, "pending"),
    status: safeString(row.status, "active"),
    payoutFet: safeNumber(row.payout_fet, 0),
    refundedFet: safeNumber(row.refunded_fet, 0),
    joinedAt: safeString(row.joined_at),
  };
}

function mapSettlement(value: unknown): AdminPartnerPredictionPoolSettlement | null {
  if (value == null || typeof value !== "object") {
    return null;
  }

  const row = value as Record<string, unknown>;
  const officialOutcome = safeString(row.official_outcome) as AdminPartnerPoolOutcome;

  return {
    officialOutcome: officialOutcome || null,
    logicalWinners: safeNumber(row.logical_winners, 0),
    eligibleWinners: safeNumber(row.eligible_winners, 0),
    ineligibleWinners: safeNumber(row.ineligible_winners, 0),
    totalPaidFet: safeNumber(row.total_paid_fet, 0),
    totalRefundedFet: safeNumber(row.total_refunded_fet, 0),
    unawardedPartnerFet: safeNumber(row.unawarded_partner_fet, 0),
    settlementMode: safeString(row.settlement_mode),
    settledAt: safeString(row.settled_at),
  };
}

function mapPool(row: Record<string, unknown>): AdminPartnerPredictionPool {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: safeNumber(row.club_id, 0),
    partnerId: safeString(row.partner_id),
    partnerName: safeString(row.partner_name, "Partner"),
    partnerSlug: safeString(row.partner_slug),
    initiativeId: safeString(row.initiative_id) || null,
    fixtureId: safeString(row.fixture_id),
    title: safeString(row.title, "Partner WDW pool"),
    predictionKind: "wdw",
    partnerStakeFet: safeNumber(row.partner_stake_fet, 0),
    fanEntryFet: safeNumber(row.fan_entry_fet, 0),
    eligibilityMode: (
      safeString(row.eligibility_mode, "open_to_all")
    ) as AdminPartnerPredictionPool["eligibilityMode"],
    status: safeString(row.status, "open"),
    lockAt: safeString(row.lock_at),
    totalEntries: safeNumber(row.total_entries, 0),
    totalFanEntryFet: safeNumber(row.total_fan_entry_fet, 0),
    viewerEntry: mapEntry(row.viewer_entry),
    settlement: mapSettlement(row.settlement),
  };
}

function normalizeRpcArray(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(
    (row): row is Record<string, unknown> => row != null && typeof row === "object",
  );
}

export async function getAdminPartnerOptions(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminPartnerOption[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminPartnerOption[]>("partner-options");
  }

  const { data, error } = await client
    .from("partners")
    .select("id,name,slug,category")
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .order("name", { ascending: true });

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) => mapPartnerOption(row as Record<string, unknown>))
    : [];
}

export async function getAdminPartnerPredictionPools(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminPartnerPredictionPool[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminPartnerPredictionPool[]>("partner-prediction-pools");
  }

  const clubId = requireAdminClubId(access, "load partner prediction pools");
  const { data, error } = await client.rpc("partner_prediction_pool_feed", {
    p_club_id: clubId,
    p_statuses: ["open", "locked", "settled", "void"],
    p_limit: 100,
    p_offset: 0,
  });

  if (error) {
    throw new Error(error.message);
  }

  return normalizeRpcArray(data).map(mapPool);
}

export async function saveAdminPartnerPredictionPool(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminPartnerPredictionPoolInput,
): Promise<AdminPartnerPredictionPool> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminPartnerPredictionPool>("partner-prediction-pools", {
      method: "POST",
      body: input,
    });
  }

  const clubId = requireAdminClubId(access, "create partner prediction pools");
  const { data, error } = await client.rpc("partner_prediction_pool_create", {
    p_partner_id: input.partnerId,
    p_fixture_id: input.fixtureId,
    p_title: input.title,
    p_partner_stake_fet: Math.max(0, safeNumber(input.partnerStakeFet, 0)),
    p_fan_entry_fet: Math.max(0, safeNumber(input.fanEntryFet, 0)),
    p_initiative_id: input.initiativeId ?? null,
    p_eligibility_mode: input.eligibilityMode ?? "open_to_all",
    p_max_entries: input.maxEntries ?? null,
    p_idempotency_key: input.idempotencyKey ?? null,
    p_metadata: input.metadata ?? {},
    p_club_id: clubId,
  });

  if (error) {
    throw new Error(error.message);
  }

  return mapPool(data as Record<string, unknown>);
}

export async function settleAdminPartnerPredictionPool(
  client: SupabaseClient,
  _access: AdminAccess,
  poolId: string,
): Promise<AdminPartnerPredictionPool> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminPartnerPredictionPool>("partner-prediction-pool-settlement", {
      method: "POST",
      body: { poolId },
    });
  }

  const { data, error } = await client.rpc("partner_prediction_pool_settle", {
    p_pool_id: poolId,
  });

  if (error) {
    throw new Error(error.message);
  }

  return mapPool(data as Record<string, unknown>);
}
