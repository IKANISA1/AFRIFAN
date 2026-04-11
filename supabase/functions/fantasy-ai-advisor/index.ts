import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";

const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
const geminiModel = Deno.env.get("GEMINI_MODEL")?.trim() ??
  "gemini-pro";

type AdviceRequest = {
  entry_id?: string;
  question?: string;
};

function buildPrompt(params: {
  teamName: string;
  overallRank: number | null;
  bankBalance: number;
  squadSummary: string;
  chipsUsed: unknown;
  question: string;
}) {
  return [
    "You are an elite football fantasy advisor.",
    "Be direct, specific, evidence-based, and concise.",
    "Return a maximum of 120 words split into 2 or 3 actionable bullet points.",
    "",
    `Team: ${params.teamName}`,
    `Overall rank: ${params.overallRank?.toLocaleString() ?? "unranked"}`,
    `Bank: ${(params.bankBalance / 10).toFixed(1)}M remaining`,
    `Current squad: ${params.squadSummary}`,
    `Chips used: ${JSON.stringify(params.chipsUsed)}`,
    `Manager question: "${params.question}"`,
    "",
    "Mention specific player names when helpful.",
    "No generic boilerplate.",
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

    const entryRow = await client
      .schema("fantasy")
      .from("fantasy_entries")
      .select("id, team_name, overall_points, overall_rank, bank_balance, chips_used, competition_id")
      .eq("id", entryId)
      .single();

    if (entryRow.error != null || entryRow.data == null) {
      return jsonError("Entry not found", 404);
    }

    const currentGameweekRow = await client
      .schema("fantasy")
      .from("gameweeks")
      .select("id")
      .eq("competition_id", entryRow.data["competition_id"] as string)
      .in("status", ["live", "upcoming"])
      .order("number")
      .limit(1)
      .maybeSingle();

    const gameweekId = currentGameweekRow.data?.id as string | undefined;
    if (gameweekId == null) {
      return jsonError("No active or upcoming gameweek found for this competition.", 404);
    }

    const selectionsRow = await client
      .schema("fantasy")
      .from("squad_selections")
      .select("player_id, is_starter, is_captain, position, player:players(name, short_name, team_name)")
      .eq("entry_id", entryId)
      .eq("gameweek_id", gameweekId);

    if (selectionsRow.error != null) {
      return jsonError(selectionsRow.error.message, 500);
    }

    const squadSummary = (selectionsRow.data ?? [])
      .map((selection: Record<string, unknown>) => {
        const player = (selection.player ?? {}) as Record<string, unknown>;
        const marker = selection.is_captain == true ? ", C" : "";
        return `${player.short_name ?? player.name ?? "Unknown"} (${selection.position ?? "UNK"}, ${player.team_name ?? "Unknown"}${marker})`;
      })
      .join(", ");

    const prompt = buildPrompt({
      teamName: (entryRow.data.team_name as string | null) ?? "My Team",
      overallRank: (entryRow.data.overall_rank as number | null) ?? null,
      bankBalance: (entryRow.data.bank_balance as number | null) ?? 0,
      squadSummary: squadSummary.length === 0 ? "No saved squad yet." : squadSummary,
      chipsUsed: entryRow.data.chips_used ?? [],
      question: body.question?.trim().length
          ? body.question!.trim()
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
              parts: [
                {"text": prompt},
              ],
            },
          ],
          generationConfig: {
            maxOutputTokens: 220,
            temperature: 0.7,
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
    const advice =
      ((payload.candidates as Array<Record<string, unknown>> | undefined)?.[0]
        ?.content as Record<string, unknown> | undefined)?.parts as
        | Array<Record<string, unknown>>
        | undefined;
    const adviceText = (advice?.[0]?.text as string | undefined) ??
      "No advice available.";

    return new Response(
      JSON.stringify({ advice: adviceText }),
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
        error: error instanceof Error ? error.message : "Fantasy AI advisor failed.",
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
