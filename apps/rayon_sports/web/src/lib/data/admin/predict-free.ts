import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requireAdminClubId } from "./helpers";
import { requestAdminApi } from "./http";
import { getAdminPartnerPredictionPools, normalizeAdminPartnerPredictionPool } from "./partner-pools";

type Economics = "free_v1" | "legacy_paid_v1" | null;
export interface AdminPredictFixture {
  id: string;
  poolId: string | null;
  competition: string;
  homeTeam: string;
  awayTeam: string;
  kickoffAt: string | null;
  fixtureStatus: string;
  status: "no_pool" | "open" | "locked" | "settled" | "refunded";
  homeScore: number | null;
  awayScore: number | null;
  stakeFet: number | null;
  entryCount: number;
  stakedFet: number;
  paidFet: number;
  winnerCount: number;
  resultConfirmed: boolean;
  economicsVersion: Economics;
}
export interface AdminFreePredictDashboard {
  enabled: boolean;
  fixtures: AdminPredictFixture[];
}
export class AdminPredictValidationError extends Error {}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fixtureStatuses = ["scheduled", "live", "finished", "postponed", "cancelled"];
const poolStatuses = ["no_pool", "open", "locked", "settled", "refunded"];
const count = (value: unknown): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
const nullableScore = (value: unknown): value is number | null =>
  value === null || (count(value) && value <= 100);
const text = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0 && value.length <= 240;
function object(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("The prediction response could not be confirmed.");
  }
  return value as Record<string, unknown>;
}

export function normalizeAdminFreePredictDashboard(value: unknown): AdminFreePredictDashboard {
  const row = object(value);
  const settings = object(row.settings);
  if (typeof settings.enabled !== "boolean" || settings.entry_fet !== 0 ||
      settings.welcome_fet !== 0 || settings.economics_version !== "free_v1" ||
      !Array.isArray(row.fixtures) || row.fixtures.length > 1000) {
    throw new Error("Free prediction settings could not be confirmed.");
  }
  const ids = new Set<string>();
  const pools = new Set<string>();
  const fixtures = row.fixtures.map((item): AdminPredictFixture => {
    const f = object(item);
    const version = f.economics_version;
    if (typeof f.id !== "string" || !uuid.test(f.id) || ids.has(f.id) ||
        !(f.pool_id === null || (typeof f.pool_id === "string" && uuid.test(f.pool_id) && !pools.has(f.pool_id))) ||
        !text(f.competition) || !text(f.home_team) || !text(f.away_team) ||
        !(f.kickoff_at === null || (typeof f.kickoff_at === "string" && f.kickoff_at.length <= 64 && Number.isFinite(Date.parse(f.kickoff_at)))) ||
        typeof f.fixture_status !== "string" || !fixtureStatuses.includes(f.fixture_status) ||
        typeof f.status !== "string" || !poolStatuses.includes(f.status) ||
        !nullableScore(f.home_score) || !nullableScore(f.away_score) ||
        !(f.stake_fet === null || count(f.stake_fet)) ||
        !count(f.entry_count) || !count(f.staked_fet) || !count(f.paid_fet) ||
        !count(f.winner_count) || f.winner_count > f.entry_count || typeof f.result_confirmed !== "boolean" ||
        !(version === null || version === "free_v1" || version === "legacy_paid_v1")) {
      throw new Error("The prediction fixture could not be confirmed.");
    }
    if (f.pool_id === null ? (version !== null || f.status !== "no_pool" || f.stake_fet !== null ||
        f.entry_count !== 0 || f.staked_fet !== 0 || f.paid_fet !== 0 || f.winner_count !== 0 || f.result_confirmed) :
        (version === null || f.status === "no_pool" || f.stake_fet === null)) {
      throw new Error("The prediction pool identity could not be confirmed.");
    }
    if (version === "free_v1" && (f.stake_fet !== 0 || f.staked_fet !== 0 || f.paid_fet !== 0)) {
      throw new Error("Free predictions cannot move FET.");
    }
    ids.add(f.id);
    if (typeof f.pool_id === "string") pools.add(f.pool_id);
    return {
      id: f.id, poolId: f.pool_id as string | null, competition: f.competition,
      homeTeam: f.home_team, awayTeam: f.away_team, kickoffAt: f.kickoff_at as string | null,
      fixtureStatus: f.fixture_status, status: f.status as AdminPredictFixture["status"],
      homeScore: f.home_score, awayScore: f.away_score, stakeFet: f.stake_fet as number | null,
      entryCount: f.entry_count, stakedFet: f.staked_fet, paidFet: f.paid_fet,
      winnerCount: f.winner_count, resultConfirmed: f.result_confirmed, economicsVersion: version,
    };
  });
  return { enabled: settings.enabled, fixtures };
}

