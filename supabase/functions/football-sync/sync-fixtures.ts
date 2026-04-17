/**
 * sync-fixtures — Batch-syncs fixtures for all tracked leagues.
 *
 * 1. Reads `football.sync_config` for active leagues
 * 2. For each league: calls API-Football GET /fixtures
 * 3. Resolves team IDs (upserts teams if new)
 * 4. Upserts into `football.fixtures`
 * 5. Updates sync_config + sync_log
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  getFixtures,
  getTeams,
  getRateLimit,
  type ApiFixture,
  type ApiTeam,
} from "./api-football-client.ts";
import {
  mapFixtureToFixture,
  mapTeamToTeam,
  type FixtureRow,
} from "./mappers.ts";

export interface SyncFixturesResult {
  league: string;
  fixtures_fetched: number;
  fixtures_upserted: number;
  teams_upserted: number;
  api_requests_used: number;
  error?: string;
}

export async function syncFixtures(
  adminClient: SupabaseClient,
): Promise<SyncFixturesResult[]> {
  const results: SyncFixturesResult[] = [];

  // 1. Load tracked leagues
  const { data: configs, error: configError } = await adminClient
    .from("football_sync_config")
    .select("*")
    .eq("sync_fixtures", true)
    .eq("is_active", true);

  if (configError || !configs) {
    console.error("[sync-fixtures] Failed to load sync configs:", configError);
    return [];
  }

  for (const config of configs) {
    const leagueId = Number(config.external_league_id);
    const seasonYear = Number(config.season_year ?? new Date().getFullYear());
    const leagueName = config.league_name ?? `League ${leagueId}`;

    let apiRequestsUsed = 0;
    const logId = await createSyncLog(adminClient, config.id, "fixtures");

    try {
      // 2. Fetch fixtures from API
      const apiFixtures = await getFixtures({
        league: leagueId,
        season: seasonYear,
      });
      apiRequestsUsed++;

      if (apiFixtures.length === 0) {
        await completeSyncLog(adminClient, logId, 0, 0, apiRequestsUsed);
        results.push({
          league: leagueName,
          fixtures_fetched: 0,
          fixtures_upserted: 0,
          teams_upserted: 0,
          api_requests_used: apiRequestsUsed,
        });
        continue;
      }

      // 3. Ensure all teams exist
      const teamsUpserted = await ensureTeamsExist(
        adminClient,
        apiFixtures,
        leagueId,
        seasonYear,
      );
      if (teamsUpserted.apiRequestsUsed > 0) {
        apiRequestsUsed += teamsUpserted.apiRequestsUsed;
      }

      // 4. Resolve competition + season IDs
      const competitionId = await resolveCompetitionId(
        adminClient,
        leagueId,
      );
      const seasonId = await resolveSeasonId(
        adminClient,
        competitionId,
        seasonYear,
      );

      if (!competitionId || !seasonId) {
        throw new Error(
          `Cannot resolve competition/season for league ${leagueId} season ${seasonYear}`,
        );
      }

      // 5. Build fixture rows with resolved IDs
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

        if (!homeTeamId || !awayTeamId) {
          console.warn(
            `[sync-fixtures] Skipping fixture ${apiFixture.fixture.id}: cannot resolve team(s)`,
          );
          continue;
        }

        // Upsert fixture
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

        if (upsertError) {
          console.error(
            `[sync-fixtures] Upsert error for fixture ${apiFixture.fixture.id}:`,
            upsertError.message,
          );
        } else {
          upsertedCount++;
        }
      }

      // 6. Update sync_config
      await adminClient
        .from("football_sync_config")
        .update({
          last_synced_at: new Date().toISOString(),
          sync_status: "idle",
        })
        .eq("id", config.id);

      await completeSyncLog(
        adminClient,
        logId,
        apiFixtures.length,
        upsertedCount,
        apiRequestsUsed,
      );

      results.push({
        league: leagueName,
        fixtures_fetched: apiFixtures.length,
        fixtures_upserted: upsertedCount,
        teams_upserted: teamsUpserted.count,
        api_requests_used: apiRequestsUsed,
      });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error(`[sync-fixtures] Error for league ${leagueId}:`, errorMessage);

      await failSyncLog(adminClient, logId, errorMessage, apiRequestsUsed);

      results.push({
        league: leagueName,
        fixtures_fetched: 0,
        fixtures_upserted: 0,
        teams_upserted: 0,
        api_requests_used: apiRequestsUsed,
        error: errorMessage,
      });
    }

    // Budget check
    const rateLimit = getRateLimit();
    if (rateLimit.dailyRemaining <= 5) {
      console.warn("[sync-fixtures] Near daily limit, stopping.");
      break;
    }
  }

  return results;
}

/* ---------- Helpers ---------- */

