import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  HttpError,
  requireAdminCaller,
  requireCronSecret,
} from "../_shared/auth.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

import {
  getApiStatus,
  getRateLimit,
  searchLeagues,
} from "./api-football-client.ts";
import { mapLeagueToCompetition, mapSeasonToSeason } from "./mappers.ts";
import { syncFixtures } from "./sync-fixtures.ts";
import { syncStandings } from "./sync-standings.ts";
import { syncLive } from "./sync-live.ts";
import { autoSettleFinishedFixtures } from "./auto-settle.ts";
import { syncHistory } from "./sync-history.ts";
import { downloadLogos } from "./download-logos.ts";

/**
 * football-sync — Main edge function handler.
 *
 * Supports commands via JSON body or query param:
 *   - discover-leagues: Search API-Football for league IDs
 *   - register-league: Register a league for automatic sync
 *   - sync-fixtures: Batch-sync fixtures for all tracked leagues
 *   - sync-standings: Batch-sync standings
 *   - sync-live: Fetch live match details
 *   - sync-history: Backfill past results for tracked leagues
 *   - auto-settle: Settle predictions for finished fixtures
 *   - download-logos: Download logos to Supabase Storage
 *   - seed-leagues: Register all target leagues in one call
 *   - status: Check API quota and sync status
 *   - full-sync: Run fixtures + standings + auto-settle in sequence
 *
 * Auth:
 *   - Cron: CRON_JOB_SECRET header
 *   - Admin: Bearer token with admin role
 */

async function handler(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  try {
    // Parse command
    let command = "";
    let payload: Record<string, unknown> = {};

    if (request.method === "POST") {
      try {
        const body = await request.json();
        command = typeof body.command === "string" ? body.command : "";
        payload = body;
      } catch {
        // Empty body OK for cron
      }
    }

    // Allow GET with ?command= for admin testing
    if (!command) {
      const url = new URL(request.url);
      command = url.searchParams.get("command") ?? "";
    }

    if (!command) {
      return jsonError("Missing 'command' parameter", 400);
    }

    // Auth: either cron secret or admin user
    try {
      requireCronSecret(request);
    } catch {
      // Not cron — require admin auth
      await requireAdminCaller(request);
    }

    const adminClient = createAdminClient();

    switch (command) {
      case "discover-leagues":
        return await handleDiscoverLeagues(payload);

      case "register-league":
        return await handleRegisterLeague(adminClient, payload);

      case "sync-fixtures":
        return await handleSyncFixtures(adminClient);

      case "sync-standings":
        return await handleSyncStandings(adminClient);

      case "sync-live":
        return await handleSyncLive(adminClient);

      case "auto-settle":
        return await handleAutoSettle(adminClient);

      case "sync-history":
        return await handleSyncHistory(adminClient, payload);

      case "download-logos":
        return await handleDownloadLogos(adminClient);

      case "seed-leagues":
        return await handleSeedLeagues(adminClient, payload);

      case "full-sync":
        return await handleFullSync(adminClient);

      case "status":
        return await handleStatus(adminClient);

      default:
        return jsonError(`Unknown command: ${command}`, 400);
    }
  } catch (err) {
    if (err instanceof HttpError) {
      return jsonError(err.message, err.status);
    }
    logDiagnostic("error", "football_sync__football_sync_unhandled_error", err);
    return jsonError(
      err instanceof Error ? err.message : "Internal error",
      500,
    );
  }
}

/* ---------- Command Handlers ---------- */

async function handleDiscoverLeagues(
  payload: Record<string, unknown>,
): Promise<Response> {
  const search = typeof payload.search === "string"
    ? payload.search
    : undefined;
  const country = typeof payload.country === "string"
    ? payload.country
    : undefined;
  const id = typeof payload.id === "number" ? payload.id : undefined;

  const leagues = await searchLeagues({ search, country, id });

  const mapped = leagues.map((league) => ({
    api_league_id: league.league.id,
    name: league.league.name,
    type: league.league.type,
    country: league.country.name,
    country_code: league.country.code,
    logo: league.league.logo,
    current_season: league.seasons.find((s) => s.current)?.year ?? null,
    seasons_available: league.seasons.map((s) => s.year),
  }));

  return jsonOk({
    success: true,
    data: mapped,
    rate_limit: getRateLimit(),
  });
}

