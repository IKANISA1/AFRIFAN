import { createClient } from "npm:@supabase/supabase-js@2";
import { jsonError } from "./response.ts";

/**
 * Checks if a platform feature is enabled for a specific channel and club.
 *
 * Uses the `check_feature_enabled` RPC in Supabase.
 * Returns `true` if enabled or if the check fails (fail-open for resilience).
 */
export async function isFeatureEnabled(
  client: ReturnType<typeof createClient>,
  options: {
    featureKey: string;
    channel?: "mobile" | "web";
    clubId?: number | null;
  }
): Promise<boolean> {
  try {
    const { data, error } = await client.rpc("check_feature_enabled", {
      p_feature_key: options.featureKey,
      p_channel: options.channel || "mobile",
      p_club_id: options.clubId ?? null,
    });

    if (error) {
      console.error(`[feature-guard] RPC error for ${options.featureKey}:`, error.message);
      return true; // Fail open
    }

    // data is boolean or null
    return data !== false;
  } catch (err) {
    console.error(`[feature-guard] Unexpected error checking ${options.featureKey}:`, err);
    return true; // Fail open
  }
}

/**
 * Helper to enforce that a feature is enabled. 
 * If disabled, returns a 403 jsonError response.
 */
export async function enforceFeature(
  client: ReturnType<typeof createClient>,
  options: {
    featureKey: string;
    channel?: "mobile" | "web";
    clubId?: number | null;
  }
): Promise<Response | null> {
  const enabled = await isFeatureEnabled(client, options);
  if (!enabled) {
    return jsonError(`The feature '${options.featureKey}' is currently disabled for this channel.`, 403);
  }
  return null;
}
