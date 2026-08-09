/**
 * sync-standings — Batch-syncs standings for all tracked leagues.
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { getRateLimit, getStandings } from "./api-football-client.ts";
import { mapStandingToStanding } from "./mappers.ts";

export interface SyncStandingsResult {
  league: string;
  standings_fetched: number;
  standings_upserted: number;
  api_requests_used: number;
  error?: string;
}

export async function syncStandings(
  adminClient: SupabaseClient,
): Promise<SyncStandingsResult[]> {
  const results: SyncStandingsResult[] = [];

  const { data: configs, error: configError } = await adminClient
    .from("football_sync_config")
    .select("*")
    .eq("sync_standings", true)
    .eq("is_active", true);

  if (configError || !configs) {
    console.error("[sync-standings] Failed to load sync configs:", configError);
    return [];
  }

  for (const config of configs) {
    const leagueId = Number(config.external_league_id);
    const seasonYear = Number(config.season_year ?? new Date().getFullYear());
    const leagueName = config.league_name ?? `League ${leagueId}`;
    let apiRequestsUsed = 0;

    try {
      // 1. Fetch standings from API
      const apiStandings = await getStandings({
        league: leagueId,
        season: seasonYear,
      });
      apiRequestsUsed++;

      if (apiStandings.length === 0) {
        results.push({
          league: leagueName,
          standings_fetched: 0,
          standings_upserted: 0,
          api_requests_used: apiRequestsUsed,
        });
        continue;
      }

      // 2. Resolve competition + season IDs
      const competitionId = await resolveCompetitionId(adminClient, leagueId);
      const seasonId = competitionId
        ? await resolveSeasonId(adminClient, competitionId, seasonYear)
        : null;

      if (!competitionId || !seasonId) {
        throw new Error(
          `Cannot resolve competition/season for league ${leagueId}`,
        );
      }

      // 3. Process each standings group
      let totalFetched = 0;
      let totalUpserted = 0;

      for (const standingData of apiStandings) {
        const groups = standingData.league?.standings ?? [];

        for (const group of groups) {
          for (const entry of group) {
            totalFetched++;

            const row = mapStandingToStanding(entry, leagueId);

            // Resolve team ID
            const teamId = await resolveTeamId(
              adminClient,
              entry.team.id,
            );

            if (!teamId) {
              console.warn(
                `[sync-standings] Skipping standing for team ${entry.team.id}: not found`,
              );
              continue;
            }

            const { error: upsertError } = await adminClient
              .schema("football")
              .from("standings")
              .upsert(
                {
                  competition_id: competitionId,
                  season_id: seasonId,
                  team_id: teamId,
                  stage_name: row.stage_name,
                  group_name: row.group_name,
                  position: row.position,
                  played: row.played,
                  won: row.won,
                  drawn: row.drawn,
                  lost: row.lost,
                  goals_for: row.goals_for,
                  goals_against: row.goals_against,
                  goal_difference: row.goal_difference,
                  points: row.points,
                  form: row.form,
                  notes: row.notes,
                  metadata: row.metadata,
                },
                {
                  onConflict: "season_id,stage_name,group_name,team_id",
                },
              );

            if (upsertError) {
              console.error(
                `[sync-standings] Upsert error for team ${entry.team.id}:`,
                upsertError.message,
              );
            } else {
              totalUpserted++;
            }
          }
        }
      }

      // 4. Update sync timestamp
      await adminClient
        .from("football_sync_config")
        .update({
          last_standings_synced_at: new Date().toISOString(),
          sync_status: "idle",
        })
        .eq("id", config.id);

      results.push({
        league: leagueName,
        standings_fetched: totalFetched,
        standings_upserted: totalUpserted,
        api_requests_used: apiRequestsUsed,
      });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error(
        `[sync-standings] Error for league ${leagueId}:`,
        errorMessage,
      );
      results.push({
        league: leagueName,
        standings_fetched: 0,
        standings_upserted: 0,
        api_requests_used: apiRequestsUsed,
        error: errorMessage,
      });
    }

    const rateLimit = getRateLimit();
    if (rateLimit.dailyRemaining <= 5) {
      console.warn("[sync-standings] Near daily limit, stopping.");
      break;
    }
  }

  return results;
}

/* ---------- ID resolution helpers ---------- */

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