async function handleRegisterLeague(
  adminClient: ReturnType<typeof createAdminClient>,
  payload: Record<string, unknown>,
): Promise<Response> {
  const apiLeagueId = Number(payload.api_league_id);
  const seasonYear = Number(payload.season_year ?? new Date().getFullYear());
  const leagueName = typeof payload.league_name === "string"
    ? payload.league_name
    : `League ${apiLeagueId}`;

  if (!apiLeagueId || isNaN(apiLeagueId)) {
    return jsonError("api_league_id is required", 400);
  }

  // 1. Fetch league details from API to create competition + season
  const leagues = await searchLeagues({ id: apiLeagueId });
  if (leagues.length === 0) {
    return jsonError(`League ${apiLeagueId} not found in API-Football`, 404);
  }

  const league = leagues[0];
  const competitionRow = mapLeagueToCompetition(league);

  // 2. Upsert competition
  const { data: comp, error: compError } = await adminClient
    .schema("football")
    .from("competitions")
    .upsert(competitionRow, {
      onConflict: "external_provider,external_competition_id",
    })
    .select("id, slug")
    .single();

  if (compError) {
    return jsonError(`Failed to upsert competition: ${compError.message}`, 500);
  }

  // 3. Upsert season
  const currentSeason = league.seasons.find((s) => s.year === seasonYear) ??
    league.seasons.find((s) => s.current);

  if (currentSeason) {
    const seasonRow = mapSeasonToSeason(league, currentSeason, comp.slug);
    await adminClient
      .schema("football")
      .from("seasons")
      .upsert(
        {
          competition_id: comp.id,
          slug: seasonRow.slug,
          label: seasonRow.label,
          year_start: seasonRow.year_start,
          year_end: seasonRow.year_end,
          starts_on: seasonRow.starts_on,
          ends_on: seasonRow.ends_on,
          status: seasonRow.status,
          is_active: seasonRow.is_active,
          metadata: seasonRow.metadata,
        },
        { onConflict: "competition_id,label" },
      );
  }

  // 4. Create sync config
  const { data: syncConfig, error: syncError } = await adminClient
    .from("football_sync_config")
    .upsert(
      {
        competition_id: comp.id,
        external_provider: "api-football",
        external_league_id: String(apiLeagueId),
        league_name: leagueName,
        season_year: seasonYear,
        sync_fixtures: payload.sync_fixtures !== false,
        sync_standings: payload.sync_standings !== false,
        sync_live: payload.sync_live !== false,
        sync_squads: payload.sync_squads === true,
        is_active: true,
      },
      { onConflict: "external_provider,external_league_id" },
    )
    .select("id")
    .single();

  if (syncError) {
    return jsonError(
      `Failed to create sync config: ${syncError.message}`,
      500,
    );
  }

  return jsonOk({
    success: true,
    data: {
      sync_config_id: syncConfig?.id,
      competition_id: comp.id,
      competition_slug: comp.slug,
      api_league_id: apiLeagueId,
      league_name: leagueName,
      season_year: seasonYear,
    },
    rate_limit: getRateLimit(),
  });
}

async function handleSyncFixtures(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  const results = await syncFixtures(adminClient);

  // After fixture sync, auto-settle
  const settleResult = await autoSettleFinishedFixtures(adminClient);

  return jsonOk({
    success: true,
    data: {
      sync: results,
      settlement: settleResult,
    },
    rate_limit: getRateLimit(),
  });
}

async function handleSyncStandings(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  const results = await syncStandings(adminClient);
  return jsonOk({
    success: true,
    data: results,
    rate_limit: getRateLimit(),
  });
}

async function handleSyncLive(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  const results = await syncLive(adminClient);

  // Also auto-settle after live sync (captures newly-finished)
  const settleResult = await autoSettleFinishedFixtures(adminClient);

  return jsonOk({
    success: true,
    data: {
      live: results,
      settlement: settleResult,
    },
    rate_limit: getRateLimit(),
  });
}

