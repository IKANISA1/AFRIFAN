import { NextRequest, NextResponse } from "next/server";
import { adminClubScopeCookieName, getRequestedAdminClubId } from "@/lib/admin-club-scope";
import {
  deleteAdminFanEngagementToken,
  deleteAdminArticle,
  deleteAdminContributionGroup,
  deleteAdminFanClub,
  deleteAdminMatch,
  deleteAdminMembershipPackage,
  deleteAdminProduct,
  deleteAdminSquadPlayer,
  deleteAdminStandingRow,
  getAdminArticles,
  getAdminClubProfile,
  getAdminContributionSnapshot,
  getAdminDashboardSnapshot,
  getAdminFanEngagementTokens,
  getAdminFanClubs,
  getAdminMatches,
  getAdminMembershipPackages,
  getAdminNotificationContext,
  getAdminProducts,
  getAdminSmsSnapshot,
  getAdminSquad,
  getAdminStandings,
  resolveAdminAccess,
  saveAdminArticle,
  saveAdminContributionGroup,
  saveAdminFanClub,
  saveAdminFanEngagementToken,
  saveAdminClubProfile,
  saveAdminMatch,
  saveAdminMembershipPackage,
  saveAdminProduct,
  saveAdminSquadPlayer,
  saveAdminStandingRow,
  sendAdminNotification,
} from "@/lib/data/admin";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function getRequestedClubId(request: NextRequest) {
  return getRequestedAdminClubId(
    request.nextUrl.searchParams,
    request.cookies.get(adminClubScopeCookieName)?.value ?? null,
  );
}

async function getAdminRequestContext(request: NextRequest) {
  const serverClient = await getServerSupabase();
  if (serverClient == null) {
    return {
      response: NextResponse.json(
        { error: "Server Supabase is not configured." },
        { status: 500 },
      ),
    };
  }

  const {
    data: { user },
    error: authError,
  } = await serverClient.auth.getUser();
  if (authError || user == null) {
    return {
      response: NextResponse.json(
        { error: "Admin authentication is required." },
        { status: 401 },
      ),
    };
  }

  const access = await resolveAdminAccess(serverClient, user, {
    requestedClubId: getRequestedClubId(request),
  });
  if (!access.hasAccess) {
    return {
      response: NextResponse.json(
        { error: "Admin access denied." },
        { status: 403 },
      ),
    };
  }

  const adminClient = getAdminSupabase();
  if (adminClient == null) {
    return {
      response: NextResponse.json(
        { error: "Server admin client is not configured." },
        { status: 500 },
      ),
    };
  }

  return { access, adminClient, serverClient };
}

async function parseJsonBody(request: NextRequest) {
  return (await request.json().catch(() => ({}))) as Record<string, unknown>;
}

