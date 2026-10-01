import { NextRequest, NextResponse } from "next/server";
import { adminClubScopeCookieName, getRequestedAdminClubId } from "@/lib/admin-club-scope";
import { resolveAdminAccess } from "@/lib/data/admin";
import { withFeatureGuard } from "@/lib/server-feature-guard";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";
import { controlledApiFailureResponse, controlledApiJson, withControlledApiTimeout } from "@/lib/controlled-api-response";
import { rejectStaffWithoutStepUp } from "@/lib/staff-assurance-server";

function getRequestedClubId(request: NextRequest) {
  return getRequestedAdminClubId(
    request.nextUrl.searchParams,
    request.cookies.get(adminClubScopeCookieName)?.value ?? null,
  );
}

export async function getAdminRequestContext(request: NextRequest) {
  const serverClient = await getServerSupabase();
  if (serverClient == null) {
    return {
      response: controlledApiJson(
        {
          code: "ADMIN_RESOURCE_FAILED",
          error: "The admin resource could not be loaded.",
          retryable: true,
          change_confirmed: false,
        },
        502,
      ),
    };
  }

  const {
    data: { user },
    error: authError,
  } = await serverClient.auth.getUser();
  if (authError || user == null) {
    return {
      response: controlledApiJson(
        {
          code: "ADMIN_AUTHENTICATION_REQUIRED",
          error: "Admin authentication is required.",
        },
        401,
      ),
    };
  }

  const access = await resolveAdminAccess(serverClient, user, {
    requestedClubId: getRequestedClubId(request),
  });
  if (!access.hasAccess) {
    return {
      response: controlledApiJson(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: "Admin access denied.",
        },
        403,
      ),
    };
  }

  const rejectedAssurance = await rejectStaffWithoutStepUp(serverClient, user.id);
  if (rejectedAssurance) return { response: rejectedAssurance };

  const adminClient = getAdminSupabase();
  if (adminClient == null) {
    return {
      response: controlledApiJson(
        {
          code: "ADMIN_RESOURCE_FAILED",
          error: "The admin resource could not be loaded.",
          retryable: true,
          change_confirmed: false,
        },
        502,
      ),
    };
  }

  return { access, adminClient, serverClient };
}

export function requiresPlatformAdmin(resource: string) {
  return (
    resource === "access" ||
    resource === "access-users" ||
    resource === "sms-manual-reviews"
  );
}

export async function parseJsonBody(request: NextRequest) {
  return (await request.json().catch(() => ({}))) as Record<string, unknown>;
}

export async function runAdminResourceOperation(
  operation: () => Promise<NextResponse | undefined>,
) {
  try {
    const response = await withControlledApiTimeout(
      Promise.resolve().then(operation),
    );
    if (response == null) {
      return controlledApiFailureResponse(
        new Error("Admin resource returned no response."),
        "ADMIN_RESOURCE",
      );
    }
    response.headers.set("Cache-Control", "no-store");

    if (response.status === 200) {
      const body = (await response
        .clone()
        .json()
        .catch(() => null)) as {
        data?: unknown;
      } | null;
      if (Array.isArray(body?.data) && body.data.length === 0) {
        return controlledApiJson({
          code: "ADMIN_RESOURCE_EMPTY",
          state: "empty",
          data: [],
        });
      }
    }

    return response;
  } catch (error) {
    return controlledApiFailureResponse(error, "ADMIN_RESOURCE");
  }
}

export function withScopedFeatureGuard(
  access: {
    clubId: string | null;
    isAuthenticated: boolean;
    role: string | null;
  },
  featureKey: string,
  handler: () => Promise<NextResponse>,
) {
  return withFeatureGuard(featureKey, handler, "web", "action", {
    clubId: access.clubId,
    isAuthenticated: access.isAuthenticated,
    roles: access.role ? [access.role] : [],
  });
}

export type AdminResourceContext = Extract<Awaited<ReturnType<typeof getAdminRequestContext>>, { access: unknown }>;
