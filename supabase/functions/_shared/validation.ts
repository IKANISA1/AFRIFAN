/**
 * Shared validation helpers for all Edge Functions.
 * Centralizes JWT club_id extraction and request validation per RULES.md §6.3.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { jsonError, jsonForbidden, jsonUnauthorized } from "./response.ts";
import {
  assertVerifiedStaffStepUp,
  hasActiveAdminAssignment,
  HttpError,
  metadataBool,
} from "./auth.ts";
import { fetchBoundedJson } from "./http.ts";
import {
  createAdminClient,
  getSupabasePublishableKey,
  getSupabaseUrl,
} from "./supabase.ts";

export interface ValidatedRequest {
  userId: string;
  isAnonymous: boolean;
  clubId: string | null;
  roles: string[];
  supabase: ReturnType<typeof createClient> | any;
}

function normalizeRole(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

function extractRoles(appMetadata: Record<string, unknown>): string[] {
  const roles = new Set<string>();

  const primaryRole = normalizeRole(appMetadata["role"]);
  if (primaryRole != null) {
    roles.add(primaryRole);
  }

  const adminRole = normalizeRole(appMetadata["admin_role"]);
  if (adminRole != null) {
    roles.add(adminRole);
  }

  const rawRoles = appMetadata["roles"];
  if (Array.isArray(rawRoles)) {
    for (const value of rawRoles) {
      const role = normalizeRole(value);
      if (role != null) {
        roles.add(role);
      }
    }
  }

  if (
    metadataBool(appMetadata["is_admin"]) || metadataBool(appMetadata["admin"])
  ) {
    roles.add("admin");
  }

  if (metadataBool(appMetadata["super_admin"])) {
    roles.add("super_admin");
  }

  return Array.from(roles);
}

export function extractTrustedClubId(
  appMetadata: Record<string, unknown>,
): string | null {
  const value = appMetadata["club_id"];
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) {
    return String(value);
  }
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return /^[1-9][0-9]*$/.test(trimmed) && Number.isSafeInteger(Number(trimmed))
    ? trimmed
    : null;
}

/**
 * Validates the Authorization header, extracts user identity and club_id
 * from JWT claims. Returns a ValidatedRequest on success.
 *
 * Per RULES.md §6.3: All edge functions must validate club_id against JWT claims.
 */
export async function validateRequest(
  req: Request,
  options?: {
    requireClubId?: boolean;
    requireAdmin?: boolean;
    requireClubAdmin?: number | string;
  },
): Promise<ValidatedRequest | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonUnauthorized("Missing Authorization header");
  }

  const supabaseUrl = getSupabaseUrl();
  const supabasePublishableKey = getSupabasePublishableKey();

  const supabase = createClient(supabaseUrl, supabasePublishableKey, {
    global: { headers: { Authorization: authHeader } },
  });

  let authResponseOk = false;
  let user: any;
  try {
    user = await fetchBoundedJson(
      async (input, init) => {
        const response = await fetch(input, init);
        authResponseOk = response.ok;
        return response;
      },
      `${supabaseUrl}/auth/v1/user`,
      {
        headers: {
          Authorization: authHeader,
          apikey: supabasePublishableKey,
        },
      },
      { maxBytes: 128 * 1024, timeoutMs: 10_000, acceptErrorResponse: true },
    );
  } catch (_) {
    return jsonError("Sign-in verification is unavailable.", 503);
  }
  if (!authResponseOk) {
    return jsonUnauthorized("Invalid or expired token");
  }
  if (!user || typeof user !== "object" || typeof user.id !== "string") {
    return jsonUnauthorized("Invalid or expired token");
  }

  const appMetadata = (user.app_metadata ?? {}) as Record<string, unknown>;
  if (
    ["deletion_pending", "failed", "completed", "closed"].includes(
      String(appMetadata["account_lifecycle"] ?? ""),
    )
  ) {
    return jsonForbidden(
      "Account closure is pending. Access has been revoked.",
    );
  }
  // User metadata is user-editable and must never establish tenant scope.
  const clubId = extractTrustedClubId(appMetadata);

  if (options?.requireClubId && !clubId) {
    return jsonForbidden("club_id required in JWT claims");
  }

  const roles = extractRoles(appMetadata);

  if (options?.requireAdmin || options?.requireClubAdmin !== undefined) {
    const scopedClub = options.requireClubAdmin === undefined
      ? undefined
      : extractTrustedClubId({ club_id: options.requireClubAdmin });
    if (scopedClub === null) return jsonForbidden("Invalid club identifier.");
    try {
      // The assignment store is authoritative. JWT roles are presentation hints
      // and may remain stale after a staff grant is revoked.
      const adminClient = createAdminClient();
      if (
        options.requireAdmin &&
        !await hasActiveAdminAssignment(adminClient, user.id)
      ) {
        return jsonForbidden("Admin access required.");
      }
      if (
        scopedClub !== undefined &&
        !await hasActiveAdminAssignment(
          adminClient,
          user.id,
          Number(scopedClub),
        )
      ) {
        return jsonForbidden("Club admin access required.");
      }
      assertVerifiedStaffStepUp(authHeader, user.id, user.is_anonymous);
    } catch (error) {
      return jsonError(
        error instanceof HttpError
          ? error.message
          : "Failed to verify admin access.",
        error instanceof HttpError ? error.status : 503,
      );
    }
  }

  return {
    userId: user.id,
    isAnonymous: user.is_anonymous === true,
    clubId,
    roles,
    supabase,
  };
}

/** Type guard: checks if validateRequest returned an error Response. */
export function isErrorResponse(
  result: ValidatedRequest | Response,
): result is Response {
  return result instanceof Response;
}

/**
 * Validates that a required JSON body field is present and non-empty.
 */
export function requireField<T>(
  body: Record<string, unknown>,
  field: string,
): T | null {
  const value = body[field];
  if (value === undefined || value === null || value === "") {
    return null;
  }
  return value as T;
}
