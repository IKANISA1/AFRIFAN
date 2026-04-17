/**
 * Shared validation helpers for all Edge Functions.
 * Centralizes JWT club_id extraction and request validation per RULES.md §6.3.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { jsonForbidden, jsonUnauthorized } from "./response.ts";

export interface ValidatedRequest {
  userId: string;
  clubId: string | null;
  roles: string[];
  supabase: ReturnType<typeof createClient> | any;
}

const GLOBAL_ADMIN_ROLES = new Set(["admin", "super_admin"]);
const CLUB_ADMIN_ROLES = new Set(["club_admin", "club_moderator"]);

function metadataBool(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "1";
  }
  return false;
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

function hasMetadataAdminAccess(
  appMetadata: Record<string, unknown>,
  clubId?: number | string | null,
): boolean {
  const role = normalizeRole(appMetadata["role"]);
  if (
    metadataBool(appMetadata["is_admin"]) ||
    metadataBool(appMetadata["admin"]) ||
    (role != null && GLOBAL_ADMIN_ROLES.has(role))
  ) {
    return true;
  }

  if (role != null && CLUB_ADMIN_ROLES.has(role)) {
    if (clubId == null) return true;
    return String(appMetadata["club_id"]) === String(clubId);
  }

  return false;
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

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authHeader,
      apikey: supabaseAnonKey,
    },
  });

  if (!authResponse.ok) {
    return jsonUnauthorized("Invalid or expired token");
  }

  const user = await authResponse.json().catch(() => null);
  if (!user || typeof user !== "object" || typeof user.id !== "string") {
    return jsonUnauthorized("Invalid or expired token");
  }

  const clubId = (user.app_metadata?.club_id as string | undefined) ??
    (user.user_metadata?.club_id as string | undefined) ??
    null;

  if (options?.requireClubId && !clubId) {
    return jsonForbidden("club_id required in JWT claims");
  }

  const appMetadata = (user.app_metadata ?? {}) as Record<string, unknown>;
  const roles = extractRoles(appMetadata);

  if (options?.requireAdmin) {
    const isAppAdmin = hasMetadataAdminAccess(appMetadata);
    if (!isAppAdmin) {
      // For global admin, we would normally check admin_role_assignments if not in metadata,
      // but if the JWT doesn't have it, we return forbidden. It expects the JWT to be up to date.
      return jsonForbidden("Admin access required.");
    }
  }

  if (options?.requireClubAdmin !== undefined) {
    const isClubAdmin = hasMetadataAdminAccess(
      appMetadata,
      options.requireClubAdmin,
    );
    if (!isClubAdmin) {
      return jsonForbidden("Club admin access required.");
    }
  }

  return { userId: user.id, clubId, roles, supabase };
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
