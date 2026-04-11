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

type SyncCompetition = {
  competition_id: string;
  slug: string;
  external_league_id: number;
  external_season: number;
  competition_type: string;
  gameweek_id: string;
  gameweek_number: number;
  deadline_at: string;
  topic: string;
};

type ApiFootballFixture = {
  fixture: {
    id: number;
    date?: string | null;
    status: {
      elapsed: number | null;
      short: string;
    };
  };
  league: {
    id: number;
    season: number;
    round?: string | null;
  };
  teams?: {
    home?: {
      id?: number | null;
      name?: string | null;
      logo?: string | null;
    };
    away?: {
      id?: number | null;
      name?: string | null;
      logo?: string | null;
    };
  };
  goals?: {
    home?: number | null;
    away?: number | null;
  };
};

type ApiFootballInjury = {
  player?: {
    id?: number | null;
    name?: string | null;
  };
  team?: {
    id?: number | null;
    name?: string | null;
  };
  injury?: {
    type?: string | null;
    reason?: string | null;
  };
};

export interface Env {
  FANTASY_KV: KVNamespace;
  RAPIDAPI_KEY: string;
  SUPABASE_EDGE_URL: string;
  SUPABASE_SERVICE_KEY: string;
}

const API_FOOTBALL_BASE = "https://api-football-v1.p.rapidapi.com/v3";
const CACHE_TTL_SECONDS = 90;
const DEADLINE_WINDOWS: Array<{ key: string; minutes: number }> = [
  { key: "24h", minutes: 24 * 60 },
  { key: "3h", minutes: 3 * 60 },
  { key: "30m", minutes: 30 },
];
const FANTASY_PROFILE_HEADERS = {
  "Accept-Profile": "fantasy",
  "Content-Profile": "fantasy",
};

function isLiveOrFinished(status: string) {
  return ["1H", "HT", "2H", "ET", "P", "FT", "AET", "PEN"].includes(status);
}

async function fetchJson<T>(
  request: RequestInfo,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(request, init);
  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
  return await response.json() as T;
}

async function fetchSupabaseRpc<T>(
  env: Env,
  rpcName: string,
  body: Record<string, unknown> = {},
): Promise<T> {
  return await fetchJson<T>(
    `${env.SUPABASE_EDGE_URL}/rest/v1/rpc/${rpcName}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: env.SUPABASE_SERVICE_KEY,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
        ...FANTASY_PROFILE_HEADERS,
      },
      body: JSON.stringify(body),
    },
  );
}

async function fetchSyncCompetitions(env: Env): Promise<SyncCompetition[]> {
  const cacheKey = "sync_competitions";
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return JSON.parse(cached) as SyncCompetition[];
  }

  const competitions = await fetchSupabaseRpc<SyncCompetition[]>(
    env,
    "fantasy_get_active_sync_competitions",
  );

  await env.FANTASY_KV.put(cacheKey, JSON.stringify(competitions), {
    expirationTtl: 60,
  });
  return competitions;
}

async function fetchFixtureEndpoint(
  env: Env,
  url: string,
): Promise<ApiFootballFixture[]> {
  const payload = await fetchJson<{ response?: ApiFootballFixture[] }>(url, {
    headers: {
      "x-rapidapi-key": env.RAPIDAPI_KEY,
      "x-rapidapi-host": "api-football-v1.p.rapidapi.com",
    },
  });
  return payload.response ?? [];
}

async function fetchFixturesBundle(
  leagueId: number,
  season: number,
  env: Env,
): Promise<ApiFootballFixture[]> {
  const cacheKey = `fixtures_bundle:${leagueId}:${season}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return JSON.parse(cached) as ApiFootballFixture[];
  }

  const endpoints = [
    `${API_FOOTBALL_BASE}/fixtures?live=all&league=${leagueId}&season=${season}`,
    `${API_FOOTBALL_BASE}/fixtures?league=${leagueId}&season=${season}&next=40`,
    `${API_FOOTBALL_BASE}/fixtures?league=${leagueId}&season=${season}&last=40`,
  ];
  const settled = await Promise.allSettled(
    endpoints.map((url) => fetchFixtureEndpoint(env, url)),
  );

  const deduped = new Map<number, ApiFootballFixture>();
  for (const result of settled) {
    if (result.status !== "fulfilled") {
      continue;
    }
    for (const fixture of result.value) {
      deduped.set(fixture.fixture.id, fixture);
    }
  }

  const fixtures = [...deduped.values()].sort((left, right) => {
    const leftDate = left.fixture.date == null
      ? Number.MAX_SAFE_INTEGER
      : Date.parse(left.fixture.date);
    const rightDate = right.fixture.date == null
      ? Number.MAX_SAFE_INTEGER
      : Date.parse(right.fixture.date);
    return leftDate - rightDate;
  });

  await env.FANTASY_KV.put(cacheKey, JSON.stringify(fixtures), {
    expirationTtl: CACHE_TTL_SECONDS,
  });

  return fixtures;
}

