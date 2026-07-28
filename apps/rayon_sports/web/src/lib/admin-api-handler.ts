import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
} from "@/lib/admin-club-scope";
import { resolveAdminAccess } from "@/lib/data/admin/access";
import { enforceFeatureState } from "@/lib/server-feature-guard";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";
import { AdminMutationConflictError } from "@/lib/data/admin/helpers";
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
};

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
  try {
    const method = request.method.toUpperCase();
    if (method !== "GET") {
      const rejectedOrigin = rejectInsecureMutation(request);
      if (rejectedOrigin) {
        return rejectedOrigin;
      }

      const rejectedLimit = await rejectRateLimitedRequest(
        request,
        options.rateLimitKey ?? `admin:${request.nextUrl.pathname}`,
        options.mutationLimit ?? 30,
        options.mutationWindowMs ?? 60_000,
      );
      if (rejectedLimit) {
        return rejectedLimit;
      }
    }

    const serverClient = await getServerSupabase();
    if (serverClient == null) {
      return NextResponse.json(
        { error: "Server Supabase is not configured." },
        { status: 500 },
      );
    }

    const {
      data: { user },
      error: authError,
    } = await serverClient.auth.getUser();

    if (authError || user == null) {
      return NextResponse.json(
        { error: "Admin authentication is required." },
        { status: 401 },
      );
    }

    const access = await resolveAdminAccess(serverClient, user, {
      requestedClubId: getRequestedClubId(request),
    });
    if (!access.hasAccess) {
      return NextResponse.json(
        { error: "Admin access denied." },
        { status: 403 },
      );
    }

    if (options.featureGuard) {
      const featureState = await enforceFeatureState(
        options.featureGuard.featureKey,
        options.featureGuard.channel ?? "web",
        options.featureGuard.mode ?? "action",
        {
          clubId: access.clubId,
          isAuthenticated: access.isAuthenticated,
          roles: access.role ? [access.role] : [],
        },
      );

      if (!featureState.allowed) {
        return NextResponse.json(
          {
            code: "FEATURE_DISABLED",
            error:
              featureState.error ?? "Feature disabled or unavailable.",
          },
          { status: 403 },
        );
      }
    }

    if (options.requireSuperAdmin && !access.isSuperAdmin) {
      return NextResponse.json(
        { error: "Platform admin access is required." },
        { status: 403 },
      );
    }

    if (options.destructiveActionId) {
      const contract = getAdminDestructiveActionContract(
        options.destructiveActionId,
      );
      if (contract == null) {
        return NextResponse.json(
          { error: "Unknown destructive action contract." },
          { status: 500 },
        );
      }
      const permission = getAdminDestructivePermission(access, contract);
      if (!permission.allowed) {
        return NextResponse.json(
          { error: permission.reason },
          { status: 403 },
        );
      }
    }

    const adminClient = getAdminSupabase();
    if (adminClient == null) {
      return NextResponse.json(
        { error: "Server admin client is not configured." },
        { status: 500 },
      );
    }

    const data = await handler(adminClient, access, serverClient);
    return NextResponse.json({ data });
  } catch (error) {
    if (error instanceof AdminMutationConflictError) {
      return NextResponse.json(
        {
          code: "STALE_RECORD",
          error: error.message,
        },
        { status: 409 },
      );
    }
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Admin request failed.",
      },
      { status: 500 },
    );
  }
}
