import { NextRequest, NextResponse } from "next/server";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
} from "@/lib/admin-club-scope";
import {
  adjustAdminFetWalletBalance,
  assignAdminRole,
  allocateAdminSmsManualReview,
  deleteAdminFanEngagementToken,
  deleteAdminArticle,
  deleteAdminConfigEntry,
  deleteAdminContentBlock,
  deleteAdminContributionGroup,
  deleteAdminFanClub,
  deleteAdminMatch,
  deleteAdminMembershipPackage,
  deleteAdminProduct,
  deleteAdminSquadPlayer,
  deleteAdminStandingRow,
  getAdminArticles,
  getAdminAppConfig,
  getAdminContentBlocks,
  getAdminContentTypes,
  getAdminClubScopeOptions,
  getAdminClubProfile,
  getAdminContributionSnapshot,
  getAdminDashboardActions,
  getAdminDashboardSnapshot,
  getAdminFetWalletSnapshot,
  getAdminFanEngagementTokens,
  getAdminFanClubs,
  getAdminMembershipApplications,
  getAdminMatches,
  getAdminMembershipPackages,
  getAdminNotificationContext,
  getAdminProducts,
  getAdminRoleAssignments,
  getAdminRuntimeRegistrySnapshot,
  getAdminSmsSnapshot,
  getAdminSmsManualReviewWorkspace,
  getAdminSupporterRegistry,
  getAdminSquad,
  getAdminStandings,
  getAdminTicketOrders,
  findAdminUserCandidate,
  rejectAdminSmsManualReview,
  resolveAdminAccess,
  revokeAdminRole,
  saveAdminArticle,
  saveAdminConfigEntry,
  saveAdminContentBlock,
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
  getAdminOffers,
  saveAdminOffer,
  deleteAdminOffer,
  getAdminPredictionMarkets,
  saveAdminPredictionMarket,
  saveAdminPlatformOptionSet,
  saveAdminPlatformOptionValue,
  saveAdminPlatformRoute,
  saveAdminRuntimeCopyEntry,
  saveAdminSiteNavigationItem,
  saveAdminSiteSearchItem,
  getAdminCompetitions,
  saveAdminCompetition,
  getAdminSeasons,
  saveAdminSeason,
  getAdminFixtures,
  saveAdminFixture,
  getAdminSyncLogs,
  getAdminSyncOverview,
  getAdminLiveScoreCompetitionSources,
  saveAdminLiveScoreCompetitionSource,
  deleteAdminLiveScoreCompetitionSource,
  getAdminPartnerOptions,
  getAdminPartnerPredictionPools,
  saveAdminPartnerPredictionPool,
  settleAdminPartnerPredictionPool,
  saveAdminVenueGovernanceControl,
  deleteAdminPlatformOptionSet,
  deleteAdminPlatformOptionValue,
  deleteAdminPlatformRoute,
  deleteAdminRuntimeCopyEntry,
  deleteAdminSiteNavigationItem,
  deleteAdminSiteSearchItem,
  deleteAdminVenueGovernanceControl,
} from "@/lib/data/admin";
import { AdminMutationConflictError } from "@/lib/data/admin/helpers";
import {
  getAdminDestructivePermission,
  getAdminDestructiveRouteContract,
} from "@/lib/admin-destructive-actions";
import {
  rejectInsecureMutation,
  rejectRateLimitedRequest,
} from "@/lib/security";
import { withFeatureGuard } from "@/lib/server-feature-guard";
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

function requiresPlatformAdmin(resource: string) {
  return resource === "access" || resource === "access-users";
}

async function parseJsonBody(request: NextRequest) {
  return (await request.json().catch(() => ({}))) as Record<string, unknown>;
}

function missingIdResponse() {
  return NextResponse.json(
    { error: "An id query parameter is required." },
    {
      status: 400,
    },
  );
}

