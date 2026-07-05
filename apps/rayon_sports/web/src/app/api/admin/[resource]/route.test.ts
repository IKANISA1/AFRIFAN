import { beforeEach, describe, expect, it, vi } from "vitest";
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
    getAdminLiveScoreCompetitionSources: getAdminLiveScoreCompetitionSourcesMock,
    getAdminRuntimeRegistrySnapshot: getAdminRuntimeRegistrySnapshotMock,
    getAdminMatches: noop,
    getAdminMembershipApplications: noop,
    getAdminMembershipPackages: noop,
    getAdminNotificationContext: noop,
    getAdminOffers: noop,
    getAdminPredictionMarkets: noop,
    getAdminPartnerPredictionPools: noop,
    getAdminPartnerOptions: noop,
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
    saveAdminClubProfile: saveAdminClubProfileMock,
    saveAdminCompetition: noop,
    saveAdminConfigEntry: noop,
    saveAdminContentBlock: noop,
    saveAdminContributionGroup: saveAdminContributionGroupMock,
    saveAdminFanClub: noop,
    saveAdminFanEngagementToken: noop,
    saveAdminFixture: noop,
    saveAdminLiveScoreCompetitionSource: saveAdminLiveScoreCompetitionSourceMock,
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
    deleteAdminLiveScoreCompetitionSource: deleteAdminLiveScoreCompetitionSourceMock,
    deleteAdminPlatformRoute: deleteAdminPlatformRouteMock,
    deleteAdminPlatformOptionSet: noop,
    deleteAdminPlatformOptionValue: noop,
    deleteAdminRuntimeCopyEntry: noop,
    deleteAdminSiteNavigationItem: noop,
    deleteAdminSiteSearchItem: noop,
    deleteAdminVenueGovernanceControl: noop,
    saveAdminPlatformOptionSet: noop,
    saveAdminPlatformOptionValue: noop,
    saveAdminRuntimeCopyEntry: noop,
    saveAdminSiteNavigationItem: noop,
    saveAdminSiteSearchItem: noop,
    saveAdminVenueGovernanceControl: noop,
  };
});

vi.mock("@/lib/security", () => ({
  rejectInsecureMutation: rejectInsecureMutationMock,
  rejectRateLimitedRequest: rejectRateLimitedRequestMock,
}));

vi.mock("@/lib/server-feature-guard", () => ({
  withFeatureGuard: vi.fn(
    async (
      _featureKey: string,
      handler: () => Promise<Response>,
    ) => handler(),
  ),
}));

vi.mock("@/lib/supabase/admin", () => ({
  getAdminSupabase: vi.fn(() => adminClient),
}));

vi.mock("@/lib/supabase/server", () => ({
  getServerSupabase: vi.fn(async () => serverClient),
}));

import { DELETE, GET, POST } from "./route";

describe("admin resource route", () => {
  beforeEach(() => {
    getUser.mockReset();
    resolveAdminAccessMock.mockReset();
    saveAdminContributionGroupMock.mockReset();
    saveAdminClubProfileMock.mockReset();
    saveAdminPartnerPredictionPoolMock.mockReset();
    settleAdminPartnerPredictionPoolMock.mockReset();
    getAdminLiveScoreCompetitionSourcesMock.mockReset();
    getAdminRuntimeRegistrySnapshotMock.mockReset();
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
    settleAdminPartnerPredictionPoolMock.mockResolvedValue({ id: "pool-1", status: "settled" });
    getAdminLiveScoreCompetitionSourcesMock.mockResolvedValue([{ id: "source-1" }]);
    getAdminRuntimeRegistrySnapshotMock.mockResolvedValue({
      routes: [{ id: "route-1", routeKey: "home" }],
      optionSets: [],
      optionValues: [],
      runtimeCopy: [],
      navigation: [],
      search: [],
      venueControls: [],
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
      params: Promise.resolve({ resource: "partner-prediction-pool-settlement" }),
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
          routeKey: "venue.dashboard",
          pathPattern: "/venue/dashboard",
          surface: "venue",
          featureKey: "venue_ops",
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
        routeKey: "venue.dashboard",
        pathPattern: "/venue/dashboard",
      }),
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for contribution group deletion", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/contributions?id=group-1",
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
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for LiveScore source deletion", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/livescore-sources?id=source-1",
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
    );
    expect(response.status).toBe(200);
  });

  it("uses the admin client for runtime route deletion", async () => {
    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/runtime-routes?id=route-1",
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
});
