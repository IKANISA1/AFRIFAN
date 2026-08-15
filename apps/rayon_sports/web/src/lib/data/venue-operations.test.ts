import type { SupabaseClient } from "@supabase/supabase-js";
import { afterEach, describe, expect, it, vi } from "vitest";
import { getServerSupabase } from "@/lib/supabase/server";
import { resolveVenueAccess, type VenueAccess } from "./venue-access";
import {
  captureVenueData,
  getVenueCampaigns,
  getVenueCheckins,
  getVenueMenu,
  getVenueOrders,
  getVenueOverview,
  getVenueStaff,
} from "./venue-operations";

vi.mock("@/lib/supabase/server", () => ({ getServerSupabase: vi.fn() }));

const access: VenueAccess = {
  userId: "11111111-1111-4111-8111-111111111111",
  clubId: 24,
  venueId: "22222222-2222-4222-8222-222222222222",
  venueName: "Kigali Partner Venue",
  venueCity: "Kigali",
  role: "manager",
  canManageMenu: true,
  canOperateOrders: true,
  canLaunchPromotions: true,
};

type QueryResult = {
  data?: unknown;
  error: { message?: string } | null;
  count?: number | null;
};

type QueryInput = QueryResult | { rejectWith: unknown };

function query(result: QueryInput) {
  const calls: Array<[string, ...unknown[]]> = [];
  const chain = {
    calls,
    select(...args: unknown[]) {
      calls.push(["select", ...args]);
      return chain;
    },
    eq(...args: unknown[]) {
      calls.push(["eq", ...args]);
      return chain;
    },
    in(...args: unknown[]) {
      calls.push(["in", ...args]);
      return chain;
    },
    gte(...args: unknown[]) {
      calls.push(["gte", ...args]);
      return chain;
    },
    order(...args: unknown[]) {
      calls.push(["order", ...args]);
      return chain;
    },
    limit(...args: unknown[]) {
      calls.push(["limit", ...args]);
      return chain;
    },
    maybeSingle() {
      calls.push(["maybeSingle"]);
      return chain;
    },
    then<TResult1 = QueryResult, TResult2 = never>(
      onfulfilled?:
        ((value: QueryResult) => TResult1 | PromiseLike<TResult1>) | null,
      onrejected?:
        ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
    ) {
      const operation =
        "rejectWith" in result
          ? Promise.reject(result.rejectWith)
          : Promise.resolve(result);
      return operation.then(onfulfilled, onrejected);
    },
  };
  return chain;
}

function client(...results: QueryInput[]) {
  const queries = results.map(query);
  const tables: string[] = [];
  const supabase = {
    from(table: string) {
      tables.push(table);
      const next = queries.shift();
      if (!next) throw new Error(`Unexpected query for ${table}`);
      return next;
    },
  } as unknown as SupabaseClient;
  return { supabase, tables };
}

