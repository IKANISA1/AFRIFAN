import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  adjustAdminFetWalletBalance,
  deleteAdminContentBlock,
  deleteAdminStandingRow,
  getAdminClubProfile,
  getAdminContentBlocks,
  getAdminFetWalletSnapshot,
  getAdminContributionSnapshot,
  getAdminMembershipApplications,
  getAdminSupporterRegistry,
  getAdminProducts,
  getAdminSmsSnapshot,
  getAdminTicketOrders,
  reviewMembershipApplication,
  saveAdminFanClub,
  saveAdminClubProfile,
  saveAdminContentBlock,
  sendAdminNotification,
  saveAdminSquadPlayer,
  updateTicketStatus,
} from "@/lib/data/admin";
import { requestAdminApi } from "@/lib/data/admin/http";

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

  it("loads products through the scoped admin API in the browser", async () => {
    const origin = window.location.origin;
    const expected = [{ id: "product-1", name: "Replica Kit" }];
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
      defaultLanguage: "rw",
      supportedLanguages: ["rw", "en", "fr"],
      officialContact: "+250 700 000 000",
      primaryColorHex: "#0038A8",
      secondaryColorHex: "#0E2B55",
      accentColorHex: "#F7B500",
      featureFlags: { chat: true, fan_clubs: true, shop: true, sms_ledger: true, ticketing: true },
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(getAdminClubProfile(client, access)).resolves.toEqual(expected);
    expectFetchCall(fetchMock, `${origin}/api/admin/settings`, "GET");
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
      defaultLanguage: "rw",
      supportedLanguages: ["rw", "en", "fr"],
      officialContact: "+250 700 000 000",
      facebookUrl: null,
      xUrl: null,
      instagramUrl: null,
      tiktokUrl: null,
      officialLogoUrl: null,
      primaryColorHex: "#0038A8",
      secondaryColorHex: "#0E2B55",
      accentColorHex: "#F7B500",
      featureFlags: { chat: true, fan_clubs: true, shop: true, sms_ledger: true, ticketing: true },
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse({ success: true }) as Response);

    await expect(saveAdminClubProfile(client, access, payload)).resolves.toEqual({
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
      deleteAdminStandingRow(client, access, "standing-1"),
    ).resolves.toBeUndefined();
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/standings?id=standing-1`,
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
    deleteAdminContentBlock(client, access, "cms-1"),
  ).resolves.toBeUndefined();
  expectFetchCall(
    fetchMock,
    `${origin}/api/admin/cms-content?id=cms-1`,
    "DELETE",
  );
});

it("loads wallet operations through the scoped admin API in the browser", async () => {
  const origin = window.location.origin;
  const expected = {
    overview: [
      {
        userId: "supporter-1",
        displayName: "UAT Supporter Alpha",
        balance: 1250,
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
  const expected = [{ id: "ticket-1", status: "pending" }];
  const fetchMock = vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(jsonResponse(expected) as Response);

  await expect(getAdminTicketOrders(client, access)).resolves.toEqual(expected);
  expectFetchCall(fetchMock, `${origin}/api/admin/tickets`, "GET");
});

it("updates ticket status through the scoped admin API in the browser", async () => {
  const origin = window.location.origin;
  const payload = { ticketId: "ticket-1", status: "valid" };
  const fetchMock = vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(jsonResponse({ success: true }) as Response);

  await expect(
    updateTicketStatus(client, access, payload.ticketId, payload.status),
  ).resolves.toBeUndefined();
  expectFetchCall(
    fetchMock,
    `${origin}/api/admin/tickets/status`,
    "POST",
    JSON.stringify(payload),
  );
});

it("loads supporter registry through the scoped admin API in the browser", async () => {
  const origin = window.location.origin;
  const expected = [{ id: "supporter-1", displayName: "Alpha Fan" }];
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
  const expected = [{ id: "application-1", status: "pending" }];
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

it("reviews membership applications through the scoped admin API in the browser", async () => {
  const origin = window.location.origin;
  const payload = {
    applicationId: "application-1",
    decision: "approved" as const,
    notes: "Approved after payment confirmation.",
  };
  const fetchMock = vi
    .spyOn(globalThis, "fetch")
    .mockResolvedValue(jsonResponse({ success: true }) as Response);

  await expect(
    reviewMembershipApplication(
      client,
      access,
      payload.applicationId,
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
});
