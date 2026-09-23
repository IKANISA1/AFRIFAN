import { createClient } from "npm:@supabase/supabase-js@2";
import { jsonError } from "./response.ts";

type FeatureGuardOptions = {
  featureKey: string;
  channel?: "mobile" | "web";
  clubId?: number | null;
  isAuthenticated?: boolean;
  roles?: string[];
};

type FeatureAccessState = {
  is_available?: boolean;
  reason?: string;
};

async function fetchFeatureAccessState(
  client: ReturnType<typeof createClient>,
  options: FeatureGuardOptions,
): Promise<FeatureAccessState | null> {
  const rpcClient = client as any;
  const { data, error } = await rpcClient.rpc("get_feature_access_state", {
    p_feature_key: options.featureKey,
    p_channel: options.channel || "mobile",
    p_club_id: options.clubId ?? null,
    p_is_authenticated: options.isAuthenticated ?? true,
    p_roles: options.roles ?? [],
  });

  if (error) {
    console.error(
      `[feature-guard] RPC error for ${options.featureKey}:`,
      error.message,
    );
    return null;
  }

  if (data == null || typeof data !== "object" || Array.isArray(data)) {
    console.error(
      `[feature-guard] Invalid access state payload for ${options.featureKey}:`,
      data,
    );
    return null;
  }

  return data as FeatureAccessState;
}

/**
 * Checks whether a platform feature is available for backend execution.
 *
 * Errors fail closed.
 */
export async function isFeatureEnabled(
  client: ReturnType<typeof createClient>,
  options: FeatureGuardOptions,
): Promise<boolean> {
  try {
    const state = await fetchFeatureAccessState(client, options);
    return state?.is_available === true;
  } catch (err) {
    console.error(
      `[feature-guard] Unexpected error checking ${options.featureKey}:`,
      err,
    );
    return false;
  }
}

/**
 * Helper to enforce that a feature is enabled.
 * If disabled, returns a JSON error response.
 */
export async function enforceFeature(
  client: ReturnType<typeof createClient>,
  options: FeatureGuardOptions,
): Promise<Response | null> {
  try {
    const state = await fetchFeatureAccessState(client, options);
    if (state == null) {
      return jsonError(
        `Feature access could not be resolved for '${options.featureKey}'.`,
        503,
      );
    }

    if (state.is_available === true) {
      return null;
    }

    const reason =
      typeof state.reason === "string" && state.reason.length > 0
        ? state.reason
        : "disabled";
    return jsonError(
      `The feature '${options.featureKey}' is not available (${reason}).`,
      403,
    );
  } catch (err) {
    console.error(
      `[feature-guard] Unexpected error checking ${options.featureKey}:`,
      err,
    );
    return jsonError(
      `Feature access could not be resolved for '${options.featureKey}'.`,
      503,
    );
  }
}
