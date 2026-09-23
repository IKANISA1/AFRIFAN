import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const {
  getUser,
  resolveAdminAccessMock,
  saveAdminContributionGroupMock,
  saveAdminClubProfileMock,
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
  return {
    getUser,
    resolveAdminAccessMock: vi.fn(),
    saveAdminContributionGroupMock: vi.fn(),
    saveAdminClubProfileMock: vi.fn(),
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
    saveAdminCompetition: noop,
    saveAdminConfigEntry: noop,
    saveAdminContentBlock: noop,
    saveAdminContributionGroup: saveAdminContributionGroupMock,
    saveAdminFanClub: noop,
    saveAdminFanEngagementToken: noop,
    saveAdminFixture: noop,
    saveAdminLiveScoreCompetitionSource:
      saveAdminLiveScoreCompetitionSourceMock,
    saveAdminPlatformRoute: saveAdminPlatformRouteMock,
    saveAdminMatch: noop,
    saveAdminMembershipPackage: noop,
    saveAdminOffer: noop,
    saveAdminPredictionMarket: noop,
    saveAdminPartnerPredictionPool: saveAdminPartnerPredictionPoolMock,
    saveAdminProduct: noop,
    saveAdminSeason: noop,
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
    getUser.mockReset();
    resolveAdminAccessMock.mockReset();
    saveAdminContributionGroupMock.mockReset();
    saveAdminClubProfileMock.mockReset();
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
      clubId: "24",
      availableClubIds: ["24"],
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
      "https://admin.gikundiro.com/api/admin/livescore-sources",
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(getAdminLiveScoreCompetitionSourcesMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the scoped admin client and bounded limit for audit-log reads", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/audit-logs?limit=75",
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "audit-logs" }),
    })) as Response;

    expect(getAdminAuditLogsMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
      { limit: 75 },
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime registry reads", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/runtime-registry",
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "runtime-registry" }),
    })) as Response;

    expect(getAdminRuntimeRegistrySnapshotMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for scoped home-banner reads", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/cms-banners",
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "cms-banners" }),
    })) as Response;

    expect(getAdminBannersMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      data: [{ id: "banner-1", title: "Controlled banner" }],
    });
  });

  it("uses the admin client for contribution group creation", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/contributions",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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
      expect.objectContaining({ clubId: "24" }),
      expect.objectContaining({ name: "Circle" }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the server client for partner WDW pool creation", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/partner-prediction-pools",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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

    expect(saveAdminPartnerPredictionPoolMock).toHaveBeenCalledWith(
      serverClient,
      expect.objectContaining({ clubId: "24" }),
      expect.objectContaining({
        partnerId: "partner-1",
        fixtureId: "fixture-1",
        title: "Partner Derby Pool",
        partnerStakeFet: 5000,
        fanEntryFet: 100,
        eligibilityMode: "partner_earn_required",
      }),
    );
    expect(response.status).toBe(200);
  });

  it("loads the prediction workspace through one mixed-client boundary", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/predictions",
      { method: "GET" },
    );

    const response = (await GET(request, {
      params: Promise.resolve({ resource: "predictions" }),
    })) as Response;

    expect(getAdminPredictionsWorkspaceMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
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

  it("uses the server client for partner WDW pool settlement", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/partner-prediction-pool-settlement",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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

    expect(settleAdminPartnerPredictionPoolMock).toHaveBeenCalledWith(
      serverClient,
      expect.objectContaining({ clubId: "24" }),
      "pool-1",
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for LiveScore source saves", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/livescore-sources",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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
      adminClient,
      expect.objectContaining({ clubId: "24" }),
      expect.objectContaining({ sourceKey: "rwanda-premier-league" }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime route saves", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/runtime-routes",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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
      expect.objectContaining({ clubId: "24" }),
      expect.objectContaining({
        routeKey: "admin.dashboard",
        pathPattern: "/admin",
      }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for contribution group deletion", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/contributions?id=group-1&expected_updated_at=2026-07-24T18%3A00%3A00Z",
      {
        method: "DELETE",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "contributions" }),
    })) as Response;

    expect(deleteAdminContributionGroupMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
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
      clubId: "24",
      availableClubIds: ["24"],
      canSelectClub: false,
      assignmentCount: 1,
    });
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/contributions?id=group-1&expected_updated_at=2026-07-24T18%3A00%3A00Z",
      {
        method: "DELETE",
        headers: { origin: "https://admin.gikundiro.com" },
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
      availableClubIds: ["24"],
      canSelectClub: false,
      assignmentCount: 1,
    });
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/contributions?id=group-1&expected_updated_at=2026-07-24T18%3A00%3A00Z",
      {
        method: "DELETE",
        headers: { origin: "https://admin.gikundiro.com" },
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

  it("uses the admin client for LiveScore source deletion", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/livescore-sources?id=source-1&expected_updated_at=2026-07-24T18%3A00%3A00Z",
      {
        method: "DELETE",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "livescore-sources" }),
    })) as Response;

    expect(deleteAdminLiveScoreCompetitionSourceMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
      "source-1",
      "2026-07-24T18:00:00Z",
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime route deletion", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/runtime-routes?id=route-1&expected_updated_at=2026-07-24T18%3A00%3A00Z",
      {
        method: "DELETE",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      },
    );

    const response = (await DELETE(request, {
      params: Promise.resolve({ resource: "runtime-routes" }),
    })) as Response;

    expect(deleteAdminPlatformRouteMock).toHaveBeenCalledWith(
      adminClient,
      expect.objectContaining({ clubId: "24" }),
      "route-1",
      "2026-07-24T18:00:00Z",
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for club settings updates including team colors", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/settings",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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
      expect.objectContaining({ clubId: "24" }),
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
      "https://admin.gikundiro.com/api/admin/livescore-sources",
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
      "https://admin.gikundiro.com/api/admin/livescore-sources",
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
      "https://admin.gikundiro.com/api/admin/livescore-sources",
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
      "https://admin.gikundiro.com/api/admin/contributions",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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
      "https://admin.gikundiro.com/api/admin/contributions",
      {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
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
      "https://admin.gikundiro.com/api/admin/livescore-sources",
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
