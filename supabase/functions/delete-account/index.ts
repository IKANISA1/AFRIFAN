import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireAuthenticatedCaller } from "../_shared/auth.ts";
import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type DeleteAccountRequest = {
  user_id?: string;
};

type AdminClientLike = {
  auth: {
    admin: {
      deleteUser(
        userId: string,
      ): Promise<{ data: unknown; error: unknown }>;
    };
  };
};

type DeleteAccountDependencies = {
  createAdminClient: () => AdminClientLike;
  requireAuthenticatedCaller: typeof requireAuthenticatedCaller;
};

const defaultDependencies: DeleteAccountDependencies = {
  createAdminClient: () => createAdminClient() as unknown as AdminClientLike,
  requireAuthenticatedCaller,
};

export function createDeleteAccountHandler(
  dependencies: Partial<DeleteAccountDependencies> = {},
) {
  const deps: DeleteAccountDependencies = {
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

    try {
      const caller = await deps.requireAuthenticatedCaller(request);
      const adminClient = deps.createAdminClient();

      let body: DeleteAccountRequest = {};
      try {
        body = await request.json() as DeleteAccountRequest;
      } catch (_) {
        body = {};
      }

      const requestedUserId = body.user_id?.trim();
      if (
        requestedUserId != null &&
        requestedUserId.isNotEmpty &&
        requestedUserId !== caller.userId
      ) {
        throw new HttpError(
          403,
          "You can only delete the currently authenticated account.",
        );
      }

      const { error } = await adminClient.auth.admin.deleteUser(caller.userId);
      if (error) {
        throw new HttpError(500, "Failed to delete the authenticated account.");
      }

      return jsonResponse({
        success: true,
        data: { user_id: caller.userId },
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return errorResponse(error.message, error.status);
      }

      return errorResponse(
        error instanceof Error ? error.message : "Account deletion failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createDeleteAccountHandler());
}
