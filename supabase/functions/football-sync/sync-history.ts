import { logDiagnostic } from "../_shared/diagnostics.ts";
/**
 * sync-history — Backfills past results for tracked leagues.
 *
 * Fetches historical fixture data for a given season and updates
 * scores/statuses from API-Football. Uses date-range batching
 * to minimize API calls (free tier: 100/day).
 *
 * Strategy: Fetch fixtures with status=FT (finished) for each league
 * in a single call per league — the API returns all finished fixtures.
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { getFixtures, getRateLimit } from "./api-football-client.ts";
import { mapFixtureToFixture } from "./mappers.ts";

export interface SyncHistoryResult {
  league: string;
  fixtures_fetched: number;
  fixtures_upserted: number;
  api_requests_used: number;
  error?: string;
}

export async function syncHistory(
  adminClient: SupabaseClient,
  options: {
    leagueId?: number;
    seasonYear?: number;
    syncAll?: boolean;
  } = {},
): Promise<SyncHistoryResult[]> {
  const results: SyncHistoryResult[] = [];

  // Load configs — either specific league or all
  let query = adminClient
    .from("football_sync_config")
    .select("*")
    .eq("is_active", true);

  if (options.leagueId) {
    query = query.eq("external_league_id", String(options.leagueId));
  }

  const { data: configs, error: configError } = await query;
  if (configError || !configs || configs.length === 0) {
    logDiagnostic("error", "football_sync_sync_history__sync_history_no_sync_configs_found", configError);
    return [];
  }

  for (const config of configs) {
    const leagueId = Number(config.external_league_id);
    const seasonYear = options.seasonYear ??
      Number(config.season_year ?? new Date().getFullYear());
    const leagueName = config.league_name ?? `League ${leagueId}`;
    let apiRequestsUsed = 0;

    // Budget check
    const rateLimit = getRateLimit();
    if (rateLimit.dailyRemaining <= 5) {
      logDiagnostic("warn", "football_sync_sync_history__sync_history_near_daily_limit_stopping");
      results.push({
        league: leagueName,
        fixtures_fetched: 0,
        fixtures_upserted: 0,
        api_requests_used: 0,
        error: "Daily API limit nearly exhausted",
      });
      break;
    }

    try {
      // Fetch all finished fixtures for this league/season in one call
      const apiFixtures = await getFixtures({
        league: leagueId,
        season: seasonYear,
        status: "FT-AET-PEN-AWD-WO", // All "finished" variants
      });
      apiRequestsUsed++;

      if (apiFixtures.length === 0) {
        results.push({
          league: leagueName,
          fixtures_fetched: 0,
          fixtures_upserted: 0,
          api_requests_used: apiRequestsUsed,
        });
        continue;
      }

      // Resolve IDs
      const competitionId = await resolveCompetitionId(adminClient, leagueId);
      const seasonId = competitionId
        ? await resolveSeasonId(adminClient, competitionId, seasonYear)
        : null;

      if (!competitionId || !seasonId) {
        throw new Error(
          `Cannot resolve competition/season for league ${leagueId}`,
        );
      }

      let upsertedCount = 0;

      for (const apiFixture of apiFixtures) {
        const row = mapFixtureToFixture(apiFixture);

        // Resolve team IDs
        const homeTeamId = await resolveTeamId(
          adminClient,
          apiFixture.teams.home.id,
        );
        const awayTeamId = await resolveTeamId(
          adminClient,
          apiFixture.teams.away.id,
        );

        if (!homeTeamId || !awayTeamId) continue;

        const { error: upsertError } = await adminClient
          .schema("football")
          .from("fixtures")
          .upsert(
            {
              competition_id: competitionId,
              season_id: seasonId,
              stage_name: row.stage_name,
              group_name: row.group_name,
              round_name: row.round_name,
              kickoff_at: row.kickoff_at,
              venue_name: row.venue_name,
              venue_city: row.venue_city,
              home_team_id: homeTeamId,
              away_team_id: awayTeamId,
              home_score: row.home_score,
              away_score: row.away_score,
              status: row.status,
              external_provider: row.external_provider,
              external_fixture_id: row.external_fixture_id,
              metadata: row.metadata,
            },
            { onConflict: "external_provider,external_fixture_id" },
          );

        if (!upsertError) upsertedCount++;
      }

      results.push({
        league: leagueName,
        fixtures_fetched: apiFixtures.length,
        fixtures_upserted: upsertedCount,
        api_requests_used: apiRequestsUsed,
      });

      logDiagnostic("info", "football_sync_sync_history__sync_history");
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      logDiagnostic("error", "football_sync_sync_history__sync_history_error_for_league", errorMessage);
      results.push({
        league: leagueName,
        fixtures_fetched: 0,
        fixtures_upserted: 0,
        api_requests_used: apiRequestsUsed,
        error: errorMessage,
      });
    }
  }

  return results;
}

/* ---------- ID Resolution ---------- */

async function resolveCompetitionId(
  client: SupabaseClient,
  apiLeagueId: number,
): Promise<string | null> {
  const { data } = await client
    .schema("football")
    .from("competitions")
    .select("id")
    .eq("external_provider", "api-football")
    .eq("external_competition_id", String(apiLeagueId))
    .maybeSingle();
  return data?.id ?? null;
}

async function resolveSeasonId(
  client: SupabaseClient,
  competitionId: string,
  year: number,
): Promise<string | null> {
  const { data } = await client
    .schema("football")
    .from("seasons")
    .select("id")
    .eq("competition_id", competitionId)
    .or(`year_start.eq.${year},year_end.eq.${year}`)
    .order("year_start", { ascending: false })
    .limit(1)
    .maybeSingle();
  return data?.id ?? null;
}

async function resolveTeamId(
  client: SupabaseClient,
  apiTeamId: number,
): Promise<string | null> {
  const { data } = await client
    .schema("football")
    .from("teams")
    .select("id")
    .eq("external_provider", "api-football")
    .eq("external_team_id", String(apiTeamId))
    .maybeSingle();
  return data?.id ?? null;
}
