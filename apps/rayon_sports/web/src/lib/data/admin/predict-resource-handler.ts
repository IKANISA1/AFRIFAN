import { NextResponse } from "next/server";
import {
  getAdminPredictionsWorkspace,
  getAdminPredictionMarkets,
  saveAdminPredictionMarket,
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
} from "@/lib/data/admin";
import {
  AdminPredictValidationError,
  confirmAdminLegacyPredictResultForActor,
  getAdminFreePredictDashboardResponse,
  mutateAdminFreePredict,
  settleAdminLegacyPredictForActor,
} from "@/lib/data/admin/predict-free";
import { withScopedFeatureGuard, type AdminResourceContext } from "@/lib/admin-resource-transport";
import { controlledApiJson } from "@/lib/controlled-api-response";

// Called only after the shared transport authenticates and resolves club scope.
// The server client retains the caller JWT; attributed historical commands alone
// receive the service client, with their actor derived from validated access.
export async function handleAdminPredictGet(resource: string, context: AdminResourceContext, limit: string | null) {
  const { access, adminClient, serverClient } = context;
  switch (resource) {
      case "predict-operations":
        return NextResponse.json({ data: await getAdminFreePredictDashboardResponse(serverClient, access) });
      case "predictions":
        return NextResponse.json({
          data: await getAdminPredictionsWorkspace(adminClient, access, {
            poolClient: serverClient,
          }),
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
      case "football-sync-logs":
        return NextResponse.json({
          data: await getAdminSyncLogs(
            adminClient,
            access,
            Number(limit ?? 50),
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
    default: return null;
  }
}

export async function handleAdminPredictPost(resource: string, context: AdminResourceContext, body: Record<string, unknown>) {
  const { access, adminClient, serverClient } = context;
  switch (resource) {
      case "predictions-markets":
        return NextResponse.json({
          data: await saveAdminPredictionMarket(
            serverClient,
            access,
            body as never,
          ),
        });
      case "predictions-competitions":
        return NextResponse.json({
          data: await saveAdminCompetition(serverClient, access, body as never),
        });
      case "predictions-seasons":
        return NextResponse.json({
          data: await saveAdminSeason(serverClient, access, body as never),
        });
      case "predictions-fixtures":
        return NextResponse.json({
          data: await saveAdminFixture(serverClient, access, body as never),
        });
      case "predict-operations":
        if ((body.entryFet != null && body.entryFet !== 0) ||
            (body.welcomeFet != null && body.welcomeFet !== 0)) {
          throw new AdminPredictValidationError("Free predictions cannot use paid entry or welcome credit settings.");
        }
        return await withScopedFeatureGuard(access, "predict", async () =>
          NextResponse.json({ data: await mutateAdminFreePredict(serverClient, access, body as never) }),
        );
      case "predict-legacy-confirm-result":
        if (!access.isSuperAdmin || access.role !== "super_admin") {
          return controlledApiJson({ code: "ADMIN_ACCESS_DENIED", error: "Global administrator access is required.", change_confirmed: false }, 403);
        }
        return await withScopedFeatureGuard(access, "predict", async () =>
          NextResponse.json({ data: await confirmAdminLegacyPredictResultForActor(adminClient, serverClient, access, body as never) }),
        );
      case "predict-legacy-settlement":
        if (!access.isSuperAdmin || access.role !== "super_admin") {
          return controlledApiJson({ code: "ADMIN_ACCESS_DENIED", error: "Global administrator access is required.", change_confirmed: false }, 403);
        }
        return await withScopedFeatureGuard(access, "predict", async () =>
          NextResponse.json({ data: await settleAdminLegacyPredictForActor(adminClient, serverClient, access, body as never) }),
        );
      case "partner-prediction-pools":
      case "partner-prediction-pool-settlement":
        return controlledApiJson({ code: "PREDICT_LEGACY_OPERATION_RETIRED", error: "Use free predictions or the attributed historical reconciliation command.", change_confirmed: false }, 410);
      case "livescore-sources":
        return NextResponse.json({
          data: await saveAdminLiveScoreCompetitionSource(
            serverClient,
            access,
            body as never,
          ),
        });
    default: return null;
  }
}

export function adminPredictFailureResponse(error: unknown) {
  return error instanceof AdminPredictValidationError
    ? controlledApiJson({ code: "ADMIN_PREDICT_INVALID", error: error.message, retryable: false, change_confirmed: false }, 400)
    : null;
}

// Destructive permission and loaded-version checks are retained by the caller
// before dispatch; the domain mutation keeps its existing audit/concurrency path.
export async function handleAdminPredictDelete(resource: string, context: AdminResourceContext, id: string, expectedUpdatedAt: string) {
  if (resource !== "livescore-sources") return null;
  await deleteAdminLiveScoreCompetitionSource(context.serverClient, context.access, id, expectedUpdatedAt);
  return NextResponse.json({ data: { success: true } });
}
