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
          body:
            delta > 0
              ? `You climbed ${Math.abs(delta)} places after Gameweek ${gameweekNumber}.`
              : `You dropped ${Math.abs(delta)} places after Gameweek ${gameweekNumber}.`,
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

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    const authHeader = request.headers.get("Authorization");
    const expectedBearer = `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`;
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

    const beforeRanks = new Map<string, { userId: string; rank: number | null }>(
      entries.map((entry) => [entry.id, { userId: entry.user_id, rank: entry.overall_rank }]),
    );

    const results = await Promise.allSettled(
      entries.map(async (entry) => {
        const { data, error } = await adminClient.rpc("fantasy_aggregate_entry_score", {
          p_entry_id: entry.id,
          p_gameweek_id: gameweekId,
        });

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
      failed.forEach((result) => console.error("fantasy-score failure", result.reason));
    }

    const { error: rankError } = await adminClient.rpc("fantasy_rank_gameweek_entries", {
      p_gameweek_id: gameweekId,
    });
    if (rankError) {
      throw new Error(rankError.message);
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
      },
    });

    if (body.finalize == true) {
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
        error: error instanceof Error ? error.message : "Fantasy scoring failed.",
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
