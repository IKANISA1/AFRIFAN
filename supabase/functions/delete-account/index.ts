import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";

export async function handleRequest(request: Request) {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    const validated = await validateRequest(request);
    if (isErrorResponse(validated)) return validated;
    const { userId } = validated;

    const adminClient = createAdminClient();

    // Rate limit: max 3 deletion attempts per hour per user.
    await enforceRateLimit(adminClient, userId, "delete-account", {
      maxRequests: 3,
      windowSeconds: 3600,
    });

    let body: { user_id?: string } = {};
    try {
      body = await request.json();
    } catch (_) {
      body = {};
    }

    const requestedUserId = body.user_id?.trim();
    if (requestedUserId && requestedUserId !== userId) {
      return jsonError("You can only delete the currently authenticated account.", 403);
    }

    const { error } = await adminClient.auth.admin.deleteUser(userId);
    if (error) {
       return jsonError("Failed to delete the authenticated account.", 500);
    }

    return jsonOk({ success: true, data: { user_id: userId } });
  } catch (error) {
    return jsonError(error instanceof Error ? error.message : "Account deletion failed.", 500);
  }
}

if (import.meta.main) {
  Deno.serve((req: Request) => handleRequest(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}
