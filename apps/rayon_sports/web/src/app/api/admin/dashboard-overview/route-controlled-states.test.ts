import { NextRequest } from "next/server";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { httpFixtureClubId, httpFixtureOrigin, registerLocalHttpAssertions } from "../../../../../e2e/fixtures/local-http-route-assertions";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), access: vi.fn(), snapshot: vi.fn(), actions: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ getServerSupabase: vi.fn(async () => ({ auth: { getUser: mocks.getUser } })) }));
vi.mock("@/lib/supabase/admin", () => ({ getAdminSupabase: vi.fn(() => ({ kind: "controlled-admin" })) }));
vi.mock("@/lib/data/admin/access", () => ({ resolveAdminAccess: mocks.access }));
vi.mock("@/lib/data/admin", () => ({ getAdminDashboardSnapshot: mocks.snapshot, getAdminDashboardActions: mocks.actions }));
import { AdminMutationConflictError } from "@/lib/data/admin/helpers";
import { GET } from "./route";
const path = "/api/admin/dashboard-overview";
const empty = { metrics: { activeUsers: 0, pendingVerifications: 0, activeSupportCircles: 0,
  recentTicketSales: 0, totalFans: 0, ticketRevenue: 0 }, activity: [] };
const states = ["empty", "error", "permission_denied", "syncing", "conflict", "security_timeout"] as const;
describe("dashboard actual authenticated response states", () => {
  beforeEach(() => {
    vi.clearAllMocks(); vi.useRealTimers();
    mocks.getUser.mockResolvedValue({ data: { user: { id: "admin-1" } }, error: null });
    mocks.access.mockResolvedValue({ hasAccess: true, isAuthenticated: true, isSuperAdmin: false,
      role: "club_admin", userId: "admin-1", clubId: httpFixtureClubId(), availableClubIds: [httpFixtureClubId()] });
    mocks.snapshot.mockResolvedValue(empty); mocks.actions.mockResolvedValue([]);
  });
  afterEach(() => vi.useRealTimers());
  for (const state of states) it(`${path}: ${state} handler outcome`, async () => {
    let release: ((value: typeof empty) => void) | undefined;
    if (state === "permission_denied") mocks.access.mockResolvedValue({ hasAccess: false, isAuthenticated: true });
    else if (state === "error") mocks.snapshot.mockRejectedValue(Error("private provider detail"));
    else if (state === "conflict") mocks.snapshot.mockRejectedValue(new AdminMutationConflictError("private revision"));
    else if (state === "security_timeout") { vi.useFakeTimers(); mocks.snapshot.mockReturnValue(new Promise(() => {})); }
    else if (state === "syncing") mocks.snapshot.mockReturnValue(new Promise((resolve) => { release = resolve; }));
    let settled = false;
    const responsePromise = GET(new NextRequest(`${httpFixtureOrigin()}${path}`, { headers: { cookie: `africlub_admin_club=${httpFixtureClubId()}` } }))
      .then((response) => { settled = true; return response; });
    if (state === "syncing") {
      for (let i = 0; i < 12; i++) await Promise.resolve();
      expect(mocks.snapshot).toHaveBeenCalledTimes(1); expect(settled).toBe(false); release?.(empty);
    }
    if (state === "security_timeout") await vi.advanceTimersByTimeAsync(12000);
    const response = await responsePromise;
    expect(response.status).toBe({ empty: 200, syncing: 200, error: 500, permission_denied: 403, conflict: 409, security_timeout: 504 }[state]);
    expect(response.headers.get("cache-control")).toBe("no-store");
    const body = await response.json();
    if (state === "empty" || state === "syncing") {
      expect(body).toEqual({ data: { snapshot: empty, quickActions: [] } });
      expect(mocks.snapshot.mock.calls[0][1].clubId).toBe(httpFixtureClubId());
    } else {
      expect(body).not.toHaveProperty("data"); expect(JSON.stringify(body)).not.toContain("private");
      if (state === "permission_denied") expect(mocks.snapshot).not.toHaveBeenCalled();
    }
  });
});
registerLocalHttpAssertions(states.map((state) => ({ name: `${path}: ${state} handler outcome`, route: path, state })));