function clubScope(access: AdminAccess) {
  if (!access.hasAccess || !access.isAuthenticated || !access.userId) {
    throw new AdminPredictValidationError("Authenticated administrator access is required.");
  }
  return requireAdminClubId(access, "manage free predictions");
}
function requireId(value: unknown) {
  if (typeof value !== "string" || !uuid.test(value)) {
    throw new AdminPredictValidationError("Choose a confirmed prediction fixture or pool.");
  }
  return value;
}
function requireSource(value: unknown) {
  if (typeof value !== "string" || value.length > 2000) {
    throw new AdminPredictValidationError("A confirmed HTTPS source is required.");
  }
  try {
    const url = new URL(value.trim());
    if (url.protocol === "https:" && url.hostname && !url.username && !url.password) return url.href;
  } catch {}
  throw new AdminPredictValidationError("A confirmed HTTPS source is required.");
}
async function rpc(client: SupabaseClient, name: string, args: Record<string, unknown>) {
  const { data, error } = await client.rpc(name, args);
  if (error) throw error;
  return data;
}
export async function getAdminFreePredictDashboardResponse(client: SupabaseClient, access: AdminAccess) {
  const result = await rpc(client, "predict_admin_dashboard", { p_club_id: clubScope(access) });
  normalizeAdminFreePredictDashboard(result);
  return result;
}
export async function getAdminFreePredictDashboard(client: SupabaseClient, access: AdminAccess, signal?: AbortSignal) {
  const clubId = clubScope(access);
  const result = typeof window !== "undefined"
    ? await requestAdminApi<unknown>("predict-operations", { signal, query: { club: clubId } })
    : await getAdminFreePredictDashboardResponse(client, access);
  return normalizeAdminFreePredictDashboard(result);
}

export type AdminFreePredictCommand =
  | { action: "settings"; enabled: boolean }
  | { action: "prepare"; fixtureId: string; sourceUrl: string }
  | { action: "confirm-result"; poolId: string; homeScore: number; awayScore: number; sourceUrl: string }
  | { action: "settle"; poolId: string; voidReason?: string | null };

export async function mutateAdminFreePredict(client: SupabaseClient, access: AdminAccess, input: AdminFreePredictCommand) {
  const clubId = clubScope(access);
  let name: string;
  let args: Record<string, unknown>;
  switch (input.action) {
    case "settings":
      if (typeof input.enabled !== "boolean") throw new AdminPredictValidationError("Choose the prediction availability.");
      name = "predict_admin_settings";
      args = { p_club_id: clubId, p_enabled: input.enabled, p_entry_fet: 0 };
      break;
    case "prepare":
      name = "predict_admin_prepare";
      args = { p_club_id: clubId, p_fixture_id: requireId(input.fixtureId), p_source_url: requireSource(input.sourceUrl) };
      break;
    case "confirm-result":
      if (!count(input.homeScore) || input.homeScore > 100 || !count(input.awayScore) || input.awayScore > 100) {
        throw new AdminPredictValidationError("Use confirmed whole-number scores from 0 to 100.");
      }
      name = "predict_admin_confirm_result";
      args = { p_pool_id: requireId(input.poolId), p_home_score: input.homeScore, p_away_score: input.awayScore, p_source_url: requireSource(input.sourceUrl) };
      break;
    case "settle": {
      if (input.voidReason != null && typeof input.voidReason !== "string") {
        throw new AdminPredictValidationError("A void reason must be text.");
      }
      const reason = input.voidReason == null ? null : input.voidReason.trim();
      if (reason != null && (reason.length < 8 || reason.length > 500)) {
        throw new AdminPredictValidationError("A void reason must contain 8 to 500 characters.");
      }
      name = "predict_admin_settle";
      args = { p_pool_id: requireId(input.poolId), p_void_reason: reason };
      break;
    }
    default: throw new AdminPredictValidationError("Choose a supported free prediction operation.");
  }
  // Pool-only RPCs resolve their own club. Re-read the current selected club so a
  // forged pool ID cannot redirect a multi-club operator's approved action.
  if (typeof window === "undefined" && input.action !== "settings") {
    const current = await getAdminFreePredictDashboard(client, access);
    const fixture = current.fixtures.find((f) => input.action === "prepare" ? f.id === input.fixtureId : f.poolId === input.poolId);
    if (!fixture || fixture.economicsVersion === "legacy_paid_v1" ||
        (input.action !== "prepare" && fixture.economicsVersion !== "free_v1")) {
      throw new AdminPredictValidationError("This pool is unavailable for free prediction operations.");
    }
  }
  const result = object(typeof window !== "undefined"
    ? await requestAdminApi<unknown>("predict-operations", { method: "POST", body: input, query: { club: clubId } })
    : await rpc(client, name, args));
  if (input.action === "settings") {
    if (result.enabled !== input.enabled || result.entry_fet !== 0 || result.economics_version !== "free_v1") {
      throw new Error("Free prediction settings were not confirmed.");
    }
  } else {
    if (result.economics_version !== "free_v1") throw new Error("The free prediction operation was not confirmed.");
    if (input.action === "prepare" && (result.id !== input.fixtureId || typeof result.pool_id !== "string" ||
        !uuid.test(result.pool_id) || result.stake_fet !== 0 || !(result.payout_fet === 0 || result.payout_fet === null))) {
      throw new Error("The prepared free prediction was not confirmed.");
    }
    if (input.action === "confirm-result" && result.result !== (input.homeScore > input.awayScore ? "home" : input.homeScore < input.awayScore ? "away" : "draw")) {
      throw new Error("The confirmed prediction result was not returned.");
    }
    if (input.action === "settle" && (!count(result.winner_count) || result.paid_fet !== 0 ||
        result.status !== (input.voidReason == null ? "settled" : "refunded"))) {
      throw new Error("The free prediction settlement was not confirmed.");
    }
  }
  return result;
}

