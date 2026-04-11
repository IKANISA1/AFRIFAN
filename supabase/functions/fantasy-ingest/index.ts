import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { sendToUser } from "../_shared/fcm.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

const adminClient = createAdminClient();

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
  players?: Array<{
    team: {
      id: number;
    };
    players?: Array<{
      player: {
        id: number;
        name: string;
      };
      statistics?: Array<{
        games: {
          minutes: number | null;
          position: string | null;
        };
        goals: {
          total: number | null;
          assists: number | null;
          conceded: number | null;
          saves: number | null;
          owngoals: number | null;
          penaltysaved: number | null;
          penaltymissed: number | null;
        };
        cards: {
          yellow: number | null;
          red: number | null;
        };
        tackles: {
          total: number | null;
          blocks: number | null;
          interceptions: number | null;
        };
        fantasy?: {
          bonus_points?: number | null;
          bps_score?: number | null;
          defensive_contributions?: number | null;
        };
      }>;
    }>;
  }>;
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

type IngestRequest = {
  fixtures?: ApiFootballFixture[];
  gameweek_id?: string;
  finalize?: boolean;
  stage_advance_player_ids?: number[];
  injuries?: ApiFootballInjury[];
};

type GoalSnapshot = {
  player_id: number;
  goals: number;
};

type FixtureRow = Record<string, unknown> & {
  competition_id: string;
  external_fixture_id: number;
  gameweek_id: string;
  status_short: string;
};

type FixtureStatRow = Record<string, unknown> & {
  fixture_id: string;
  gameweek_id: string;
  player_id: number;
};

function isLiveOrFinished(status: string) {
  return ["1H", "HT", "2H", "ET", "P", "FT", "AET", "PEN"].includes(status);
}

function isFinished(status: string) {
  return ["FT", "AET", "PEN"].includes(status);
}

function isKnockoutRound(roundLabel: string | null | undefined) {
  const value = (roundLabel ?? "").toLowerCase();
  return value.includes("round of 32") ||
    value.includes("round of 16") ||
    value.includes("quarter") ||
    value.includes("semi") ||
    (value.includes("final") && !value.includes("qual"));
}

function winnerTeamIdForFixture(fixture: ApiFootballFixture): number | null {
  const homeGoals = fixture.goals?.home;
  const awayGoals = fixture.goals?.away;
  const homeId = fixture.teams?.home?.id ?? null;
  const awayId = fixture.teams?.away?.id ?? null;

  if (
    !isFinished(fixture.fixture.status.short) ||
    !isKnockoutRound(fixture.league.round) ||
    homeGoals == null ||
    awayGoals == null ||
    homeId == null ||
    awayId == null
  ) {
    return null;
  }

  if (homeGoals === awayGoals) {
    return null;
  }

  return homeGoals > awayGoals ? homeId : awayId;
}

async function notifyCaptainGoals(
  gameweekId: string,
  previousGoals: Map<number, number>,
  rows: GoalSnapshot[],
) {
  const scoredPlayerIds = rows
    .filter((row) => {
      const before = previousGoals.get(row.player_id) ?? 0;
      return row.goals > before && row.goals > 0;
    })
    .map((row) => row.player_id);

  if (scoredPlayerIds.length === 0) {
    return;
  }

  const { data: captainRows, error } = await adminClient
    .schema("fantasy")
    .from("squad_selections")
    .select(`
      player_id,
      entry:fantasy_entries!inner(id, user_id),
      player:players!inner(name, short_name)
    `)
    .eq("gameweek_id", gameweekId)
    .eq("is_captain", true)
    .in("player_id", scoredPlayerIds);

  if (error || !captainRows) {
    console.error("captain goal lookup failed", error);
    return;
  }

  await Promise.allSettled(
    captainRows.map((row: any) =>
      sendToUser(
        row.entry.user_id as string,
        {
          title: "Captain haul",
          body: `${
            row.player.short_name ?? row.player.name
          } just scored for your captain pick.`,
        },
        {
          type: "captain_scored",
          gameweek_id: gameweekId,
          player_id: String(row.player_id),
        },
      ).catch((pushError) => console.error("captain push failed", pushError))
    ),
  );
}

