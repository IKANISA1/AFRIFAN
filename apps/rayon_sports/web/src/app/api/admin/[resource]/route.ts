import { forwardAdminNotificationCommand } from "@/lib/data/admin/notification-command";
import { getAdminRequestContext, parseJsonBody, requiresPlatformAdmin, runAdminResourceOperation, withScopedFeatureGuard } from "@/lib/admin-resource-transport";
import { adminPredictFailureResponse, handleAdminPredictDelete, handleAdminPredictGet, handleAdminPredictPost } from "@/lib/data/admin/predict-resource-handler";
import { NextRequest, NextResponse } from "next/server";
import {
  adjustAdminFetWalletBalance,
  assignAdminRole,
  allocateAdminSmsManualReview,
  deleteAdminFanEngagementToken,
  deleteAdminArticle,
  deleteAdminBanner,
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
  getAdminBanners,
  getAdminAppConfig,
  getAdminAuditLogs,
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
  revokeAdminRole,
  saveAdminArticle,
  saveAdminBanner,
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
  getAdminOffers,
  saveAdminOffer,
  deleteAdminOffer,
  saveAdminPlatformOptionSet,
  saveAdminPlatformOptionValue,
  saveAdminPlatformRoute,
  saveAdminRuntimeCopyEntry,
  saveAdminSiteNavigationItem,
  saveAdminSiteSearchItem,
  deleteAdminPlatformOptionSet,
  deleteAdminPlatformOptionValue,
  deleteAdminPlatformRoute,
  deleteAdminRuntimeCopyEntry,
  deleteAdminSiteNavigationItem,
  deleteAdminSiteSearchItem,
} from "@/lib/data/admin";
import { AdminMutationConflictError } from "@/lib/data/admin/helpers";
import { AdminRuntimeRegistryValidationError } from "@/lib/data/admin/runtime-registries";
import { AdminShopValidationError } from "@/lib/data/admin/shop";
import { AdminMembershipValidationError } from "@/lib/data/admin/membership";
import { AdminSmsValidationError } from "@/lib/data/admin/sms";
import {
  getAdminDestructivePermission,
  getAdminDestructiveRouteContract,
} from "@/lib/admin-destructive-actions";
import {
  rejectInsecureMutation,
  rejectRateLimitedRequest,
} from "@/lib/security";
import {
  controlledApiFailureResponse,
  controlledApiJson,
} from "@/lib/controlled-api-response";

export const dynamic = "force-dynamic";

// These actual configuration writers must carry the caller JWT into SQL,
// where current assignments and assurance are rechecked after row waits.
const staffConfigurationResources = new Set([
  "matches", "cms", "cms-banners", "cms-config", "cms-content", "membership", "shop",
]);
const globalConfigurationResources = new Set([
  "cms-banners", "predictions-markets", "predictions-competitions", "predictions-seasons", "predictions-fixtures",
]);
const clubAdminConfigurationResources = new Set(["membership", "shop", "livescore-sources"]);

function rejectConfigurationWrite(resource: string, access: { isSuperAdmin: boolean; role: string | null }) {
  if (access.isSuperAdmin) return null;
  const globalRequired = globalConfigurationResources.has(resource);
  if (globalRequired || (clubAdminConfigurationResources.has(resource) && access.role !== "club_admin")) {
    return controlledApiJson({ code: "ADMIN_ACCESS_DENIED", change_confirmed: false,
      error: globalRequired ? "Platform admin access is required." : "Club-admin access is required." }, 403);
  }
  return null;
}

function missingIdResponse() {
  return controlledApiJson(
    {
      code: "ADMIN_RESOURCE_EMPTY",
      error: "An id query parameter is required.",
      retryable: false,
      change_confirmed: false,
    },
    400,
  );
}

function adminResourceEmptyResponse() {
  return controlledApiJson(
    {
      code: "ADMIN_RESOURCE_EMPTY",
      error: "Unknown admin resource.",
      retryable: false,
      change_confirmed: false,
    },
    404,
  );
}