async function fetchPlayerStats(
  fixtureId: number,
  env: Env,
): Promise<any[]> {
  const cacheKey = `fixture_players:${fixtureId}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return JSON.parse(cached) as any[];
  }

  const payload = await fetchJson<{ response?: any[] }>(
    `${API_FOOTBALL_BASE}/fixtures/players?fixture=${fixtureId}`,
    {
      headers: {
        "x-rapidapi-key": env.RAPIDAPI_KEY,
        "x-rapidapi-host": "api-football-v1.p.rapidapi.com",
      },
    },
  );

  const stats = payload.response ?? [];
  await env.FANTASY_KV.put(cacheKey, JSON.stringify(stats), {
    expirationTtl: CACHE_TTL_SECONDS,
  });
  return stats;
}

async function fetchInjuries(
  leagueId: number,
  season: number,
  env: Env,
): Promise<ApiFootballInjury[]> {
  const cacheKey = `injuries:${leagueId}:${season}`;
  const cached = await env.FANTASY_KV.get(cacheKey);
  if (cached != null) {
    return JSON.parse(cached) as ApiFootballInjury[];
  }

  const payload = await fetchJson<{ response?: ApiFootballInjury[] }>(
    `${API_FOOTBALL_BASE}/injuries?league=${leagueId}&season=${season}`,
    {
      headers: {
        "x-rapidapi-key": env.RAPIDAPI_KEY,
        "x-rapidapi-host": "api-football-v1.p.rapidapi.com",
      },
    },
  );

  const injuries = payload.response ?? [];
  await env.FANTASY_KV.put(cacheKey, JSON.stringify(injuries), {
    expirationTtl: 600,
  });
  return injuries;
}

async function sendTopicAlert(
  env: Env,
  payload: {
    topic: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  },
) {
  const response = await fetch(
    `${env.SUPABASE_EDGE_URL}/functions/v1/fantasy-topic-alerts`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      },
      body: JSON.stringify(payload),
    },
  );

  if (!response.ok) {
    throw new Error(await response.text());
  }
}

async function dispatchDeadlineAlerts(
  env: Env,
  competition: SyncCompetition,
) {
  const deadlineAt = Date.parse(competition.deadline_at);
  if (!Number.isFinite(deadlineAt)) {
    return [];
  }

  const now = Date.now();
  const diffMinutes = Math.round((deadlineAt - now) / 60000);
  const alerts: string[] = [];

  for (const window of DEADLINE_WINDOWS) {
    if (diffMinutes <= 0 || diffMinutes > window.minutes) {
      continue;
    }

    const key = `deadline_alert:${competition.gameweek_id}:${window.key}`;
    const sent = await env.FANTASY_KV.get(key);
    if (sent != null) {
      continue;
    }

    const label = window.key === "24h"
      ? "24 hours"
      : window.key === "3h"
      ? "3 hours"
      : "30 minutes";

    await sendTopicAlert(env, {
      topic: competition.topic,
      title: "Fantasy deadline approaching",
      body: `${competition.slug.toUpperCase()} locks in ${label}. ` +
        `Finalize your squad for GW${competition.gameweek_number}.`,
      data: {
        type: "deadline_alert",
        competition_slug: competition.slug,
        gameweek_id: competition.gameweek_id,
        gameweek_number: String(competition.gameweek_number),
        window: window.key,
      },
    });

    await env.FANTASY_KV.put(key, new Date(now).toISOString(), {
      expirationTtl: 48 * 60 * 60,
    });
    alerts.push(window.key);
  }

  return alerts;
}

async function syncCompetition(
  env: Env,
  competition: SyncCompetition,
) {
  const [fixtures, injuries] = await Promise.all([
    fetchFixturesBundle(
      competition.external_league_id,
      competition.external_season,
      env,
    ),
    fetchInjuries(
      competition.external_league_id,
      competition.external_season,
      env,
    ).catch(() => [] as ApiFootballInjury[]),
  ]);

  const enrichedFixtures = await Promise.all(
    fixtures.map(async (fixture) => ({
      ...fixture,
      players: isLiveOrFinished(fixture.fixture.status.short)
        ? await fetchPlayerStats(fixture.fixture.id, env).catch(() => [])
        : [],
    })),
  );

  const ingestResponse = await fetch(
    `${env.SUPABASE_EDGE_URL}/functions/v1/fantasy-ingest`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      },
      body: JSON.stringify({
        fixtures: enrichedFixtures,
        injuries,
        gameweek_id: competition.gameweek_id,
      }),
    },
  );

  if (!ingestResponse.ok) {
    throw new Error(await ingestResponse.text());
  }

  const deadlineAlerts = await dispatchDeadlineAlerts(env, competition);

  return {
    competitionId: competition.competition_id,
    slug: competition.slug,
    gameweekId: competition.gameweek_id,
    fixtures: enrichedFixtures.length,
    injuries: injuries.length,
    deadlineAlerts,
    result: await ingestResponse.json(),
  };
}

async function runAllCompetitions(env: Env) {
  const competitions = await fetchSyncCompetitions(env);
  const settled = await Promise.allSettled(
    competitions.map((competition) => syncCompetition(env, competition)),
  );

  const completed = settled.flatMap((result) =>
    result.status === "fulfilled" ? [result.value] : []
  );
  const failed = settled.flatMap((result) =>
    result.status === "rejected"
      ? [
        result.reason instanceof Error
          ? result.reason.message
          : String(result.reason),
      ]
      : []
  );

  return {
    competitionCount: competitions.length,
    completed,
    failed,
  };
}

export default {
  async scheduled(
    _event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext,
  ) {
    ctx.waitUntil(
      runAllCompetitions(env).catch((error) =>
        console.error("fantasy-cron scheduled failed", error)
      ),
    );
  },

  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/trigger") {
      const task = runAllCompetitions(env);
      ctx.waitUntil(
        task.catch((error) =>
          console.error("fantasy-cron manual trigger failed", error)
        ),
      );
      return new Response(JSON.stringify({ accepted: true }), {
        status: 202,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      const competitions = await fetchSyncCompetitions(env).catch(() => []);
      return new Response(
        JSON.stringify({
          worker: "africlub-fantasy-cron",
          competitionCount: competitions.length,
          competitions,
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
