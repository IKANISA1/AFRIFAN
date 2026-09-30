
import { recordProductDiagnostic } from "./privacy-safe-diagnostics";
import { NextResponse } from "next/server";
import { getActiveClubReference } from "./club-context";
import { getAdminSupabase } from "./supabase/admin";

type FeatureGuardMode = "navigation" | "route" | "action";
type FeatureGuardContext = {
  clubId?: number | string | null;
  isAuthenticated?: boolean;
  roles?: string[];
};

type FeatureStatePayload = {
  is_registered?: boolean;
  is_visible?: boolean;
  is_operational?: boolean;
  is_available?: boolean;
  reason?: string | null;
};

function parseFeatureState(data: unknown): FeatureStatePayload | null {
  if (data == null || typeof data !== "object" || Array.isArray(data)) {
    return null;
  }

  return data as FeatureStatePayload;
}

function resolveGuardResult(
  state: FeatureStatePayload,
  mode: FeatureGuardMode,
): { allowed: boolean; error?: string } {
  const isRegistered = state.is_registered ?? false;
  const isVisible = state.is_visible ?? false;
  const isOperational = state.is_operational ?? false;
  const isAvailable = state.is_available ?? false;
  const reason = state.reason ?? "unknown";

  if (!isRegistered) {
    return {
      allowed: false,
      error: "This feature is not registered for this platform.",
    };
  }

  let allowed = false;
  switch (mode) {
    case "navigation":
      allowed = isVisible;
      break;
    case "route":
      allowed = isVisible && isAvailable;
      break;
    case "action":
      allowed = isOperational && isAvailable;
      break;
  }

  if (allowed) {
    return { allowed: true };
  }

  let message = "This feature is currently unavailable.";
  switch (reason) {
    case "global_disabled":
      message = "This feature is currently disabled.";
      break;
    case "channel_disabled":
      message = "This feature is unavailable on this channel.";
      break;
    case "hidden":
    case "channel_hidden":
      message = "This feature is not currently available.";
      break;
    case "maintenance":
      message = "This feature is temporarily in maintenance.";
      break;
    case "outside_schedule":
      message = "This feature is not active right now.";
      break;
    case "dependency_blocked":
      message = "This feature depends on another unavailable module.";
      break;
    case "auth_required":
      message = "You need to sign in to use this feature.";
      break;
    case "role_restricted":
      message = "Your account is not allowed to use this feature.";
      break;
  }

  return { allowed: false, error: message };
}

/**
 * Server-side feature guard using the `get_feature_access_state` RPC.
 *
 * Uses the admin client to evaluate feature visibility and operational state
 * while failing closed on backend errors.
 */
export async function enforceFeatureState(
  featureKey: string,
  channel: "mobile" | "web" = "web",
  mode: FeatureGuardMode = "action",
  context: FeatureGuardContext = {},
): Promise<{ allowed: boolean; error?: string }> {
  const supabase = getAdminSupabase();
  if (!supabase) {
    return { allowed: false, error: "System initialization error." };
  }

  try {
    const requestedClubId =
      typeof context.clubId === "number"
        ? context.clubId
        : Number.parseInt(String(context.clubId ?? ""), 10);
    const clubId = Number.isFinite(requestedClubId)
      ? requestedClubId
      : (await getActiveClubReference()).numericId;
    const adminClient = supabase as unknown as {
      rpc: (
        name: string,
        params: Record<string, unknown>,
      ) => Promise<{ data: unknown; error: { message?: string } | null }>;
    };
    const { data, error } = await adminClient.rpc("get_feature_access_state", {
      p_feature_key: featureKey,
      p_channel: channel,
      p_club_id: clubId,
      p_is_authenticated: context.isAuthenticated ?? false,
      p_roles: (context.roles ?? []).filter(
        (role): role is string => typeof role === "string" && role.trim().length > 0,
      ),
    });

    if (error) {
      recordProductDiagnostic("feature_guard_rpc_failed");
      return { allowed: false, error: "Feature access could not be verified." };
    }

    const state = parseFeatureState(data);
    if (state == null) {
      return { allowed: false, error: "Feature access could not be verified." };
    }

    return resolveGuardResult(state, mode);
  } catch {
    recordProductDiagnostic("feature_guard_unavailable");
    return { allowed: false, error: "Feature access could not be verified." };
  }
}

/**
 * Wraps an API handler with a feature guard.
 * Returns 403 if the feature is disabled.
 */
export async function withFeatureGuard(
  featureKey: string,
  handler: () => Promise<NextResponse>,
  channel: "mobile" | "web" = "web",
  mode: FeatureGuardMode = "action",
  context: FeatureGuardContext = {},
): Promise<NextResponse> {
  const { allowed, error } = await enforceFeatureState(
    featureKey,
    channel,
    mode,
    context,
  );

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
