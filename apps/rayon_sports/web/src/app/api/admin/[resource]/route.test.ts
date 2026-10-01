import { registerLocalHttpAssertions, httpFixtureOrigin, httpFixtureClubId } from "../../../../../e2e/fixtures/local-http-route-assertions";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { withFeatureGuard } from "@/lib/server-feature-guard";
import { AdminMembershipValidationError } from "@/lib/data/admin/membership";

const {
  getUser,
  getClaims,
  resolveAdminAccessMock,
  saveAdminContributionGroupMock,
  saveAdminClubProfileMock,
  saveAdminMatchMock,
  saveAdminProductMock,
  saveAdminMembershipPackageMock,
  saveAdminPredictionMarketMock,
  saveAdminCompetitionMock,
  saveAdminSeasonMock,
  saveAdminFixtureMock,
  saveAdminPartnerPredictionPoolMock,
  settleAdminPartnerPredictionPoolMock,
  getAdminLiveScoreCompetitionSourcesMock,
  getAdminRuntimeRegistrySnapshotMock,
  getAdminBannersMock,
  getAdminAuditLogsMock,
  getAdminPredictionsWorkspaceMock,
  saveAdminPlatformRouteMock,
  deleteAdminPlatformRouteMock,
  saveAdminLiveScoreCompetitionSourceMock,
  deleteAdminLiveScoreCompetitionSourceMock,
  deleteAdminContributionGroupMock,
  rejectInsecureMutationMock,
  rejectRateLimitedRequestMock,
  getRequestedAdminClubIdMock,
  adminClient,
  serverClient,
} = vi.hoisted(() => {
  const getUser = vi.fn();
  const getClaims = vi.fn();
  return {
    getUser,
    getClaims,
    resolveAdminAccessMock: vi.fn(),
    saveAdminContributionGroupMock: vi.fn(),
    saveAdminClubProfileMock: vi.fn(),
    saveAdminMatchMock: vi.fn(),
    saveAdminProductMock: vi.fn(),
    saveAdminMembershipPackageMock: vi.fn(),
    saveAdminPredictionMarketMock: vi.fn(),
    saveAdminCompetitionMock: vi.fn(),
    saveAdminSeasonMock: vi.fn(),
    saveAdminFixtureMock: vi.fn(),
    saveAdminPartnerPredictionPoolMock: vi.fn(),
    settleAdminPartnerPredictionPoolMock: vi.fn(),
    getAdminLiveScoreCompetitionSourcesMock: vi.fn(),
    getAdminRuntimeRegistrySnapshotMock: vi.fn(),
    getAdminBannersMock: vi.fn(),
    getAdminAuditLogsMock: vi.fn(),
    getAdminPredictionsWorkspaceMock: vi.fn(),
    saveAdminPlatformRouteMock: vi.fn(),
    deleteAdminPlatformRouteMock: vi.fn(),
    saveAdminLiveScoreCompetitionSourceMock: vi.fn(),
    deleteAdminLiveScoreCompetitionSourceMock: vi.fn(),
    deleteAdminContributionGroupMock: vi.fn(),
    rejectInsecureMutationMock: vi.fn(),
    rejectRateLimitedRequestMock: vi.fn(),
    getRequestedAdminClubIdMock: vi.fn(),
    adminClient: { kind: "admin" },
    serverClient: {
      kind: "server",
      auth: {
        getUser,
        getClaims,
      },
    },
  };
});

vi.mock("@/lib/admin-club-scope", () => ({
  adminClubScopeCookieName: "admin-club-scope",
  getRequestedAdminClubId: getRequestedAdminClubIdMock,
}));

