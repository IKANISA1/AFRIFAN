import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
} from "../_shared/response.ts";
import { isErrorResponse, validateRequest } from "../_shared/validation.ts";

const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
const geminiModel = Deno.env.get("GEMINI_MODEL")?.trim() ?? "gemini-pro";

type AdviceMode = "advice" | "debrief";

type AdviceRequest = {
  entry_id?: string;
  question?: string;
  mode?: AdviceMode;
};

type GameweekRow = {
  id: string;
  name: string;
  number: number;
  status: string;
  deadline_at?: string | null;
};

type PlayerPoolRow = {
  external_id: number;
  name: string;
  short_name: string;
  position: string;
  team_name: string;
  price: number;
  price_change: number;
  ownership_percent: number;
  form_points: number;
  total_points: number;
  recent_points: number[];
};

function normalizeMode(value: string | undefined): AdviceMode {
  return value === "debrief" ? "debrief" : "advice";
}

function formatGameweekSummary(gameweek: GameweekRow | null): string {
  if (gameweek == null) {
    return "No active gameweek context available.";
  }
  const deadline = gameweek.deadline_at == null
    ? "deadline unknown"
    : new Date(gameweek.deadline_at).toISOString();
  return `${gameweek.name} (GW${gameweek.number}, status ${gameweek.status}, deadline ${deadline})`;
}

function pickTargetGameweek(
  gameweeks: GameweekRow[],
  mode: AdviceMode,
): GameweekRow | null {
  if (gameweeks.length === 0) {
    return null;
  }

  if (mode === "debrief") {
    return gameweeks.find((gameweek) =>
      gameweek.status === "finished" ||
      gameweek.status === "scoring" ||
      gameweek.status === "live"
    ) ?? gameweeks[0];
  }

  return gameweeks.find((gameweek) =>
    gameweek.status === "live" ||
    gameweek.status === "upcoming" ||
    gameweek.status === "scoring"
  ) ?? gameweeks[0];
}