function withScopedFeatureGuard(
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

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  try {
    const requestContext = await getAdminRequestContext(request);
    if ("response" in requestContext) {
      return requestContext.response;
    }

    const { access, adminClient, serverClient } = requestContext;
    const { resource } = await context.params;

    if (requiresPlatformAdmin(resource) && !access.isSuperAdmin) {
      return NextResponse.json(
        { error: "Platform admin access is required." },
        { status: 403 },
      );
    }

    switch (resource) {
      case "access":
        return NextResponse.json({
          data: await getAdminRoleAssignments(adminClient, access, {
            activeOnly:
              request.nextUrl.searchParams.get("active_only") !== "false",
          }),
        });
      case "access-users": {
        const identifier = request.nextUrl.searchParams.get("q");
        if (!identifier) {
          return NextResponse.json(
            { error: "A q query parameter is required." },
            { status: 400 },
          );
        }
        return NextResponse.json({
          data: await findAdminUserCandidate(adminClient, access, identifier),
        });
      }
      case "dashboard":
        return NextResponse.json({
          data: await getAdminDashboardSnapshot(adminClient, access),
        });
      case "dashboard-actions":
        return NextResponse.json({
          data: await getAdminDashboardActions(adminClient, access),
        });
      case "matches":
        return NextResponse.json({
          data: await getAdminMatches(adminClient, access),
        });
      case "cms":
        return NextResponse.json({
          data: await getAdminArticles(adminClient, access),
        });
      case "cms-config":
        return NextResponse.json({
          data: await getAdminAppConfig(adminClient, access),
        });
      case "cms-content":
        return NextResponse.json({
          data: await getAdminContentBlocks(adminClient, access),
        });
      case "cms-content-types":
        return NextResponse.json({
          data: await getAdminContentTypes(adminClient, access),
        });
      case "settings":
        return NextResponse.json({
          data: await getAdminClubProfile(adminClient, access),
        });
      case "club-scope":
        return NextResponse.json({
          data: await getAdminClubScopeOptions(adminClient, access),
        });
      case "membership":
        return NextResponse.json({
          data: await getAdminMembershipPackages(adminClient, access),
        });
      case "membership-supporters":
        return NextResponse.json({
          data: await getAdminSupporterRegistry(adminClient, access),
        });
      case "membership-applications":
        return NextResponse.json({
          data: await getAdminMembershipApplications(adminClient, access),
        });
      case "shop":
        return NextResponse.json({
          data: await getAdminProducts(adminClient, access),
        });
      case "tickets":
        return NextResponse.json({
          data: await getAdminTicketOrders(adminClient, access),
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
      case "sms-manual-reviews":
        return NextResponse.json({
          data: await getAdminSmsManualReviewWorkspace(serverClient, access),
        });
      case "squad":
        return NextResponse.json({
          data: await getAdminSquad(adminClient, access),
        });
      case "gamification":
        return NextResponse.json({
          data: await getAdminFanEngagementTokens(adminClient, access),
        });
      case "gamification-wallet":
        return NextResponse.json({
          data: await getAdminFetWalletSnapshot(serverClient, access, {
            search: request.nextUrl.searchParams.get("search"),
            userId: request.nextUrl.searchParams.get("user_id"),
          }),
        });
      case "offers":
        return NextResponse.json({
          data: await getAdminOffers(adminClient, access),
        });
      case "predictions-markets":
        return NextResponse.json({
          data: await getAdminPredictionMarkets(adminClient, access),
        });
      case "predictions-competitions":
        return NextResponse.json({
          data: await getAdminCompetitions(adminClient, access),
        });
      case "predictions-seasons":
        return NextResponse.json({
          data: await getAdminSeasons(adminClient, access),
        });
      case "predictions-fixtures":
        return NextResponse.json({
          data: await getAdminFixtures(adminClient, access),
        });
      case "partner-options":
        return NextResponse.json({
          data: await getAdminPartnerOptions(adminClient, access),
        });
      case "partner-prediction-pools":
        return NextResponse.json({
          data: await getAdminPartnerPredictionPools(serverClient, access),
        });
      case "runtime-registry":
        return NextResponse.json({
          data: await getAdminRuntimeRegistrySnapshot(adminClient, access),
        });
      case "football-sync-logs":
        return NextResponse.json({
          data: await getAdminSyncLogs(
            adminClient,
            access,
            Number(request.nextUrl.searchParams.get("limit") ?? 50),
          ),
        });
      case "football-sync-overview":
        return NextResponse.json({
          data: await getAdminSyncOverview(adminClient, access),
        });
      case "livescore-sources":
        return NextResponse.json({
          data: await getAdminLiveScoreCompetitionSources(adminClient, access),
        });
      default:
        return NextResponse.json(
          { error: "Unknown admin resource." },
          {
            status: 404,
          },
        );
    }
  } catch (error) {
    const resource = await context.params
      .then((p) => p.resource)
      .catch(() => "unknown");
    console.error(`[admin-api] GET /${resource} failed:`, error);
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Admin request failed.",
        resource,
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

    if (requiresPlatformAdmin(resource) && !access.isSuperAdmin) {
      return NextResponse.json(
        { error: "Platform admin access is required." },
        { status: 403 },
      );
    }

    switch (resource) {
      case "access":
        return NextResponse.json({
          data: await assignAdminRole(serverClient, access, body as never),
        });
      case "sms-manual-reviews": {
        const action = typeof body.action === "string" ? body.action : "";
        if (action === "allocate") {
          await allocateAdminSmsManualReview(serverClient, access, {
            reviewId: String(body.reviewId ?? ""),
            intentId: String(body.intentId ?? ""),
            note: typeof body.note === "string" ? body.note : null,
          });
          return NextResponse.json({ data: { success: true } });
        }
        if (action === "reject") {
          await rejectAdminSmsManualReview(serverClient, access, {
            reviewId: String(body.reviewId ?? ""),
            note: typeof body.note === "string" ? body.note : null,
          });
          return NextResponse.json({ data: { success: true } });
        }
        return NextResponse.json(
          { error: "A valid SMS manual review action is required." },
          { status: 400 },
        );
      }
      case "matches":
        return NextResponse.json({
          data: await saveAdminMatch(adminClient, access, body as never),
        });
      case "cms":
        return NextResponse.json({
          data: await saveAdminArticle(adminClient, access, body as never),
        });
      case "cms-config":
        return NextResponse.json({
          data: await saveAdminConfigEntry(adminClient, access, body as never),
        });
      case "cms-content":
        return NextResponse.json({
          data: await saveAdminContentBlock(adminClient, access, body as never),
        });
      case "settings":
        return NextResponse.json({
          data: await saveAdminClubProfile(adminClient, access, body as never),
        });
      case "membership":
        return NextResponse.json({
          data: await saveAdminMembershipPackage(
            adminClient,
            access,
            body as never,
          ),
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
          data: await saveAdminContributionGroup(
            adminClient,
            access,
            body as never,
          ),
        });
      case "notifications":
        return withScopedFeatureGuard(access, "notifications", async () =>
          NextResponse.json({
            data: await sendAdminNotification(
              serverClient,
              body as never,
              access,
            ),
          }),
        );
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
      case "gamification-wallet":
        return withScopedFeatureGuard(access, "fanzone", async () =>
          NextResponse.json({
            data: await adjustAdminFetWalletBalance(serverClient, access, {
              userId: String(body.userId ?? ""),
              amount: Number(body.amount ?? 0),
              reason: String(body.reason ?? ""),
              idempotencyKey:
                typeof body.idempotencyKey === "string"
                  ? body.idempotencyKey
                  : null,
            }),
          }),
        );
      case "offers":
        return NextResponse.json({
          data: await saveAdminOffer(adminClient, access, body as never),
        });
      case "predictions-markets":
        return NextResponse.json({
          data: await saveAdminPredictionMarket(
            adminClient,
            access,
            body as never,
          ),
        });
      case "predictions-competitions":
        return NextResponse.json({
          data: await saveAdminCompetition(adminClient, access, body as never),
        });
      case "predictions-seasons":
        return NextResponse.json({
          data: await saveAdminSeason(adminClient, access, body as never),
        });
      case "predictions-fixtures":
        return NextResponse.json({
          data: await saveAdminFixture(adminClient, access, body as never),
        });
      case "partner-prediction-pools":
        return withScopedFeatureGuard(access, "fanzone", async () =>
          NextResponse.json({
            data: await saveAdminPartnerPredictionPool(
              serverClient,
              access,
              body as never,
            ),
          }),
        );
      case "partner-prediction-pool-settlement":
        return withScopedFeatureGuard(access, "fanzone", async () =>
          NextResponse.json({
            data: await settleAdminPartnerPredictionPool(
              serverClient,
              access,
              String(body.poolId ?? ""),
            ),
          }),
        );
      case "livescore-sources":
        return NextResponse.json({
          data: await saveAdminLiveScoreCompetitionSource(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-routes":
        return NextResponse.json({
          data: await saveAdminPlatformRoute(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-option-sets":
        return NextResponse.json({
          data: await saveAdminPlatformOptionSet(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-option-values":
        return NextResponse.json({
          data: await saveAdminPlatformOptionValue(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-copy":
        return NextResponse.json({
          data: await saveAdminRuntimeCopyEntry(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-navigation":
        return NextResponse.json({
          data: await saveAdminSiteNavigationItem(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-search":
        return NextResponse.json({
          data: await saveAdminSiteSearchItem(
            adminClient,
            access,
            body as never,
          ),
        });
      case "runtime-venue-controls":
        return NextResponse.json({
          data: await saveAdminVenueGovernanceControl(
            adminClient,
            access,
            body as never,
          ),
        });
      default:
        return NextResponse.json(
          { error: "Unknown admin resource." },
          {
            status: 404,
          },
        );
    }
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
        error: error instanceof Error ? error.message : "Admin request failed.",
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
    const expectedUpdatedAt = request.nextUrl.searchParams.get(
      "expected_updated_at",
    );

    if (requiresPlatformAdmin(resource) && !access.isSuperAdmin) {
      return NextResponse.json(
        { error: "Platform admin access is required." },
        { status: 403 },
      );
    }

    const destructiveContract =
      getAdminDestructiveRouteContract(resource);
    if (destructiveContract == null) {
      return NextResponse.json(
        { error: "Unknown admin resource." },
        { status: 404 },
      );
    }
    const destructivePermission = getAdminDestructivePermission(
      access,
      destructiveContract,
    );
    if (!destructivePermission.allowed) {
      return NextResponse.json(
        { error: destructivePermission.reason },
        { status: 403 },
      );
    }

    if (!id) {
      return missingIdResponse();
    }

    switch (resource) {
      case "access":
        await revokeAdminRole(requestContext.serverClient, access, id);
        break;
      case "matches":
        await deleteAdminMatch(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "cms":
        await deleteAdminArticle(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "cms-config":
        await deleteAdminConfigEntry(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "cms-content":
        await deleteAdminContentBlock(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "membership":
        await deleteAdminMembershipPackage(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "shop":
        await deleteAdminProduct(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "fan-clubs":
        await deleteAdminFanClub(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "standings":
        await deleteAdminStandingRow(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "contributions":
        await deleteAdminContributionGroup(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "squad":
        await deleteAdminSquadPlayer(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "gamification":
        await deleteAdminFanEngagementToken(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "offers":
        await deleteAdminOffer(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "livescore-sources":
        await deleteAdminLiveScoreCompetitionSource(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-routes":
        await deleteAdminPlatformRoute(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-option-sets":
        await deleteAdminPlatformOptionSet(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-option-values":
        await deleteAdminPlatformOptionValue(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-copy":
        await deleteAdminRuntimeCopyEntry(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-navigation":
        await deleteAdminSiteNavigationItem(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-search":
        await deleteAdminSiteSearchItem(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      case "runtime-venue-controls":
        await deleteAdminVenueGovernanceControl(
          adminClient,
          access,
          id,
          expectedUpdatedAt ?? "",
        );
        break;
      default:
        return NextResponse.json(
          { error: "Unknown admin resource." },
          {
            status: 404,
          },
        );
    }

    return NextResponse.json({ data: { success: true } });
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
        error: error instanceof Error ? error.message : "Admin request failed.",
      },
      { status: 500 },
    );
  }
}