vi.mock("@/lib/data/admin", () => {
  const noop = vi.fn();
  return {
    adjustAdminFetWalletBalance: noop,
    assignAdminRole: noop,
    allocateAdminSmsManualReview: noop,
    deleteAdminArticle: noop,
    deleteAdminBanner: noop,
    deleteAdminConfigEntry: noop,
    deleteAdminContentBlock: noop,
    deleteAdminContributionGroup: deleteAdminContributionGroupMock,
    deleteAdminFanClub: noop,
    deleteAdminFanEngagementToken: noop,
    deleteAdminMatch: noop,
    deleteAdminMembershipPackage: noop,
    deleteAdminOffer: noop,
    deleteAdminProduct: noop,
    deleteAdminSquadPlayer: noop,
    deleteAdminStandingRow: noop,
    findAdminUserCandidate: noop,
    getAdminAppConfig: noop,
    getAdminArticles: noop,
    getAdminBanners: getAdminBannersMock,
    getAdminAuditLogs: getAdminAuditLogsMock,
    getAdminClubProfile: noop,
    getAdminClubScopeOptions: noop,
    getAdminCompetitions: noop,
    getAdminContentBlocks: noop,
    getAdminContributionSnapshot: noop,
    getAdminDashboardSnapshot: noop,
    getAdminFanClubs: noop,
    getAdminFanEngagementTokens: noop,
    getAdminFetWalletSnapshot: noop,
    getAdminFixtures: noop,
    getAdminLiveScoreCompetitionSources:
      getAdminLiveScoreCompetitionSourcesMock,
    getAdminRuntimeRegistrySnapshot: getAdminRuntimeRegistrySnapshotMock,
    getAdminMatches: noop,
    getAdminMembershipPackages: noop,
    getAdminNotificationContext: noop,
    getAdminOffers: noop,
    getAdminPredictionMarkets: noop,
    getAdminPartnerPredictionPools: noop,
    getAdminPartnerOptions: noop,
    getAdminPredictionsWorkspace: getAdminPredictionsWorkspaceMock,
    getAdminProducts: noop,
    getAdminRoleAssignments: noop,
    getAdminSeasons: noop,
    getAdminSmsManualReviewWorkspace: noop,
    getAdminSmsSnapshot: noop,
    getAdminSquad: noop,
    getAdminStandings: noop,
    getAdminSupporterRegistry: noop,
    getAdminTicketOrders: noop,
    rejectAdminSmsManualReview: noop,
    resolveAdminAccess: resolveAdminAccessMock,
    revokeAdminRole: noop,
    saveAdminArticle: noop,
    saveAdminBanner: noop,
    saveAdminClubProfile: saveAdminClubProfileMock,
    saveAdminCompetition: saveAdminCompetitionMock,
    saveAdminConfigEntry: noop,
    saveAdminContentBlock: noop,
    saveAdminContributionGroup: saveAdminContributionGroupMock,
    saveAdminFanClub: noop,
    saveAdminFanEngagementToken: noop,
    saveAdminFixture: saveAdminFixtureMock,
    saveAdminLiveScoreCompetitionSource:
      saveAdminLiveScoreCompetitionSourceMock,
    saveAdminPlatformRoute: saveAdminPlatformRouteMock,
    saveAdminMatch: saveAdminMatchMock,
    saveAdminMembershipPackage: saveAdminMembershipPackageMock,
    saveAdminOffer: noop,
    saveAdminPredictionMarket: saveAdminPredictionMarketMock,
    saveAdminPartnerPredictionPool: saveAdminPartnerPredictionPoolMock,
    saveAdminProduct: saveAdminProductMock,
    saveAdminSeason: saveAdminSeasonMock,
    saveAdminSquadPlayer: noop,
    saveAdminStandingRow: noop,
    sendAdminNotification: noop,
    settleAdminPartnerPredictionPool: settleAdminPartnerPredictionPoolMock,
    deleteAdminLiveScoreCompetitionSource:
      deleteAdminLiveScoreCompetitionSourceMock,
    deleteAdminPlatformRoute: deleteAdminPlatformRouteMock,
    deleteAdminPlatformOptionSet: noop,
    deleteAdminPlatformOptionValue: noop,
    deleteAdminRuntimeCopyEntry: noop,
    deleteAdminSiteNavigationItem: noop,
    deleteAdminSiteSearchItem: noop,
    saveAdminPlatformOptionSet: noop,
    saveAdminPlatformOptionValue: noop,
    saveAdminRuntimeCopyEntry: noop,
    saveAdminSiteNavigationItem: noop,
    saveAdminSiteSearchItem: noop,
  };
});

const predictOperations = vi.hoisted(() => ({
  dashboard: vi.fn(), mutate: vi.fn(), legacy: vi.fn(), legacyConfirm: vi.fn(),
}));
vi.mock("@/lib/data/admin/predict-free", async (importOriginal) => ({
  ...await importOriginal<typeof import("@/lib/data/admin/predict-free")>(),
  getAdminFreePredictDashboardResponse: predictOperations.dashboard,
  mutateAdminFreePredict: predictOperations.mutate,
  settleAdminLegacyPredictForActor: predictOperations.legacy,
  confirmAdminLegacyPredictResultForActor: predictOperations.legacyConfirm,
}));

