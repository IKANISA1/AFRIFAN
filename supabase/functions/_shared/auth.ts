import { createAdminClient } from "./supabase.ts";
import { createLifecycleUserClient } from "./account_lifecycle_client.ts";

type AuthUserLike = {
  id: string;
  app_metadata?: Record<string, unknown> | null;
  is_anonymous?: boolean;
};

type UserClientLike = {
  auth: {
    getUser(jwt?: string): Promise<{
      data: { user: AuthUserLike | null };
      error: unknown;
    }>;
  };
};

type AdminClientLike = unknown;

import { HttpError } from "./http_error.ts";
export { HttpError } from "./http_error.ts";

export type AuthenticatedCaller = {
  user: AuthUserLike;
  userId: string;
  appMetadata: Record<string, unknown>;
  isAppAdmin: boolean;
  isAdmin: boolean;
};

type AuthDependencies = {
  createUserClient: (authorization: string) => UserClientLike;
};

type AdminAuthDependencies = AuthDependencies & {
  createAdminClient: () => AdminClientLike;
};

function defaultAuthDependencies(): AuthDependencies {
  return {
    createUserClient: (authorization) =>
      createLifecycleUserClient(authorization) as unknown as UserClientLike,
  };
}

function defaultAdminAuthDependencies(): AdminAuthDependencies {
  return {
    ...defaultAuthDependencies(),
    createAdminClient: () => createAdminClient() as unknown as AdminClientLike,
  };
}

const GLOBAL_ADMIN_ROLES = new Set(["admin", "super_admin"]);
const CLUB_ADMIN_ROLES = new Set(["club_admin", "club_moderator"]);

export function metadataBool(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "1";
  }
  return false;
}

function normalizeRole(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeClubId(value: unknown): number | null {
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) {
    return value;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    const parsed = /^[1-9][0-9]*$/.test(trimmed) ? Number(trimmed) : NaN;
    return Number.isSafeInteger(parsed) ? parsed : null;
  }
  return null;
}

function appMetadataClubId(
  appMetadata: Record<string, unknown>,
): number | null {
  return normalizeClubId(appMetadata["club_id"]);
}

function hasMetadataAdminAccess(
  appMetadata: Record<string, unknown>,
  clubId?: number,
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
    if (clubId == null) {
      return true;
    }
    return appMetadataClubId(appMetadata) == clubId;
  }

  return false;
}

export async function hasActiveAdminAssignment(
  adminClient: AdminClientLike,
  userId: string,
  clubId?: number,
): Promise<boolean> {
  const { data, error } = await (adminClient as ReturnType<
    typeof createAdminClient
  >)
    .from("admin_role_assignments")
    .select("role, club_id, is_active, revoked_at")
    .eq("user_id", userId)
    .eq("is_active", true);

  if (error) {
    throw new HttpError(500, "Failed to verify admin access.");
  }

  const rows = Array.isArray(data) ? data : [];
  for (const row of rows) {
    if (row["is_active"] !== true || row["revoked_at"] != null) continue;
    const role = normalizeRole(row["role"]);
    if (role == null) {
      continue;
    }
    if (GLOBAL_ADMIN_ROLES.has(role)) {
      return true;
    }
    if (
      clubId != null &&
      CLUB_ADMIN_ROLES.has(role) &&
      normalizeClubId(row["club_id"]) == clubId
    ) {
      return true;
    }
  }

  return false;
}

export function getAuthorizationHeader(request: Request): string | null {
  const value = request.headers.get("authorization") ??
    request.headers.get("Authorization");
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : null;
}

function bearerJwt(authorization: string): string {
  const matched = /^Bearer ([A-Za-z0-9_.-]{1,16384})$/.exec(authorization);
  if (!matched) throw new HttpError(401, "Authentication required.");
  return matched[1];
}

/**
 * Decode only the exact bearer JWT already validated by provider getUser, after
 * current assignment authorization. This is an additional denial check, never
 * a JWT signature verifier or a substitute for provider identity verification.
 */
export function assertVerifiedStaffStepUp(
  authorization: string,
  verifiedUserId: string,
  providerIsAnonymous?: boolean,
): void {
  const denied = () =>
    new HttpError(403, "Verify your authenticator code to continue.");
  try {
    const jwt = bearerJwt(authorization);
    const parts = jwt.split(".");
    if (
      parts.length !== 3 || parts.some((part) =>
        !/^[A-Za-z0-9_-]+$/.test(part)
      ) || parts[1].length > 8192
    ) throw denied();
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const bytes = Uint8Array.from(
      atob(payload.padEnd(Math.ceil(payload.length / 4) * 4, "=")),
      (character) => character.charCodeAt(0),
    );
    const claims: unknown = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (!claims || typeof claims !== "object" || Array.isArray(claims)) {
      throw denied();
    }
    const c = claims as Record<string, unknown>;
    const now = Math.floor(Date.now() / 1000);
    if (
      c.sub !== verifiedUserId || c.role !== "authenticated" ||
      c.is_anonymous !== false || providerIsAnonymous === true ||
      c.aal !== "aal2" || !Number.isSafeInteger(c.exp) ||
      Number(c.exp) <= now || !Array.isArray(c.amr) || c.amr.length === 0 ||
      c.amr.length > 16
    ) throw denied();
    const methods = c.amr as Record<string, unknown>[];
    if (
      methods.some((method) =>
        !method || typeof method !== "object" || Array.isArray(method) ||
        typeof method.method !== "string" ||
        !Number.isSafeInteger(method.timestamp) || Number(method.timestamp) < 0
      )
    ) throw denied();
    if (
      !methods.some((method) =>
        (method.method === "totp" || method.method === "mfa/totp") &&
        Number(method.timestamp) >= now - 300 &&
        Number(method.timestamp) <= now + 30
      )
    ) throw denied();
  } catch {
    throw denied();
  }
}

