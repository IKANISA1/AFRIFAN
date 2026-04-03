import { createAdminClient, createUserClient } from "./supabase.ts";

type AuthUserLike = {
  id: string;
  app_metadata?: Record<string, unknown> | null;
};

type UserClientLike = {
  auth: {
    getUser(): Promise<{
      data: { user: AuthUserLike | null };
      error: unknown;
    }>;
  };
};

type AdminClientLike = unknown;

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

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
      createUserClient(authorization) as unknown as UserClientLike,
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
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function appMetadataClubId(appMetadata: Record<string, unknown>): number | null {
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

async function hasActiveAdminAssignment(
  adminClient: AdminClientLike,
  userId: string,
  clubId?: number,
): Promise<boolean> {
  const { data, error } = await (adminClient as ReturnType<
    typeof createAdminClient
  >)
    .from("admin_role_assignments")
    .select("role, club_id, is_active")
    .eq("user_id", userId)
    .eq("is_active", true);

  if (error) {
    throw new HttpError(500, "Failed to verify admin access.");
  }

  const rows = Array.isArray(data) ? data : [];
  for (const row of rows) {
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
    if (clubId == null && CLUB_ADMIN_ROLES.has(role)) {
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
  } = await userClient.auth.getUser();

  if (error || !user) {
    throw new HttpError(401, "Authentication required.");
  }

  const appMetadata = (user.app_metadata ?? {}) as Record<string, unknown>;
  const isAppAdmin = hasMetadataAdminAccess(appMetadata);

  return {
    user,
    userId: user.id,
    appMetadata,
    isAppAdmin,
    isAdmin: isAppAdmin,
  };
}

export async function requireAdminCaller(
  request: Request,
  dependencies: Partial<AdminAuthDependencies> = {},
): Promise<AuthenticatedCaller> {
  const deps: AdminAuthDependencies = {
    ...defaultAdminAuthDependencies(),
    ...dependencies,
  };

  const caller = await requireAuthenticatedCaller(request, deps);
  if (hasMetadataAdminAccess(caller.appMetadata)) {
    return caller;
  }

  const adminClient = deps.createAdminClient();
  if (await hasActiveAdminAssignment(adminClient, caller.userId)) {
    return {
      ...caller,
      isAdmin: true,
    };
  }

  throw new HttpError(403, "Admin access required.");
}

export async function requireClubAdminCaller(
  request: Request,
  clubId: number,
  dependencies: Partial<AdminAuthDependencies> = {},
): Promise<AuthenticatedCaller> {
  const deps: AdminAuthDependencies = {
    ...defaultAdminAuthDependencies(),
    ...dependencies,
  };

  const caller = await requireAuthenticatedCaller(request, deps);
  if (hasMetadataAdminAccess(caller.appMetadata, clubId)) {
    return {
      ...caller,
      isAdmin: true,
    };
  }

  const adminClient = deps.createAdminClient();
  if (await hasActiveAdminAssignment(adminClient, caller.userId, clubId)) {
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
  const providedSecret = bearerToken ??
    request.headers.get("x-cron-secret")?.trim();

  if (!providedSecret || providedSecret !== configuredSecret) {
    throw new HttpError(401, "Unauthorized.");
  }
}