async function ensureTeamsExist(
  client: SupabaseClient,
  fixtures: ApiFixture[],
  leagueId: number,
  seasonYear: number,
): Promise<{ count: number; apiRequestsUsed: number }> {
  const apiTeamIds = new Set<number>();
  for (const f of fixtures) {
    apiTeamIds.add(f.teams.home.id);
    apiTeamIds.add(f.teams.away.id);
  }

  // Check which teams already exist
  const { data: existingTeams } = await client
    .schema("football")
    .from("teams")
    .select("external_team_id")
    .eq("external_provider", "api-football")
    .in(
      "external_team_id",
      Array.from(apiTeamIds).map(String),
    );

  const existingIds = new Set(
    (existingTeams ?? []).map((t: Record<string, string>) => t.external_team_id),
  );

  const missingIds = Array.from(apiTeamIds).filter(
    (id) => !existingIds.has(String(id)),
  );

  if (missingIds.length === 0) {
    return { count: 0, apiRequestsUsed: 0 };
  }

  // Fetch full team data from API — batch via league endpoint
  let apiRequestsUsed = 0;
  let upsertedCount = 0;

  try {
    const apiTeams = await getTeams({ league: leagueId, season: seasonYear });
    apiRequestsUsed++;

    for (const apiTeam of apiTeams) {
      if (!missingIds.includes(apiTeam.team.id)) continue;

      const row = mapTeamToTeam(apiTeam);
      const { error } = await client
        .schema("football")
        .from("teams")
        .upsert(row, { onConflict: "external_provider,external_team_id" });

      if (!error) upsertedCount++;
    }
  } catch (err) {
    console.error("[sync-fixtures] Team fetch error:", err);
    // Fall back to creating stub teams from fixture data
    for (const fixture of fixtures) {
      for (const team of [fixture.teams.home, fixture.teams.away]) {
        if (!missingIds.includes(team.id)) continue;

        const slug = team.name.toLowerCase().replace(/[^a-z0-9]+/g, "-");
        const { error } = await client
          .schema("football")
          .from("teams")
          .upsert(
            {
              slug,
              name: team.name,
              short_name: null,
              team_type: "club",
              crest_url: team.logo,
              external_provider: "api-football",
              external_team_id: String(team.id),
              is_active: true,
              metadata: { api_logo: team.logo },
            },
            { onConflict: "external_provider,external_team_id" },
          );

        if (!error) upsertedCount++;
      }
    }
  }

  return { count: upsertedCount, apiRequestsUsed };
}

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
  competitionId: string | null,
  year: number,
): Promise<string | null> {
  if (!competitionId) return null;

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

async function createSyncLog(
  client: SupabaseClient,
  syncConfigId: string,
  syncType: string,
): Promise<string> {
  const { data } = await client
    .from("football_sync_log")
    .insert({
      sync_config_id: syncConfigId,
      sync_type: syncType,
      status: "started",
    })
    .select("id")
    .single();

  return data?.id ?? "";
}

async function completeSyncLog(
  client: SupabaseClient,
  logId: string,
  fetched: number,
  upserted: number,
  apiRequests: number,
): Promise<void> {
  if (!logId) return;
  await client
    .from("football_sync_log")
    .update({
      status: "completed",
      records_fetched: fetched,
      records_upserted: upserted,
      api_requests_used: apiRequests,
      completed_at: new Date().toISOString(),
    })
    .eq("id", logId);
}

async function failSyncLog(
  client: SupabaseClient,
  logId: string,
  errorMessage: string,
  apiRequests: number,
): Promise<void> {
  if (!logId) return;
  await client
    .from("football_sync_log")
    .update({
      status: "failed",
      error_message: errorMessage,
      api_requests_used: apiRequests,
      completed_at: new Date().toISOString(),
    })
    .eq("id", logId);
}