export async function requireAuthenticatedCaller(
  request: Request,
  dependencies: Partial<AuthDependencies> = {},
): Promise<AuthenticatedCaller> {
  const deps: AuthDependencies = {
    ...defaultAuthDependencies(),
    ...dependencies,
  };

  const authorization = getAuthorizationHeader(request);
  if (!authorization) {
    throw new HttpError(401, "Authentication required.");
  }

  const userClient = deps.createUserClient(authorization);
  const {
    data: { user },
    error,
  } = await userClient.auth.getUser(bearerJwt(authorization));

  if (error || !user || typeof user.id !== "string" || !user.id) {
    throw new HttpError(401, "Authentication required.");
  }

  const appMetadata = (user.app_metadata ?? {}) as Record<string, unknown>;
  if (
    ["deletion_pending", "failed", "completed", "closed"].includes(
      String(appMetadata["account_lifecycle"] ?? ""),
    )
  ) {
    throw new HttpError(
      403,
      "Account closure is pending. Access has been revoked.",
    );
  }
  const isAppAdmin = hasMetadataAdminAccess(appMetadata);

  return {
    user,
    userId: user.id,
    appMetadata,
    isAppAdmin,
    // Metadata is a presentation hint, never current authorization.
    isAdmin: false,
  };
}

export async function requireGlobalAdminCaller(
  request: Request,
  dependencies: Partial<AdminAuthDependencies> = {},
): Promise<AuthenticatedCaller> {
  const deps: AdminAuthDependencies = {
    ...defaultAdminAuthDependencies(),
    ...dependencies,
  };

  const authorization = getAuthorizationHeader(request) ?? "";
  const caller = await requireAuthenticatedCaller(request, deps);
  const adminClient = deps.createAdminClient();
  if (await hasActiveAdminAssignment(adminClient, caller.userId)) {
    assertVerifiedStaffStepUp(
      authorization,
      caller.userId,
      caller.user.is_anonymous,
    );
    return {
      ...caller,
      isAdmin: true,
    };
  }

  throw new HttpError(403, "Admin access required.");
}

/** Compatibility alias with global-only semantics. Prefer an explicit scope. */
export const requireAdminCaller = requireGlobalAdminCaller;

export async function requireClubAdminCaller(
  request: Request,
  clubId: number,
  dependencies: Partial<AdminAuthDependencies> = {},
): Promise<AuthenticatedCaller> {
  const deps: AdminAuthDependencies = {
    ...defaultAdminAuthDependencies(),
    ...dependencies,
  };

  if (normalizeClubId(clubId) !== clubId) {
    throw new HttpError(400, "Invalid club identifier.");
  }

  const authorization = getAuthorizationHeader(request) ?? "";
  const caller = await requireAuthenticatedCaller(request, deps);

  const adminClient = deps.createAdminClient();
  if (await hasActiveAdminAssignment(adminClient, caller.userId, clubId)) {
    assertVerifiedStaffStepUp(
      authorization,
      caller.userId,
      caller.user.is_anonymous,
    );
    return {
      ...caller,
      isAdmin: true,
    };
  }

  throw new HttpError(403, "Club admin access required.");
}

export function requireCronSecret(
  request: Request,
  envNames: string[] = ["CRON_JOB_SECRET"],
  options: {
    getEnv?: (name: string) => string | undefined;
  } = {},
): void {
  const getEnv = options.getEnv ?? ((name: string) => Deno.env.get(name));
  const configuredSecret = envNames
    .map((name) => getEnv(name)?.trim())
    .find((value) => value != null && value.length > 0);

  if (!configuredSecret) {
    throw new HttpError(
      500,
      `Missing cron secret configuration: ${envNames.join(" or ")}`,
    );
  }

  const authorization = getAuthorizationHeader(request);
  const bearerToken = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : null;
  // Prefer x-cron-secret header over Bearer (Bearer may be a Supabase JWT for gateway auth)
  const cronHeader = request.headers.get("x-cron-secret")?.trim();
  const providedSecret = cronHeader ?? bearerToken;

  if (!providedSecret || providedSecret !== configuredSecret) {
    throw new HttpError(401, "Unauthorized.");
  }
}
