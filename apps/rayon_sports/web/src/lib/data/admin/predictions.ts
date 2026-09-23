/**
 * Admin predictions — strict, bounded catalog and fixture operations.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { requestAdminApi } from "./http";
import { mutateRecordWithVariantsIfUnchanged } from "./helpers";
import {
  getAdminPartnerOptions,
  getAdminPartnerPredictionPools,
  normalizeAdminPartnerOptions,
  normalizeAdminPartnerPredictionPools,
  type AdminPartnerOption,
  type AdminPartnerPredictionPool,
} from "./partner-pools";

const MAX_CATALOG_RECORDS = 500;
const MAX_FIXTURE_RECORDS = 500;
const MAX_FET_VALUE = 1_000_000;
const marketGroups = ["match_result", "goals", "scorers", "specials"] as const;
const difficultyTiers = ["entry", "mid", "hard", "advanced"] as const;
const competitionKinds = ["league", "cup", "tournament"] as const;
const seasonStatuses = ["planned", "active", "finished", "archived"] as const;
const fixtureStatuses = [
  "scheduled",
  "live",
  "finished",
  "postponed",
  "cancelled",
] as const;

export type AdminPredictionMarketGroup = (typeof marketGroups)[number];
export type AdminPredictionDifficultyTier = (typeof difficultyTiers)[number];
export type AdminCompetitionKind = (typeof competitionKinds)[number];
export type AdminSeasonStatus = (typeof seasonStatuses)[number];
export type AdminFixtureStatus = (typeof fixtureStatuses)[number];

export interface AdminPredictionMarket {
  id: string;
  slug: string;
  name: string;
  shortName: string;
  marketGroup: AdminPredictionMarketGroup;
  marketCategory: string;
  betType: string;
  difficultyTier: AdminPredictionDifficultyTier;
  defaultFetValue: number;
  description: string;
  isActive: boolean;
  leagueAvailability: string[];
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface AdminCompetition {
  id: string;
  slug: string;
  name: string;
  shortName: string;
  competitionKind: AdminCompetitionKind;
  region: string;
  countryCode: string | null;
  countryName: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AdminSeason {
  id: string;
  competitionId: string;
  competitionName: string;
  slug: string;
  label: string;
  yearStart: number | null;
  yearEnd: number | null;
  startsOn: string | null;
  endsOn: string | null;
  status: AdminSeasonStatus;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AdminFixture {
  id: string;
  competitionName: string;
  seasonLabel: string;
  roundName: string | null;
  kickoffAt: string;
  venueName: string | null;
  homeTeamName: string;
  homeTeamShortName: string;
  awayTeamName: string;
  awayTeamShortName: string;
  homeScore: number | null;
  awayScore: number | null;
  status: AdminFixtureStatus;
  updatedAt: string;
}

export interface AdminPredictionsWorkspace {
  markets: AdminPredictionMarket[];
  competitions: AdminCompetition[];
  seasons: AdminSeason[];
  fixtures: AdminFixture[];
  partnerPools: AdminPartnerPredictionPool[];
  partners: AdminPartnerOption[];
}

export interface AdminPredictionMarketInput {
  id?: string | null;
  expectedUpdatedAt?: string | null;
  slug: string;
  name: string;
  shortName: string;
  marketGroup: AdminPredictionMarketGroup;
  marketCategory: string;
  betType: string;
  difficultyTier: AdminPredictionDifficultyTier;
  defaultFetValue: number;
  description: string;
  isActive: boolean;
  leagueAvailability: string[];
  sortOrder: number;
}

export interface AdminCompetitionInput {
  id?: string | null;
  expectedUpdatedAt?: string | null;
  slug: string;
  name: string;
  shortName: string;
  competitionKind: AdminCompetitionKind;
  region: string;
  countryCode?: string | null;
  countryName?: string | null;
  isActive: boolean;
}

export interface AdminSeasonInput {
  id?: string | null;
  expectedUpdatedAt?: string | null;
  competitionId: string;
  slug: string;
  label: string;
  yearStart?: number | null;
  yearEnd?: number | null;
  startsOn?: string | null;
  endsOn?: string | null;
  status: AdminSeasonStatus;
  isActive: boolean;
}

export interface AdminFixtureInput {
  id: string;
  expectedUpdatedAt: string;
  homeScore?: number | null;
  awayScore?: number | null;
  status?: AdminFixtureStatus;
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

function nullableDate(value: unknown) {
  if (value == null || value === "") return null;
  return boundedDate(value) ?? undefined;
}

function enumValue<T extends readonly string[]>(
  value: unknown,
  values: T,
): T[number] | null {
  const text = boundedText(value, 80);
  return text != null && values.includes(text) ? (text as T[number]) : null;
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

function requirePlatformAdmin(access: AdminAccess, action: string) {
  if (
    !access.isSuperAdmin &&
    access.role !== "super_admin" &&
    access.role !== "admin"
  ) {
    throw new Error(`Platform admin access is required to ${action}.`);
  }
}

function normalizedStringArray(
  value: unknown,
  maximum: number,
  itemLimit: number,
) {
  if (!Array.isArray(value)) return null;
  const items: string[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, maximum)) {
    const text = boundedText(entry, itemLimit);
    if (text == null) return null;
    if (!seen.has(text)) {
      items.push(text);
      seen.add(text);
    }
  }
  return items;
}

export function normalizeAdminPredictionMarket(
  value: unknown,
): AdminPredictionMarket | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const slug = boundedText(row.slug, 160);
  const name = boundedText(row.name, 160);
  const shortName = boundedText(row.shortName ?? row.short_name, 80);
  const marketGroup = enumValue(
    row.marketGroup ?? row.market_group,
    marketGroups,
  );
  const marketCategory = boundedText(
    row.marketCategory ?? row.market_category,
    120,
  );
  const betType = boundedText(row.betType ?? row.bet_type, 80);
  const difficultyTier = enumValue(
    row.difficultyTier ?? row.difficulty_tier,
    difficultyTiers,
  );
  const defaultFetValue = boundedInteger(
    row.defaultFetValue ?? row.default_fet_value,
    0,
    MAX_FET_VALUE,
  );
  const description =
    row.description == null || row.description === ""
      ? ""
      : boundedText(row.description, 1_000);
  const isActive = row.isActive ?? row.is_active;
  const leagueAvailability = normalizedStringArray(
    row.leagueAvailability ?? row.league_availability,
    32,
    80,
  );
  const sortOrder = boundedInteger(
    row.sortOrder ?? row.sort_order,
    0,
    MAX_FET_VALUE,
  );
  const createdAt = boundedDate(row.createdAt ?? row.created_at);
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);
  if (
    id == null ||
    slug == null ||
    name == null ||
    shortName == null ||
    marketGroup == null ||
    marketCategory == null ||
    betType == null ||
    difficultyTier == null ||
    defaultFetValue == null ||
    description == null ||
    typeof isActive !== "boolean" ||
    leagueAvailability == null ||
    sortOrder == null ||
    createdAt == null ||
    updatedAt == null
  ) {
    return null;
  }
  return {
    id,
    slug,
    name,
    shortName,
    marketGroup,
    marketCategory,
    betType,
    difficultyTier,
    defaultFetValue,
    description,
    isActive,
    leagueAvailability,
    sortOrder,
    createdAt,
    updatedAt,
  };
}

export function normalizeAdminCompetition(
  value: unknown,
): AdminCompetition | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const slug = boundedText(row.slug, 160);
  const name = boundedText(row.name, 160);
  const shortName = boundedText(row.shortName ?? row.short_name, 80);
  const competitionKind = enumValue(
    row.competitionKind ?? row.competition_kind,
    competitionKinds,
  );
  const region = boundedText(row.region, 80);
  const countryCode = nullableText(row.countryCode ?? row.country_code, 8);
  const countryName = nullableText(row.countryName ?? row.country_name, 120);
  const isActive = row.isActive ?? row.is_active;
  const createdAt = boundedDate(row.createdAt ?? row.created_at);
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);
  if (
    id == null ||
    slug == null ||
    name == null ||
    shortName == null ||
    competitionKind == null ||
    region == null ||
    countryCode === undefined ||
    countryName === undefined ||
    typeof isActive !== "boolean" ||
    createdAt == null ||
    updatedAt == null
  ) {
    return null;
  }
  return {
    id,
    slug,
    name,
    shortName,
    competitionKind,
    region,
    countryCode,
    countryName,
    isActive,
    createdAt,
    updatedAt,
  };
}

export function normalizeAdminSeason(value: unknown): AdminSeason | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const competitionId = boundedText(
    row.competitionId ?? row.competition_id,
    128,
  );
  const competitionName = boundedText(
    row.competitionName ?? row.competition_name,
    160,
  );
  const slug = boundedText(row.slug, 160);
  const label = boundedText(row.label, 120);
  const rawYearStart = row.yearStart ?? row.year_start;
  const rawYearEnd = row.yearEnd ?? row.year_end;
  const yearStart =
    rawYearStart == null ? null : boundedInteger(rawYearStart, 1800, 2200);
  const yearEnd =
    rawYearEnd == null ? null : boundedInteger(rawYearEnd, 1800, 2200);
  const startsOn = nullableDate(row.startsOn ?? row.starts_on);
  const endsOn = nullableDate(row.endsOn ?? row.ends_on);
  const status = enumValue(row.status, seasonStatuses);
  const isActive = row.isActive ?? row.is_active;
  const createdAt = boundedDate(row.createdAt ?? row.created_at);
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);
  if (
    id == null ||
    competitionId == null ||
    competitionName == null ||
    slug == null ||
    label == null ||
    (rawYearStart != null && yearStart == null) ||
    (rawYearEnd != null && yearEnd == null) ||
    startsOn === undefined ||
    endsOn === undefined ||
    status == null ||
    typeof isActive !== "boolean" ||
    createdAt == null ||
    updatedAt == null ||
    (yearStart != null && yearEnd != null && yearEnd < yearStart) ||
    (startsOn != null &&
      endsOn != null &&
      Date.parse(endsOn) < Date.parse(startsOn))
  ) {
    return null;
  }
  return {
    id,
    competitionId,
    competitionName,
    slug,
    label,
    yearStart,
    yearEnd,
    startsOn,
    endsOn,
    status,
    isActive,
    createdAt,
    updatedAt,
  };
}

export function normalizeAdminFixture(value: unknown): AdminFixture | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const row = value as Record<string, unknown>;
  const id = boundedText(row.id, 128);
  const competitionName = boundedText(
    row.competitionName ?? row.competition_name,
    160,
  );
  const seasonLabel = boundedText(row.seasonLabel ?? row.season_label, 120);
  const roundName = nullableText(row.roundName ?? row.round_name, 120);
  const kickoffAt = boundedDate(row.kickoffAt ?? row.kickoff_at);
  const venueName = nullableText(row.venueName ?? row.venue_name, 160);
  const homeTeamName = boundedText(row.homeTeamName ?? row.home_team_name, 160);
  const homeTeamShortName =
    boundedText(row.homeTeamShortName ?? row.home_team_short_name, 80) ??
    homeTeamName;
  const awayTeamName = boundedText(row.awayTeamName ?? row.away_team_name, 160);
  const awayTeamShortName =
    boundedText(row.awayTeamShortName ?? row.away_team_short_name, 80) ??
    awayTeamName;
  const rawHomeScore = row.homeScore ?? row.home_score;
  const rawAwayScore = row.awayScore ?? row.away_score;
  const homeScore =
    rawHomeScore == null ? null : boundedInteger(rawHomeScore, 0, 100);
  const awayScore =
    rawAwayScore == null ? null : boundedInteger(rawAwayScore, 0, 100);
  const status = enumValue(row.status, fixtureStatuses);
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);
  if (
    id == null ||
    competitionName == null ||
    seasonLabel == null ||
    roundName === undefined ||
    kickoffAt == null ||
    venueName === undefined ||
    homeTeamName == null ||
    homeTeamShortName == null ||
    awayTeamName == null ||
    awayTeamShortName == null ||
    (rawHomeScore != null && homeScore == null) ||
    (rawAwayScore != null && awayScore == null) ||
    (homeScore == null) !== (awayScore == null) ||
    status == null ||
    updatedAt == null
  ) {
    return null;
  }
  return {
    id,
    competitionName,
    seasonLabel,
    roundName,
    kickoffAt,
    venueName,
    homeTeamName,
    homeTeamShortName,
    awayTeamName,
    awayTeamShortName,
    homeScore,
    awayScore,
    status,
    updatedAt,
  };
}

function normalizeCollection<T>(
  value: unknown,
  limit: number,
  normalizer: (entry: unknown) => T | null,
) {
  if (!Array.isArray(value)) return [] as T[];
  const rows: T[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, limit)) {
    const row = normalizer(entry);
    const id =
      row != null && typeof row === "object" && "id" in row
        ? String((row as { id: unknown }).id)
        : null;
    if (row != null && id != null && !seen.has(id)) {
      rows.push(row);
      seen.add(id);
    }
  }
  return rows;
}

export function normalizeAdminPredictionsWorkspace(
  value: unknown,
): AdminPredictionsWorkspace {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {
      markets: [],
      competitions: [],
      seasons: [],
      fixtures: [],
      partnerPools: [],
      partners: [],
    };
  }
  const row = value as Record<string, unknown>;
  return {
    markets: normalizeCollection(
      row.markets,
      MAX_CATALOG_RECORDS,
      normalizeAdminPredictionMarket,
    ),
    competitions: normalizeCollection(
      row.competitions,
      MAX_CATALOG_RECORDS,
      normalizeAdminCompetition,
    ),
    seasons: normalizeCollection(
      row.seasons,
      MAX_CATALOG_RECORDS,
      normalizeAdminSeason,
    ),
    fixtures: normalizeCollection(
      row.fixtures,
      MAX_FIXTURE_RECORDS,
      normalizeAdminFixture,
    ),
    partnerPools: normalizeAdminPartnerPredictionPools(row.partnerPools),
    partners: normalizeAdminPartnerOptions(row.partners),
  };
}

async function mutateFootballRecordIfUnchanged(
  client: SupabaseClient,
  table: string,
  id: string | null | undefined,
  expectedUpdatedAt: string | null | undefined,
  payload: Record<string, unknown>,
) {
  const tableClient = client.schema("football").from(table);
  if (id) {
    return mutateRecordWithVariantsIfUnchanged(
      client.schema("football") as unknown as SupabaseClient,
      table,
      id,
      expectedUpdatedAt,
      [payload],
    );
  }
  const response = await tableClient.insert(payload).select("id").single();
  if (response.error) throw new Error(response.error.message);
  const insertedId = boundedText(response.data?.id, 128);
  if (insertedId == null) {
    throw new Error(
      "The record was saved but its identifier was not confirmed.",
    );
  }
  return insertedId;
}

export async function getAdminPredictionMarkets(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminPredictionMarket[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("predictions-markets");
    return normalizeCollection(
      result,
      MAX_CATALOG_RECORDS,
      normalizeAdminPredictionMarket,
    );
  }
  const { data, error } = await client
    .schema("football")
    .from("prediction_markets")
    .select(
      "id,slug,name,short_name,market_group,market_category,bet_type,difficulty_tier,default_fet_value,description,is_active,league_availability,sort_order,created_at,updated_at",
    )
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true })
    .limit(MAX_CATALOG_RECORDS);
  if (error) throw new Error(error.message);
  return normalizeCollection(
    data,
    MAX_CATALOG_RECORDS,
    normalizeAdminPredictionMarket,
  );
}

export async function getAdminCompetitions(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminCompetition[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("predictions-competitions");
    return normalizeCollection(
      result,
      MAX_CATALOG_RECORDS,
      normalizeAdminCompetition,
    );
  }
  const { data, error } = await client
    .schema("football")
    .from("competitions")
    .select(
      "id,slug,name,short_name,competition_kind,region,country_code,country_name,is_active,created_at,updated_at",
    )
    .order("name", { ascending: true })
    .limit(MAX_CATALOG_RECORDS);
  if (error) throw new Error(error.message);
  return normalizeCollection(
    data,
    MAX_CATALOG_RECORDS,
    normalizeAdminCompetition,
  );
}

export async function getAdminSeasons(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminSeason[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("predictions-seasons");
    return normalizeCollection(
      result,
      MAX_CATALOG_RECORDS,
      normalizeAdminSeason,
    );
  }
  const { data, error } = await client
    .from("football_seasons_catalog")
    .select(
      "id,competition_id,competition_name,slug,label,year_start,year_end,starts_on,ends_on,status,is_active,created_at,updated_at",
    )
    .order("year_start", { ascending: false })
    .order("label", { ascending: true })
    .limit(MAX_CATALOG_RECORDS);
  if (error) throw new Error(error.message);
  return normalizeCollection(data, MAX_CATALOG_RECORDS, normalizeAdminSeason);
}

export async function getAdminFixtures(
  client: SupabaseClient,
  _access: AdminAccess,
): Promise<AdminFixture[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("predictions-fixtures");
    return normalizeCollection(
      result,
      MAX_FIXTURE_RECORDS,
      normalizeAdminFixture,
    );
  }
  const { data, error } = await client
    .from("football_fixtures_catalog")
    .select(
      "id,competition_name,season_label,round_name,kickoff_at,venue_name,home_team_name,home_team_short_name,away_team_name,away_team_short_name,home_score,away_score,status,updated_at",
    )
    .order("kickoff_at", { ascending: true })
    .limit(MAX_FIXTURE_RECORDS);
  if (error) throw new Error(error.message);
  return normalizeCollection(data, MAX_FIXTURE_RECORDS, normalizeAdminFixture);
}

export async function getAdminPredictionsWorkspace(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal; poolClient?: SupabaseClient } = {},
): Promise<AdminPredictionsWorkspace> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("predictions", {
      signal: options.signal,
    });
    return normalizeAdminPredictionsWorkspace(result);
  }
  const [markets, competitions, seasons, fixtures, partnerPools, partners] =
    await Promise.all([
      getAdminPredictionMarkets(client, access),
      getAdminCompetitions(client, access),
      getAdminSeasons(client, access),
      getAdminFixtures(client, access),
      getAdminPartnerPredictionPools(options.poolClient ?? client, access),
      getAdminPartnerOptions(client, access),
    ]);
  return normalizeAdminPredictionsWorkspace({
    markets,
    competitions,
    seasons,
    fixtures,
    partnerPools,
    partners,
  });
}

export async function saveAdminPredictionMarket(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminPredictionMarketInput,
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-markets", {
      method: "POST",
      body: input,
    });
  }
  requirePlatformAdmin(access, "change prediction templates");
  const leagueAvailability = normalizedStringArray(
    input.leagueAvailability,
    32,
    80,
  );
  if (leagueAvailability == null) {
    throw new Error("League availability is invalid.");
  }
  if (!marketGroups.includes(input.marketGroup)) {
    throw new Error("Choose a supported market group.");
  }
  if (!difficultyTiers.includes(input.difficultyTier)) {
    throw new Error("Choose a supported difficulty tier.");
  }
  return mutateFootballRecordIfUnchanged(
    client,
    "prediction_markets",
    input.id,
    input.expectedUpdatedAt,
    {
      slug: requireText(input.slug, "Market slug", 160),
      name: requireText(input.name, "Market name", 160),
      short_name: requireText(input.shortName, "Short name", 80),
      market_group: input.marketGroup,
      market_category: requireText(input.marketCategory, "Category", 120),
      bet_type: requireText(input.betType, "Bet type", 80),
      difficulty_tier: input.difficultyTier,
      default_fet_value: requireInteger(
        input.defaultFetValue,
        "Default FET value",
        0,
        MAX_FET_VALUE,
      ),
      description: nullableText(input.description, 1_000) ?? "",
      is_active: input.isActive,
      league_availability: leagueAvailability,
      sort_order: requireInteger(
        input.sortOrder,
        "Sort order",
        0,
        MAX_FET_VALUE,
      ),
    },
  );
}

export async function saveAdminCompetition(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminCompetitionInput,
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-competitions", {
      method: "POST",
      body: input,
    });
  }
  requirePlatformAdmin(access, "change football competitions");
  if (!competitionKinds.includes(input.competitionKind)) {
    throw new Error("Choose a supported competition kind.");
  }
  const countryCode = nullableText(input.countryCode, 8);
  const countryName = nullableText(input.countryName, 120);
  if (countryCode === undefined || countryName === undefined) {
    throw new Error("Competition country details are invalid.");
  }
  return mutateFootballRecordIfUnchanged(
    client,
    "competitions",
    input.id,
    input.expectedUpdatedAt,
    {
      slug: requireText(input.slug, "Competition slug", 160),
      name: requireText(input.name, "Competition name", 160),
      short_name: requireText(input.shortName, "Short name", 80),
      competition_kind: input.competitionKind,
      region: requireText(input.region, "Region", 80),
      country_code: countryCode,
      country_name: countryName,
      is_active: input.isActive,
    },
  );
}

export async function saveAdminSeason(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminSeasonInput,
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-seasons", {
      method: "POST",
      body: input,
    });
  }
  requirePlatformAdmin(access, "change football seasons");
  if (!seasonStatuses.includes(input.status)) {
    throw new Error("Choose a supported season status.");
  }
  const yearStart =
    input.yearStart == null
      ? null
      : requireInteger(input.yearStart, "Start year", 1800, 2200);
  const yearEnd =
    input.yearEnd == null
      ? null
      : requireInteger(input.yearEnd, "End year", 1800, 2200);
  const startsOn = nullableDate(input.startsOn);
  const endsOn = nullableDate(input.endsOn);
  if (
    startsOn === undefined ||
    endsOn === undefined ||
    (yearStart != null && yearEnd != null && yearEnd < yearStart) ||
    (startsOn != null &&
      endsOn != null &&
      Date.parse(endsOn) < Date.parse(startsOn))
  ) {
    throw new Error("Season dates are invalid.");
  }
  return mutateFootballRecordIfUnchanged(
    client,
    "seasons",
    input.id,
    input.expectedUpdatedAt,
    {
      competition_id: requireText(input.competitionId, "Competition", 128),
      slug: requireText(input.slug, "Season slug", 160),
      label: requireText(input.label, "Season label", 120),
      year_start: yearStart,
      year_end: yearEnd,
      starts_on: startsOn,
      ends_on: endsOn,
      status: input.status,
      is_active: input.isActive,
    },
  );
}

export async function saveAdminFixture(
  client: SupabaseClient,
  access: AdminAccess,
  input: AdminFixtureInput,
): Promise<string> {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("predictions-fixtures", {
      method: "POST",
      body: input,
    });
  }
  requirePlatformAdmin(access, "change football fixtures");
  const payload: Record<string, unknown> = {};
  if (input.homeScore !== undefined) {
    payload.home_score =
      input.homeScore == null
        ? null
        : requireInteger(input.homeScore, "Home score", 0, 100);
  }
  if (input.awayScore !== undefined) {
    payload.away_score =
      input.awayScore == null
        ? null
        : requireInteger(input.awayScore, "Away score", 0, 100);
  }
  if (input.status !== undefined) {
    if (!fixtureStatuses.includes(input.status)) {
      throw new Error("Choose a supported fixture status.");
    }
    payload.status = input.status;
  }
  if (Object.keys(payload).length === 0) {
    throw new Error("No fixture change was supplied.");
  }
  return mutateFootballRecordIfUnchanged(
    client,
    "fixtures",
    requireText(input.id, "Fixture", 128),
    input.expectedUpdatedAt,
    payload,
  );
}