function scopedRow(overrides: Record<string, unknown>) {
  return { club_id: access.clubId, venue_id: access.venueId, ...overrides };
}

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("venue access resolution", () => {
  it("distinguishes configuration, signed-out, and authentication-service failures", async () => {
    vi.mocked(getServerSupabase).mockResolvedValueOnce(null);
    await expect(resolveVenueAccess()).resolves.toEqual({
      status: "not_configured",
    });

    vi.mocked(getServerSupabase).mockResolvedValueOnce({
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({ data: { user: null }, error: null }),
      },
    } as unknown as SupabaseClient);
    await expect(resolveVenueAccess()).resolves.toEqual({
      status: "signed_out",
    });

    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    vi.mocked(getServerSupabase).mockResolvedValueOnce({
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: null },
            error: { message: "unavailable" },
          }),
      },
    } as unknown as SupabaseClient);
    await expect(resolveVenueAccess()).resolves.toMatchObject({
      status: "service_error",
    });
    expect(error).toHaveBeenCalledWith(
      "Venue authentication lookup failed",
      expect.objectContaining({
        correlationId: expect.stringMatching(/^venue-/),
      }),
    );
  });

  it("returns a correlation id for membership service errors", async () => {
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const mock = client({
      data: null,
      error: { message: "database unavailable" },
    });
    Object.assign(mock.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(mock.supabase);
    const result = await resolveVenueAccess();
    expect(result).toMatchObject({ status: "service_error" });
    expect(error).toHaveBeenCalledWith(
      "Venue membership lookup failed",
      expect.objectContaining({
        correlationId: expect.stringMatching(/^venue-/),
      }),
    );
  });

  it("fails closed without an active membership or assigned venue", async () => {
    for (const results of [
      [{ data: [], error: null }],
      [
        {
          data: [{ club_id: 24, venue_id: access.venueId, role: "manager" }],
          error: null,
        },
        { data: null, error: null },
      ],
    ]) {
      const mock = client(...results);
      Object.assign(mock.supabase, {
        auth: {
          getUser: vi
            .fn()
            .mockResolvedValue({
              data: { user: { id: access.userId } },
              error: null,
            }),
        },
      });
      vi.mocked(getServerSupabase).mockResolvedValueOnce(mock.supabase);
      await expect(resolveVenueAccess()).resolves.toEqual({
        status: "forbidden",
      });
    }
  });

  it("surfaces assigned-venue errors and resolves a matching assignment", async () => {
    const membership = {
      club_id: 24,
      venue_id: access.venueId,
      role: "manager",
    };
    const venue = {
      id: access.venueId,
      club_id: 24,
      display_name: access.venueName,
      city: access.venueCity,
    };
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const failed = client(
      { data: [membership], error: null },
      { data: null, error: { message: "venue unavailable" } },
    );
    Object.assign(failed.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(failed.supabase);
    await expect(resolveVenueAccess()).resolves.toMatchObject({
      status: "service_error",
    });
    expect(error).toHaveBeenCalledWith(
      "Assigned venue lookup failed",
      expect.any(Object),
    );

    const ready = client(
      { data: [membership], error: null },
      { data: venue, error: null },
    );
    Object.assign(ready.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(ready.supabase);
    await expect(resolveVenueAccess()).resolves.toMatchObject({
      status: "ready",
      access,
    });
  });

  it("fails closed when authorization dependencies reject or return malformed scope", async () => {
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    vi.mocked(getServerSupabase).mockResolvedValueOnce({
      auth: {
        getUser: vi.fn().mockRejectedValue(new Error("auth transport failed")),
      },
    } as unknown as SupabaseClient);
    await expect(resolveVenueAccess()).resolves.toMatchObject({
      status: "service_error",
    });

    const rejectedMembership = client({
      rejectWith: new Error("membership transport failed"),
    });
    Object.assign(rejectedMembership.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(
      rejectedMembership.supabase,
    );
    await expect(resolveVenueAccess()).resolves.toMatchObject({
      status: "service_error",
    });

    const membership = {
      club_id: 24,
      venue_id: access.venueId,
      role: "manager",
    };
    const rejectedVenue = client(
      { data: [membership], error: null },
      { rejectWith: new Error("venue transport failed") },
    );
    Object.assign(rejectedVenue.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(rejectedVenue.supabase);
    await expect(resolveVenueAccess()).resolves.toMatchObject({
      status: "service_error",
    });

    const malformedMemberships = client({
      data: { unexpected: true },
      error: null,
    });
    Object.assign(malformedMemberships.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(
      malformedMemberships.supabase,
    );
    await expect(resolveVenueAccess()).resolves.toEqual({
      status: "forbidden",
    });

    const malformedVenue = client(
      { data: [membership], error: null },
      {
        data: {
          id: access.venueId,
          club_id: access.clubId,
          display_name: "",
          city: null,
        },
        error: null,
      },
    );
    Object.assign(malformedVenue.supabase, {
      auth: {
        getUser: vi
          .fn()
          .mockResolvedValue({
            data: { user: { id: access.userId } },
            error: null,
          }),
      },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(malformedVenue.supabase);
    await expect(resolveVenueAccess()).resolves.toEqual({
      status: "forbidden",
    });
    expect(error).toHaveBeenCalled();
  });

  it("fails closed when authentication authorization times out", async () => {
    vi.useFakeTimers();
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    vi.mocked(getServerSupabase).mockResolvedValueOnce({
      auth: { getUser: vi.fn(() => new Promise(() => undefined)) },
    } as unknown as SupabaseClient);

    const pending = resolveVenueAccess();
    await vi.advanceTimersByTimeAsync(12_000);
    await expect(pending).resolves.toMatchObject({ status: "service_error" });
  });
});

describe("venue operations", () => {
  it("scopes and returns overview counts", async () => {
    const mock = client(
      { count: 2, error: null },
      { count: 3, error: null },
      { count: 4, error: null },
    );
    await expect(getVenueOverview(mock.supabase, access)).resolves.toEqual({
      activeCampaigns: 2,
      openOrders: 3,
      checkinsToday: 4,
    });
    expect(mock.tables).toEqual([
      "venue_checkin_campaigns",
      "venue_drink_orders",
      "venue_checkins",
    ]);
  });

  it.each([
    [
      "Campaigns query failed",
      [
        { error: { message: "campaign denied" } },
        { error: null },
        { error: null },
      ],
    ],
    [
      "Orders query failed",
      [
        { error: null },
        { error: { message: "order denied" } },
        { error: null },
      ],
    ],
    [
      "Check-ins query failed",
      [
        { error: null },
        { error: null },
        { error: { message: "checkin denied" } },
      ],
    ],
  ] as const)("surfaces %s overview errors", async (label, results) => {
    await expect(
      getVenueOverview(client(...results).supabase, access),
    ).rejects.toThrow(label);
  });

  it("captures success and emits an opaque correlation id on failure", async () => {
    await expect(captureVenueData(async () => 7, "orders")).resolves.toEqual({
      ok: true,
      data: 7,
    });
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const result = await captureVenueData(async () => {
      throw new Error("secret backend detail");
    }, "orders");
    expect(result).toMatchObject({ ok: false });
    expect(result.ok ? "" : result.correlationId).toMatch(/^orders-/);
    expect(error).toHaveBeenCalledWith(
      "Venue workflow data failed",
      expect.objectContaining({ label: "orders" }),
    );
  });

  it("times out stalled venue data operations without exposing details", async () => {
    vi.useFakeTimers();
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const pending = captureVenueData(
      () => new Promise(() => undefined),
      "campaigns",
    );
    await vi.advanceTimersByTimeAsync(12_000);
    await expect(pending).resolves.toMatchObject({ ok: false });
    expect(error).toHaveBeenCalledWith(
      "Venue workflow data failed",
      expect.objectContaining({ label: "campaigns" }),
    );
  });

  it("maps order rows and rejects a cross-venue row", async () => {
    const row = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      status: "ready",
      total_amount: "2500",
      currency_code: "RWF",
      payment_status: "paid",
      age_gate_confirmed: true,
      created_at: "2026-07-18T12:00:00Z",
    });
    await expect(
      getVenueOrders(client({ data: [row], error: null }).supabase, access),
    ).resolves.toEqual([
      expect.objectContaining({
        id: "33333333-3333-4333-8333-333333333333",
        totalAmount: 2500,
        ageGateConfirmed: true,
      }),
    ]);
    await expect(
      getVenueOrders(
        client({ data: [{ ...row, venue_id: "other" }], error: null }).supabase,
        access,
      ),
    ).rejects.toThrow("Venue scope mismatch");
  });

  it("maps menu, check-in, and staff rows", async () => {
    const menu = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      item_name: "Water",
      description: null,
      price_amount: "1000",
      currency_code: "RWF",
      is_active: true,
      is_alcohol: false,
      sort_order: 2,
    });
    const checkin = scopedRow({
      id: "44444444-4444-4444-8444-444444444444",
      status: "approved",
      location_verification_status: "verified",
      fet_awarded: "5",
      checked_in_at: "2026-07-18T12:00:00Z",
      review_reason: null,
    });
    const staff = scopedRow({
      id: "55555555-5555-4555-8555-555555555555",
      user_id: "66666666-6666-4666-8666-666666666666",
      role: "staff",
      granted_at: "2026-07-18T12:00:00Z",
    });
    await expect(
      getVenueMenu(client({ data: [menu], error: null }).supabase, access),
    ).resolves.toEqual([
      expect.objectContaining({
        name: "Water",
        priceAmount: 1000,
        isAlcohol: false,
      }),
    ]);
    await expect(
      getVenueCheckins(
        client({ data: [checkin], error: null }).supabase,
        access,
      ),
    ).resolves.toEqual([
      expect.objectContaining({ locationStatus: "verified", fetAwarded: 5 }),
    ]);
    await expect(
      getVenueStaff(client({ data: [staff], error: null }).supabase, access),
    ).resolves.toEqual([
      expect.objectContaining({ isCurrentUser: false, role: "staff" }),
    ]);
  });

  it("maps launchable campaigns and exhausted campaigns", async () => {
    const active = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      campaign_name: "Matchday",
      status: "approved",
      starts_at: "2026-01-01T00:00:00Z",
      ends_at: "2027-01-01T00:00:00Z",
      fet_award_per_checkin: 5,
      fet_budget: 100,
      awarded_fet: 20,
      require_location: true,
    });
    const exhausted = {
      ...active,
      id: "44444444-4444-4444-8444-444444444444",
      awarded_fet: 100,
    };
    await expect(
      getVenueCampaigns(
        client({ data: [active, exhausted], error: null }).supabase,
        access,
      ),
    ).resolves.toEqual([
      expect.objectContaining({
        name: "Matchday",
        isLaunchable: true,
        requireLocation: true,
      }),
      expect.objectContaining({ isLaunchable: false }),
    ]);
  });

  it("surfaces list errors and rejects malformed collection responses", async () => {
    await expect(
      getVenueOrders(
        client({ data: null, error: { message: "offline" } }).supabase,
        access,
      ),
    ).rejects.toThrow("Orders query failed");
    await expect(
      getVenueMenu(
        client({ data: { unexpected: true }, error: null }).supabase,
        access,
      ),
    ).rejects.toThrow("Menu response is invalid");
  });

  it("rejects malformed, duplicate, and oversized operational records", async () => {
    const order = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      status: "ready",
      total_amount: 2500,
      currency_code: "RWF",
      payment_status: "paid",
      age_gate_confirmed: true,
      created_at: "2026-07-18T12:00:00Z",
    });
    await expect(
      getVenueOrders(
        client({ data: [{ ...order, status: "invented" }], error: null })
          .supabase,
        access,
      ),
    ).rejects.toThrow("Order status is invalid");
    await expect(
      getVenueOrders(
        client({ data: [order, order], error: null }).supabase,
        access,
      ),
    ).rejects.toThrow("Orders contains duplicate records");
    await expect(
      getVenueOrders(
        client({
          data: Array.from({ length: 101 }, (_value, index) => ({
            ...order,
            id: `33333333-3333-4333-8333-${String(index).padStart(12, "0")}`,
          })),
          error: null,
        }).supabase,
        access,
      ),
    ).rejects.toThrow("Orders response is invalid");
  });

  it("rejects every malformed primitive at the venue data boundary", async () => {
    const order = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      status: "ready",
      total_amount: 2500,
      currency_code: "RWF",
      payment_status: "paid",
      age_gate_confirmed: true,
      created_at: "2026-07-18T12:00:00Z",
    });
    const invalidOrders: Array<[Record<string, unknown>, string]> = [
      [{ ...order, id: "not-a-uuid" }, "Order identifier is invalid"],
      [{ ...order, total_amount: -1 }, "Order total is invalid"],
      [{ ...order, currency_code: "12!" }, "Currency is invalid"],
      [{ ...order, age_gate_confirmed: "yes" }, "Age gate is invalid"],
      [
        { ...order, created_at: "not-a-time" },
        "Order creation time is invalid",
      ],
    ];
    for (const [row, message] of invalidOrders) {
      await expect(
        getVenueOrders(client({ data: [row], error: null }).supabase, access),
      ).rejects.toThrow(message);
    }

    const menu = scopedRow({
      id: "44444444-4444-4444-8444-444444444444",
      item_name: "Water",
      description: "",
      price_amount: 1000,
      currency_code: "RWF",
      is_active: true,
      is_alcohol: false,
      sort_order: 0,
    });
    await expect(
      getVenueMenu(
        client({ data: [{ ...menu, item_name: 7 }], error: null }).supabase,
        access,
      ),
    ).rejects.toThrow("Menu item name is invalid");
    await expect(
      getVenueMenu(
        client({ data: [{ ...menu, item_name: " " }], error: null }).supabase,
        access,
      ),
    ).rejects.toThrow("Menu item name is invalid");
  });

  it("rejects invalid campaign lifecycles and active menus above the limit", async () => {
    const campaign = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      campaign_name: "Matchday",
      status: "approved",
      starts_at: "2027-01-01T00:00:00Z",
      ends_at: "2026-01-01T00:00:00Z",
      fet_award_per_checkin: 5,
      fet_budget: 100,
      awarded_fet: 20,
      require_location: true,
    });
    await expect(
      getVenueCampaigns(
        client({ data: [campaign], error: null }).supabase,
        access,
      ),
    ).rejects.toThrow("Campaign lifecycle is invalid");

    const menu = Array.from({ length: 11 }, (_value, index) =>
      scopedRow({
        id: `33333333-3333-4333-8333-${String(index).padStart(12, "0")}`,
        item_name: `Drink ${index + 1}`,
        description: "",
        price_amount: 1000,
        currency_code: "RWF",
        is_active: true,
        is_alcohol: false,
        sort_order: index,
      }),
    );
    await expect(
      getVenueMenu(client({ data: menu, error: null }).supabase, access),
    ).rejects.toThrow("Menu exceeds the active-item limit");
  });

  it("omits staff identifiers and retains only current-user truth", async () => {
    const current = scopedRow({
      id: "33333333-3333-4333-8333-333333333333",
      user_id: access.userId,
      role: "manager",
      granted_at: "2026-07-18T12:00:00Z",
      private_note: "must not cross the DTO boundary",
    });
    const [member] = await getVenueStaff(
      client({ data: [current], error: null }).supabase,
      access,
    );
    expect(member).toEqual({
      id: "33333333-3333-4333-8333-333333333333",
      role: "manager",
      grantedAt: "2026-07-18T12:00:00Z",
      isCurrentUser: true,
    });
    expect(member).not.toHaveProperty("userId");
    expect(member).not.toHaveProperty("private_note");
  });
});
