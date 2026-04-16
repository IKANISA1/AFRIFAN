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
import { normalizeBioPayEmbedding } from "../_shared/BioPay_embedding.ts";
import { validateBioPayLivenessMetadata } from "../_shared/BioPay_liveness.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type EnrollRequest = {
  display_name?: string;
  route_type?: string;
  recipient_value?: string;
  country_code?: string;
  consent_version?: string;
  embedding?: unknown;
  liveness?: unknown;
  model_version?: string;
  quality_score?: number;
};

type AdminClientLike = ReturnType<typeof createAdminClient>;

export type BioPayEnrollHandlerDependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
  requireAppCheckToken: (request: Request) => Promise<string>;
  validateLiveness: typeof validateBioPayLivenessMetadata;
  recordOperationalHealthEvent: (
    adminClient: AdminClientLike,
    event: Parameters<typeof recordOperationalHealthEvent>[1],
  ) => Promise<void>;
  recordEdgeFunctionFailure: (
    adminClient: AdminClientLike,
    options: Parameters<typeof recordEdgeFunctionFailure>[1],
  ) => Promise<void>;
};

const defaultDependencies: BioPayEnrollHandlerDependencies = {
  createAdminClient,
  validateRequest,
  requireAppCheckToken,
  validateLiveness: validateBioPayLivenessMetadata,
  recordOperationalHealthEvent,
  recordEdgeFunctionFailure,
};

export function createBioPayEnrollHandler(
  dependencies: Partial<BioPayEnrollHandlerDependencies> = {},
) {
  const deps: BioPayEnrollHandlerDependencies = {
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

      await deps.requireAppCheckToken(request);

      const body = await request.json() as EnrollRequest;
      const embedding = normalizeBioPayEmbedding(body.embedding);

      const numericClubId = Number(clubId);

      const liveness = await deps.validateLiveness(body.liveness, {
        adminClient,
        requesterUserId: userId,
        clubId: numericClubId,
        mode: "enrollment",
      });

      const { data, error } = await adminClient.rpc(
        "BioPay_upsert_enrollment_server",
        {
          p_requester_user_id: userId,
          p_club_id: numericClubId,
          p_display_name: body.display_name ?? null,
          p_route_type: body.route_type ?? null,
          p_recipient_value: body.recipient_value ?? null,
          p_country_code: body.country_code ?? "RW",
          p_consent_version: body.consent_version ?? "BioPay-v1",
          p_embedding: embedding,
          p_model_version: body.model_version ?? "mobilefacenet_int8_v1",
          p_quality_score: body.quality_score ?? null,
        },
      );

      if (error) {
        throw error;
      }

      const row = Array.isArray(data) ? data[0] : data;
      if (!row) {
        throw new Error("BioPay enrollment did not return a profile.");
      }

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "BioPay",
        component: "enrollment",
        status: "ok",
        severity: "info",
        message: "BioPay enrollment completed.",
        functionName: "BioPay-enroll",
        userId: userId,
        subjectType: "BioPay_profile",
        subjectId: row.id?.toString() ?? null,
        metadata: {
          route_type: row.route_type ?? null,
          country_code: row.country_code ?? null,
          liveness,
          app_check_enforced: true,
        },
      });

      return jsonOk({
        success: true,
        data: row,
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }

      await deps.recordEdgeFunctionFailure(adminClient, {
        functionName: "BioPay-enroll",
        error,
        issueCode: "BioPay_enroll_failed",
        userId: requesterUserId,
      });

      console.error("BioPay-enroll failed:", error);
      return jsonError(
        error instanceof Error ? error.message : "BioPay enrollment failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createBioPayEnrollHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