async function handleAutoSettle(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  const results = await autoSettleFinishedFixtures(adminClient);
  return jsonOk({
    success: true,
    data: results,
    rate_limit: getRateLimit(),
  });
}

async function handleFullSync(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  const fixtureResults = await syncFixtures(adminClient);
  const standingResults = await syncStandings(adminClient);
  const liveResults = await syncLive(adminClient);
  const settleResult = await autoSettleFinishedFixtures(adminClient);

  return jsonOk({
    success: true,
    data: {
      fixtures: fixtureResults,
      standings: standingResults,
      live: liveResults,
      settlement: settleResult,
    },
    rate_limit: getRateLimit(),
  });
}

async function handleStatus(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  // Get sync configs
  const { data: configs } = await adminClient
    .from("football_sync_config")
    .select("*")
    .eq("is_active", true)
    .order("league_name", { ascending: true });

  // Get recent sync logs
  const { data: logs } = await adminClient
    .from("football_sync_log")
    .select("*")
    .order("started_at", { ascending: false })
    .limit(20);

  // Try to get API status (doesn't count against quota)
  let apiStatus = null;
  try {
    apiStatus = await getApiStatus();
  } catch {
    // API status check is optional
  }

  return jsonOk({
    success: true,
    data: {
      tracked_leagues: configs ?? [],
      recent_logs: logs ?? [],
      api_status: apiStatus,
      rate_limit: getRateLimit(),
    },
  });
}

async function handleSyncHistory(
  adminClient: ReturnType<typeof createAdminClient>,
  payload: Record<string, unknown>,
): Promise<Response> {
  const leagueId = typeof payload.league_id === "number"
    ? payload.league_id
    : undefined;
  const seasonYear = typeof payload.season_year === "number"
    ? payload.season_year
    : undefined;

  const results = await syncHistory(adminClient, {
    leagueId,
    seasonYear,
    syncAll: !leagueId,
  });

  // Auto-settle after backfill
  const settleResult = await autoSettleFinishedFixtures(adminClient);

  return jsonOk({
    success: true,
    data: { history: results, settlement: settleResult },
    rate_limit: getRateLimit(),
  });
}

async function handleDownloadLogos(
  adminClient: ReturnType<typeof createAdminClient>,
): Promise<Response> {
  const results = await downloadLogos(adminClient);
  return jsonOk({
    success: true,
    data: results,
    rate_limit: getRateLimit(),
  });
}

/**
 * Target leagues for Africlub:
 *
 * Known API-Football IDs (these are well-documented):
 *   1 = FIFA World Cup
 *   2 = UEFA Champions League
 *   39 = English Premier League
 *   140 = La Liga
 *
 * African leagues — IDs will be discovered via API:
 *   Rwanda, DRC, Zambia, Ghana, Ivory Coast,
 *   Kenya, Tanzania, Uganda, Malawi
 */
const TARGET_LEAGUES: Array<{
  api_league_id: number | null;
  name: string;
  country: string | null;
  search: string | null;
  season_year: number;
}> = [
  // Tier 1: International + European
  {
    api_league_id: 1,
    name: "FIFA World Cup 2026",
    country: null,
    search: null,
    season_year: 2026,
  },
  {
    api_league_id: 2,
    name: "UEFA Champions League",
    country: null,
    search: null,
    season_year: 2025,
  },
  {
    api_league_id: 39,
    name: "English Premier League",
    country: null,
    search: null,
    season_year: 2025,
  },
  {
    api_league_id: 140,
    name: "La Liga",
    country: null,
    search: null,
    season_year: 2025,
  },

  // Tier 2: Core African markets (known seeds)
  {
    api_league_id: null,
    name: "Rwanda Premier League",
    country: "Rwanda",
    search: "Premier League",
    season_year: 2025,
  },
  {
    api_league_id: 424,
    name: "Linafoot",
    country: "Congo-DR",
    search: "Ligue 1",
    season_year: 2025,
  },
  {
    api_league_id: null,
    name: "Zambia Super League",
    country: "Zambia",
    search: "Super League",
    season_year: 2025,
  },

  // Tier 3: Expanded African coverage
  {
    api_league_id: null,
    name: "Ghana Premier League",
    country: "Ghana",
    search: "Premier League",
    season_year: 2025,
  },
  {
    api_league_id: null,
    name: "Ligue 1 Côte d'Ivoire",
    country: "Ivory-Coast",
    search: "Ligue 1",
    season_year: 2025,
  },
  {
    api_league_id: null,
    name: "Kenya Premier League",
    country: "Kenya",
    search: "Premier League",
    season_year: 2025,
  },
  {
    api_league_id: null,
    name: "Tanzania Premier League",
    country: "Tanzania",
    search: "Premier League",
    season_year: 2025,
  },
  {
    api_league_id: null,
    name: "Uganda Premier League",
    country: "Uganda",
    search: "Premier League",
    season_year: 2025,
  },
  {
    api_league_id: null,
    name: "Malawi Super League",
    country: "Malawi",
    search: "Super League",
    season_year: 2025,
  },
];

