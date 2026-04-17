import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const {
  getUser,
  resolveAdminAccessMock,
  enforceFeatureStateMock,
  rejectInsecureMutationMock,
  rejectRateLimitedRequestMock,
  adminClient,
  serverClient,
} = vi.hoisted(() => {
  const getUser = vi.fn();
  return {
    getUser,
    resolveAdminAccessMock: vi.fn(),
    enforceFeatureStateMock: vi.fn(),
    rejectInsecureMutationMock: vi.fn(),
    rejectRateLimitedRequestMock: vi.fn(),
    adminClient: { kind: "admin" },
    serverClient: {
      auth: {
        getUser,
      },
    },
  };
});

vi.mock("./supabase/server", () => ({
  getServerSupabase: vi.fn(async () => serverClient),
}));

vi.mock("./supabase/admin", () => ({
  getAdminSupabase: vi.fn(() => adminClient),
}));

vi.mock("./data/admin/access", () => ({
  resolveAdminAccess: resolveAdminAccessMock,
}));

vi.mock("./server-feature-guard", () => ({
  enforceFeatureState: enforceFeatureStateMock,
}));

vi.mock("./security", () => ({
  rejectInsecureMutation: rejectInsecureMutationMock,
  rejectRateLimitedRequest: rejectRateLimitedRequestMock,
}));

import { handleAdminApiRoute } from "./admin-api-handler";

describe("handleAdminApiRoute", () => {
  beforeEach(() => {
    getUser.mockReset();
    resolveAdminAccessMock.mockReset();
    enforceFeatureStateMock.mockReset();
    rejectInsecureMutationMock.mockReset();
    rejectRateLimitedRequestMock.mockReset();

    getUser.mockResolvedValue({
      data: {
        user: { id: "user-1" },
      },
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
  });

  it("returns a 403 when the feature guard blocks the action", async () => {
    enforceFeatureStateMock.mockResolvedValue({
      allowed: false,
      error: "This feature is currently disabled.",
    });

    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/tickets/status", {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      }),
      async () => ({ success: true }),
      {
        featureGuard: {
          featureKey: "ticketing",
          mode: "action",
        },
      },
    );

    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      code: "FEATURE_DISABLED",
      error: "This feature is currently disabled.",
    });
  });

  it("passes scoped admin context into the feature guard and handler", async () => {
    enforceFeatureStateMock.mockResolvedValue({ allowed: true });
    const handler = vi.fn(async (...args: unknown[]) => {
      expect(args[0]).toBe(adminClient);
      expect(args[1]).toMatchObject({
        clubId: "24",
        role: "club_admin",
      });
      expect(args[2]).toBe(serverClient);
      return { success: true };
    });

    const response = await handleAdminApiRoute(
      new NextRequest(
        "https://admin.gikundiro.com/api/admin/membership-applications/review?club=24",
        {
          method: "POST",
          headers: {
            origin: "https://admin.gikundiro.com",
          },
        },
      ),
      handler,
      {
        featureGuard: {
          featureKey: "membership",
        },
      },
    );

    expect(enforceFeatureStateMock).toHaveBeenCalledWith(
      "membership",
      "web",
      "action",
      {
        clubId: "24",
        isAuthenticated: true,
        roles: ["club_admin"],
      },
    );
    expect(handler).toHaveBeenCalledTimes(1);
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      data: { success: true },
    });
  });
});
