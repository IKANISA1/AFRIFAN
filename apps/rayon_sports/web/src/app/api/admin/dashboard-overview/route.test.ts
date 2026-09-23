import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  handleAdminApiRoute: vi.fn(),
  getAdminDashboardSnapshot: vi.fn(),
  getAdminDashboardActions: vi.fn(),
  adminClient: { kind: "admin" },
  access: {
    hasAccess: true,
    isAuthenticated: true,
    isSuperAdmin: false,
    role: "club_admin",
    clubId: "24",
  },
  serverClient: { kind: "server" },
}));

vi.mock("@/lib/admin-api-handler", () => ({
  handleAdminApiRoute: mocks.handleAdminApiRoute,
}));

vi.mock("@/lib/data/admin", () => ({
  getAdminDashboardSnapshot: mocks.getAdminDashboardSnapshot,
  getAdminDashboardActions: mocks.getAdminDashboardActions,
}));

import { GET } from "./route";

describe("admin dashboard overview route", () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it("uses the shared authenticated admin boundary and settles one snapshot", async () => {
    const snapshot = {
      metrics: {
        activeUsers: 12,
        pendingVerifications: 2,
        activeSupportCircles: 3,
        recentTicketSales: 8,
        totalFans: 12,
        ticketRevenue: 42_000,
      },
      activity: [],
    };
    const quickActions = [
      {
        id: "members",
        title: "Review members",
        route: "/admin/membership",
      },
    ];
    mocks.getAdminDashboardSnapshot.mockResolvedValue(snapshot);
    mocks.getAdminDashboardActions.mockResolvedValue(quickActions);
    mocks.handleAdminApiRoute.mockImplementation(
      async (
        _request: NextRequest,
        handler: (
          client: typeof mocks.adminClient,
          access: typeof mocks.access,
          server: typeof mocks.serverClient,
        ) => Promise<unknown>,
      ) => {
        const data = await handler(
          mocks.adminClient,
          mocks.access,
          mocks.serverClient,
        );
        return Response.json(
          { data },
          { headers: { "Cache-Control": "no-store" } },
        );
      },
    );

    const request = new NextRequest(
      "https://admin.gikundiro.com/api/admin/dashboard-overview",
    );
    const response = await GET(request);

    expect(mocks.handleAdminApiRoute).toHaveBeenCalledWith(
      request,
      expect.any(Function),
    );
    expect(mocks.getAdminDashboardSnapshot).toHaveBeenCalledWith(
      mocks.adminClient,
      mocks.access,
    );
    expect(mocks.getAdminDashboardActions).toHaveBeenCalledWith(
      mocks.adminClient,
      mocks.access,
    );
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      data: { snapshot, quickActions },
    });
  });

  it("does not convert a partial read into a confirmed dashboard", async () => {
    mocks.getAdminDashboardSnapshot.mockRejectedValue(
      new Error("database.internal secret=private"),
    );
    mocks.getAdminDashboardActions.mockResolvedValue([]);
    mocks.handleAdminApiRoute.mockImplementation(
      async (
        _request: NextRequest,
        handler: (
          client: typeof mocks.adminClient,
          access: typeof mocks.access,
          server: typeof mocks.serverClient,
        ) => Promise<unknown>,
      ) => {
        try {
          await handler(
            mocks.adminClient,
            mocks.access,
            mocks.serverClient,
          );
          return Response.json({ data: {} });
        } catch {
          return Response.json(
            {
              code: "ADMIN_REQUEST_FAILED",
              error: "Admin request failed.",
              retryable: true,
              change_confirmed: false,
            },
            { status: 500, headers: { "Cache-Control": "no-store" } },
          );
        }
      },
    );

    const response = await GET(
      new NextRequest(
        "https://admin.gikundiro.com/api/admin/dashboard-overview",
      ),
    );
    const payload = await response.json();

    expect(response.status).toBe(500);
    expect(payload).not.toHaveProperty("data");
    expect(JSON.stringify(payload)).not.toContain("database.internal");
    expect(JSON.stringify(payload)).not.toContain("private");
  });
});
