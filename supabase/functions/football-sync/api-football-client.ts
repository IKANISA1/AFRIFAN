/**
 * API-Football v3 — Type-safe HTTP client
 *
 * Base URL: https://v3.football.api-sports.io/
 * Auth header: x-apisports-key
 * Rate limits tracked via response headers.
 */

const BASE_URL = "https://v3.football.api-sports.io";

/* ---------- Rate-limit tracking ---------- */

export interface RateLimitInfo {
  dailyLimit: number;
  dailyRemaining: number;
  minuteLimit: number;
  minuteRemaining: number;
}

let lastKnownRateLimit: RateLimitInfo = {
  dailyLimit: 100,
  dailyRemaining: 100,
  minuteLimit: 10,
  minuteRemaining: 10,
};

export function getRateLimit(): Readonly<RateLimitInfo> {
  return { ...lastKnownRateLimit };
}

function parseRateLimits(headers: Headers): void {
  const dailyLimit = headers.get("x-ratelimit-requests-limit");
  const dailyRemaining = headers.get("x-ratelimit-requests-remaining");
  const minuteLimit = headers.get("X-RateLimit-Limit");
  const minuteRemaining = headers.get("X-RateLimit-Remaining");

  if (dailyLimit != null) lastKnownRateLimit.dailyLimit = Number(dailyLimit);
  if (dailyRemaining != null) lastKnownRateLimit.dailyRemaining = Number(dailyRemaining);
  if (minuteLimit != null) lastKnownRateLimit.minuteLimit = Number(minuteLimit);
  if (minuteRemaining != null) lastKnownRateLimit.minuteRemaining = Number(minuteRemaining);
}

/* ---------- Core fetch ---------- */

export class ApiFootballError extends Error {
  constructor(
    public readonly endpoint: string,
    public readonly status: number,
    message: string,
  ) {
    super(`API-Football [${endpoint}] ${status}: ${message}`);
  }
}

export class RateLimitExceededError extends ApiFootballError {
  constructor(endpoint: string) {
    super(endpoint, 429, "Rate limit exceeded");
  }
}

function getApiKey(): string {
  const key = Deno.env.get("API_FOOTBALL_KEY")?.trim();
  if (!key) {
    throw new Error("Missing API_FOOTBALL_KEY environment variable");
  }
  return key;
}

async function apiFetch<T>(
  endpoint: string,
  params: Record<string, string | number | boolean> = {},
  options: { maxRetries?: number; retryDelayMs?: number } = {},
): Promise<{ response: T[]; paging?: { current: number; total: number } }> {
  const maxRetries = options.maxRetries ?? 2;
  const retryDelayMs = options.retryDelayMs ?? 1000;

  // Pre-flight: refuse if we know we're out of budget
  if (lastKnownRateLimit.dailyRemaining <= 0) {
    throw new RateLimitExceededError(endpoint);
  }
  if (lastKnownRateLimit.minuteRemaining <= 0) {
    // Wait 60s if minute limit exhausted
    console.warn(`[api-football] Minute limit exhausted, waiting 60s before ${endpoint}`);
    await sleep(60_000);
  }

  const url = new URL(`${BASE_URL}/${endpoint}`);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, String(value));
  }

  let lastError: Error | null = null;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      const delay = retryDelayMs * Math.pow(2, attempt - 1);
      console.warn(`[api-football] Retry ${attempt}/${maxRetries} for ${endpoint} in ${delay}ms`);
      await sleep(delay);
    }

    try {
      const res = await fetch(url.toString(), {
        method: "GET",
        headers: {
          "x-apisports-key": getApiKey(),
        },
      });

      parseRateLimits(res.headers);

      if (res.status === 429) {
        throw new RateLimitExceededError(endpoint);
      }

      if (!res.ok) {
        const text = await res.text();
        throw new ApiFootballError(endpoint, res.status, text);
      }

      const json = await res.json();

      // API-Football returns { get, parameters, errors, results, paging, response }
      if (json.errors && Object.keys(json.errors).length > 0) {
        const errorMessages = Object.values(json.errors).join("; ");
        throw new ApiFootballError(endpoint, 200, `API errors: ${errorMessages}`);
      }

      return {
        response: Array.isArray(json.response) ? json.response : [],
        paging: json.paging ?? undefined,
      };
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      if (err instanceof RateLimitExceededError) {
        throw err; // Don't retry rate limits
      }
    }
  }

  throw lastError ?? new Error(`Failed to fetch ${endpoint}`);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/* ---------- Response types ---------- */

