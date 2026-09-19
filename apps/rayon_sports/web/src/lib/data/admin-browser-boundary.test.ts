import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  adjustAdminFetWalletBalance,
  deleteAdminContentBlock,
  deleteAdminStandingRow,
  getAdminClubProfile,
  getAdminAuditLogs,
  getAdminContentBlocks,
  getAdminFetWalletSnapshot,
  getAdminContributionSnapshot,
  getAdminMembershipApplications,
  getAdminSupporterRegistry,
  getAdminProducts,
  getAdminSmsSnapshot,
  getAdminTicketOrders,
  bulkUpdateTicketStatus,
  reviewMembershipApplication,
  saveAdminFanClub,
  saveAdminClubProfile,
  saveAdminContentBlock,
  sendAdminNotification,
  saveAdminSquadPlayer,
  updateTicketStatus,
} from "@/lib/data/admin";
import { requestAdminApi } from "@/lib/data/admin/http";
import {
  getAdminFeatures,
  updateAdminFeature,
} from "@/lib/data/admin/features";
import {
  getAdminRuntimeRegistrySnapshot,
  saveAdminPlatformRoute,
} from "@/lib/data/admin/runtime-registries";

const client = {} as SupabaseClient;
const access = { clubId: "24" } as AdminAccess;

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify({ data }), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

function expectFetchCall(
  fetchMock: {
    mock: {
      calls: unknown[];
    };
  },
  url: string,
  method: "GET" | "POST" | "DELETE",
  body?: string,
) {
  expect(fetchMock).toHaveBeenCalledTimes(1);
  const [calledUrl, options] =
    (fetchMock.mock.calls[0] as [unknown, RequestInit | undefined]) ?? [];
  expect(String(calledUrl)).toBe(url);
  expect(options).toMatchObject({
    method,
    credentials: "same-origin",
    cache: "no-store",
  });
  if (body !== undefined) {
    expect(options).toMatchObject({
      body,
      headers: { "Content-Type": "application/json" },
    });
  }
}

