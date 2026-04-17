/**
 * API-Football response → Supabase `football.*` table mappers.
 *
 * Each mapper converts an API-Football response object into a row shape
 * suitable for upserting into the corresponding `football.*` table.
 */

import type {
  ApiFixture,
  ApiFixtureEvent,
  ApiFixtureLineup,
  ApiFixtureStatistic,
  ApiLeague,
  ApiSquad,
  ApiSquadPlayer,
  ApiTeam,
} from "./api-football-client.ts";

const PROVIDER = "api-football";

/* ---------- Helpers ---------- */

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function parseHeight(raw: string | null): number | null {
  if (!raw) return null;
  const num = parseInt(raw.replace(/[^0-9]/g, ""), 10);
  return Number.isFinite(num) ? num : null;
}

function parseWeight(raw: string | null): number | null {
  if (!raw) return null;
  const num = parseInt(raw.replace(/[^0-9]/g, ""), 10);
  return Number.isFinite(num) ? num : null;
}

/**
 * Maps API-Football fixture short status codes to our local enum.
 *
 * API statuses: TBD, NS, 1H, HT, 2H, ET, BT, P, SUSP, INT, FT, AET, PEN,
 *               PST, CANC, ABD, AWD, WO, LIVE
 *
 * Our statuses: scheduled, live, finished, postponed, cancelled
 */
function mapFixtureStatus(
  shortStatus: string,
): "scheduled" | "live" | "finished" | "postponed" | "cancelled" {
  switch (shortStatus) {
    case "1H":
    case "2H":
    case "ET":
    case "BT":
    case "P":
    case "HT":
    case "SUSP":
    case "INT":
    case "LIVE":
      return "live";
    case "FT":
    case "AET":
    case "PEN":
    case "AWD":
    case "WO":
      return "finished";
    case "PST":
      return "postponed";
    case "CANC":
    case "ABD":
      return "cancelled";
    case "TBD":
    case "NS":
    default:
      return "scheduled";
  }
}

function mapCompetitionKind(
  leagueType: string,
): "league" | "cup" | "tournament" {
  switch (leagueType.toLowerCase()) {
    case "cup":
      return "cup";
    case "league":
    default:
      return "league";
  }
}

/* ---------- Competition mapper ---------- */

export interface CompetitionRow {
  slug: string;
  name: string;
  short_name: string;
  competition_kind: "league" | "cup" | "tournament";
  region: string;
  country_code: string | null;
  country_name: string | null;
  external_provider: string;
  external_competition_id: string;
  is_active: boolean;
  metadata: Record<string, unknown>;
}

export function mapLeagueToCompetition(league: ApiLeague): CompetitionRow {
  const isDomestic = league.country.name !== "World";
  // Country-qualify domestic league slugs to avoid collisions
  // e.g. "premier-league-ghana" instead of just "premier-league"
  const baseSlug = slugify(league.league.name);
  const slug = isDomestic && league.country.name
    ? `${baseSlug}-${slugify(league.country.name)}`
    : baseSlug;

  return {
    slug,
    name: league.league.name,
    short_name: league.league.name.length > 20
      ? league.league.name.substring(0, 20)
      : league.league.name,
    competition_kind: mapCompetitionKind(league.league.type),
    region: isDomestic ? "domestic" : "international",
    country_code: league.country.code ?? null,
    country_name: league.country.name,
    external_provider: PROVIDER,
    external_competition_id: String(league.league.id),
    is_active: true,
    metadata: {
      api_league_logo: league.league.logo,
      api_country_flag: league.country.flag,
    },
  };
}

/* ---------- Season mapper ---------- */

export interface SeasonRow {
  competition_id: string; // Will be resolved during upsert
  slug: string;
  label: string;
  year_start: number;
  year_end: number;
  starts_on: string | null;
  ends_on: string | null;
  status: "planned" | "active" | "finished" | "archived";
  is_active: boolean;
  metadata: Record<string, unknown>;
}

