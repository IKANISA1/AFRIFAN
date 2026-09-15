import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
} from "@/lib/admin-club-scope";
import { resolveAdminAccess } from "@/lib/data/admin/access";
import { enforceFeatureState } from "@/lib/server-feature-guard";
import {
  rejectInsecureMutation,
  rejectRateLimitedRequest,
} from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";
import {
  AdminMutationAuthorizationError,
  AdminMutationConflictError,
} from "@/lib/data/admin/helpers";
import {
  getAdminDestructiveActionContract,
  getAdminDestructivePermission,
} from "@/lib/admin-destructive-actions";

type AdminRouteHandler<T> = (
  adminClient: NonNullable<ReturnType<typeof getAdminSupabase>>,
  access: Awaited<ReturnType<typeof resolveAdminAccess>>,
  serverClient: NonNullable<Awaited<ReturnType<typeof getServerSupabase>>>,
) => Promise<T>;

type AdminRouteOptions = {
  featureGuard?: {
    featureKey: string;
    channel?: "mobile" | "web";
    mode?: "navigation" | "route" | "action";
  };
  requireSuperAdmin?: boolean;
  rateLimitKey?: string;
  mutationLimit?: number;
  mutationWindowMs?: number;
  destructiveActionId?: string;
  operationTimeoutMs?: number;
};

const adminApiOperationTimeoutMs = 12_000;

class AdminApiOperationTimeoutError extends Error {
  constructor() {
    super("Admin operation timed out.");
    this.name = "AdminApiOperationTimeoutError";
  }
}

export class AdminApiValidationError extends Error {
  readonly code: string;

  constructor(message: string, code = "ADMIN_REQUEST_EMPTY") {
    super(message);
    this.name = "AdminApiValidationError";
    this.code = code;
  }
}

export class AdminApiAuthorizationError extends Error {
  readonly code: string;

  constructor(message = "Admin access denied.", code = "ADMIN_ACCESS_DENIED") {
    super(message);
    this.name = "AdminApiAuthorizationError";
    this.code = code;
  }
}

function adminJsonResponse(body: unknown, status = 200) {
  return NextResponse.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
    },
  });
}

