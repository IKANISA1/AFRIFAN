import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { HttpError } from "../_shared/auth.ts";
import { requireAppCheckToken } from "../_shared/app_check.ts";
import { resolveClubIdFromMetadata } from "../_shared/club.ts";
import {
  generateBiopayNonce,
  signBiopayToken,
  type SignedBiopayTokenPayload,
} from "../_shared/biopay_signed_token.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { createAdminClient, createUserClient } from "../_shared/supabase.ts";

type CreateChallengeRequest = {
  mode?: string;
};

type AdminClientLike = ReturnType<typeof createAdminClient>;
type UserClientLike = {
  auth: {
    getUser(): Promise<{
      data: {
        user: { id: string; app_metadata?: Record<string, unknown> } | null;
      };
      error: unknown;
    }>;
  };
};

export type BiopayCreateLivenessChallengeDependencies = {
  createAdminClient: () => AdminClientLike;
  createUserClient: (authorization: string) => UserClientLike;
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
  createUserClient: (authorization) =>
    createUserClient(authorization) as unknown as UserClientLike,
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
    const corsResponse = handleCors(request);
    if (corsResponse) {
      return corsResponse;
    }

    if (request.method !== "POST") {
      return methodNotAllowed("POST");
    }

    const adminClient = deps.createAdminClient();
    let requesterUserId: string | null = null;

    try {
      const authorization = request.headers.get("authorization") ??
        request.headers.get("Authorization");
      if (!authorization) {
        return errorResponse("Missing authorization header.", 401);
      }

      const userClient = deps.createUserClient(authorization);
      const { data: authData, error: authError } = await userClient.auth
        .getUser();
      if (authError || !authData.user) {
        return errorResponse("Unauthorized.", 401);
      }

      requesterUserId = authData.user.id;
      await deps.requireAppCheckToken(request);

      const body = await request.json() as CreateChallengeRequest;
      const mode = body.mode?.trim().toLowerCase() === "enrollment"
        ? "enrollment"
        : "payment";
      const clubId = await resolveClubIdFromMetadata(
        adminClient,
        authData.user.app_metadata,
      );

      const now = deps.now();
      const expiresAt = new Date(
        now.getTime() + CHALLENGE_TTL_SECONDS * 1000,
      ).toISOString();
      const nonce = generateBiopayNonce();

      const { data: challengeRow, error: challengeError } = await adminClient
        .from("biopay_liveness_challenges")
        .insert({
          user_id: authData.user.id,
          club_id: clubId,
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
        requester_user_id: authData.user.id,
        club_id: clubId,
        mode,
      });

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "biopay",
        component: "liveness",
        status: "ok",
        severity: "info",
        message: "BioPay liveness challenge issued.",
        functionName: "biopay-create-liveness-challenge",
        userId: authData.user.id,
        subjectType: "biopay_liveness_challenge",
        subjectId: challengeRow.id?.toString() ?? null,
        metadata: {
          club_id: clubId,
          mode,
          expires_at: expiresAt,
        },
      });

      return jsonResponse({
        success: true,
        data: {
          token,
          mode,
          expires_at: expiresAt,
        },
      });
    } catch (error) {
      if (error instanceof SyntaxError) {
        return errorResponse("Invalid JSON body.", 400);
      }
      if (error instanceof HttpError) {
        return errorResponse(error.message, error.status);
      }

      await deps.recordEdgeFunctionFailure(adminClient, {
        functionName: "biopay-create-liveness-challenge",
        error,
        issueCode: "biopay_create_liveness_challenge_failed",
        userId: requesterUserId,
      });
      return errorResponse(
        error instanceof Error
          ? error.message
          : "BioPay liveness challenge creation failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createBiopayCreateLivenessChallengeHandler());
}