async function notifyStageAdvance(
  gameweekId: string,
  playerIds: number[],
) {
  if (playerIds.length === 0) {
    return;
  }

  const { data: rows, error } = await adminClient
    .schema("fantasy")
    .from("squad_selections")
    .select(`
      player_id,
      entry:fantasy_entries!inner(id, user_id),
      player:players!inner(name, short_name, team_name)
    `)
    .eq("gameweek_id", gameweekId)
    .in("player_id", playerIds);

  if (error || !rows) {
    console.error("stage advance lookup failed", error);
    return;
  }

  await Promise.allSettled(
    rows.map((row: any) =>
      sendToUser(
        row.entry.user_id as string,
        {
          title: "Stage advance bonus",
          body: `${row.player.team_name ?? "Your nation"} advanced. ` +
            `${
              row.player.short_name ?? row.player.name
            } is in line for the stage bonus.`,
        },
        {
          type: "stage_advance",
          gameweek_id: gameweekId,
          player_id: String(row.player_id),
        },
      ).catch((pushError) =>
        console.error("stage advance push failed", pushError)
      )
    ),
  );
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    const authHeader = request.headers.get("Authorization");
    const expectedBearer = `Bearer ${
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    }`;
    if (authHeader !== expectedBearer) {
      return jsonError("Unauthorized", 401);
    }

    const body = await request.json() as IngestRequest;
    const gameweekId = body.gameweek_id?.trim();
    const fixtures = body.fixtures ?? [];
    const injuries = body.injuries ?? [];
    const stageAdvancePlayerIds = new Set(body.stage_advance_player_ids ?? []);

    if (
      gameweekId == null || gameweekId.length === 0 || fixtures.length === 0
    ) {
      return jsonError("fixtures and gameweek_id required", 400);
    }

    const { data: gameweekRow, error: gameweekError } = await adminClient
      .schema("fantasy")
      .from("gameweeks")
      .select("id, competition_id")
      .eq("id", gameweekId)
      .single();

    if (gameweekError || !gameweekRow) {
      return jsonError("gameweek_id not found", 400);
    }

    const fixtureUpserts: FixtureRow[] = [];
    const fixtureStatSeedRows: Array<Record<string, unknown>> = [];

    for (const fixture of fixtures) {
      const winnerTeamId = winnerTeamIdForFixture(fixture);
      fixtureUpserts.push({
        competition_id: gameweekRow.competition_id as string,
        gameweek_id: gameweekId,
        external_fixture_id: fixture.fixture.id,
        external_league_id: fixture.league.id,
        external_season: fixture.league.season,
        provider: "api-football",
        kickoff_at: fixture.fixture.date ?? null,
        round_label: fixture.league.round ?? null,
        status_short: fixture.fixture.status.short,
        elapsed_minutes: fixture.fixture.status.elapsed,
        home_team_id: fixture.teams?.home?.id ?? null,
        home_team_name: fixture.teams?.home?.name ?? null,
        home_logo_url: fixture.teams?.home?.logo ?? null,
        away_team_id: fixture.teams?.away?.id ?? null,
        away_team_name: fixture.teams?.away?.name ?? null,
        away_logo_url: fixture.teams?.away?.logo ?? null,
        home_goals: fixture.goals?.home ?? null,
        away_goals: fixture.goals?.away ?? null,
        metadata: {
          round: fixture.league.round ?? null,
        },
        last_synced_at: new Date().toISOString(),
      });

      if (!isLiveOrFinished(fixture.fixture.status.short)) {
        continue;
      }

      for (const teamData of fixture.players ?? []) {
        for (const playerData of teamData.players ?? []) {
          const stat = playerData.statistics?.[0];
          if (stat == null) {
            continue;
          }

          const minutes = stat.games.minutes ?? 0;
          const goals = stat.goals.total ?? 0;
          const assists = stat.goals.assists ?? 0;
          const saves = stat.goals.saves ?? 0;
          const goalsConceded = stat.goals.conceded ?? 0;
          const ownGoals = stat.goals.owngoals ?? 0;
          const penaltiesSaved = stat.goals.penaltysaved ?? 0;
          const penaltiesMissed = stat.goals.penaltymissed ?? 0;
          const yellowCards = stat.cards.yellow ?? 0;
          const redCards = stat.cards.red ?? 0;
          const computedDefensiveContributions = (stat.tackles.total ?? 0) +
            (stat.tackles.blocks ?? 0) +
            (stat.tackles.interceptions ?? 0);
          const stageAdvanced = winnerTeamId != null &&
            winnerTeamId === teamData.team.id;
          if (stageAdvanced) {
            stageAdvancePlayerIds.add(playerData.player.id);
          }

          fixtureStatSeedRows.push({
            fixture_external_id: fixture.fixture.id,
            gameweek_id: gameweekId,
            player_id: playerData.player.id,
            minutes_played: minutes,
            goals,
            assists,
            clean_sheet: goalsConceded === 0 && minutes >= 60,
            goals_conceded: goalsConceded,
            yellow_cards: yellowCards,
            red_cards: redCards,
            penalties_saved: penaltiesSaved,
            penalties_missed: penaltiesMissed,
            own_goals: ownGoals,
            saves,
            bonus_points: stat.fantasy?.bonus_points ?? 0,
            bps_score: stat.fantasy?.bps_score ?? 0,
            defensive_contributions: stat.fantasy?.defensive_contributions ??
              computedDefensiveContributions,
            stage_advanced: stageAdvanced ||
              stageAdvancePlayerIds.has(playerData.player.id),
            last_synced_at: new Date().toISOString(),
          });
        }
      }
    }

    if (injuries.length > 0) {
      const { error: injuryUpsertError } = await adminClient
        .schema("fantasy")
        .from("fixture_injuries")
        .upsert(
          injuries
            .filter((injury) => (injury.player?.id ?? 0) > 0)
            .map((injury) => ({
              competition_id: gameweekRow.competition_id as string,
              player_id: injury.player?.id as number,
              player_name: injury.player?.name ?? "Unknown player",
              team_id: injury.team?.id ?? null,
              team_name: injury.team?.name ?? null,
              status: injury.injury?.type ?? "injury",
              reason: injury.injury?.reason ?? null,
              source: "api-football",
              last_synced_at: new Date().toISOString(),
            })),
          {
            onConflict: "competition_id,player_id",
          },
        );

      if (injuryUpsertError) {
        console.error("fantasy-ingest injury upsert failed", injuryUpsertError);
      }
    }

    const { data: upsertedFixtures, error: fixtureUpsertError } =
      await adminClient
        .schema("fantasy")
        .from("fantasy_fixtures")
        .upsert(fixtureUpserts, {
          onConflict: "external_fixture_id",
        })
        .select("id, external_fixture_id");

    if (fixtureUpsertError) {
      console.error("fantasy-ingest fixture upsert failed", fixtureUpsertError);
      return jsonError(fixtureUpsertError.message, 500);
    }

    if (fixtureStatSeedRows.length === 0) {
      return jsonOk({
        message: "No player stats to upsert",
        upserted_fixtures: fixtureUpserts.length,
        upserted_stats: 0,
        gameweek_id: gameweekId,
      });
    }

    const fixtureIdByExternalId = new Map<number, string>(
      (upsertedFixtures ?? []).map((row) => [
        row.external_fixture_id as number,
        row.id as string,
      ]),
    );

    const statUpserts: FixtureStatRow[] = fixtureStatSeedRows
      .map((row) => {
        const fixtureId = fixtureIdByExternalId.get(
          row.fixture_external_id as number,
        );
        if (!fixtureId) {
          return null;
        }

        return {
          ...row,
          fixture_id: fixtureId,
        } as FixtureStatRow;
      })
      .filter((row): row is FixtureStatRow => row != null)
      .map(({ fixture_external_id: _fixtureExternalId, ...row }) => row);

    const playerIds = [...new Set(statUpserts.map((row) => row.player_id))];
    const { data: existingRows } = await adminClient
      .schema("fantasy")
      .from("player_gameweek_stats")
      .select("player_id, goals")
      .eq("gameweek_id", gameweekId)
      .in("player_id", playerIds);

    const previousGoals = new Map<number, number>();
    for (const row of existingRows ?? []) {
      previousGoals.set(
        row.player_id as number,
        (row.goals as number | null) ?? 0,
      );
    }

    const { error: statUpsertError } = await adminClient
      .schema("fantasy")
      .from("player_fixture_stats")
      .upsert(statUpserts, {
        onConflict: "fixture_id,player_id",
      });

    if (statUpsertError) {
      console.error("fantasy-ingest stat upsert failed", statUpsertError);
      return jsonError(statUpsertError.message, 500);
    }

    const { error: refreshError } = await adminClient.rpc(
      "fantasy_refresh_player_gameweek_stats",
      {
        p_gameweek_id: gameweekId,
      },
    );
    if (refreshError) {
      console.error(
        "fantasy refresh_player_gameweek_stats failed",
        refreshError,
      );
      return jsonError(refreshError.message, 500);
    }

    const { data: refreshedRows } = await adminClient
      .schema("fantasy")
      .from("player_gameweek_stats")
      .select("player_id, goals")
      .eq("gameweek_id", gameweekId)
      .in("player_id", playerIds);

    await notifyCaptainGoals(
      gameweekId,
      previousGoals,
      (refreshedRows ?? []) as GoalSnapshot[],
    );
    await notifyStageAdvance(gameweekId, [...stageAdvancePlayerIds]);

    const { error: scoreError } = await adminClient.functions.invoke(
      "fantasy-score",
      {
        body: {
          gameweek_id: gameweekId,
          finalize: body.finalize === true,
        },
      },
    );
    if (scoreError) {
      console.error("fantasy-score trigger failed", scoreError);
    }

    return new Response(
      JSON.stringify({
        upserted_fixtures: fixtureUpserts.length,
        upserted_stats: statUpserts.length,
        gameweek_id: gameweekId,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders(),
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    console.error("fantasy-ingest failed", error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error
          ? error.message
          : "Fantasy ingest failed.",
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders(),
          "Content-Type": "application/json",
        },
      },
    );
  }
});
