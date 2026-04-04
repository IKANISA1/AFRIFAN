import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { HttpError } from "../_shared/auth.ts";
import { requireAppCheckToken } from "../_shared/app_check.ts";
import {
  generateBiopayNonce,
  signBiopayToken,
  type SignedBiopayTokenPayload,
} from "../_shared/biopay_signed_token.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type CreateChallengeRequest = {
  mode?: string;
};

type AdminClientLike = ReturnType<typeof createAdminClient>;

export type BiopayCreateLivenessChallengeDependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
  requireAppCheckToken: (request: Request) => Promise<string>;
  signBiopayToken: (payload: SignedBiopayTokenPayload) => Promise<string>;
  recordOperationalHealthEvent: (
    adminClient: AdminClientLike,
    event: Parameters<typeof recordOperationalHealthEvent>[1],
  ) => Promise<void>;
  recordEdgeFunctionFailure: (
    adminClient: AdminClientLike,
    options: Parameters<typeof recordEdgeFunctionFailure>[1],
  ) => Promise<void>;
  now: () => Date;
};

const CHALLENGE_TTL_SECONDS = 300;

const defaultDependencies: BiopayCreateLivenessChallengeDependencies = {
  createAdminClient,
  validateRequest,
  requireAppCheckToken,
  signBiopayToken,
  recordOperationalHealthEvent,
  recordEdgeFunctionFailure,
  now: () => new Date(),
};

export function createBiopayCreateLivenessChallengeHandler(
  dependencies: Partial<BiopayCreateLivenessChallengeDependencies> = {},
) {
  const deps: BiopayCreateLivenessChallengeDependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
    }

    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    const adminClient = deps.createAdminClient();
    let requesterUserId: string | null = null;

    try {
      const validated = await deps.validateRequest(request, { requireClubId: true });
      if (isErrorResponse(validated)) return validated;
      
      const { userId, clubId } = validated;
      requesterUserId = userId;
      const numericClubId = Number(clubId);

      await deps.requireAppCheckToken(request);

      const body = await request.json() as CreateChallengeRequest;
      const mode = body.mode?.trim().toLowerCase() === "enrollment"
        ? "enrollment"
        : "payment";

      const now = deps.now();
      const expiresAt = new Date(
        now.getTime() + CHALLENGE_TTL_SECONDS * 1000,
      ).toISOString();
      const nonce = generateBiopayNonce();

      const { data: challengeRow, error: challengeError } = await adminClient
        .from("biopay_liveness_challenges")
        .insert({
          user_id: userId,
          club_id: numericClubId,
          mode,
          nonce,
          issued_at: now.toISOString(),
          expires_at: expiresAt,
        })
        .select("id")
        .single();

      if (challengeError || !challengeRow) {
        throw challengeError ?? new Error("Failed to create liveness challenge.");
      }

      const token = await deps.signBiopayToken({
        kind: "liveness_challenge",
        v: 1,
        iat: now.toISOString(),
        exp: expiresAt,
        nonce,
        challenge_id: challengeRow.id,
        requester_user_id: userId,
        club_id: numericClubId,
        mode,
      });

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "biopay",
        component: "liveness",
        status: "ok",
        severity: "info",
        message: "BioPay liveness challenge issued.",
        functionName: "biopay-create-liveness-challenge",
        userId: userId,
        subjectType: "biopay_liveness_challenge",
        subjectId: challengeRow.id?.toString() ?? null,
        metadata: {
          club_id: numericClubId,
          mode,
          expires_at: expiresAt,
        },
      });

      return jsonOk({
        success: true,
        data: {
          token,
          mode,
          expires_at: expiresAt,
        },
      });
    } catch (error) {
      if (error instanceof SyntaxError) {
        return jsonError("Invalid JSON body.", 400);
      }
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }

      await deps.recordEdgeFunctionFailure(adminClient, {
        functionName: "biopay-create-liveness-challenge",
        error,
        issueCode: "biopay_create_liveness_challenge_failed",
        userId: requesterUserId,
      });
      console.error("biopay-create-liveness-challenge failed:", error);
      return jsonError(
        error instanceof Error
          ? error.message
          : "BioPay liveness challenge creation failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createBiopayCreateLivenessChallengeHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
