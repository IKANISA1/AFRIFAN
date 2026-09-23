/**
 * sync-live — Fetch live match details (stats, events, lineups).
 *
 * Only runs for fixtures that are currently live or recently finished.
 * Budget-conscious: each fixture requires up to 3 API calls.
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  getFixtureEvents,
  getFixtureLineups,
  getFixtureStatistics,
  getRateLimit,
} from "./api-football-client.ts";
import {
  mapEventsToFixtureEvents,
  mapLineupsToFixtureLineups,
  mapStatsToFixtureStats,
} from "./mappers.ts";

export interface SyncLiveResult {
  fixtures_processed: number;
  stats_synced: number;
  events_synced: number;
  lineups_synced: number;
  api_requests_used: number;
  errors: string[];
}

export async function syncLive(
  adminClient: SupabaseClient,
): Promise<SyncLiveResult> {
  const result: SyncLiveResult = {
    fixtures_processed: 0,
    stats_synced: 0,
    events_synced: 0,
    lineups_synced: 0,
    api_requests_used: 0,
    errors: [],
  };

  // 1. Find fixtures that need live data:
  //    - Currently live
  //    - Recently finished (last 3 hours) without stats
  const { data: liveFixtures, error } = await adminClient
    .schema("football")
    .from("fixtures")
    .select("id, external_fixture_id, status, home_team_id, away_team_id")
    .eq("external_provider", "api-football")
    .or(
      `status.eq.live,and(status.eq.finished,updated_at.gte.${hoursAgo(3)})`,
    )
    .limit(15); // Budget: 15 × 3 = 45 API calls max

  if (error || !liveFixtures || liveFixtures.length === 0) {
    if (error) result.errors.push(`Query error: ${error.message}`);
    return result;
  }

  for (const fixture of liveFixtures) {
    const apiFixtureId = Number(fixture.external_fixture_id);
    if (!apiFixtureId || isNaN(apiFixtureId)) continue;

    // Budget check
    const rateLimit = getRateLimit();
    if (rateLimit.dailyRemaining <= 10) {
      console.warn("[sync-live] Near daily limit, stopping.");
      break;
    }

    try {
      // Stats
      const apiStats = await getFixtureStatistics(apiFixtureId);
      result.api_requests_used++;

      if (apiStats.length >= 2) {
        const statRows = mapStatsToFixtureStats(apiStats);
        for (const statRow of statRows) {
          const { error: statError } = await adminClient
            .schema("football")
            .from("fixture_stats")
            .upsert(
              {
                fixture_id: fixture.id,
                stat_key: statRow.stat_key,
                stat_label: statRow.stat_label,
                home_value: statRow.home_value,
                away_value: statRow.away_value,
                home_display: statRow.home_display,
                away_display: statRow.away_display,
                sort_order: statRow.sort_order,
              },
              { onConflict: "fixture_id,stat_key" },
            );

          if (!statError) result.stats_synced++;
        }
      }

      // Events
      const apiEvents = await getFixtureEvents(apiFixtureId);
      result.api_requests_used++;

      if (apiEvents.length > 0) {
        // Delete existing events and re-insert (events can change)
        await adminClient
          .schema("football")
          .from("fixture_events")
          .delete()
          .eq("fixture_id", fixture.id);

        const eventRows = mapEventsToFixtureEvents(apiEvents);
        for (const eventRow of eventRows) {
          const teamId = eventRow.metadata.api_team_id
            ? await resolveTeamId(
              adminClient,
              Number(eventRow.metadata.api_team_id),
            )
            : null;

          const { error: eventError } = await adminClient
            .schema("football")
            .from("fixture_events")
            .insert({
              fixture_id: fixture.id,
              team_id: teamId,
              event_type: eventRow.event_type,
              minute: eventRow.minute,
              stoppage_minute: eventRow.stoppage_minute,
              event_label: eventRow.event_label,
              event_detail: eventRow.event_detail,
              sort_order: eventRow.sort_order,
              metadata: eventRow.metadata,
            });

          if (!eventError) result.events_synced++;
        }
      }

      // Lineups
      const apiLineups = await getFixtureLineups(apiFixtureId);
      result.api_requests_used++;

      if (apiLineups.length > 0) {
        const lineupRows = mapLineupsToFixtureLineups(apiLineups);

        for (const lineupRow of lineupRows) {
          const teamId = lineupRow.players[0]?.metadata?.api_team_id
            ? await resolveTeamByApiLineup(
              adminClient,
              apiLineups,
              lineupRow,
            )
            : null;

          // Use fixture home/away team IDs as fallback
          const resolvedTeamId = teamId ?? fixture.home_team_id ??
            fixture.away_team_id;

          if (!resolvedTeamId) continue;

          // Upsert lineup
          const { data: lineupData, error: lineupError } = await adminClient
            .schema("football")
            .from("fixture_lineups")
            .upsert(
              {
                fixture_id: fixture.id,
                team_id: resolvedTeamId,
                formation: lineupRow.formation,
                coach_name: lineupRow.coach_name,
                is_confirmed: lineupRow.is_confirmed,
                source: lineupRow.source,
              },
              { onConflict: "fixture_id,team_id" },
            )
            .select("id")
            .single();

          if (lineupError || !lineupData) continue;

          // Delete existing lineup players and re-insert
          await adminClient
            .schema("football")
            .from("fixture_lineup_players")
            .delete()
            .eq("fixture_lineup_id", lineupData.id);

          for (const player of lineupRow.players) {
            await adminClient
              .schema("football")
              .from("fixture_lineup_players")
              .insert({
                fixture_lineup_id: lineupData.id,
                player_name: player.player_name,
                squad_number: player.squad_number,
                position: player.position,
                lineup_role: player.lineup_role,
                sort_order: player.sort_order,
                is_captain: player.is_captain,
                is_goalkeeper: player.is_goalkeeper,
                metadata: player.metadata,
              });
          }

          result.lineups_synced++;
        }
      }

      result.fixtures_processed++;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(
        `[sync-live] Error for fixture ${apiFixtureId}:`,
        msg,
      );
      result.errors.push(`Fixture ${apiFixtureId}: ${msg}`);
    }
  }

  return result;
}

/* ---------- Helpers ---------- */

function hoursAgo(hours: number): string {
  const d = new Date();
  d.setHours(d.getHours() - hours);
  return d.toISOString();
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

async function resolveTeamByApiLineup(
  client: SupabaseClient,
  apiLineups: { team: { id: number } }[],
  lineupRow: { players: Array<{ metadata: Record<string, unknown> }> },
): Promise<string | null> {
  // Find matching API lineup to get team ID
  for (const apiLineup of apiLineups) {
    const apiTeamId = apiLineup.team.id;
    return await resolveTeamId(client, apiTeamId);
  }
  return null;
}
