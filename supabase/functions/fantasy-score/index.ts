import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { sendToUser } from "../_shared/fcm.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type EntryRow = {
  id: string;
  user_id: string;
  overall_rank: number | null;
};

type H2HEntry = {
  id: string;
  user_id: string;
  team_name: string;
};

type H2HFixtureRow = {
  id: string;
  home_points: number | null;
  away_points: number | null;
  winner_entry_id: string | null;
  home_entry: H2HEntry | null;
  away_entry: H2HEntry | null;
};

type ScoreRequest = {
  gameweek_id?: string;
  finalize?: boolean;
};

const adminClient = createAdminClient();

async function fetchCompetitionEntries(gameweekId: string) {
  const { data: gameweek, error: gameweekError } = await adminClient
    .schema("fantasy")
    .from("gameweeks")
    .select("id, number, competition_id")
    .eq("id", gameweekId)
    .single();

  if (gameweekError || !gameweek) {
    throw new Error("Gameweek not found.");
  }

  const { data: entries, error: entriesError } = await adminClient
    .schema("fantasy")
    .from("fantasy_entries")
    .select("id, user_id, overall_rank")
    .eq("competition_id", gameweek.competition_id);

  if (entriesError) {
    throw new Error(entriesError.message);
  }

  return {
    gameweek,
    entries: (entries ?? []) as EntryRow[],
  };
}

async function sendRankMovementNotifications(
  beforeRanks: Map<string, { userId: string; rank: number | null }>,
  afterEntries: EntryRow[],
  gameweekNumber: number,
) {
  const tasks: Promise<unknown>[] = [];

  for (const entry of afterEntries) {
    const before = beforeRanks.get(entry.id);
    if (before == null || before.rank == null || entry.overall_rank == null) {
      continue;
    }

    const delta = before.rank - entry.overall_rank;
    if (Math.abs(delta) < 10) {
      continue;
    }

    const direction = delta > 0 ? "up" : "down";
    tasks.push(
      sendToUser(
        entry.user_id,
        {
          title: "Fantasy rank swing",
          body: delta > 0
            ? `You climbed ${
              Math.abs(delta)
            } places after Gameweek ${gameweekNumber}.`
            : `You dropped ${
              Math.abs(delta)
            } places after Gameweek ${gameweekNumber}.`,
        },
        {
          type: "rank_change",
          direction,
          places: String(Math.abs(delta)),
          gameweek_number: String(gameweekNumber),
        },
      ).catch((error) => console.error("rank_change push failed", error)),
    );
  }

  await Promise.allSettled(tasks);
}

