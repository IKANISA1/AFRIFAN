/**
 * Admin predictions — read/write for prediction markets, fixtures, competitions, and seasons.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";

/* ---------- Types ---------- */

export interface AdminPredictionMarket {
  id: string;
  slug: string;
  name: string;
  shortName: string;
  marketGroup: string;
  marketCategory: string;
  betType: string;
  difficultyTier: string;
  defaultFetValue: number;
  description: string;
  isActive: boolean;
  leagueAvailability: string[];
  sortOrder: number;
  createdAt: string;
}

export interface AdminCompetition {
  id: string;
  slug: string;
  name: string;
  shortName: string;
  competitionKind: string;
  region: string;
  countryCode: string;
  countryName: string;
  isActive: boolean;
  createdAt: string;
}

export interface AdminSeason {
  id: string;
  competitionId: string;
  competitionName: string;
  slug: string;
  label: string;
  yearStart: number;
  yearEnd: number;
  startsOn: string;
  endsOn: string;
  status: string;
  isActive: boolean;
  createdAt: string;
}

export interface AdminFixture {
  id: string;
  competitionName: string;
  seasonLabel: string;
  roundName: string;
  kickoffAt: string;
  venueName: string;
  homeTeamName: string;
  homeTeamShortName: string;
  awayTeamName: string;
  awayTeamShortName: string;
  homeScore: number | null;
  awayScore: number | null;
  status: string;
}

/* ---------- Mappers ---------- */