describe("admin browser API boundary", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("builds GET requests for the admin API helper", async () => {
    const origin = window.location.origin;
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ ok: true }) as Response);

    const result = await requestAdminApi<{ ok: boolean }>("dashboard", {
      query: { clubId: 24, includeDrafts: true },
    });

    expect(result).toEqual({ ok: true });
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/dashboard?clubId=24&includeDrafts=true`,
      "GET",
    );
  });

  it("surfaces API errors from the helper", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ error: "Admin access denied." }), {
        status: 403,
        headers: {
          "Content-Type": "application/json",
        },
      }) as Response,
    );

    await expect(requestAdminApi("dashboard")).rejects.toThrow(
      "Admin access denied.",
    );
  });

  it("retains the stale-record status and code from the admin API", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          code: "STALE_RECORD",
          error: "Refresh and review the latest record.",
        }),
        {
          status: 409,
          headers: {
            "Content-Type": "application/json",
          },
        },
      ) as Response,
    );

    await expect(requestAdminApi("contributions")).rejects.toMatchObject({
      status: 409,
      code: "STALE_RECORD",
    });
  });

  it("loads products through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = [
      {
        id: "product-1",
        clubId: 24,
        name: "Replica Kit",
        subtitle: "2026 home shirt",
        description: "Official supporter replica shirt.",
        category: "Merch",
        price: 35_000,
        imageUrl: "https://cdn.example.com/kit.webp",
        sizes: ["S", "M", "L"],
        isActive: true,
        collection: "Home",
        sortOrder: 10,
        createdAt: "2026-07-30T09:00:00.000Z",
        updatedAt: "2026-07-30T09:00:00.000Z",
      },
    ];
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminProducts(client, access)).resolves.toEqual(expected);
    expectFetchCall(fetchMock, `${origin}/api/admin/shop`, "GET");
  });

  it("loads club settings with editable team colors through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = {
      id: 24,
      clubName: "Rayon Sports FC",
      clubSlug: "rayon-sports",
      shortName: "Rayon",
      nickname: "Gikundiro",
      countryCode: "RW",
      league: "Rwanda Premier League",
      region: "Kigali",
      currencyCode: "RWF",
      currencySymbol: "FRw",
      defaultLanguage: "en",
      supportedLanguages: ["en"],
      officialContact: "+250 700 000 000",
      facebookUrl: null,
      xUrl: null,
      instagramUrl: null,
      tiktokUrl: null,
      officialLogoUrl: null,
      primaryColorHex: "#0038A8",
      secondaryColorHex: "#0E2B55",
      accentColorHex: "#F7B500",
      updatedAt: "2026-07-30T09:00:00.000Z",
      featureFlags: {
        chat: true,
        fan_clubs: true,
        shop: true,
        sms_ledger: true,
        ticketing: true,
      },
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminClubProfile(client, access)).resolves.toEqual(
      expected,
    );
    expectFetchCall(fetchMock, `${origin}/api/admin/settings`, "GET");
  });

  it("loads a bounded, normalized audit snapshot through the scoped admin API", async () => {
    const origin = window.location.origin;
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse([
        {
          id: "audit-1",
          actorKind: "administrator",
          userName: "Verified Administrator",
          action: "settings.update",
          targetTable: "african_football_clubs",
          targetId: "24",
          oldData: {},
          newData: { access_token: "private" },
          metadata: {},
          notes: null,
          createdAt: "2026-07-30T09:00:00.000Z",
        },
      ]) as Response,
    );

    await expect(
      getAdminAuditLogs(client, access, { limit: 75 }),
    ).resolves.toEqual([
      expect.objectContaining({
        id: "audit-1",
        newData: { access_token: "[redacted]" },
      }),
    ]);
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/audit-logs?limit=75`,
      "GET",
    );
  });

  it("preserves an explicit empty club-settings response without fabricating defaults", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(null) as Response);

    await expect(getAdminClubProfile(client, access)).resolves.toBeNull();
    expectFetchCall(
      fetchMock,
      `${window.location.origin}/api/admin/settings`,
      "GET",
    );
  });

  it("saves club settings with normalized team colors through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      id: 24,
      clubName: "Rayon Sports FC",
      clubSlug: "rayon-sports",
      shortName: "Rayon",
      nickname: "Gikundiro",
      countryCode: "RW",
      league: "Rwanda Premier League",
      region: "Kigali",
      currencyCode: "RWF",
      currencySymbol: "FRw",
      defaultLanguage: "en",
      supportedLanguages: ["en"],
      officialContact: "+250 700 000 000",
      facebookUrl: null,
      xUrl: null,
      instagramUrl: null,
      tiktokUrl: null,
      officialLogoUrl: null,
      primaryColorHex: "#0038A8",
      secondaryColorHex: "#0E2B55",
      accentColorHex: "#F7B500",
      expectedUpdatedAt: "2026-07-30T09:00:00.000Z",
      featureFlags: {
        chat: true,
        fan_clubs: true,
        shop: true,
        sms_ledger: true,
        ticketing: true,
      },
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      saveAdminClubProfile(client, access, payload),
    ).resolves.toEqual({
      success: true,
    });
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/settings`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("saves fan clubs through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      name: "Kigali North",
      region: "Kigali",
      description: "North chapter",
      memberCount: 42,
      eventCount: 3,
      rating: 5,
      isActive: true,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse("fan-club-1") as Response);

    await expect(saveAdminFanClub(client, access, payload)).resolves.toBe(
      "fan-club-1",
    );
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/fan-clubs`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("deletes standings rows through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      deleteAdminStandingRow(
        client,
        access,
        "standing-1",
        "2026-07-24T18:00:00Z",
      ),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/standings?id=standing-1&expected_updated_at=2026-07-24T18%3A00%3A00Z`,
      "DELETE",
    );
  });

  it("loads contribution snapshots through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = {
      groups: [],
      contributions: [],
      monthlyTotal: 0,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminContributionSnapshot(client, access)).resolves.toEqual(
      expected,
    );
    expectFetchCall(fetchMock, `${origin}/api/admin/contributions`, "GET");
  });

  it("sends notifications through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      title: "Kickoff moved",
      body: "Kickoff is now 18:00",
      audience: "all_fans" as const,
      deliveryMode: "send_now" as const,
    };
    const expected = {
      notification: { id: "notification-1" },
      delivery: { status: "sent" },
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(sendAdminNotification(client, payload)).resolves.toEqual(
      expected,
    );
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/notifications`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("loads sms monitoring through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = { metrics: { "SMS captured": 2 }, syncRuns: [] };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminSmsSnapshot(client, access)).resolves.toEqual(
      expected,
    );
    expectFetchCall(fetchMock, `${origin}/api/admin/sms`, "GET");
  });

  it("loads CMS content blocks through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = [{ id: "cms-1", title: "About the club" }];
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminContentBlocks(client, access)).resolves.toEqual(
      expected,
    );
    expectFetchCall(fetchMock, `${origin}/api/admin/cms-content`, "GET");
  });

  it("saves CMS content blocks through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      contentType: "general",
      title: "About the club",
      body: "Temporary body",
      distribution: "both" as const,
      isActive: true,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse("cms-1") as Response);

    await expect(saveAdminContentBlock(client, access, payload)).resolves.toBe(
      "cms-1",
    );
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/cms-content`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("deletes CMS content blocks through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      deleteAdminContentBlock(
        client,
        access,
        "cms-1",
        "2026-07-24T20:00:00.000Z",
      ),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/cms-content?id=cms-1&expected_updated_at=2026-07-24T20%3A00%3A00.000Z`,
      "DELETE",
    );
  });

  it("loads wallet operations through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = {
      overview: [
        {
          userId: "supporter-1",
          publicUserId: "483912",
          displayName: "UAT Supporter Alpha",
          tier: "imena",
          balance: 1250,
          transactionCount: 4,
          lastTransactionAt: "2026-07-29T20:00:00.000Z",
          lifetimeEarned: 1500,
          lifetimeSpent: 250,
        },
      ],
      ledger: [],
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(
      getAdminFetWalletSnapshot(client, access, {
        search: "Alpha",
        userId: "supporter-1",
      }),
    ).resolves.toEqual(expected);
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/gamification-wallet?search=Alpha&user_id=supporter-1`,
      "GET",
    );
  });

  it("loads ticket operations through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = [
      {
        id: "ticket-1",
        matchId: "match-1",
        userId: "user-1",
        seatType: "Standard",
        amountPaid: 15_000,
        status: "pending",
        qrCode: null,
        purchasedAt: "2026-07-30T09:00:00.000Z",
        updatedAt: "2026-07-30T09:05:00.000Z",
        userName: "Verified Supporter",
        userPhone: "+250700000000",
        matchTitle: "Rayon Sports vs APR FC",
        momoReference: "momo-1",
      },
    ];
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminTicketOrders(client, access)).resolves.toEqual(
      expected,
    );
    expectFetchCall(fetchMock, `${origin}/api/admin/tickets`, "GET");
  });

  it("updates ticket status through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      ticketId: "ticket-1",
      expectedUpdatedAt: "2026-07-30T09:05:00.000Z",
      status: "valid",
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      updateTicketStatus(
        client,
        {
          ...access,
          hasAccess: true,
          isSuperAdmin: false,
          role: "club_admin",
        },
        { id: payload.ticketId, updatedAt: payload.expectedUpdatedAt },
        payload.status,
      ),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/tickets/status`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("updates a reviewed ticket selection through the scoped bulk API", async () => {
    const origin = window.location.origin;
    const payload = {
      tickets: [
        {
          id: "ticket-1",
          expectedUpdatedAt: "2026-07-30T09:05:00.000Z",
        },
        {
          id: "ticket-2",
          expectedUpdatedAt: "2026-07-30T09:06:00.000Z",
        },
      ],
      status: "valid" as const,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        jsonResponse({ success: true, updatedCount: 2 }) as Response,
      );

    await expect(
      bulkUpdateTicketStatus(
        client,
        {
          ...access,
          hasAccess: true,
          isSuperAdmin: false,
          role: "club_admin",
        },
        payload.tickets.map(({ id, expectedUpdatedAt }) => ({
          id,
          updatedAt: expectedUpdatedAt,
        })),
        payload.status,
      ),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/tickets/bulk-status`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("loads supporter registry through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = [
      {
        id: "supporter-1",
        userId: "user-1",
        displayName: "Alpha Fan",
        phone: "+250788123456",
        tier: "gold" as const,
        status: "active" as const,
        points: 420,
        chapter: "Kigali",
        membershipNumber: "RS-0001",
        joinedAt: "2026-07-29T10:00:00.000Z",
      },
    ];
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminSupporterRegistry(client, access)).resolves.toEqual(
      expected,
    );
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/membership-supporters`,
      "GET",
    );
  });

  it("loads membership applications through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = [
      {
        id: "application-1",
        userId: "user-1",
        clubId: 24,
        tier: "gold" as const,
        status: "pending" as const,
        paymentStatus: "paid" as const,
        applicationDate: "2026-07-29T10:00:00.000Z",
        reviewDate: null,
        reviewerId: null,
        notes: null,
        userName: "Alpha Fan",
        userPhone: "+250788123456",
        updatedAt: "2026-07-29T10:00:00.000Z",
      },
    ];
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(
      getAdminMembershipApplications(client, access),
    ).resolves.toEqual(expected);
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/membership-applications`,
      "GET",
    );
  });

  it("rejects membership applications through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      applicationId: "application-1",
      expectedUpdatedAt: "2026-07-24T20:00:00.000Z",
      decision: "rejected" as const,
      notes: "Provider payment was not verified.",
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      reviewMembershipApplication(
        client,
        access,
        payload.applicationId,
        payload.expectedUpdatedAt,
        payload.decision,
        payload.notes,
      ),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/membership-applications/review`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("saves wallet adjustments through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      userId: "supporter-1",
      amount: 125,
      reason: "Manual reconciliation",
      idempotencyKey: "wallet-adjustment-1",
    };
    const expected = {
      status: "success",
      amount: 125,
      balance: 625,
      referenceId: "wallet-adjustment-ref",
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(
      adjustAdminFetWalletBalance(client, access, payload),
    ).resolves.toEqual(expected);
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/gamification-wallet`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("saves squad players through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const payload = {
      id: null,
      name: "Jean Bosco",
      role: "Midfielder",
      number: 8,
      nationality: "Rwanda",
      bio: "Creative midfielder",
      imageUrl: "",
      isActive: true,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      saveAdminSquadPlayer(client, access, payload),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/squad`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("loads and validates platform features through the scoped admin API", async () => {
    const origin = window.location.origin;
    const expected = [
      {
        id: "feature-1",
        clubId: 24,
        scope: "club",
        featureKey: "ticketing",
        displayName: "Ticketing",
        description: "Matchday ticket controls.",
        category: "commerce",
        isEnabled: true,
        visibilityState: "visible",
        updatedAt: "2026-07-30T09:00:00.000Z",
        channels: [],
        rules: null,
      },
    ];
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminFeatures(client, access)).resolves.toEqual(expected);
    expectFetchCall(fetchMock, `${origin}/api/admin/features`, "GET");
  });

  it("saves validated feature updates through the scoped admin API", async () => {
    const origin = window.location.origin;
    const payload = {
      id: "feature-1",
      expectedUpdatedAt: "2026-07-30T09:00:00.000Z",
      updates: { isEnabled: false },
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(
      updateAdminFeature(
        client,
        access,
        payload.id,
        payload.expectedUpdatedAt,
        payload.updates,
      ),
    ).resolves.toEqual({ success: true });
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/features/update`,
      "POST",
      JSON.stringify(payload),
    );
  });

  it("loads and validates the bounded runtime registry snapshot", async () => {
    const origin = window.location.origin;
    const expected = {
      routes: [],
      optionSets: [],
      optionValues: [],
      runtimeCopy: [],
      navigation: [],
      search: [],
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(
      getAdminRuntimeRegistrySnapshot(client, access),
    ).resolves.toEqual(expected);
    expectFetchCall(fetchMock, `${origin}/api/admin/runtime-registry`, "GET");
  });

  it("sends only validated runtime-route fields through the admin API", async () => {
    const origin = window.location.origin;
    const input = {
      scope: "club" as const,
      clubId: 24,
      routeKey: "tickets.detail",
      pathPattern: "/tickets/:matchId",
      surface: "web" as const,
      featureKey: "ticketing",
      label: "Ticket detail",
      authRequired: true,
      requiredRoles: ["member"],
      presentation: "screen",
      showInNavigation: false,
      showOnHome: false,
      sortOrder: 10,
      isActive: true,
      metadata: { owner: "platform" },
    };
    const expectedBody = {
      id: null,
      expectedUpdatedAt: null,
      ...input,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse("route-1") as Response);

    await expect(saveAdminPlatformRoute(client, access, input)).resolves.toBe(
      "route-1",
    );
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/runtime-routes`,
      "POST",
      JSON.stringify(expectedBody),
    );
  });
});
