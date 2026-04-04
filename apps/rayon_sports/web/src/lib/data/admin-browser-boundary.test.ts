import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  deleteAdminStandingRow,
  getAdminContributionSnapshot,
  getAdminProducts,
  getAdminSmsSnapshot,
  saveAdminFanClub,
  sendAdminNotification,
  saveAdminSquadPlayer,
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
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/shop`,
      "GET",
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

    await expect(
      saveAdminFanClub(client, access, payload),
    ).resolves.toBe("fan-club-1");
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
      aliases: {},
      monthlyTotal: 0,
    };
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(jsonResponse(expected) as Response);

    await expect(
      getAdminContributionSnapshot(client, access),
    ).resolves.toEqual(expected);
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/contributions`,
      "GET",
    );
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

    await expect(getAdminSmsSnapshot(client, access)).resolves.toEqual(expected);
    expectFetchCall(
      fetchMock,
      `${origin}/api/admin/sms`,
      "GET",
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
