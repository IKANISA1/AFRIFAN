interface KVNamespace {
  get(key: string): Promise<string | null>;
  put(
    key: string,
    value: string,
    options?: { expirationTtl?: number },
  ): Promise<void>;
}

type ScheduledEvent = {
  cron: string;
  scheduledTime: number;
};

interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
}

export interface Env {
  FANTASY_KV: KVNamespace;
  RAPIDAPI_KEY: string;
  SUPABASE_EDGE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  ACTIVE_COMPETITION_SLUG: string;
  API_FOOTBALL_LEAGUE_ID: string;
  API_FOOTBALL_SEASON: string;
}

const API_FOOTBALL_BASE = "https://api-football-v1.p.rapidapi.com/v3";
const CACHE_TTL_SECONDS = 90;
const FANTASY_PROFILE_HEADERS = {
  "Accept-Profile": "fantasy",
  "Content-Profile": "fantasy",
};

async function fetchJson<T>(request: RequestInfo, init?: RequestInit): Promise<T> {
  const response = await fetch(request, init);
  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
  return await response.json() as T;
}

async function fetchLiveFixtures(env: Env): Promise<any[]> {
  const cacheKey = `live_fixtures:${env.API_FOOTBALL_LEAGUE_ID}:${env.API_FOOTBALL_SEASON}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return JSON.parse(cached) as any[];
  }

  const url =
    `${API_FOOTBALL_BASE}/fixtures?live=all&league=${env.API_FOOTBALL_LEAGUE_ID}&season=${env.API_FOOTBALL_SEASON}`;
  const payload = await fetchJson<{ response?: any[] }>(url, {
    headers: {
      "x-rapidapi-key": env.RAPIDAPI_KEY,
      "x-rapidapi-host": "api-football-v1.p.rapidapi.com",
    },
  });

  const fixtures = payload.response ?? [];
  await env.FANTASY_KV.put(cacheKey, JSON.stringify(fixtures), {
    expirationTtl: CACHE_TTL_SECONDS,
  });

  return fixtures;
}

async function fetchPlayerStats(fixtureId: number, env: Env): Promise<any[]> {
  const cacheKey = `fixture_players:${fixtureId}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return JSON.parse(cached) as any[];
  }

  const url = `${API_FOOTBALL_BASE}/fixtures/players?fixture=${fixtureId}`;
  const payload = await fetchJson<{ response?: any[] }>(url, {
    headers: {
      "x-rapidapi-key": env.RAPIDAPI_KEY,
      "x-rapidapi-host": "api-football-v1.p.rapidapi.com",
    },
  });

  const stats = payload.response ?? [];
  await env.FANTASY_KV.put(cacheKey, JSON.stringify(stats), {
    expirationTtl: CACHE_TTL_SECONDS,
  });

  return stats;
}

async function getCompetitionId(env: Env): Promise<string | null> {
  const cacheKey = `competition_id:${env.ACTIVE_COMPETITION_SLUG}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return cached;
  }

  const url =
    `${env.SUPABASE_EDGE_URL}/rest/v1/competitions?slug=eq.${encodeURIComponent(env.ACTIVE_COMPETITION_SLUG)}&select=id&limit=1`;
  const rows = await fetchJson<Array<{ id: string }>>(url, {
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      ...FANTASY_PROFILE_HEADERS,
    },
  });

  const competitionId = rows[0]?.id ?? null;
  if (competitionId != null) {
    await env.FANTASY_KV.put(cacheKey, competitionId, { expirationTtl: 600 });
  }
  return competitionId;
}

async function getActiveGameweekId(env: Env): Promise<string | null> {
  const cacheKey = `active_gw:${env.ACTIVE_COMPETITION_SLUG}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return cached;
  }

  const competitionId = await getCompetitionId(env);
  if (competitionId == null) {
    return null;
  }

  const url =
    `${env.SUPABASE_EDGE_URL}/rest/v1/gameweeks?competition_id=eq.${competitionId}&status=in.(live,upcoming)&select=id&order=number.asc&limit=1`;
  const rows = await fetchJson<Array<{ id: string }>>(url, {
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      ...FANTASY_PROFILE_HEADERS,
    },
  });

  const gameweekId = rows[0]?.id ?? null;
  if (gameweekId != null) {
    await env.FANTASY_KV.put(cacheKey, gameweekId, { expirationTtl: 300 });
  }
  return gameweekId;
}

async function runIngest(env: Env) {
  const [fixtures, gameweekId] = await Promise.all([
    fetchLiveFixtures(env),
    getActiveGameweekId(env),
  ]);

  if (gameweekId == null || fixtures.length == 0) {
    return { triggered: false, gameweekId, fixtures: fixtures.length };
  }

  const fixtureStats = await Promise.all(
    fixtures.map(async (fixture) => ({
      ...fixture,
      players: await fetchPlayerStats(fixture.fixture.id as number, env),
    })),
  );

  const response = await fetch(`${env.SUPABASE_EDGE_URL}/functions/v1/fantasy-ingest`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
    },
    body: JSON.stringify({
      fixtures: fixtureStats,
      gameweek_id: gameweekId,
    }),
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  return {
    triggered: true,
    gameweekId,
    fixtures: fixtures.length,
    result: await response.json(),
  };
}

export default {
  async scheduled(
    _event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext,
  ) {
    ctx.waitUntil(runIngest(env).catch((error) => console.error("fantasy-cron scheduled failed", error)));
  },

  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/trigger") {
      const task = runIngest(env);
      ctx.waitUntil(task.catch((error) => console.error("fantasy-cron manual trigger failed", error)));
      return new Response(JSON.stringify({ accepted: true }), {
        status: 202,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      const competitionId = await getCompetitionId(env);
      const gameweekId = await getActiveGameweekId(env);
      return new Response(
        JSON.stringify({
          worker: "africlub-fantasy-cron",
          competitionId,
          gameweekId,
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    return new Response("Fantasy Cron Worker", { status: 200 });
  },
};