export interface AdminLegacyPredictCommand {
  engine: "predict" | "partner";
  poolId: string;
  operationId: string;
  voidReason?: string | null;
}
async function admitHistoricalStaffCommand(
  callerClient: SupabaseClient, access: AdminAccess, operationId: string,
  action: "predict_legacy_settle" | "partner_legacy_settle" | "predict_legacy_confirm",
  poolId: string, args: Record<string, unknown>,
) {
  const receipt = object(await rpc(callerClient, "admit_verified_staff_command", {
    p_operation_id: operationId, p_action: action, p_resource_id: poolId, p_arguments: args,
  }));
  if (receipt.operation_id !== operationId || receipt.actor_id !== access.userId || receipt.action !== action
    || receipt.resource_id !== poolId || receipt.club_id !== requireAdminClubId(access)
    || !["admitted", "completed"].includes(String(receipt.status))
    || (receipt.status === "admitted" && (typeof receipt.expires_at !== "string" || !Number.isFinite(Date.parse(receipt.expires_at)) || Date.parse(receipt.expires_at) <= Date.now()))) {
    throw new Error("The original staff command admission could not be confirmed. Check its saved operation before retrying.");
  }
}
export async function settleAdminLegacyPredictForActor(
  serviceClient: SupabaseClient, callerClient: SupabaseClient, access: AdminAccess, input: AdminLegacyPredictCommand,
) {
  clubScope(access);
  if (!access.isSuperAdmin || access.role !== "super_admin") {
    throw new AdminPredictValidationError("Global administrator access is required for historical reconciliation.");
  }
  const poolId = requireId(input.poolId);
  const operationId = requireId(input.operationId);
  if (input.engine !== "predict" && input.engine !== "partner") throw new AdminPredictValidationError("Choose a historical prediction engine.");
  if (input.voidReason != null && typeof input.voidReason !== "string") throw new AdminPredictValidationError("A void reason must be text.");
  const reason = input.voidReason == null ? null : input.voidReason.trim();
  if (reason != null && (input.engine === "partner" || reason.length < 8 || reason.length > 500)) {
    throw new AdminPredictValidationError("Use an 8 to 500 character reason for a historical Predict void.");
  }
  // The read uses the actual caller JWT. Service authority is used only after
  // the selected tenant and historical engine have both been verified.
  if (typeof window === "undefined" && input.engine === "predict") {
    const current = await getAdminFreePredictDashboard(callerClient, access);
    if (!current.fixtures.some((f) => f.poolId === poolId && f.economicsVersion === "legacy_paid_v1")) {
      throw new AdminPredictValidationError("This historical pool is unavailable in the selected club.");
    }
  } else if (typeof window === "undefined") {
    const current = await getAdminPartnerPredictionPools(callerClient, access);
    if (!current.some((p) => p.id === poolId && p.clubId === requireAdminClubId(access))) throw new AdminPredictValidationError("This historical partner pool is unavailable in the selected club.");
  }
  if (typeof window === "undefined") {
    await admitHistoricalStaffCommand(callerClient, access, operationId,
      input.engine === "predict" ? "predict_legacy_settle" : "partner_legacy_settle", poolId,
      input.engine === "predict" ? { void_reason: reason } : {});
  }
  const result = object(typeof window !== "undefined"
    ? await requestAdminApi<unknown>("predict-legacy-settlement", { method: "POST", body: input, query: { club: access.clubId } })
    : await rpc(serviceClient, input.engine === "predict" ? "predict_admin_settle_for_actor" : "partner_prediction_pool_settle_for_actor", {
    p_pool_id: poolId, p_actor_id: access.userId, p_operation_id: operationId,
    ...(input.engine === "predict" ? { p_void_reason: reason } : {}),
  }));
  if (result.operation_id !== operationId || result.economics_version !== "legacy_paid_v1") {
    throw new Error("The attributed historical settlement was not confirmed.");
  }
  if (input.engine === "predict" ? (!count(result.paid_fet) || !count(result.winner_count) ||
      !["settled", "refunded"].includes(String(result.status))) : normalizeAdminPartnerPredictionPool(result) == null) {
    throw new Error("The historical settlement receipt could not be confirmed.");
  }
  return input.engine === "partner"
    ? { ...normalizeAdminPartnerPredictionPool(result), operation_id: operationId, economics_version: "legacy_paid_v1" }
    : { status: result.status, paid_fet: result.paid_fet, winner_count: result.winner_count, operation_id: operationId, economics_version: "legacy_paid_v1" };
}