function missingIdResponse() {
  return NextResponse.json({ error: "An id query parameter is required." }, {
    status: 400,
  });
}

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  try {
    const requestContext = await getAdminRequestContext(request);
    if ("response" in requestContext) {
      return requestContext.response;
    }

    const { access, adminClient } = requestContext;
    const { resource } = await context.params;

    switch (resource) {
      case "dashboard":
        return NextResponse.json({
          data: await getAdminDashboardSnapshot(adminClient, access),
        });
      case "matches":
        return NextResponse.json({
          data: await getAdminMatches(adminClient, access),
        });
      case "cms":
        return NextResponse.json({
          data: await getAdminArticles(adminClient, access),
        });
      case "settings":
        return NextResponse.json({
          data: await getAdminClubProfile(adminClient, access),
        });
      case "membership":
        return NextResponse.json({
          data: await getAdminMembershipPackages(adminClient, access),
        });
      case "shop":
        return NextResponse.json({
          data: await getAdminProducts(adminClient, access),
        });
      case "fan-clubs":
        return NextResponse.json({
          data: await getAdminFanClubs(adminClient, access),
        });
      case "standings":
        return NextResponse.json({
          data: await getAdminStandings(adminClient, access),
        });
      case "contributions":
        return NextResponse.json({
          data: await getAdminContributionSnapshot(adminClient, access),
        });
      case "notifications":
        return NextResponse.json({
          data: await getAdminNotificationContext(adminClient, access),
        });
      case "sms":
        return NextResponse.json({
          data: await getAdminSmsSnapshot(adminClient, access),
        });
      case "squad":
        return NextResponse.json({
          data: await getAdminSquad(adminClient, access),
        });
      case "gamification":
        return NextResponse.json({
          data: await getAdminFanEngagementTokens(adminClient, access),
        });
      default:
        return NextResponse.json({ error: "Unknown admin resource." }, {
          status: 404,
        });
    }
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Admin request failed.",
      },
      { status: 500 },
    );
  }
}

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  const rejectedOrigin = rejectInsecureMutation(request);
  if (rejectedOrigin) {
    return rejectedOrigin;
  }

  const rejectedLimit = await rejectRateLimitedRequest(
    request,
    "admin-mutation",
    45,
    60_000,
  );
  if (rejectedLimit) {
    return rejectedLimit;
  }

  try {
    const requestContext = await getAdminRequestContext(request);
    if ("response" in requestContext) {
      return requestContext.response;
    }

    const { access, adminClient, serverClient } = requestContext;
    const { resource } = await context.params;
    const body = await parseJsonBody(request);

    switch (resource) {
      case "matches":
        return NextResponse.json({
          data: await saveAdminMatch(adminClient, access, body as never),
        });
      case "cms":
        return NextResponse.json({
          data: await saveAdminArticle(adminClient, access, body as never),
        });
      case "settings":
        return NextResponse.json({
          data: await saveAdminClubProfile(adminClient, access, body as never),
        });
      case "membership":
        return NextResponse.json({
          data: await saveAdminMembershipPackage(adminClient, access, body as never),
        });
      case "shop":
        return NextResponse.json({
          data: await saveAdminProduct(adminClient, access, body as never),
        });
      case "fan-clubs":
        return NextResponse.json({
          data: await saveAdminFanClub(adminClient, access, body as never),
        });
      case "standings":
        return NextResponse.json({
          data: await saveAdminStandingRow(adminClient, access, body as never),
        });
      case "contributions":
        return NextResponse.json({
          data: await saveAdminContributionGroup(adminClient, access, body as never),
        });
      case "notifications":
        return NextResponse.json({
          data: await sendAdminNotification(serverClient, body as never, access),
        });
      case "squad":
        await saveAdminSquadPlayer(adminClient, access, body as never);
        return NextResponse.json({ data: { success: true } });
      case "gamification":
        return NextResponse.json({
          data: await saveAdminFanEngagementToken(
            adminClient,
            access,
            body as never,
          ),
        });
      default:
        return NextResponse.json({ error: "Unknown admin resource." }, {
          status: 404,
        });
    }
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Admin request failed.",
      },
      { status: 500 },
    );
  }
}

export async function DELETE(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  const rejectedOrigin = rejectInsecureMutation(request);
  if (rejectedOrigin) {
    return rejectedOrigin;
  }

  const rejectedLimit = await rejectRateLimitedRequest(
    request,
    "admin-delete",
    30,
    60_000,
  );
  if (rejectedLimit) {
    return rejectedLimit;
  }

  try {
    const requestContext = await getAdminRequestContext(request);
    if ("response" in requestContext) {
      return requestContext.response;
    }

    const { access, adminClient } = requestContext;
    const { resource } = await context.params;
    const id = request.nextUrl.searchParams.get("id");

    if (!id) {
      return missingIdResponse();
    }

    switch (resource) {
      case "matches":
        await deleteAdminMatch(adminClient, access, id);
        break;
      case "cms":
        await deleteAdminArticle(adminClient, access, id);
        break;
      case "membership":
        await deleteAdminMembershipPackage(adminClient, access, id);
        break;
      case "shop":
        await deleteAdminProduct(adminClient, access, id);
        break;
      case "fan-clubs":
        await deleteAdminFanClub(adminClient, access, id);
        break;
      case "standings":
        await deleteAdminStandingRow(adminClient, access, id);
        break;
      case "contributions":
        await deleteAdminContributionGroup(adminClient, access, id);
        break;
      case "squad":
        await deleteAdminSquadPlayer(adminClient, access, id);
        break;
      case "gamification":
        await deleteAdminFanEngagementToken(adminClient, access, id);
        break;
      default:
        return NextResponse.json({ error: "Unknown admin resource." }, {
          status: 404,
        });
    }

    return NextResponse.json({ data: { success: true } });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Admin request failed.",
      },
      { status: 500 },
    );
  }
}