async function handleSeedLeagues(
  adminClient: ReturnType<typeof createAdminClient>,
  payload: Record<string, unknown>,
): Promise<Response> {
  const dryRun = payload.dry_run === true;
  const results: Array<{
    name: string;
    api_league_id: number | null;
    status: string;
    error?: string;
  }> = [];

  for (const target of TARGET_LEAGUES) {
    const rateLimit = getRateLimit();
    if (rateLimit.dailyRemaining <= 5) {
      results.push({
        name: target.name,
        api_league_id: target.api_league_id,
        status: "skipped_rate_limit",
      });
      continue;
    }

    try {
      let apiLeagueId = target.api_league_id;

      // Discover league ID if not known
      if (!apiLeagueId && target.country) {
        const discovered = await searchLeagues({ country: target.country });
        // Find the best match
        const match = discovered.find((l) => {
          const name = l.league.name.toLowerCase();
          const search = (target.search ?? "").toLowerCase();
          return (
            name.includes(search) &&
            l.league.type === "League" &&
            l.seasons.some((s) => s.current)
          );
        }) ?? discovered.find((l) =>
          l.league.type === "League" && l.seasons.some((s) =>
            s.current
          )
        );

        if (match) {
          apiLeagueId = match.league.id;
        } else {
          results.push({
            name: target.name,
            api_league_id: null,
            status: "not_found",
            error:
              `No matching league found in ${target.country}. ${discovered.length} leagues returned.`,
          });
          continue;
        }
      }

      if (!apiLeagueId) {
        results.push({
          name: target.name,
          api_league_id: null,
          status: "error",
          error: "No API league ID resolved",
        });
        continue;
      }

      if (dryRun) {
        results.push({
          name: target.name,
          api_league_id: apiLeagueId,
          status: "dry_run_ok",
        });
        continue;
      }

      // Register the league
      const registerResponse = await handleRegisterLeague(adminClient, {
        api_league_id: apiLeagueId,
        league_name: target.name,
        season_year: target.season_year,
        sync_fixtures: true,
        sync_standings: true,
        sync_live: true,
      });

      const registerBody = await registerResponse.json();

      results.push({
        name: target.name,
        api_league_id: apiLeagueId,
        status: registerBody.success ? "registered" : "error",
        error: registerBody.success ? undefined : registerBody.error,
      });
    } catch (err) {
      results.push({
        name: target.name,
        api_league_id: target.api_league_id,
        status: "error",
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  return jsonOk({
    success: true,
    data: {
      leagues: results,
      total: results.length,
      registered: results.filter((r) => r.status === "registered").length,
      errors: results.filter((r) => r.status === "error").length,
    },
    rate_limit: getRateLimit(),
  });
}

/* ---------- Server ---------- */

if (import.meta.main) {
  Deno.serve((req: Request) =>
    handler(req).then(
      (res) =>
        new Response(res.body, {
          status: res.status,
          statusText: res.statusText,
          headers: {
            ...Object.fromEntries(res.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  );
}