export interface ApiLeague {
  league: {
    id: number;
    name: string;
    type: string; // "League" | "Cup"
    logo: string;
  };
  country: {
    name: string;
    code: string | null;
    flag: string | null;
  };
  seasons: Array<{
    year: number;
    start: string;
    end: string;
    current: boolean;
    coverage: Record<string, unknown>;
  }>;
}

export interface ApiTeam {
  team: {
    id: number;
    name: string;
    code: string | null;
    country: string;
    founded: number | null;
    national: boolean;
    logo: string;
  };
  venue: {
    id: number | null;
    name: string | null;
    city: string | null;
    capacity: number | null;
  } | null;
}

export interface ApiFixture {
  fixture: {
    id: number;
    referee: string | null;
    timezone: string;
    date: string;
    timestamp: number;
    venue: {
      id: number | null;
      name: string | null;
      city: string | null;
    } | null;
    status: {
      long: string;
      short: string;
      elapsed: number | null;
      extra: number | null;
    };
  };
  league: {
    id: number;
    name: string;
    country: string;
    logo: string;
    flag: string | null;
    season: number;
    round: string;
  };
  teams: {
    home: { id: number; name: string; logo: string; winner: boolean | null };
    away: { id: number; name: string; logo: string; winner: boolean | null };
  };
  goals: {
    home: number | null;
    away: number | null;
  };
  score: {
    halftime: { home: number | null; away: number | null };
    fulltime: { home: number | null; away: number | null };
    extratime: { home: number | null; away: number | null } | null;
    penalty: { home: number | null; away: number | null } | null;
  };
}

export interface ApiStanding {
  league: {
    id: number;
    name: string;
    country: string;
    logo: string;
    flag: string | null;
    season: number;
    standings: Array<
      Array<{
        rank: number;
        team: { id: number; name: string; logo: string };
        points: number;
        goalsDiff: number;
        group: string;
        form: string | null;
        status: string;
        description: string | null;
        all: {
          played: number;
          win: number;
          draw: number;
          lose: number;
          goals: { for: number; against: number };
        };
        home: {
          played: number;
          win: number;
          draw: number;
          lose: number;
          goals: { for: number; against: number };
        };
        away: {
          played: number;
          win: number;
          draw: number;
          lose: number;
          goals: { for: number; against: number };
        };
        update: string;
      }>
    >;
  };
}

export interface ApiFixtureStatistic {
  team: { id: number; name: string; logo: string };
  statistics: Array<{ type: string; value: string | number | null }>;
}

export interface ApiFixtureEvent {
  time: { elapsed: number; extra: number | null };
  team: { id: number; name: string; logo: string };
  player: { id: number | null; name: string | null };
  assist: { id: number | null; name: string | null };
  type: string;
  detail: string;
  comments: string | null;
}

export interface ApiFixtureLineup {
  team: { id: number; name: string; logo: string };
  formation: string | null;
  coach: { id: number | null; name: string | null; photo: string | null };
  startXI: Array<{
    player: { id: number; name: string; number: number; pos: string | null; grid: string | null };
  }>;
  substitutes: Array<{
    player: { id: number; name: string; number: number; pos: string | null; grid: string | null };
  }>;
}