export function mapSeasonToSeason(
  league: ApiLeague,
  season: ApiLeague["seasons"][number],
  competitionSlug: string,
): SeasonRow {
  return {
    competition_id: "", // Resolved during upsert
    slug: `${competitionSlug}-${season.year}`,
    label: String(season.year),
    year_start: season.year,
    year_end: season.year,
    starts_on: season.start || null,
    ends_on: season.end || null,
    status: season.current ? "active" : "finished",
    is_active: season.current,
    metadata: {
      api_league_id: league.league.id,
      coverage: season.coverage,
    },
  };
}

/* ---------- Team mapper ---------- */

export interface TeamRow {
  slug: string;
  name: string;
  short_name: string | null;
  team_type: "club" | "national";
  country_code: string | null;
  country_name: string | null;
  city: string | null;
  founded_year: number | null;
  crest_url: string | null;
  external_provider: string;
  external_team_id: string;
  is_active: boolean;
  metadata: Record<string, unknown>;
}

export function mapTeamToTeam(t: ApiTeam): TeamRow {
  return {
    slug: slugify(t.team.name),
    name: t.team.name,
    short_name: t.team.code ?? null,
    team_type: t.team.national ? "national" : "club",
    country_code: null, // API doesn't provide ISO code directly
    country_name: t.team.country,
    city: t.venue?.city ?? null,
    founded_year: t.team.founded ?? null,
    crest_url: t.team.logo,
    external_provider: PROVIDER,
    external_team_id: String(t.team.id),
    is_active: true,
    metadata: {
      api_logo: t.team.logo,
      venue_name: t.venue?.name ?? null,
      venue_capacity: t.venue?.capacity ?? null,
    },
  };
}

/* ---------- Fixture mapper ---------- */

export interface FixtureRow {
  competition_id: string; // Resolved during upsert
  season_id: string; // Resolved during upsert
  stage_name: string;
  group_name: string;
  round_name: string | null;
  kickoff_at: string | null;
  venue_name: string | null;
  venue_city: string | null;
  home_team_id: string; // Resolved during upsert
  away_team_id: string; // Resolved during upsert
  home_score: number | null;
  away_score: number | null;
  status: "scheduled" | "live" | "finished" | "postponed" | "cancelled";
  external_provider: string;
  external_fixture_id: string;
  metadata: Record<string, unknown>;
}

export function mapFixtureToFixture(f: ApiFixture): FixtureRow {
  const status = mapFixtureStatus(f.fixture.status.short);

  return {
    competition_id: "", // Resolved
    season_id: "", // Resolved
    stage_name: "regular_season",
    group_name: "",
    round_name: f.league.round ?? null,
    kickoff_at: f.fixture.date,
    venue_name: f.fixture.venue?.name ?? null,
    venue_city: f.fixture.venue?.city ?? null,
    home_team_id: "", // Resolved
    away_team_id: "", // Resolved
    home_score: f.goals.home,
    away_score: f.goals.away,
    status,
    external_provider: PROVIDER,
    external_fixture_id: String(f.fixture.id),
    metadata: {
      api_fixture_id: f.fixture.id,
      api_home_team_id: f.teams.home.id,
      api_away_team_id: f.teams.away.id,
      api_league_id: f.league.id,
      api_season: f.league.season,
      api_status_short: f.fixture.status.short,
      api_status_long: f.fixture.status.long,
      api_elapsed: f.fixture.status.elapsed,
      api_extra: f.fixture.status.extra,
      referee: f.fixture.referee,
      halftime_score: f.score.halftime,
      fulltime_score: f.score.fulltime,
      extratime_score: f.score.extratime,
      penalty_score: f.score.penalty,
      home_team_logo: f.teams.home.logo,
      away_team_logo: f.teams.away.logo,
    },
  };
}

/* ---------- Standing mapper ---------- */

