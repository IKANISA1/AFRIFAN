import { NextResponse } from "next/server";
import { getAdminSupabase } from "./supabase/admin";
import { siteConfig } from "./config";

/**
 * Server-side feature guard using the `check_feature_enabled` RPC.
 *
 * Uses the admin client to bypass RLS and perform a direct check.
 * Returns `{ allowed: true }` if the feature is enabled for the web channel,
 * or `{ allowed: false, error }` with a user-friendly error message.
 */
export async function enforceFeatureState(
  featureKey: string,
  channel: "mobile" | "web" = "web"
): Promise<{ allowed: boolean; error?: string }> {
  const supabase = getAdminSupabase();
  if (!supabase) {
    return { allowed: false, error: "System initialization error." };
  }

  try {
    const { data, error } = await supabase.rpc("check_feature_enabled", {
      p_feature_key: featureKey,
      p_channel: channel,
      p_club_id: siteConfig.defaultClubId,
    });

    if (error) {
      console.error(`[feature-guard] RPC error for ${featureKey}:`, error.message);
      // Fail open — if the check fails, allow the feature (resilience)
      return { allowed: true };
    }

    if (data === false) {
      return {
        allowed: false,
        error: `This feature is currently unavailable.`,
      };
    }

    return { allowed: true };
  } catch (err) {
    console.error(`[feature-guard] Unexpected error for ${featureKey}:`, err);
    // Fail open
    return { allowed: true };
  }
}

/**
 * Wraps an API handler with a feature guard.
 * Returns 403 if the feature is disabled.
 */
export async function withFeatureGuard(
  featureKey: string,
  handler: () => Promise<NextResponse>,
  channel: "mobile" | "web" = "web"
): Promise<NextResponse> {
  const { allowed, error } = await enforceFeatureState(featureKey, channel);

  if (!allowed) {
    return NextResponse.json(
      {
        code: "FEATURE_DISABLED",
        error: error || "Feature disabled or unavailable.",
      },
      { status: 403 }
    );
  }

  return handler();
}