async function withAdminApiOperationTimeout<T>(
  operation: T,
  timeoutMs: number,
): Promise<Awaited<T>> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race<Awaited<T>>([
      Promise.resolve(operation),
      new Promise<Awaited<T>>((_resolve, reject) => {
        timeoutId = setTimeout(() => {
          reject(new AdminApiOperationTimeoutError());
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId != null) {
      clearTimeout(timeoutId);
    }
  }
}

function getRequestedClubId(request: NextRequest) {
  return getRequestedAdminClubId(
    request.nextUrl.searchParams,
    request.cookies.get(adminClubScopeCookieName)?.value ?? null,
  );
}

export async function handleAdminApiRoute<T>(
  request: NextRequest,
  handler: AdminRouteHandler<T>,
  options: AdminRouteOptions = {},
) {
  const operationTimeoutMs =
    options.operationTimeoutMs ?? adminApiOperationTimeoutMs;

  try {
    const method = request.method.toUpperCase();
    if (method !== "GET") {
      const rejectedOrigin = rejectInsecureMutation(request);
      if (rejectedOrigin) {
        return rejectedOrigin;
      }

      const rejectedLimit = await withAdminApiOperationTimeout(
        rejectRateLimitedRequest(
          request,
          options.rateLimitKey ?? `admin:${request.nextUrl.pathname}`,
          options.mutationLimit ?? 30,
          options.mutationWindowMs ?? 60_000,
        ),
        operationTimeoutMs,
      );
      if (rejectedLimit) {
        return rejectedLimit;
      }
    }

    const serverClient = await withAdminApiOperationTimeout(
      getServerSupabase(),
      operationTimeoutMs,
    );
    if (serverClient == null) {
      return adminJsonResponse(
        {
          code: "ADMIN_REQUEST_FAILED",
          error: "Admin request failed.",
          retryable: true,
          change_confirmed: false,
        },
        500,
      );
    }

    const {
      data: { user },
      error: authError,
    } = await withAdminApiOperationTimeout(
      serverClient.auth.getUser(),
      operationTimeoutMs,
    );

    if (authError || user == null) {
      return adminJsonResponse(
        {
          code: "ADMIN_AUTHENTICATION_REQUIRED",
          error: "Admin authentication is required.",
        },
        401,
      );
    }

    const access = await withAdminApiOperationTimeout(
      resolveAdminAccess(serverClient, user, {
        requestedClubId: getRequestedClubId(request),
      }),
      operationTimeoutMs,
    );
    if (!access.hasAccess) {
      return adminJsonResponse(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: "Admin access denied.",
        },
        403,
      );
    }

    if (options.featureGuard) {
      const featureState = await withAdminApiOperationTimeout(
        enforceFeatureState(
          options.featureGuard.featureKey,
          options.featureGuard.channel ?? "web",
          options.featureGuard.mode ?? "action",
          {
            clubId: access.clubId,
            isAuthenticated: access.isAuthenticated,
            roles: access.role ? [access.role] : [],
          },
        ),
        operationTimeoutMs,
      );

      if (!featureState.allowed) {
        return adminJsonResponse(
          {
            code: "FEATURE_DISABLED",
            error: featureState.error ?? "Feature disabled or unavailable.",
          },
          403,
        );
      }
    }

    if (options.requireSuperAdmin && !access.isSuperAdmin) {
      return adminJsonResponse(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: "Platform admin access is required.",
        },
        403,
      );
    }

    if (options.destructiveActionId) {
      const contract = getAdminDestructiveActionContract(
        options.destructiveActionId,
      );
      if (contract == null) {
        return adminJsonResponse(
          {
            code: "ADMIN_REQUEST_FAILED",
            error: "Admin request failed.",
            retryable: false,
            change_confirmed: false,
          },
          500,
        );
      }
      const permission = getAdminDestructivePermission(access, contract);
      if (!permission.allowed) {
        return adminJsonResponse(
          {
            code: "ADMIN_ACCESS_DENIED",
            error: permission.reason,
          },
          403,
        );
      }
    }

    const adminClient = getAdminSupabase();
    if (adminClient == null) {
      return adminJsonResponse(
        {
          code: "ADMIN_REQUEST_FAILED",
          error: "Admin request failed.",
          retryable: true,
          change_confirmed: false,
        },
        500,
      );
    }

    const data = await withAdminApiOperationTimeout(
      handler(adminClient, access, serverClient),
      operationTimeoutMs,
    );
    if (Array.isArray(data) && data.length === 0) {
      return adminJsonResponse({
        code: "ADMIN_RESOURCE_EMPTY",
        state: "empty",
        data: [],
      });
    }
    return adminJsonResponse({ data });
  } catch (error) {
    if (error instanceof AdminApiOperationTimeoutError) {
      return adminJsonResponse(
        {
          code: "ADMIN_OPERATION_TIMEOUT",
          error:
            "The admin operation timed out. Check current data before retrying.",
          retryable: true,
          change_confirmed: false,
        },
        504,
      );
    }
    if (error instanceof AdminMutationConflictError) {
      return adminJsonResponse(
        {
          code: "STALE_RECORD",
          error:
            "This record changed after it was loaded. Refresh the latest data before retrying.",
          retryable: true,
          change_confirmed: false,
        },
        409,
      );
    }
    if (error instanceof AdminApiValidationError) {
      return adminJsonResponse(
        {
          code: error.code,
          error: error.message,
          retryable: false,
          change_confirmed: false,
        },
        400,
      );
    }
    if (
      error instanceof AdminApiAuthorizationError ||
      error instanceof AdminMutationAuthorizationError
    ) {
      return adminJsonResponse(
        {
          code: error.code,
          error: error.message,
          retryable: false,
          change_confirmed: false,
        },
        403,
      );
    }
    return adminJsonResponse(
      {
        code: "ADMIN_REQUEST_FAILED",
        error: "Admin request failed.",
        retryable: true,
        change_confirmed: false,
      },
      500,
    );
  }
}
