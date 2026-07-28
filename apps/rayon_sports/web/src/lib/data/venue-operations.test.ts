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
  getVenueTvCode,
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

function query(result: QueryResult) {
  const calls: Array<[string, ...unknown[]]> = [];
  const chain = {
    calls,
    select(...args: unknown[]) { calls.push(["select", ...args]); return chain; },
    eq(...args: unknown[]) { calls.push(["eq", ...args]); return chain; },
    in(...args: unknown[]) { calls.push(["in", ...args]); return chain; },
    gte(...args: unknown[]) { calls.push(["gte", ...args]); return chain; },
    order(...args: unknown[]) { calls.push(["order", ...args]); return chain; },
    limit(...args: unknown[]) { calls.push(["limit", ...args]); return chain; },
    maybeSingle() { calls.push(["maybeSingle"]); return chain; },
    then<TResult1 = QueryResult, TResult2 = never>(
      onfulfilled?: ((value: QueryResult) => TResult1 | PromiseLike<TResult1>) | null,
      onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
    ) {
      return Promise.resolve(result).then(onfulfilled, onrejected);
    },
  };
  return chain;
}

function client(...results: QueryResult[]) {
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

afterEach(() => vi.restoreAllMocks());

describe("venue access resolution", () => {
  it("distinguishes configuration and authentication failures", async () => {
    vi.mocked(getServerSupabase).mockResolvedValueOnce(null);
    await expect(resolveVenueAccess()).resolves.toEqual({ status: "not_configured" });

    vi.mocked(getServerSupabase).mockResolvedValueOnce({
      auth: { getUser: vi.fn().mockResolvedValue({ data: { user: null }, error: { message: "expired" } }) },
    } as unknown as SupabaseClient);
    await expect(resolveVenueAccess()).resolves.toEqual({ status: "signed_out" });
  });

  it("returns a correlation id for membership service errors", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const mock = client({ data: null, error: { message: "database unavailable" } });
    Object.assign(mock.supabase, {
      auth: { getUser: vi.fn().mockResolvedValue({ data: { user: { id: access.userId } }, error: null }) },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(mock.supabase);
    const result = await resolveVenueAccess();
    expect(result).toMatchObject({ status: "service_error" });
    expect(error).toHaveBeenCalledWith("Venue membership lookup failed", expect.objectContaining({ correlationId: expect.stringMatching(/^venue-/) }));
  });

  it("fails closed without an active membership or assigned venue", async () => {
    for (const results of [
      [{ data: [], error: null }],
      [{ data: [{ club_id: 24, venue_id: access.venueId, role: "manager" }], error: null }, { data: null, error: null }],
    ]) {
      const mock = client(...results);
      Object.assign(mock.supabase, {
        auth: { getUser: vi.fn().mockResolvedValue({ data: { user: { id: access.userId } }, error: null }) },
      });
      vi.mocked(getServerSupabase).mockResolvedValueOnce(mock.supabase);
      await expect(resolveVenueAccess()).resolves.toEqual({ status: "forbidden" });
    }
  });

  it("surfaces assigned-venue errors and resolves a matching assignment", async () => {
    const membership = { club_id: 24, venue_id: access.venueId, role: "manager" };
    const venue = { id: access.venueId, club_id: 24, display_name: access.venueName, city: access.venueCity };
    const error = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const failed = client(
      { data: [membership], error: null },
      { data: null, error: { message: "venue unavailable" } },
    );
    Object.assign(failed.supabase, {
      auth: { getUser: vi.fn().mockResolvedValue({ data: { user: { id: access.userId } }, error: null }) },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(failed.supabase);
    await expect(resolveVenueAccess()).resolves.toMatchObject({ status: "service_error" });
    expect(error).toHaveBeenCalledWith("Assigned venue lookup failed", expect.any(Object));

    const ready = client(
      { data: [membership], error: null },
      { data: venue, error: null },
    );
    Object.assign(ready.supabase, {
      auth: { getUser: vi.fn().mockResolvedValue({ data: { user: { id: access.userId } }, error: null }) },
    });
    vi.mocked(getServerSupabase).mockResolvedValueOnce(ready.supabase);
    await expect(resolveVenueAccess()).resolves.toMatchObject({ status: "ready", access });
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
    ["Campaigns", [{ error: { message: "campaign denied" } }, { error: null }, { error: null }]],
    ["Orders", [{ error: null }, { error: { message: "order denied" } }, { error: null }]],
    ["Check-ins", [{ error: null }, { error: null }, { error: { message: "checkin denied" } }]],
  ] as const)("surfaces %s overview errors", async (label, results) => {
    await expect(getVenueOverview(client(...results).supabase, access)).rejects.toThrow(label);
  });

  it("captures success and emits an opaque correlation id on failure", async () => {
    await expect(captureVenueData(async () => 7, "orders")).resolves.toEqual({ ok: true, data: 7 });
    const error = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const result = await captureVenueData(async () => { throw new Error("secret backend detail"); }, "orders");
    expect(result).toMatchObject({ ok: false });
    expect(result.ok ? "" : result.correlationId).toMatch(/^orders-/);
    expect(error).toHaveBeenCalledWith("Venue workflow data failed", expect.objectContaining({ label: "orders" }));
  });

  it("maps order rows and rejects a cross-venue row", async () => {
    const row = scopedRow({ id: "order-1", status: "ready", total_amount: "2500", currency_code: "RWF", payment_status: "paid", age_gate_confirmed: true, created_at: "2026-07-18T12:00:00Z" });
    await expect(getVenueOrders(client({ data: [row], error: null }).supabase, access)).resolves.toEqual([
      expect.objectContaining({ id: "order-1", totalAmount: 2500, ageGateConfirmed: true }),
    ]);
    await expect(getVenueOrders(client({ data: [{ ...row, venue_id: "other" }], error: null }).supabase, access)).rejects.toThrow("Venue scope mismatch");
  });

  it("maps menu, check-in, and staff rows", async () => {
    const menu = scopedRow({ id: "drink-1", item_name: "Water", description: null, price_amount: "1000", currency_code: "RWF", is_active: true, is_alcohol: false, sort_order: 2 });
    const checkin = scopedRow({ id: "checkin-1", status: "approved", location_verification_status: "verified", fet_awarded: "5", checked_in_at: "2026-07-18T12:00:00Z", review_reason: null });
    const staff = scopedRow({ id: "staff-1", user_id: "user-2", role: "staff", granted_at: "2026-07-18T12:00:00Z" });
    await expect(getVenueMenu(client({ data: [menu], error: null }).supabase, access)).resolves.toEqual([expect.objectContaining({ name: "Water", priceAmount: 1000, isAlcohol: false })]);
    await expect(getVenueCheckins(client({ data: [checkin], error: null }).supabase, access)).resolves.toEqual([expect.objectContaining({ locationStatus: "verified", fetAwarded: 5 })]);
    await expect(getVenueStaff(client({ data: [staff], error: null }).supabase, access)).resolves.toEqual([expect.objectContaining({ userId: "user-2", role: "staff" })]);
  });

  it("maps launchable campaigns and exhausted campaigns", async () => {
    const active = scopedRow({ id: "campaign-1", campaign_name: "Matchday", status: "approved", starts_at: "2026-01-01T00:00:00Z", ends_at: "2027-01-01T00:00:00Z", fet_award_per_checkin: 5, fet_budget: 100, awarded_fet: 20, require_location: true });
    const exhausted = { ...active, id: "campaign-2", awarded_fet: 100 };
    await expect(getVenueCampaigns(client({ data: [active, exhausted], error: null }).supabase, access)).resolves.toEqual([
      expect.objectContaining({ name: "Matchday", isLaunchable: true, requireLocation: true }),
      expect.objectContaining({ isLaunchable: false }),
    ]);
  });

  it("returns no TV code, maps a code, and surfaces query errors", async () => {
    await expect(getVenueTvCode(client({ data: null, error: null }).supabase, access)).resolves.toBeNull();
    const row = scopedRow({ status: "active", expires_at: "2026-07-18T13:00:00Z", rotates_at: "2026-07-18T12:05:00Z", venue_checkin_campaigns: { campaign_name: "Matchday" } });
    await expect(getVenueTvCode(client({ data: row, error: null }).supabase, access)).resolves.toEqual(expect.objectContaining({ campaignName: "Matchday" }));
    await expect(getVenueTvCode(client({ error: { message: "denied" } }).supabase, access)).rejects.toThrow("TV code: denied");
  });

  it("surfaces list errors and treats a non-array response as empty", async () => {
    await expect(getVenueOrders(client({ data: null, error: { message: "offline" } }).supabase, access)).rejects.toThrow("Orders: offline");
    await expect(getVenueMenu(client({ data: { unexpected: true }, error: null }).supabase, access)).resolves.toEqual([]);
  });
});