function mapMarket(row: Record<string, unknown>): AdminPredictionMarket {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    slug: safeString(row.slug),
    name: safeString(row.name, "Market"),
    shortName: safeString(row.short_name),
    marketGroup: safeString(row.market_group),
    marketCategory: safeString(row.market_category),
    betType: safeString(row.bet_type),
    difficultyTier: safeString(row.difficulty_tier),
    defaultFetValue: safeNumber(row.default_fet_value, 0),
    description: safeString(row.description),
    isActive: row.is_active !== false,
    leagueAvailability: Array.isArray(row.league_availability) ? row.league_availability.map(String) : [],
    sortOrder: safeNumber(row.sort_order, 0),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapCompetition(row: Record<string, unknown>): AdminCompetition {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    slug: safeString(row.slug),
    name: safeString(row.name, "Competition"),
    shortName: safeString(row.short_name),
    competitionKind: safeString(row.competition_kind),
    region: safeString(row.region),
    countryCode: safeString(row.country_code),
    countryName: safeString(row.country_name),
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapSeason(row: Record<string, unknown>): AdminSeason {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    competitionId: safeString(row.competition_id),
    competitionName: safeString(row.competition_name, "Competition"),
    slug: safeString(row.slug),
    label: safeString(row.label),
    yearStart: safeNumber(row.year_start, 0),
    yearEnd: safeNumber(row.year_end, 0),
    startsOn: safeString(row.starts_on),
    endsOn: safeString(row.ends_on),
    status: safeString(row.status, "active"),
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

function mapFixture(row: Record<string, unknown>): AdminFixture {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    competitionName: safeString(row.competition_name),
    seasonLabel: safeString(row.season_label),
    roundName: safeString(row.round_name),
    kickoffAt: safeString(row.kickoff_at),
    venueName: safeString(row.venue_name),
    homeTeamName: safeString(row.home_team_name, "Home"),
    homeTeamShortName: safeString(row.home_team_short_name),
    awayTeamName: safeString(row.away_team_name, "Away"),
    awayTeamShortName: safeString(row.away_team_short_name),
    homeScore: row.home_score == null ? null : safeNumber(row.home_score, 0),
    awayScore: row.away_score == null ? null : safeNumber(row.away_score, 0),
    status: safeString(row.status, "scheduled"),
  };
}

/* ---------- Markets ---------- */

export async function getAdminPredictionMarkets(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminPredictionMarket[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminPredictionMarket[]>("predictions-markets");
  }

  const { data, error } = await client
    .from("prediction_markets_catalog")
    .select("*")
    .order("sort_order", { ascending: true });

  if (error) throw new Error(error.message);
  return Array.isArray(data) ? data.map((r) => mapMarket(r as Record<string, unknown>)) : [];
}

export async function saveAdminPredictionMarket(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id?: string | null;
    name: string;
    shortName?: string;
    slug?: string;
    marketGroup?: string;
    marketCategory?: string;
    betType?: string;
    difficultyTier?: string;
    defaultFetValue?: number;
    description?: string;
    isActive: boolean;
    sortOrder?: number;
  },
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-markets", { method: "POST", body: input });
  }

  const payload = {
    name: input.name.trim(),
    short_name: safeString(input.shortName, input.name.trim()),
    slug: safeString(input.slug, input.name.toLowerCase().replace(/[^a-z0-9]+/g, "-")),
    market_group: safeString(input.marketGroup, "custom"),
    market_category: safeString(input.marketCategory, "Custom"),
    bet_type: safeString(input.betType, "Outright"),
    difficulty_tier: safeString(input.difficultyTier, "medium"),
    default_fet_value: safeNumber(input.defaultFetValue, 50),
    description: safeString(input.description),
    is_active: input.isActive,
    sort_order: safeNumber(input.sortOrder, 0),
  };

  if (input.id) {
    const { error } = await client.from("prediction_markets_catalog").update(payload).eq("id", input.id);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("prediction_markets_catalog").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

/* ---------- Competitions ---------- */

export async function getAdminCompetitions(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminCompetition[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminCompetition[]>("predictions-competitions");
  }

  const { data, error } = await client
    .from("football_competitions_catalog")
    .select("*")
    .order("name", { ascending: true });

  if (error) throw new Error(error.message);
  return Array.isArray(data) ? data.map((r) => mapCompetition(r as Record<string, unknown>)) : [];
}

export async function saveAdminCompetition(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id?: string | null;
    name: string;
    shortName?: string;
    slug?: string;
    competitionKind?: string;
    region?: string;
    countryCode?: string;
    countryName?: string;
    isActive: boolean;
  },
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-competitions", { method: "POST", body: input });
  }

  const payload = {
    name: input.name.trim(),
    short_name: safeString(input.shortName, input.name.trim()),
    slug: safeString(input.slug, input.name.toLowerCase().replace(/[^a-z0-9]+/g, "-")),
    competition_kind: safeString(input.competitionKind, "league"),
    region: safeString(input.region, "africa"),
    country_code: safeString(input.countryCode),
    country_name: safeString(input.countryName),
    is_active: input.isActive,
  };

  if (input.id) {
    const { error } = await client.from("football_competitions_catalog").update(payload).eq("id", input.id);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("football_competitions_catalog").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

/* ---------- Seasons ---------- */

export async function getAdminSeasons(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminSeason[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSeason[]>("predictions-seasons");
  }

  const { data, error } = await client
    .from("football_seasons_catalog")
    .select("*")
    .order("year_start", { ascending: false });

  if (error) throw new Error(error.message);
  return Array.isArray(data) ? data.map((r) => mapSeason(r as Record<string, unknown>)) : [];
}

export async function saveAdminSeason(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id?: string | null;
    competitionId: string;
    competitionName?: string;
    slug?: string;
    label: string;
    yearStart: number;
    yearEnd: number;
    startsOn?: string;
    endsOn?: string;
    status?: string;
    isActive: boolean;
  },
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-seasons", { method: "POST", body: input });
  }

  const payload = {
    competition_id: input.competitionId,
    competition_name: safeString(input.competitionName),
    slug: safeString(input.slug, `season-${input.yearStart}-${input.yearEnd}`),
    label: input.label.trim(),
    year_start: input.yearStart,
    year_end: input.yearEnd,
    starts_on: input.startsOn || null,
    ends_on: input.endsOn || null,
    status: safeString(input.status, "active"),
    is_active: input.isActive,
  };

  if (input.id) {
    const { error } = await client.from("football_seasons_catalog").update(payload).eq("id", input.id);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("football_seasons_catalog").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

/* ---------- Fixtures ---------- */

export async function getAdminFixtures(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminFixture[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFixture[]>("predictions-fixtures");
  }

  const { data, error } = await client
    .from("football_fixtures_catalog")
    .select("*")
    .order("kickoff_at", { ascending: true })
    .limit(200);

  if (error) throw new Error(error.message);
  return Array.isArray(data) ? data.map((r) => mapFixture(r as Record<string, unknown>)) : [];
}

export async function saveAdminFixture(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id: string;
    homeScore?: number | null;
    awayScore?: number | null;
    status?: string;
  },
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-fixtures", { method: "POST", body: input });
  }

  const payload: Record<string, unknown> = {};
  if (input.homeScore !== undefined) payload.home_score = input.homeScore;
  if (input.awayScore !== undefined) payload.away_score = input.awayScore;
  if (input.status) payload.status = input.status;

  const { error } = await client
    .from("football_fixtures_catalog")
    .update(payload)
    .eq("id", input.id);
  if (error) throw new Error(error.message);
  return input.id;
}