async function sendHeadToHeadNotifications(
  gameweekId: string,
  gameweekNumber: number,
) {
  const { data, error } = await adminClient
    .schema("fantasy")
    .from("league_h2h_fixtures")
    .select(
      "id, home_points, away_points, winner_entry_id, home_entry:fantasy_entries!league_h2h_fixtures_home_entry_id_fkey(id, user_id, team_name), away_entry:fantasy_entries!league_h2h_fixtures_away_entry_id_fkey(id, user_id, team_name)",
    )
    .eq("gameweek_id", gameweekId);

  if (error != null) {
    console.error("h2h notification load failed", error);
    return;
  }

  const fixtures = ((data ?? []) as Array<Record<string, unknown>>).map(
    (row) => ({
      id: String(row.id ?? ""),
      home_points: row.home_points == null ? null : Number(row.home_points),
      away_points: row.away_points == null ? null : Number(row.away_points),
      winner_entry_id: row.winner_entry_id == null
        ? null
        : String(row.winner_entry_id),
      home_entry: Array.isArray(row.home_entry)
        ? (row.home_entry[0] as H2HEntry | undefined) ?? null
        : (row.home_entry as H2HEntry | null),
      away_entry: Array.isArray(row.away_entry)
        ? (row.away_entry[0] as H2HEntry | undefined) ?? null
        : (row.away_entry as H2HEntry | null),
    } satisfies H2HFixtureRow),
  );
  const tasks: Promise<unknown>[] = [];

  for (const fixture of fixtures) {
    if (
      fixture.home_entry == null ||
      fixture.away_entry == null ||
      fixture.home_points == null ||
      fixture.away_points == null
    ) {
      continue;
    }

    const scoreLine = `${fixture.home_points}-${fixture.away_points}`;
    const homeOutcome = fixture.winner_entry_id == null
      ? "draw"
      : fixture.winner_entry_id === fixture.home_entry.id
      ? "win"
      : "loss";
    const awayOutcome = fixture.winner_entry_id == null
      ? "draw"
      : fixture.winner_entry_id === fixture.away_entry.id
      ? "win"
      : "loss";

    const homeBody = homeOutcome === "win"
      ? `You beat ${fixture.away_entry.team_name} ${scoreLine} in your H2H matchup for Gameweek ${gameweekNumber}.`
      : homeOutcome === "loss"
      ? `You lost ${scoreLine} to ${fixture.away_entry.team_name} in your H2H matchup for Gameweek ${gameweekNumber}.`
      : `You drew ${scoreLine} with ${fixture.away_entry.team_name} in your H2H matchup for Gameweek ${gameweekNumber}.`;
    const awayBody = awayOutcome === "win"
      ? `You beat ${fixture.home_entry.team_name} ${fixture.away_points}-${fixture.home_points} in your H2H matchup for Gameweek ${gameweekNumber}.`
      : awayOutcome === "loss"
      ? `You lost ${fixture.away_points}-${fixture.home_points} to ${fixture.home_entry.team_name} in your H2H matchup for Gameweek ${gameweekNumber}.`
      : `You drew ${fixture.away_points}-${fixture.home_points} with ${fixture.home_entry.team_name} in your H2H matchup for Gameweek ${gameweekNumber}.`;

    tasks.push(
      sendToUser(
        fixture.home_entry.user_id,
        {
          title: "Head-to-head result",
          body: homeBody,
        },
        {
          type: "h2h_result",
          gameweek_id: gameweekId,
          gameweek_number: String(gameweekNumber),
          outcome: homeOutcome,
          opponent_team: fixture.away_entry.team_name,
        },
      ).catch((sendError) => console.error("h2h home push failed", sendError)),
    );
    tasks.push(
      sendToUser(
        fixture.away_entry.user_id,
        {
          title: "Head-to-head result",
          body: awayBody,
        },
        {
          type: "h2h_result",
          gameweek_id: gameweekId,
          gameweek_number: String(gameweekNumber),
          outcome: awayOutcome,
          opponent_team: fixture.home_entry.team_name,
        },
      ).catch((sendError) => console.error("h2h away push failed", sendError)),
    );
  }

  await Promise.allSettled(tasks);
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
    if (authHeader != expectedBearer) {
      return jsonError("Unauthorized", 401);
    }

    const body = await request.json() as ScoreRequest;
    const gameweekId = body.gameweek_id?.trim();
    if (gameweekId == null || gameweekId.length === 0) {
      return jsonError("gameweek_id required", 400);
    }

    const { gameweek, entries } = await fetchCompetitionEntries(gameweekId);
    if (entries.length == 0) {
      return jsonOk({ scored: 0, gameweek_id: gameweekId });
    }

    const beforeRanks = new Map<
      string,
      { userId: string; rank: number | null }
    >(
      entries.map((
        entry,
      ) => [entry.id, { userId: entry.user_id, rank: entry.overall_rank }]),
    );

    const results = await Promise.allSettled(
      entries.map(async (entry) => {
        const { data, error } = await adminClient.rpc(
          "fantasy_aggregate_entry_score",
          {
            p_entry_id: entry.id,
            p_gameweek_id: gameweekId,
          },
        );

        if (error) {
          throw new Error(`${entry.id}: ${error.message}`);
        }

        return {
          entry_id: entry.id,
          points: data as number | null,
        };
      }),
    );

    const failed = results.filter((result) => result.status === "rejected");
    if (failed.length > 0) {
      failed.forEach((result) =>
        console.error("fantasy-score failure", result.reason)
      );
    }

    const { error: rankError } = await adminClient.rpc(
      "fantasy_rank_gameweek_entries",
      {
        p_gameweek_id: gameweekId,
      },
    );
    if (rankError) {
      throw new Error(rankError.message);
    }

    const { error: h2hError } = await adminClient.rpc(
      "fantasy_refresh_gameweek_h2h_results",
      {
        p_gameweek_id: gameweekId,
      },
    );
    if (h2hError) {
      throw new Error(h2hError.message);
    }

    const { data: rankedEntries, error: rankedEntriesError } = await adminClient
      .schema("fantasy")
      .from("fantasy_entries")
      .select("id, user_id, overall_rank")
      .eq("competition_id", gameweek.competition_id);

    if (rankedEntriesError) {
      throw new Error(rankedEntriesError.message);
    }

    await sendRankMovementNotifications(
      beforeRanks,
      (rankedEntries ?? []) as EntryRow[],
      gameweek.number,
    );

    if (body.finalize == true) {
      await adminClient
        .schema("fantasy")
        .from("gameweeks")
        .update({ status: "finished" })
        .eq("id", gameweekId);
    }

    await adminClient.channel(`gameweek:${gameweekId}`).send({
      type: "broadcast",
      event: "scores_updated",
      payload: {
        gameweek_id: gameweekId,
        finalized: body.finalize == true,
        scored_at: new Date().toISOString(),
        h2h_refreshed: true,
      },
    });

    if (body.finalize == true) {
      await sendHeadToHeadNotifications(gameweekId, gameweek.number);
      await Promise.allSettled(
        entries.map((entry) =>
          sendToUser(
            entry.user_id,
            {
              title: `Gameweek ${gameweek.number} locked`,
              body: "Your final fantasy score is ready.",
            },
            {
              type: "gw_result",
              gameweek_id: gameweekId,
              gameweek_number: String(gameweek.number),
            },
          ).catch((error) => console.error("gw_result push failed", error))
        ),
      );
    }

    return new Response(
      JSON.stringify({
        scored: entries.length,
        failed: failed.length,
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
    console.error("fantasy-score failed", error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error
          ? error.message
          : "Fantasy scoring failed.",
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