export interface StandingRow {
  competition_id: string; // Resolved
  season_id: string; // Resolved
  team_id: string; // Resolved
  stage_name: string;
  group_name: string;
  position: number;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  goals_for: number;
  goals_against: number;
  goal_difference: number;
  points: number;
  form: string[];
  notes: string | null;
  metadata: Record<string, unknown>;
}

export function mapStandingToStanding(
  entry: ApiStanding["league"]["standings"][number][number],
  apiLeagueId: number,
): StandingRow {
  const formArray = entry.form
    ? entry.form.split("").map((char) => {
        switch (char.toUpperCase()) {
          case "W": return "W";
          case "D": return "D";
          case "L": return "L";
          default: return char.toUpperCase();
        }
      })
    : [];

  return {
    competition_id: "",
    season_id: "",
    team_id: "",
    stage_name: "overall",
    group_name: entry.group || "",
    position: entry.rank,
    played: entry.all.played,
    won: entry.all.win,
    drawn: entry.all.draw,
    lost: entry.all.lose,
    goals_for: entry.all.goals.for,
    goals_against: entry.all.goals.against,
    goal_difference: entry.goalsDiff,
    points: entry.points,
    form: formArray,
    notes: entry.description ?? null,
    metadata: {
      api_team_id: entry.team.id,
      api_league_id: apiLeagueId,
      api_team_logo: entry.team.logo,
      home_record: entry.home,
      away_record: entry.away,
    },
  };
}

/* ---------- Fixture Stats mapper ---------- */

export interface FixtureStatRow {
  fixture_id: string; // Resolved
  stat_key: string;
  stat_label: string;
  home_value: number;
  away_value: number;
  home_display: string | null;
  away_display: string | null;
  sort_order: number;
}

export function mapStatsToFixtureStats(
  stats: ApiFixtureStatistic[],
): FixtureStatRow[] {
  if (stats.length < 2) return [];

  const homeStats = stats[0]?.statistics ?? [];
  const awayStats = stats[1]?.statistics ?? [];

  const allKeys = new Map<string, { home: string | number | null; away: string | number | null }>();

  for (const s of homeStats) {
    const existing = allKeys.get(s.type) ?? { home: null, away: null };
    existing.home = s.value;
    allKeys.set(s.type, existing);
  }
  for (const s of awayStats) {
    const existing = allKeys.get(s.type) ?? { home: null, away: null };
    existing.away = s.value;
    allKeys.set(s.type, existing);
  }

  const rows: FixtureStatRow[] = [];
  let sortOrder = 0;

  for (const [type, values] of allKeys) {
    const homeRaw = values.home;
    const awayRaw = values.away;

    rows.push({
      fixture_id: "",
      stat_key: slugify(type),
      stat_label: type,
      home_value: parseStatValue(homeRaw),
      away_value: parseStatValue(awayRaw),
      home_display: homeRaw != null ? String(homeRaw) : null,
      away_display: awayRaw != null ? String(awayRaw) : null,
      sort_order: sortOrder++,
    });
  }

  return rows;
}