export interface ApiPlayer {
  player: {
    id: number;
    name: string;
    firstname: string | null;
    lastname: string | null;
    age: number | null;
    birth: { date: string | null; place: string | null; country: string | null } | null;
    nationality: string | null;
    height: string | null;
    weight: string | null;
    photo: string;
    injured: boolean;
  };
  statistics: Array<{
    team: { id: number; name: string; logo: string };
    league: { id: number; name: string };
    games: {
      position: string | null;
      number: number | null;
    };
  }>;
}

export interface ApiSquadPlayer {
  id: number;
  name: string;
  age: number | null;
  number: number | null;
  position: string;
  photo: string;
}

export interface ApiSquad {
  team: { id: number; name: string; logo: string };
  players: ApiSquadPlayer[];
}

/* ---------- Public API methods ---------- */

export async function searchLeagues(
  params: { search?: string; country?: string; id?: number; season?: number; current?: boolean } = {},
): Promise<ApiLeague[]> {
  const queryParams: Record<string, string | number | boolean> = {};
  if (params.search) queryParams.search = params.search;
  if (params.country) queryParams.country = params.country;
  if (params.id != null) queryParams.id = params.id;
  if (params.season != null) queryParams.season = params.season;
  if (params.current != null) queryParams.current = params.current;

  const { response } = await apiFetch<ApiLeague>("leagues", queryParams);
  return response;
}

export async function getTeams(
  params: { league: number; season: number },
): Promise<ApiTeam[]> {
  const { response } = await apiFetch<ApiTeam>("teams", {
    league: params.league,
    season: params.season,
  });
  return response;
}

export async function getFixtures(
  params: {
    league?: number;
    season?: number;
    date?: string;
    from?: string;
    to?: string;
    team?: number;
    status?: string;
    live?: string;
    ids?: string;
  },
): Promise<ApiFixture[]> {
  const queryParams: Record<string, string | number | boolean> = {};
  if (params.league != null) queryParams.league = params.league;
  if (params.season != null) queryParams.season = params.season;
  if (params.date) queryParams.date = params.date;
  if (params.from) queryParams.from = params.from;
  if (params.to) queryParams.to = params.to;
  if (params.team != null) queryParams.team = params.team;
  if (params.status) queryParams.status = params.status;
  if (params.live) queryParams.live = params.live;
  if (params.ids) queryParams.ids = params.ids;

  const { response } = await apiFetch<ApiFixture>("fixtures", queryParams);
  return response;
}

export async function getStandings(
  params: { league: number; season: number },
): Promise<ApiStanding[]> {
  const { response } = await apiFetch<ApiStanding>("standings", {
    league: params.league,
    season: params.season,
  });
  return response;
}

export async function getFixtureStatistics(
  fixtureId: number,
): Promise<ApiFixtureStatistic[]> {
  const { response } = await apiFetch<ApiFixtureStatistic>("fixtures/statistics", {
    fixture: fixtureId,
  });
  return response;
}

export async function getFixtureEvents(
  fixtureId: number,
): Promise<ApiFixtureEvent[]> {
  const { response } = await apiFetch<ApiFixtureEvent>("fixtures/events", {
    fixture: fixtureId,
  });
  return response;
}

export async function getFixtureLineups(
  fixtureId: number,
): Promise<ApiFixtureLineup[]> {
  const { response } = await apiFetch<ApiFixtureLineup>("fixtures/lineups", {
    fixture: fixtureId,
  });
  return response;
}

export async function getSquads(
  params: { team: number },
): Promise<ApiSquad[]> {
  const { response } = await apiFetch<ApiSquad>("players/squads", {
    team: params.team,
  });
  return response;
}

export async function getApiStatus(): Promise<{
  account: { firstname: string; lastname: string; email: string };
  subscription: { plan: string; end: string; active: boolean };
  requests: { current: number; limit_day: number };
}> {
  const { response } = await apiFetch<Record<string, unknown>>("status");
  const first = response[0] ?? {};
  return first as ReturnType<typeof getApiStatus> extends Promise<infer U> ? U : never;
}