function adminResourceConflictResponse() {
  return controlledApiJson(
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

function adminShopInvalidResponse() {
  return controlledApiJson(
    {
      code: "ADMIN_SHOP_PRODUCT_INVALID",
      error: "Review the product and correct invalid values.",
      retryable: false,
      change_confirmed: false,
    },
    400,
  );
}

function adminSmsInvalidResponse() {
  return controlledApiJson(
    {
      code: "ADMIN_SMS_ACTION_INVALID",
      error: "Review the SMS action and correct invalid values.",
      retryable: false,
      change_confirmed: false,
    },
    400,
  );
}

async function handleGet(
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
      return controlledApiJson(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: "Platform admin access is required.",
        },
        403,
      );
    }

    const predictResponse = await handleAdminPredictGet(resource, requestContext, request.nextUrl.searchParams.get("limit"));
    if (predictResponse) return predictResponse;

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
      case "cms-banners":
        return NextResponse.json({
          data: await getAdminBanners(adminClient, access),
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
      case "audit-logs":
        return NextResponse.json({
          data: await getAdminAuditLogs(adminClient, access, {
            limit: Number(request.nextUrl.searchParams.get("limit") ?? 500),
          }),
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
      case "runtime-registry":
        return NextResponse.json({
          data: await getAdminRuntimeRegistrySnapshot(adminClient, access),
        });
      default:
        return adminResourceEmptyResponse();
    }
  } catch (error) {
    return controlledApiFailureResponse(error, "ADMIN_RESOURCE");
  }
}

async function handlePost(
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

    const { access, adminClient: serviceClient, serverClient } = requestContext;
    const { resource } = await context.params;
    const adminClient = staffConfigurationResources.has(resource) ? serverClient : serviceClient;
    const body = await parseJsonBody(request);
    const configurationDenied = rejectConfigurationWrite(resource, access);
    if (configurationDenied) return configurationDenied;

    if (requiresPlatformAdmin(resource) && !access.isSuperAdmin) {
      return controlledApiJson(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: "Platform admin access is required.",
        },
        403,
      );
    }

    const predictResponse = await handleAdminPredictPost(resource, requestContext, body);
    if (predictResponse) return predictResponse;

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
      case "cms-banners":
        return NextResponse.json({
          data: await saveAdminBanner(adminClient, access, body as never),
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
      case "notifications": {
        if (!access.isSuperAdmin) return controlledApiJson({ code: "ADMIN_ACCESS_DENIED", change_confirmed: false,
          error: "Platform staff access is required for notification commands." }, 403);
        const run = async () => NextResponse.json({ data: await forwardAdminNotificationCommand(serverClient, body, access) });
        // Status recovers the original command even when creation is disabled.
        return body.action === "status" ? run() : withScopedFeatureGuard(access, "notifications", run);
      }
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
        return withScopedFeatureGuard(access, "predict", async () =>
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
      default:
        return adminResourceEmptyResponse();
    }
  } catch (error) {
    if (error instanceof AdminMutationConflictError) {
      return adminResourceConflictResponse();
    }
    const predictFailure = adminPredictFailureResponse(error);
    if (predictFailure) return predictFailure;
    if (error instanceof AdminRuntimeRegistryValidationError) {
      return controlledApiJson(
        {
          code: "ADMIN_RUNTIME_REGISTRY_INVALID",
          error:
            "Review the runtime registry record and correct invalid values.",
          retryable: false,
          change_confirmed: false,
        },
        400,
      );
    }
    if (error instanceof AdminShopValidationError) {
      return adminShopInvalidResponse();
    }
    if (error instanceof AdminMembershipValidationError) {
      return controlledApiJson({
        code: "ADMIN_MEMBERSHIP_INPUT_INVALID",
        error: "Review the membership package and correct invalid values.",
        retryable: false,
        change_confirmed: false,
      }, 400);
    }
    if (error instanceof AdminSmsValidationError) {
      return adminSmsInvalidResponse();
    }
    return controlledApiFailureResponse(error, "ADMIN_RESOURCE");
  }
}

async function handleDelete(
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

    const { access, adminClient: serviceClient, serverClient } = requestContext;
    const { resource } = await context.params;
    const adminClient = staffConfigurationResources.has(resource) ? serverClient : serviceClient;
    const id = request.nextUrl.searchParams.get("id");
    const expectedUpdatedAt = request.nextUrl.searchParams.get(
      "expected_updated_at",
    );
    const configurationDenied = rejectConfigurationWrite(resource, access);
    if (configurationDenied) return configurationDenied;

    if (requiresPlatformAdmin(resource) && !access.isSuperAdmin) {
      return controlledApiJson(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: "Platform admin access is required.",
        },
        403,
      );
    }

    const destructiveContract = getAdminDestructiveRouteContract(resource);
    if (destructiveContract == null) {
      return adminResourceEmptyResponse();
    }
    const destructivePermission = getAdminDestructivePermission(
      access,
      destructiveContract,
    );
    if (!destructivePermission.allowed) {
      return controlledApiJson(
        {
          code: "ADMIN_ACCESS_DENIED",
          error: destructivePermission.reason,
        },
        403,
      );
    }

    if (!id) {
      return missingIdResponse();
    }

    const predictResponse = await handleAdminPredictDelete(resource, requestContext, id, expectedUpdatedAt ?? "");
    if (predictResponse) return predictResponse;

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
      case "cms-banners":
        await deleteAdminBanner(
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
      default:
        return adminResourceEmptyResponse();
    }

    return NextResponse.json({ data: { success: true } });
  } catch (error) {
    if (error instanceof AdminMutationConflictError) {
      return adminResourceConflictResponse();
    }
    if (error instanceof AdminShopValidationError) {
      return adminShopInvalidResponse();
    }
    return controlledApiFailureResponse(error, "ADMIN_RESOURCE");
  }
}

export function GET(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  return runAdminResourceOperation(() => handleGet(request, context));
}

export function POST(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  return runAdminResourceOperation(() => handlePost(request, context));
}

export function DELETE(
  request: NextRequest,
  context: { params: Promise<{ resource: string }> },
) {
  return runAdminResourceOperation(() => handleDelete(request, context));
}
