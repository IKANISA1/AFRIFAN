import { logDiagnostic } from "../_shared/diagnostics.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createAnonClient } from "../_shared/supabase.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
  withEdgeBoundary,
} from "../_shared/response.ts";

export const handleRequest = async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return corsPreflightResponse(req);
  }

  try {
    const url = new URL(req.url);
    const channel = url.searchParams.get("channel") || "mobile";
    const clubIdStr = url.searchParams.get("club_id");
    const clubId = clubIdStr ? parseInt(clubIdStr, 10) : null;

    if (!clubId) {
      return jsonError("club_id is required", 400);
    }

    const supabase = createAnonClient();

    // Call the RPC function
    const { data, error } = await supabase.rpc("get_platform_config", {
      p_channel: channel,
      p_club_id: clubId,
    });

    if (error) {
      logDiagnostic("error", "get_platform_config_rpc_error", error);
      return jsonError(error.message, 500);
    }

    // Prepare response with caching headers
    const response = jsonOk(data);

    // Set caching headers for browser/CDN
    // 60s public cache, 300s stale-while-revalidate
    response.headers.set(
      "Cache-Control",
      "public, max-age=60, stale-while-revalidate=300",
    );

    // Add CORS headers to the successful response
    Object.entries(corsHeaders()).forEach(([key, value]) => {
      response.headers.set(key, value as string);
    });

    return response;
  } catch (error) {
    logDiagnostic("error", "get_platform_config_unexpected_error", error);
    return jsonError("Internal server error", 500);
  }
};
if (import.meta.main) serve(withEdgeBoundary(handleRequest));
