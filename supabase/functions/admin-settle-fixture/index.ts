import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireAdminCaller } from "../_shared/auth.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type AdminClientLike = {
  rpc(
    name: string,
    params: Record<string, unknown>,
  ): Promise<{ data: unknown; error: { message?: string } | null }>;
};

type Dependencies = {
  requireAdminCaller: typeof requireAdminCaller;
  createAdminClient: () => AdminClientLike;
};

const defaultDependencies: Dependencies = {
  requireAdminCaller,
  createAdminClient: () => createAdminClient() as unknown as AdminClientLike,
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function requiredScore(value: unknown, field: string): number {
  if (!Number.isInteger(value) || Number(value) < 0 || Number(value) > 99) {
    throw new HttpError(400, `Invalid ${field}.`);
  }
  return Number(value);
}

function optionalScore(value: unknown, field: string): number | null {
  if (value == null) return null;
  return requiredScore(value, field);
}

function boundedCount(value: unknown): number {
  return Number.isInteger(value) && Number(value) >= 0 &&
      Number(value) <= 10_000_000
    ? Number(value)
    : 0;
}

function parseRequest(body: unknown) {
  if (body == null || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError(400, "Invalid settlement request.");
  }
  const raw = body as Record<string, unknown>;
  const fixtureId = typeof raw["fixture_id"] === "string"
    ? raw["fixture_id"].trim()
    : "";
  if (!uuidPattern.test(fixtureId)) {
    throw new HttpError(400, "Invalid fixture identifier.");
  }
  const homeScore = requiredScore(raw["home_score"], "home score");
  const awayScore = requiredScore(raw["away_score"], "away score");
  const halfTimeHomeScore = optionalScore(
    raw["half_time_home_score"],
    "half-time home score",
  );
  const halfTimeAwayScore = optionalScore(
    raw["half_time_away_score"],
    "half-time away score",
  );
  if ((halfTimeHomeScore == null) !== (halfTimeAwayScore == null)) {
    throw new HttpError(400, "Both half-time scores are required together.");
  }
  if (
    halfTimeHomeScore != null &&
    (halfTimeHomeScore > homeScore || halfTimeAwayScore! > awayScore)
  ) {
    throw new HttpError(400, "Half-time scores cannot exceed final scores.");
  }

  return {
    fixtureId,
    homeScore,
    awayScore,
    halfTimeHomeScore,
    halfTimeAwayScore,
  };
}

export function createAdminSettleFixtureHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = { ...defaultDependencies, ...dependencies };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return corsPreflightResponse();
    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    try {
      await deps.requireAdminCaller(request);
      const payload = parseRequest(await request.json());
      const { data, error } = await deps.createAdminClient().rpc(
        "prediction_admin_settle",
        {
          p_fixture_id: payload.fixtureId,
          p_home_score: payload.homeScore,
          p_away_score: payload.awayScore,
          p_status: "finished",
          p_ht_home_score: payload.halfTimeHomeScore,
          p_ht_away_score: payload.halfTimeAwayScore,
        },
      );
      if (
        error || data == null || typeof data !== "object" ||
        Array.isArray(data)
      ) {
        throw new HttpError(502, "Fixture settlement was not confirmed.");
      }
      const result = data as Record<string, unknown>;
      if (
        result["status"] !== "success" ||
        result["fixture_id"] !== payload.fixtureId
      ) {
        throw new HttpError(409, "Fixture settlement was not confirmed.");
      }
      const settlement = result["settlement"] != null &&
          typeof result["settlement"] === "object" &&
          !Array.isArray(result["settlement"])
        ? result["settlement"] as Record<string, unknown>
        : {};

      return jsonOk({
        success: true,
        data: {
          receipt: {
            status: "success",
            fixture_id: payload.fixtureId,
            score: `${payload.homeScore} - ${payload.awayScore}`,
            markets_settled: boundedCount(result["markets_settled"]),
            total_won: boundedCount(settlement["total_won"]),
            total_lost: boundedCount(settlement["total_lost"]),
          },
        },
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }
      console.error("admin-settle-fixture failed");
      return jsonError("Fixture settlement was not confirmed.", 500);
    }
  };
}

if (import.meta.main) {
  const handler = createAdminSettleFixtureHandler();
  Deno.serve((request: Request) =>
    handler(request).then(
      (response) =>
        new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: {
            ...Object.fromEntries(response.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  );
}
