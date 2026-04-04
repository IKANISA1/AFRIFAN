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
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type RevokeRequest = {
  reason?: string;
};

type AdminClientLike = ReturnType<typeof createAdminClient>;

export type BiopayRevokeHandlerDependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
  requireAppCheckToken: (request: Request) => Promise<string>;
  recordOperationalHealthEvent: (
    adminClient: AdminClientLike,
    event: Parameters<typeof recordOperationalHealthEvent>[1],
  ) => Promise<void>;
  recordEdgeFunctionFailure: (
    adminClient: AdminClientLike,
    options: Parameters<typeof recordEdgeFunctionFailure>[1],
  ) => Promise<void>;
};

const defaultDependencies: BiopayRevokeHandlerDependencies = {
  createAdminClient,
  validateRequest,
  requireAppCheckToken,
  recordOperationalHealthEvent,
  recordEdgeFunctionFailure,
};

export function createBiopayRevokeHandler(
  dependencies: Partial<BiopayRevokeHandlerDependencies> = {},
) {
  const deps: BiopayRevokeHandlerDependencies = {
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

      const body = await request.json() as RevokeRequest;
      const numericClubId = Number(clubId);

      const { data, error } = await adminClient.rpc(
        "biopay_revoke_profile_server",
        {
          p_requester_user_id: userId,
          p_club_id: numericClubId,
          p_reason: body.reason ?? null,
        },
      );

      if (error) {
        throw error;
      }

      const row = Array.isArray(data) ? data[0] : data;
      if (!row) {
        throw new Error("BioPay revocation did not return a profile.");
      }

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "biopay",
        component: "revocation",
        status: "ok",
        severity: "info",
        message: "BioPay enrollment revoked.",
        functionName: "biopay-revoke",
        userId: userId,
        subjectType: "biopay_profile",
        subjectId: row.profile_id?.toString() ?? null,
        metadata: {
          public_id: row.public_id ?? null,
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
        functionName: "biopay-revoke",
        error,
        issueCode: "biopay_revoke_failed",
        userId: requesterUserId,
      });
      console.error("biopay-revoke failed:", error);
      return jsonError(
        error instanceof Error ? error.message : "BioPay revocation failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createBiopayRevokeHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