function buildPrompt(params: {
  mode: AdviceMode;
  teamName: string;
  overallRank: number | null;
  overallPoints: number;
  bankBalance: number;
  gameweekSummary: string;
  squadSignals: string[];
  injurySignals: string[];
  recentScoreSignals: string[];
  fixtureSignals: string[];
  chipsUsed: unknown;
  question: string;
}) {
  const opening = params.mode === "debrief"
    ? [
      "You are an elite fantasy football analyst writing a concise post-gameweek debrief.",
      "Focus on what worked, what hurt the rank, and the clearest next move.",
    ]
    : [
      "You are an elite football fantasy advisor.",
      "Be direct, specific, and evidence-based for the next decision window.",
    ];

  return [
    ...opening,
    "Return exactly 3 bullet points.",
    "Each bullet must be actionable, short, and mention concrete players or decisions when possible.",
    "Avoid boilerplate, disclaimers, and filler.",
    "",
    `Manager team: ${params.teamName}`,
    `Overall points: ${params.overallPoints}`,
    `Overall rank: ${params.overallRank?.toLocaleString() ?? "unranked"}`,
    `Bank: ${(params.bankBalance / 10).toFixed(1)}M remaining`,
    `Gameweek context: ${params.gameweekSummary}`,
    `Chips used: ${JSON.stringify(params.chipsUsed)}`,
    "",
    "Squad signals:",
    ...(params.squadSignals.length > 0
      ? params.squadSignals.map((line) => `- ${line}`)
      : ["- No saved squad signals available."]),
    "",
    "Injuries and availability:",
    ...(params.injurySignals.length > 0
      ? params.injurySignals.map((line) => `- ${line}`)
      : ["- No injury flags on current squad."]),
    "",
    "Recent entry scores:",
    ...(params.recentScoreSignals.length > 0
      ? params.recentScoreSignals.map((line) => `- ${line}`)
      : ["- No recent score history available."]),
    "",
    "Relevant fixtures:",
    ...(params.fixtureSignals.length > 0
      ? params.fixtureSignals.map((line) => `- ${line}`)
      : ["- No nearby fixture context available."]),
    "",
    `Manager request: "${params.question}"`,
  ].join("\n");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  if (geminiApiKey == null || geminiApiKey.length === 0) {
    return jsonError("GEMINI_API_KEY is not configured.", 503);
  }

  try {
    const validated = await validateRequest(request);
    if (isErrorResponse(validated)) {
      return validated;
    }
    const client = validated.supabase as any;

    const body = await request.json() as AdviceRequest;
    const entryId = body.entry_id?.trim();
    if (entryId == null || entryId.length === 0) {
      return jsonError("entry_id required", 400);
    }

    const mode = normalizeMode(body.mode);

    const entryRow = await client
      .schema("fantasy")
      .from("fantasy_entries")
      .select(
        "id, team_name, overall_points, overall_rank, bank_balance, chips_used, competition_id",
      )
      .eq("id", entryId)
      .single();

    if (entryRow.error != null || entryRow.data == null) {
      return jsonError("Entry not found", 404);
    }

    const competitionId = entryRow.data["competition_id"] as string;
    const gameweeksResponse = await client
      .schema("fantasy")
      .from("gameweeks")
      .select("id, name, number, status, deadline_at")
      .eq("competition_id", competitionId)
      .in("status", ["upcoming", "live", "scoring", "finished"])
      .order("number", { ascending: false });

    if (gameweeksResponse.error != null) {
      return jsonError(gameweeksResponse.error.message, 500);
    }

    const gameweeks =
      ((gameweeksResponse.data ?? []) as Array<Record<string, unknown>>)
        .map((row) => ({
          id: String(row.id ?? ""),
          name: String(row.name ?? "Gameweek"),
          number: Number(row.number ?? 0),
          status: String(row.status ?? "upcoming"),
          deadline_at: row.deadline_at == null ? null : String(row.deadline_at),
        } satisfies GameweekRow));

    const targetGameweek = pickTargetGameweek(gameweeks, mode);
    if (targetGameweek == null) {
      return jsonError("No gameweek found for this competition.", 404);
    }

    const selectionsRow = await client
      .schema("fantasy")
      .from("squad_selections")
      .select(
        "player_id, is_starter, is_captain, position, player:players(name, short_name, team_name)",
      )
      .eq("entry_id", entryId)
      .eq("gameweek_id", targetGameweek.id);

    if (selectionsRow.error != null) {
      return jsonError(selectionsRow.error.message, 500);
    }

    const selections = (selectionsRow.data ?? []) as Array<
      Record<string, unknown>
    >;
    const playerIds = selections
      .map((selection) => Number(selection.player_id ?? 0))
      .filter((playerId) => Number.isFinite(playerId) && playerId > 0);

    const poolResponse = await client.rpc(
      "fantasy_get_player_pool_by_competition_id",
      {
        p_competition_id: competitionId,
      },
    );
    if (poolResponse.error != null) {
      return jsonError(poolResponse.error.message, 500);
    }
    const poolRows = (poolResponse.data ?? []) as Array<
      Record<string, unknown>
    >;
    const poolById = new Map<number, PlayerPoolRow>();
    for (const row of poolRows) {
      const externalId = Number(row.external_id ?? 0);
      if (!Number.isFinite(externalId) || externalId <= 0) {
        continue;
      }
      poolById.set(externalId, {
        external_id: externalId,
        name: String(row.name ?? "Player"),
        short_name: String(row.short_name ?? row.name ?? "Player"),
        position: String(row.position ?? "UNK"),
        team_name: String(row.team_name ?? "Unknown"),
        price: Number(row.price ?? 0),
        price_change: Number(row.price_change ?? 0),
        ownership_percent: Number(row.ownership_percent ?? 0),
        form_points: Number(row.form_points ?? 0),
        total_points: Number(row.total_points ?? 0),
        recent_points: Array.isArray(row.recent_points)
          ? row.recent_points.map((value) => Number(value ?? 0))
          : [],
      });
    }

    let injuries: Array<Record<string, unknown>> = [];
    if (playerIds.length > 0) {
      const injuriesRow = await client
        .schema("fantasy")
        .from("fixture_injuries")
        .select("player_id, player_name, team_name, status, reason")
        .eq("competition_id", competitionId)
        .in("player_id", playerIds);
      if (injuriesRow.error == null) {
        injuries = (injuriesRow.data ?? []) as Array<Record<string, unknown>>;
      }
    }

    const recentGameweekIds = gameweeks
      .slice(0, 3)
      .map((gameweek) => gameweek.id);
    let recentScores: Array<Record<string, unknown>> = [];
    if (recentGameweekIds.length > 0) {
      const recentScoresRow = await client
        .schema("fantasy")
        .from("entry_gameweek_scores")
        .select("gameweek_id, points, rank, transfers_made")
        .eq("entry_id", entryId)
        .in("gameweek_id", recentGameweekIds);
      if (recentScoresRow.error == null) {
        recentScores = (recentScoresRow.data ?? []) as Array<
          Record<string, unknown>
        >;
      }
    }

    const nowIso = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();
    const fixturesRow = await client
      .schema("fantasy")
      .from("fantasy_fixtures")
      .select(
        "kickoff_at, round_label, home_team_name, away_team_name, status_short, home_goals, away_goals",
      )
      .eq("competition_id", competitionId)
      .gte("kickoff_at", nowIso)
      .order("kickoff_at", { ascending: true })
      .limit(8);

    const fixtures = fixturesRow.error == null
      ? ((fixturesRow.data ?? []) as Array<Record<string, unknown>>)
      : [];

    const squadSignals = selections.map((selection) => {
      const playerId = Number(selection.player_id ?? 0);
      const player = (selection.player ?? {}) as Record<string, unknown>;
      const pool = poolById.get(playerId);
      const recent = pool?.recent_points.slice(0, 3).join("/") ?? "-";
      const captainTag = selection.is_captain === true ? ", C" : "";
      return `${player.short_name ?? player.name ?? "Unknown"} (${
        selection.position ?? "UNK"
      }, ${
        player.team_name ?? pool?.team_name ?? "Unknown"
      }${captainTag}) form ${pool?.form_points ?? 0}, recent ${recent}, price ${
        (pool?.price ?? 0) / 10
      }M, ownership ${
        (pool?.ownership_percent ?? 0).toFixed(1)
      }%, price change ${pool?.price_change ?? 0}`;
    });

    const injurySignals = injuries.map((injury) =>
      `${injury.player_name ?? "Player"} (${
        injury.team_name ?? "Unknown"
      }) status ${injury.status ?? "unknown"}${
        injury.reason ? `, reason ${injury.reason}` : ""
      }`
    );

    const recentScoresByGameweek = new Map<string, Record<string, unknown>>();
    for (const row of recentScores) {
      recentScoresByGameweek.set(String(row.gameweek_id ?? ""), row);
    }
    const recentScoreSignals = gameweeks.slice(0, 3).map((gameweek) => {
      const score = recentScoresByGameweek.get(gameweek.id);
      if (score == null) {
        return `${gameweek.name}: no score recorded yet`;
      }
      return `${gameweek.name}: ${score.points ?? 0} pts, rank ${
        score.rank ?? "n/a"
      }, transfers ${score.transfers_made ?? 0}`;
    });

    const fixtureSignals = fixtures.map((fixture) => {
      const kickoffAt = fixture.kickoff_at == null
        ? "kickoff unknown"
        : new Date(String(fixture.kickoff_at)).toISOString();
      const score = fixture.home_goals == null || fixture.away_goals == null
        ? "vs"
        : `${fixture.home_goals}-${fixture.away_goals}`;
      return `${fixture.home_team_name ?? "Home"} ${score} ${
        fixture.away_team_name ?? "Away"
      } (${fixture.round_label ?? "Fixture"}, ${
        fixture.status_short ?? "NS"
      }, ${kickoffAt})`;
    });

    const prompt = buildPrompt({
      mode,
      teamName: (entryRow.data.team_name as string | null) ?? "My Team",
      overallRank: (entryRow.data.overall_rank as number | null) ?? null,
      overallPoints: (entryRow.data.overall_points as number | null) ?? 0,
      bankBalance: (entryRow.data.bank_balance as number | null) ?? 0,
      gameweekSummary: formatGameweekSummary(targetGameweek),
      squadSignals,
      injurySignals,
      recentScoreSignals,
      fixtureSignals,
      chipsUsed: entryRow.data.chips_used ?? [],
      question: body.question?.trim().length
        ? body.question!.trim()
        : mode === "debrief"
        ? "Give me a post-gameweek debrief and the clearest next move."
        : "What should I prioritize this week?",
    });

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiApiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [{ text: prompt }],
            },
          ],
          generationConfig: {
            maxOutputTokens: 320,
            temperature: 0.55,
          },
        }),
      },
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("fantasy-ai-advisor gemini error", errorText);
      return jsonError("AI service unavailable", 503);
    }

    const payload = await geminiResponse.json() as Record<string, unknown>;
    const adviceParts =
      ((payload.candidates as Array<Record<string, unknown>> | undefined)?.[0]
        ?.content as Record<string, unknown> | undefined)?.parts as
          | Array<Record<string, unknown>>
          | undefined;
    const adviceText = (adviceParts?.[0]?.text as string | undefined) ??
      "No advice available.";

    return new Response(
      JSON.stringify({
        advice: adviceText,
        mode,
        generated_at: new Date().toISOString(),
        gameweek: {
          id: targetGameweek.id,
          name: targetGameweek.name,
          number: targetGameweek.number,
          status: targetGameweek.status,
        },
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
    console.error("fantasy-ai-advisor failed", error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error
          ? error.message
          : "Fantasy AI advisor failed.",
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