export interface AdminLegacyPredictResultCommand {
  poolId: string;
  operationId: string;
  homeScore: number;
  awayScore: number;
  sourceUrl: string;
}
export async function confirmAdminLegacyPredictResultForActor(serviceClient: SupabaseClient, callerClient: SupabaseClient, access: AdminAccess, input: AdminLegacyPredictResultCommand) {
  clubScope(access);
  if (!access.isSuperAdmin || access.role !== "super_admin") throw new AdminPredictValidationError("Global administrator access is required for historical result confirmation.");
  const poolId = requireId(input.poolId);
  const operationId = requireId(input.operationId);
  const source = requireSource(input.sourceUrl);
  if (!count(input.homeScore) || input.homeScore > 100 || !count(input.awayScore) || input.awayScore > 100) throw new AdminPredictValidationError("Use confirmed whole-number scores from 0 to 100.");
  if (typeof window === "undefined") {
    const current = await getAdminFreePredictDashboard(callerClient, access);
    if (!current.fixtures.some((f) => f.poolId === poolId && f.economicsVersion === "legacy_paid_v1" &&
        f.fixtureStatus === "finished" && f.homeScore === input.homeScore && f.awayScore === input.awayScore)) {
      throw new AdminPredictValidationError("The historical result is unavailable or changed in the selected club.");
    }
    await admitHistoricalStaffCommand(callerClient, access, operationId, "predict_legacy_confirm", poolId,
      { home_score: input.homeScore, away_score: input.awayScore, source_url: source });
  }
  const result = object(typeof window !== "undefined"
    ? await requestAdminApi<unknown>("predict-legacy-confirm-result", { method: "POST", body: input, query: { club: access.clubId } })
    : await rpc(serviceClient, "predict_admin_confirm_result_for_actor", {
      p_pool_id: poolId, p_home_score: input.homeScore, p_away_score: input.awayScore, p_source_url: source,
      p_actor_id: access.userId, p_operation_id: operationId,
    }));
  const expected = input.homeScore > input.awayScore ? "home" : input.homeScore < input.awayScore ? "away" : "draw";
  if (result.operation_id !== operationId || result.economics_version !== "legacy_paid_v1" || result.result !== expected) throw new Error("The attributed historical result was not confirmed.");
  return { result: result.result, operation_id: operationId, economics_version: "legacy_paid_v1" };
}

// Only the operation UUID and normalized command are retained. Each authenticated
// subject/club has its own binding; persisting fails closed before any mutation.
export function retainLegacyPredictOperation(access: AdminAccess, engine: "predict" | "partner" | "predict-confirm", poolId: string, voidReason: string | null) {
  clubScope(access);
  const key = `africlub.predict.operation:${access.userId}:${access.clubId}:${engine}:${requireId(poolId)}`;
  const reason = voidReason == null ? null : voidReason.trim();
  const previous = window.localStorage.getItem(key);
  if (previous != null) {
    const record = object(JSON.parse(previous));
    if (typeof record.operationId !== "string" || !uuid.test(record.operationId) || record.voidReason !== reason) {
      throw new AdminPredictValidationError("Check the original reconciliation status and use its original void reason before retrying.");
    }
    return record.operationId;
  }
  const operationId = crypto.randomUUID();
  const record = JSON.stringify({ operationId, voidReason: reason });
  window.localStorage.setItem(key, record);
  if (window.localStorage.getItem(key) !== record) throw new Error("The reconciliation reference could not be retained.");
  return operationId;
}

export function retainLegacyPredictResultOperation(access: AdminAccess, input: Omit<AdminLegacyPredictResultCommand, "operationId">) {
  const source = requireSource(input.sourceUrl);
  return retainLegacyPredictOperation(access, "predict-confirm", input.poolId, JSON.stringify({ source, homeScore: input.homeScore, awayScore: input.awayScore }));
}