vi.mock("@/lib/security", () => ({
  rejectInsecureMutation: rejectInsecureMutationMock,
  rejectRateLimitedRequest: rejectRateLimitedRequestMock,
}));

vi.mock("@/lib/server-feature-guard", () => ({
  withFeatureGuard: vi.fn(
    async (_featureKey: string, handler: () => Promise<Response>) => handler(),
  ),
}));

vi.mock("@/lib/supabase/admin", () => ({
  getAdminSupabase: vi.fn(() => adminClient),
}));

vi.mock("@/lib/supabase/server", () => ({
  getServerSupabase: vi.fn(async () => serverClient),
}));

import { DELETE, GET, POST } from "./route";
import { AdminMutationConflictError } from "@/lib/data/admin/helpers";

describe("admin resource route", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  beforeEach(() => {
    predictOperations.dashboard.mockReset();
    predictOperations.mutate.mockReset();
    predictOperations.legacy.mockReset();
    predictOperations.legacyConfirm.mockReset();
    getUser.mockReset();
    getClaims.mockReset();
    getClaims.mockImplementation(async () => ({ data: { claims: { sub: "user-1", role: "authenticated", is_anonymous: false, aal: "aal2", exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) }] } }, error: null }));
    resolveAdminAccessMock.mockReset();
    saveAdminContributionGroupMock.mockReset();
    saveAdminClubProfileMock.mockReset();
    saveAdminMatchMock.mockReset();
    saveAdminProductMock.mockReset();
    saveAdminMembershipPackageMock.mockReset();
    saveAdminPredictionMarketMock.mockReset();
    saveAdminCompetitionMock.mockReset();
    saveAdminSeasonMock.mockReset();
    saveAdminFixtureMock.mockReset();
    saveAdminPartnerPredictionPoolMock.mockReset();
    settleAdminPartnerPredictionPoolMock.mockReset();
    getAdminLiveScoreCompetitionSourcesMock.mockReset();
    getAdminRuntimeRegistrySnapshotMock.mockReset();
    getAdminBannersMock.mockReset();
    getAdminAuditLogsMock.mockReset();
    getAdminPredictionsWorkspaceMock.mockReset();
    saveAdminPlatformRouteMock.mockReset();
    deleteAdminPlatformRouteMock.mockReset();
    saveAdminLiveScoreCompetitionSourceMock.mockReset();
    deleteAdminLiveScoreCompetitionSourceMock.mockReset();
    deleteAdminContributionGroupMock.mockReset();
    rejectInsecureMutationMock.mockReset();
    rejectRateLimitedRequestMock.mockReset();
    getRequestedAdminClubIdMock.mockReset();

    getUser.mockResolvedValue({
      data: { user: { id: "user-1" } },
      error: null,
    });
    resolveAdminAccessMock.mockResolvedValue({
      hasAccess: true,
      isAuthenticated: true,
      isSuperAdmin: false,
      userId: "user-1",
      role: "club_admin",
      clubId: httpFixtureClubId(),
      availableClubIds: [httpFixtureClubId()],
      canSelectClub: false,
      assignmentCount: 1,
    });
    rejectInsecureMutationMock.mockReturnValue(null);
    rejectRateLimitedRequestMock.mockResolvedValue(null);
    getRequestedAdminClubIdMock.mockReturnValue(null);
    saveAdminContributionGroupMock.mockResolvedValue("group-1");
    saveAdminClubProfileMock.mockResolvedValue({ success: true });
    saveAdminPartnerPredictionPoolMock.mockResolvedValue({ id: "pool-1" });
    settleAdminPartnerPredictionPoolMock.mockResolvedValue({
      id: "pool-1",
      status: "settled",
    });
    getAdminLiveScoreCompetitionSourcesMock.mockResolvedValue([
      { id: "source-1" },
    ]);
    getAdminRuntimeRegistrySnapshotMock.mockResolvedValue({
      routes: [{ id: "route-1", routeKey: "home" }],
      optionSets: [],
      optionValues: [],
      runtimeCopy: [],
      navigation: [],
      search: [],
    });
    getAdminBannersMock.mockResolvedValue([
      { id: "banner-1", title: "Controlled banner" },
    ]);
    getAdminAuditLogsMock.mockResolvedValue([
      { id: "audit-1", action: "settings.update" },
    ]);
    getAdminPredictionsWorkspaceMock.mockResolvedValue({
      markets: [{ id: "market-1" }],
      competitions: [],
      seasons: [],
      fixtures: [],
      partnerPools: [],
      partners: [],
    });
    saveAdminPlatformRouteMock.mockResolvedValue("route-1");
    deleteAdminPlatformRouteMock.mockResolvedValue(undefined);
    saveAdminLiveScoreCompetitionSourceMock.mockResolvedValue("source-1");
    deleteAdminLiveScoreCompetitionSourceMock.mockResolvedValue(undefined);
    deleteAdminContributionGroupMock.mockResolvedValue(undefined);
  });

  it("uses the admin client for LiveScore source reads", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(getAdminLiveScoreCompetitionSourcesMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the scoped admin client and bounded limit for audit-log reads", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/audit-logs?limit=75`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "audit-logs" }),
    })) as Response;

    expect(getAdminAuditLogsMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      { limit: 75 },
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime registry reads", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/runtime-registry`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "runtime-registry" }),
    })) as Response;

    expect(getAdminRuntimeRegistrySnapshotMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for scoped home-banner reads", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/cms-banners`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "cms-banners" }),
    })) as Response;

    expect(getAdminBannersMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      data: [{ id: "banner-1", title: "Controlled banner" }],
    });
  });

  it("uses the admin client for contribution group creation", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/contributions`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          name: "Circle",
          description: "Test",
        }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({ resource: "contributions" }),
    })) as Response;

    expect(saveAdminContributionGroupMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      expect.objectContaining({ name: "Circle" }),
    );
    expect(response.status).toBe(200);
  });

  it.each([
    ["matches", saveAdminMatchMock],
    ["shop", saveAdminProductMock],
    ["membership", saveAdminMembershipPackageMock],
    ["predictions-markets", saveAdminPredictionMarketMock],
    ["predictions-competitions", saveAdminCompetitionMock],
    ["predictions-seasons", saveAdminSeasonMock],
    ["predictions-fixtures", saveAdminFixtureMock],
    ["livescore-sources", saveAdminLiveScoreCompetitionSourceMock],
  ] as const)("carries the verified caller JWT into protected %s configuration writes", async (resource, mutation) => {
    if (resource.startsWith("predictions-")) {
      resolveAdminAccessMock.mockResolvedValue({ hasAccess: true, isAuthenticated: true, isSuperAdmin: true,
        userId: "user-1", role: "super_admin", clubId: httpFixtureClubId() });
    }
    mutation.mockResolvedValue("saved-record");
    const response = await POST(new NextRequest(`${httpFixtureOrigin()}/api/admin/${resource}`, {
      method: "POST", body: JSON.stringify({ name: "Synthetic configuration" }),
      headers: { "content-type": "application/json" },
    }), { params: Promise.resolve({ resource }) });
    expect(response?.status).toBe(200);
    expect(mutation).toHaveBeenCalledWith(serverClient, expect.objectContaining({ userId: "user-1" }), expect.any(Object));
  });

  it.each([
    ["shop", "club_moderator", saveAdminProductMock],
    ["membership", "club_moderator", saveAdminMembershipPackageMock],
    ["livescore-sources", "club_moderator", saveAdminLiveScoreCompetitionSourceMock],
    ["predictions-markets", "club_admin", saveAdminPredictionMarketMock],
    ["predictions-fixtures", "club_admin", saveAdminFixtureMock],
  ] as const)("denies %s configuration to %s before the actual writer", async (resource, role, mutation) => {
    resolveAdminAccessMock.mockResolvedValue({ hasAccess: true, isAuthenticated: true, isSuperAdmin: false,
      userId: "user-1", role, clubId: httpFixtureClubId() });
    const response = await POST(new NextRequest(`${httpFixtureOrigin()}/api/admin/${resource}`, {
      method: "POST", body: "{}", headers: { "content-type": "application/json" },
    }), { params: Promise.resolve({ resource }) });
    expect(response?.status).toBe(403);
    expect(await response?.json()).toMatchObject({ code: "ADMIN_ACCESS_DENIED", change_confirmed: false });
    expect(mutation).not.toHaveBeenCalled();
  });

  it("returns a correctable membership validation response from the actual configuration route", async () => {
    saveAdminMembershipPackageMock.mockRejectedValueOnce(new AdminMembershipValidationError());
    const response = await POST(new NextRequest(`${httpFixtureOrigin()}/api/admin/membership`, {
      method: "POST", body: "{}", headers: { "content-type": "application/json" },
    }), { params: Promise.resolve({ resource: "membership" }) });
    expect(response?.status).toBe(400);
    expect(await response?.json()).toMatchObject({
      code: "ADMIN_MEMBERSHIP_INPUT_INVALID", retryable: false, change_confirmed: false,
    });
    expect(saveAdminMembershipPackageMock).toHaveBeenCalledWith(serverClient, expect.any(Object), {});
  });

  it("denies the actual protected shop caller before mutation when staff step-up expired", async () => {
    getClaims.mockResolvedValue({ data: { claims: { sub: "user-1", role: "authenticated", is_anonymous: false, aal: "aal2", exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) - 301 }] } }, error: null });
    const response = await POST(new NextRequest(`${httpFixtureOrigin()}/api/admin/shop`, { method: "POST", body: "{}" }), { params: Promise.resolve({ resource: "shop" }) });
    expect(response?.status).toBe(403);
    expect(await response?.json()).toMatchObject({ code: "STAFF_STEP_UP_REQUIRED", change_confirmed: false });
    expect(saveAdminProductMock).not.toHaveBeenCalled();
  });

  it("retires partner WDW pool creation before any mutation", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/partner-prediction-pools`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          partnerId: "partner-1",
          fixtureId: "fixture-1",
          title: "Partner Derby Pool",
          partnerStakeFet: 5000,
          fanEntryFet: 100,
          eligibilityMode: "partner_earn_required",
        }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({ resource: "partner-prediction-pools" }),
    })) as Response;

    expect(saveAdminPartnerPredictionPoolMock).not.toHaveBeenCalled();
    expect(response.status).toBe(410);
  });

  it("loads the prediction workspace through one mixed-client boundary", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predictions`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "predictions" }),
    })) as Response;

    expect(getAdminPredictionsWorkspaceMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      { poolClient: serverClient },
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      data: {
        markets: [{ id: "market-1" }],
        competitions: [],
        seasons: [],
        fixtures: [],
        partnerPools: [],
        partners: [],
      },
    });
  });

  it("retires unattributed partner WDW pool settlement", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/partner-prediction-pool-settlement`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ poolId: "pool-1" }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({
        resource: "partner-prediction-pool-settlement",
      }),
    })) as Response;

    expect(settleAdminPartnerPredictionPoolMock).not.toHaveBeenCalled();
    expect(response.status).toBe(410);
  });

  it("uses the caller JWT for free dashboard and writes", async () => {
    predictOperations.dashboard.mockResolvedValue({ settings: { entry_fet: 0 }, fixtures: [] });
    const url = `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-operations`;
    const read = await GET(new NextRequest(url), { params: Promise.resolve({ resource: "predict-operations" }) });
    expect(read.status).toBe(200);
    expect(predictOperations.dashboard).toHaveBeenCalledWith(serverClient, expect.objectContaining({ clubId: httpFixtureClubId() }));
    predictOperations.mutate.mockResolvedValue({ enabled: true, entry_fet: 0, economics_version: "free_v1" });
    const response = await POST(new NextRequest(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ action: "settings", enabled: true }) }), { params: Promise.resolve({ resource: "predict-operations" }) });
    expect(response.status).toBe(200);
    expect(predictOperations.mutate).toHaveBeenCalledWith(serverClient, expect.objectContaining({ clubId: httpFixtureClubId() }), { action: "settings", enabled: true });
  });

  it.each(["origin", "rate"] as const)("keeps %s rejection before authentication or Predict dispatch", async (guard) => {
    if (guard === "origin") rejectInsecureMutationMock.mockReturnValue(new Response(null, { status: 403 }));
    else rejectRateLimitedRequestMock.mockResolvedValue(new Response(null, { status: 429 }));
    const response = await POST(new NextRequest(`${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-operations`, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ action: "settings", enabled: true }),
    }), { params: Promise.resolve({ resource: "predict-operations" }) });
    expect(response.status).toBe(guard === "origin" ? 403 : 429);
    expect(getUser).not.toHaveBeenCalled();
    expect(predictOperations.mutate).not.toHaveBeenCalled();
    expect(predictOperations.legacy).not.toHaveBeenCalled();
    expect(predictOperations.legacyConfirm).not.toHaveBeenCalled();
  });

  it("rejects a paid setting without calling an RPC", async () => {
    const response = await POST(new NextRequest(`${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-operations`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ action: "settings", enabled: true, entryFet: 100 }) }), { params: Promise.resolve({ resource: "predict-operations" }) });
    expect(response.status).toBe(400);
    expect(predictOperations.mutate).not.toHaveBeenCalled();
  });

  it("keeps the approved Predict activation guard before the caller mutation", async () => {
    vi.mocked(withFeatureGuard).mockImplementationOnce(async (feature, _handler, platform, mode, scope) => {
      expect(feature).toBe("predict");
      expect(platform).toBe("web");
      expect(mode).toBe("action");
      expect(scope).toEqual({ clubId: httpFixtureClubId(), isAuthenticated: true, roles: ["club_admin"] });
      return new Response(JSON.stringify({ code: "FEATURE_DISABLED", change_confirmed: false }), { status: 403 }) as never;
    });
    const response = await POST(new NextRequest(`${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-operations`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ action: "settings", enabled: true }) }), { params: Promise.resolve({ resource: "predict-operations" }) });
    expect(response.status).toBe(403);
    expect(predictOperations.mutate).not.toHaveBeenCalled();
  });

  it("denies historical service settlement for a club administrator", async () => {
    const response = await POST(new NextRequest(`${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-legacy-settlement`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ engine: "predict", poolId: "private-pool", operationId: "operation" }) }), { params: Promise.resolve({ resource: "predict-legacy-settlement" }) });
    expect(response.status).toBe(403);
    expect(predictOperations.legacy).not.toHaveBeenCalled();
  });

  it("passes validated global actor access to the separate service boundary", async () => {
    resolveAdminAccessMock.mockResolvedValue({ hasAccess: true, isAuthenticated: true, isSuperAdmin: true, userId: "user-1", role: "super_admin", clubId: httpFixtureClubId() });
    predictOperations.legacy.mockResolvedValue({ operation_id: "operation", economics_version: "legacy_paid_v1" });
    const response = await POST(new NextRequest(`${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-legacy-settlement`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ engine: "predict", poolId: "pool", operationId: "operation", actorId: "spoofed" }) }), { params: Promise.resolve({ resource: "predict-legacy-settlement" }) });
    expect(response.status).toBe(200);
    expect(predictOperations.legacy).toHaveBeenCalledWith(adminClient, serverClient, expect.objectContaining({ userId: "user-1", isSuperAdmin: true }), expect.objectContaining({ operationId: "operation" }));
  });

  it("requires a global actor for the separate historical result command", async () => {
    const url = `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/predict-legacy-confirm-result`;
    const body = { poolId: "pool", operationId: "operation", homeScore: 1, awayScore: 0, sourceUrl: "https://league.example/result" };
    const request = () => new NextRequest(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
    const denied = await POST(request(), { params: Promise.resolve({ resource: "predict-legacy-confirm-result" }) });
    expect(denied.status).toBe(403);
    expect(predictOperations.legacyConfirm).not.toHaveBeenCalled();
    resolveAdminAccessMock.mockResolvedValue({ hasAccess: true, isAuthenticated: true, isSuperAdmin: true, userId: "user-1", role: "super_admin", clubId: httpFixtureClubId() });
    predictOperations.legacyConfirm.mockResolvedValue({ result: "home", operation_id: "operation", economics_version: "legacy_paid_v1" });
    const confirmed = await POST(request(), { params: Promise.resolve({ resource: "predict-legacy-confirm-result" }) });
    expect(confirmed.status).toBe(200);
    expect(predictOperations.legacyConfirm).toHaveBeenCalledWith(adminClient, serverClient, expect.objectContaining({ userId: "user-1", isSuperAdmin: true }), body);
  });

  it("uses the admin client for LiveScore source saves", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          sourceKey: "rwanda-premier-league",
          displayName: "Rwanda Premier League",
          matchAliases: ["Rwanda Premier League"],
          sourceUrls: ["https://www.livescore.com/en/football/rwanda/"],
          isActive: true,
        }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(saveAdminLiveScoreCompetitionSourceMock).toHaveBeenCalledWith(
      serverClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      expect.objectContaining({ sourceKey: "rwanda-premier-league" }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime route saves", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/runtime-routes`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          routeKey: "admin.dashboard",
          pathPattern: "/admin",
          surface: "admin",
          featureKey: "admin",
        }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({ resource: "runtime-routes" }),
    })) as Response;

    expect(saveAdminPlatformRouteMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      expect.objectContaining({
        routeKey: "admin.dashboard",
        pathPattern: "/admin",
      }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for contribution group deletion", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/contributions?id=group-1&expected_updated_at=2026-07-24T18%3A00%3A00Z`,
      {
        method: "DELETE",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
        },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "contributions" }),
    })) as Response;

    expect(deleteAdminContributionGroupMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      "group-1",
      "2026-07-24T18:00:00Z",
    );
    expect(response.status).toBe(200);
  });

  it("denies destructive routes to club moderators before the service-role mutation", async () => {
    resolveAdminAccessMock.mockResolvedValueOnce({
      hasAccess: true,
      isAuthenticated: true,
      isSuperAdmin: false,
      userId: "moderator-1",
      role: "club_moderator",
      clubId: httpFixtureClubId(),
      availableClubIds: [httpFixtureClubId()],
      canSelectClub: false,
      assignmentCount: 1,
    });
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/contributions?id=group-1&expected_updated_at=2026-07-24T18%3A00%3A00Z`,
      {
        method: "DELETE",
        headers: { origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}` },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "contributions" }),
    })) as Response;

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({
      code: "ADMIN_ACCESS_DENIED",
      error: "Club-admin access is required.",
    });
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(deleteAdminContributionGroupMock).not.toHaveBeenCalled();
  });

  it("denies a club admin whose active club scope is missing", async () => {
    resolveAdminAccessMock.mockResolvedValueOnce({
      hasAccess: true,
      isAuthenticated: true,
      isSuperAdmin: false,
      userId: "club-admin-1",
      role: "club_admin",
      clubId: null,
      availableClubIds: [httpFixtureClubId()],
      canSelectClub: false,
      assignmentCount: 1,
    });
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/contributions?id=group-1&expected_updated_at=2026-07-24T18%3A00%3A00Z`,
      {
        method: "DELETE",
        headers: { origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}` },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "contributions" }),
    })) as Response;

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({
      code: "ADMIN_ACCESS_DENIED",
      error: "An active club scope is required.",
    });
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(deleteAdminContributionGroupMock).not.toHaveBeenCalled();
  });

  it("retains the caller JWT for LiveScore source deletion", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources?id=source-1&expected_updated_at=2026-07-24T18%3A00%3A00Z`,
      {
        method: "DELETE",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
        },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(deleteAdminLiveScoreCompetitionSourceMock).toHaveBeenCalledWith(
      serverClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      "source-1",
      "2026-07-24T18:00:00Z",
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime route deletion", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/runtime-routes?id=route-1&expected_updated_at=2026-07-24T18%3A00%3A00Z`,
      {
        method: "DELETE",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
        },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "runtime-routes" }),
    })) as Response;

    expect(deleteAdminPlatformRouteMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      "route-1",
      "2026-07-24T18:00:00Z",
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for club settings updates including team colors", async () => {
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/settings`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          clubName: "Rayon Sports FC",
          clubSlug: "rayon-sports",
          primaryColorHex: "#0038A8",
          secondaryColorHex: "#0E2B55",
          accentColorHex: "#F7B500",
        }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({ resource: "settings" }),
    })) as Response;

    expect(saveAdminClubProfileMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: httpFixtureClubId() }),
      expect.objectContaining({
        primaryColorHex: "#0038A8",
        secondaryColorHex: "#0E2B55",
        accentColorHex: "#F7B500",
      }),
    );
    expect(response.status).toBe(200);
  });

  it("returns an explicit empty state for an empty resource collection", async () => {
    getAdminLiveScoreCompetitionSourcesMock.mockResolvedValueOnce([]);
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      code: "ADMIN_RESOURCE_EMPTY",
      state: "empty",
      data: [],
    });
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("sanitizes unexpected resource errors", async () => {
    getAdminLiveScoreCompetitionSourcesMock.mockRejectedValueOnce(
      new Error("database password and raw provider details"),
    );
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;
    const body = await response.json();

    expect(response.status).toBe(502);
    expect(body).toEqual({
      code: "ADMIN_RESOURCE_FAILED",
      error: "The operation could not be completed.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("database password");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("returns a controlled permission-denied response before resource access", async () => {
    resolveAdminAccessMock.mockResolvedValueOnce({
      hasAccess: false,
      isAuthenticated: true,
      isSuperAdmin: false,
      userId: "user-1",
      role: null,
      clubId: null,
      availableClubIds: [],
      canSelectClub: false,
      assignmentCount: 0,
    });
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources`,
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({
      code: "ADMIN_ACCESS_DENIED",
      error: "Admin access denied.",
    });
    expect(getAdminLiveScoreCompetitionSourcesMock).not.toHaveBeenCalled();
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("does not confirm a mutation while its write is still syncing", async () => {
    let resolveWrite: ((value: string) => void) | undefined;
    saveAdminContributionGroupMock.mockReturnValueOnce(
      new Promise<string>((resolve) => {
        resolveWrite = resolve;
      }),
    );
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/contributions`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ name: "Circle" }),
      },
    );

    let settled = false;
    const responsePromise = POST(request, {
      params: Promise.resolve({ resource: "contributions" }),
    }).then((response) => {
      settled = true;
      return response;
    });

    await Promise.resolve();
    await Promise.resolve();
    expect(settled).toBe(false);

    resolveWrite?.("group-1");
    const response = (await responsePromise) as Response;
    expect(response.status).toBe(200);
    expect(settled).toBe(true);
  });

  it("returns a controlled conflict without claiming the write succeeded", async () => {
    saveAdminContributionGroupMock.mockRejectedValueOnce(
      new AdminMutationConflictError("raw record version details"),
    );
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/contributions`,
      {
        method: "POST",
        headers: {
          origin: `${httpFixtureOrigin("https://admin.gikundiro.com")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ name: "Circle" }),
      },
    );

    const response = (await POST(request, {
      params: Promise.resolve({ resource: "contributions" }),
    })) as Response;
    const body = await response.json();

    expect(response.status).toBe(409);
    expect(body).toEqual({
      code: "STALE_RECORD",
      error:
        "This record changed after it was loaded. Refresh the latest data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("raw record version");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("returns a bounded timeout with no success confirmation", async () => {
    vi.useFakeTimers();
    getAdminLiveScoreCompetitionSourcesMock.mockReturnValueOnce(
      new Promise(() => undefined),
    );
    const request = new NextRequest(
      `${httpFixtureOrigin("https://admin.gikundiro.com")}/api/admin/livescore-sources`,
      { method: "GET" },
    );
    const responsePromise = GET(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    });

    await vi.advanceTimersByTimeAsync(8_000);
    const response = (await responsePromise) as Response;

    expect(response.status).toBe(504);
    expect(await response.json()).toEqual({
      code: "ADMIN_RESOURCE_TIMEOUT",
      error: "The operation timed out. Check current data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
    expect(response.headers.get("cache-control")).toBe("no-store");
  });
});

registerLocalHttpAssertions([
  {
    "name": "returns an explicit empty state for an empty resource collection",
    "route": "/api/admin/:resource",
    "state": "empty"
  },
  {
    "name": "sanitizes unexpected resource errors",
    "route": "/api/admin/:resource",
    "state": "error"
  },
  {
    "name": "returns a controlled permission-denied response before resource access",
    "route": "/api/admin/:resource",
    "state": "permission_denied"
  },
  {
    "name": "does not confirm a mutation while its write is still syncing",
    "route": "/api/admin/:resource",
    "state": "syncing"
  },
  {
    "name": "returns a controlled conflict without claiming the write succeeded",
    "route": "/api/admin/:resource",
    "state": "conflict"
  },
  {
    "name": "returns a bounded timeout with no success confirmation",
    "route": "/api/admin/:resource",
    "state": "security_timeout"
  }
]);