function parseStatValue(raw: string | number | null): number {
  if (raw == null) return 0;
  if (typeof raw === "number") return raw;
  const cleaned = raw.replace("%", "").trim();
  const parsed = parseFloat(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

/* ---------- Fixture Events mapper ---------- */

export interface FixtureEventRow {
  fixture_id: string; // Resolved
  team_id: string | null; // Resolved
  event_type: string;
  minute: number | null;
  stoppage_minute: number | null;
  event_label: string | null;
  event_detail: string | null;
  sort_order: number;
  metadata: Record<string, unknown>;
}

export function mapEventsToFixtureEvents(
  events: ApiFixtureEvent[],
): FixtureEventRow[] {
  return events.map((event, index) => ({
    fixture_id: "",
    team_id: null,
    event_type: mapEventType(event.type),
    minute: event.time.elapsed ?? null,
    stoppage_minute: event.time.extra ?? null,
    event_label: event.detail || event.type,
    event_detail: [
      event.player?.name,
      event.assist?.name ? `(${event.assist.name})` : null,
      event.comments,
    ]
      .filter(Boolean)
      .join(" ") || null,
    sort_order: index,
    metadata: {
      api_team_id: event.team.id,
      api_player_id: event.player?.id,
      api_assist_id: event.assist?.id,
      api_type: event.type,
      api_detail: event.detail,
    },
  }));
}

function mapEventType(apiType: string): string {
  switch (apiType.toLowerCase()) {
    case "goal": return "goal";
    case "card": return "card";
    case "subst": return "substitution";
    case "var": return "var";
    default: return apiType.toLowerCase().replace(/\s+/g, "_");
  }
}

/* ---------- Fixture Lineups mapper ---------- */

export interface FixtureLineupRow {
  fixture_id: string; // Resolved
  team_id: string; // Resolved
  formation: string | null;
  coach_name: string | null;
  is_confirmed: boolean;
  source: string;
  players: FixtureLineupPlayerRow[];
}

export interface FixtureLineupPlayerRow {
  player_name: string;
  squad_number: number | null;
  position: string | null;
  lineup_role: "starter" | "substitute";
  sort_order: number;
  is_captain: boolean;
  is_goalkeeper: boolean;
  metadata: Record<string, unknown>;
}

export function mapLineupsToFixtureLineups(
  lineups: ApiFixtureLineup[],
): FixtureLineupRow[] {
  return lineups.map((lineup) => {
    const starters: FixtureLineupPlayerRow[] = (lineup.startXI ?? []).map(
      (entry, index) => ({
        player_name: entry.player.name,
        squad_number: entry.player.number ?? null,
        position: entry.player.pos ?? null,
        lineup_role: "starter" as const,
        sort_order: index,
        is_captain: false,
        is_goalkeeper: entry.player.pos === "G",
        metadata: {
          api_player_id: entry.player.id,
          grid: entry.player.grid,
        },
      }),
    );

    const substitutes: FixtureLineupPlayerRow[] = (lineup.substitutes ?? []).map(
      (entry, index) => ({
        player_name: entry.player.name,
        squad_number: entry.player.number ?? null,
        position: entry.player.pos ?? null,
        lineup_role: "substitute" as const,
        sort_order: starters.length + index,
        is_captain: false,
        is_goalkeeper: entry.player.pos === "G",
        metadata: {
          api_player_id: entry.player.id,
          grid: entry.player.grid,
        },
      }),
    );

    return {
      fixture_id: "",
      team_id: "",
      formation: lineup.formation ?? null,
      coach_name: lineup.coach?.name ?? null,
      is_confirmed: true,
      source: PROVIDER,
      players: [...starters, ...substitutes],
    };
  });
}

/* ---------- Squad/Player mapper ---------- */

export interface PlayerRow {
  slug: string;
  full_name: string;
  short_name: string | null;
  primary_position: string | null;
  photo_url: string | null;
  external_provider: string;
  external_player_id: string;
  is_active: boolean;
  metadata: Record<string, unknown>;
}

export interface PlayerRegistrationRow {
  player_id: string; // Resolved
  team_id: string; // Resolved
  season_id: string; // Resolved
  squad_number: number | null;
  position: string | null;
  is_active: boolean;
}

export function mapSquadToPlayers(
  squad: ApiSquad,
): { player: PlayerRow; registration: Partial<PlayerRegistrationRow> }[] {
  return squad.players.map((p: ApiSquadPlayer) => ({
    player: {
      slug: slugify(p.name),
      full_name: p.name,
      short_name: null,
      primary_position: p.position ?? null,
      photo_url: p.photo ?? null,
      external_provider: PROVIDER,
      external_player_id: String(p.id),
      is_active: true,
      metadata: {
        api_team_id: squad.team.id,
        api_age: p.age,
      },
    },
    registration: {
      squad_number: p.number ?? null,
      position: p.position ?? null,
      is_active: true,
    },
  }));
}
