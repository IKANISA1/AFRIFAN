import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  handleAdminApiRoute: vi.fn(),
  normalizeAdminFeatureUpdate: vi.fn(),
  updateAdminFeature: vi.fn(),
  adminClient: { kind: "admin" },
  access: {
    hasAccess: true,
    isAuthenticated: true,
    isSuperAdmin: false,
    role: "club_admin",
    clubId: "24",
  },
}));

vi.mock("@/lib/admin-api-handler", () => ({
  AdminApiAuthorizationError: class AdminApiAuthorizationError extends Error {
    code = "ADMIN_ACCESS_DENIED";
  },
  AdminApiValidationError: class AdminApiValidationError extends Error {
    code: string;

    constructor(message: string, code: string) {
      super(message);
      this.code = code;
    }
  },
  handleAdminApiRoute: mocks.handleAdminApiRoute,
}));

vi.mock("@/lib/data/admin/features", () => ({
  AdminFeatureValidationError: class AdminFeatureValidationError extends Error {},
  normalizeAdminFeatureUpdate: mocks.normalizeAdminFeatureUpdate,
  updateAdminFeature: mocks.updateAdminFeature,
}));

import { POST } from "./route";

function request(body: unknown) {
  return new NextRequest(
    "https://admin.gikundiro.com/api/admin/features/update",
    {
      method: "POST",
      body: JSON.stringify(body),
      headers: {
        "content-type": "application/json",
        origin: "https://admin.gikundiro.com",
      },
    },
  );
}

describe("admin feature update route", () => {
  afterEach(() => {
    vi.clearAllMocks();
    mocks.access.role = "club_admin";
    mocks.access.clubId = "24";
    mocks.access.isSuperAdmin = false;
  });

  it("validates and forwards one scoped optimistic update", async () => {
    const normalized = { isEnabled: false };
    mocks.normalizeAdminFeatureUpdate.mockReturnValue(normalized);
    mocks.updateAdminFeature.mockResolvedValue(undefined);
    mocks.handleAdminApiRoute.mockImplementation(
      async (
        _request: NextRequest,
        handler: (
          client: typeof mocks.adminClient,
          access: typeof mocks.access,
        ) => Promise<unknown>,
      ) => handler(mocks.adminClient, mocks.access),
    );

    await expect(
      POST(
        request({
          id: "feature-1",
          expectedUpdatedAt: "2026-07-30T09:00:00.000Z",
          updates: normalized,
        }),
      ),
    ).resolves.toEqual({ success: true });
    expect(mocks.normalizeAdminFeatureUpdate).toHaveBeenCalledWith(normalized);
    expect(mocks.updateAdminFeature).toHaveBeenCalledWith(
      mocks.adminClient,
      mocks.access,
      "feature-1",
      "2026-07-30T09:00:00.000Z",
      normalized,
    );
  });

  it("keeps club moderators read-only before mutation validation", async () => {
    mocks.access.role = "club_moderator";
    mocks.handleAdminApiRoute.mockImplementation(
      async (
        _request: NextRequest,
        handler: (
          client: typeof mocks.adminClient,
          access: typeof mocks.access,
        ) => Promise<unknown>,
      ) => handler(mocks.adminClient, mocks.access),
    );

    await expect(
      POST(
        request({
          id: "feature-1",
          expectedUpdatedAt: "2026-07-30T09:00:00.000Z",
          updates: { isEnabled: false },
        }),
      ),
    ).rejects.toMatchObject({
      name: "Error",
      message: "Feature configuration access is required.",
    });
    expect(mocks.normalizeAdminFeatureUpdate).not.toHaveBeenCalled();
    expect(mocks.updateAdminFeature).not.toHaveBeenCalled();
  });

  it("rejects an empty mutation before calling the data layer", async () => {
    mocks.handleAdminApiRoute.mockImplementation(
      async (
        _request: NextRequest,
        handler: (
          client: typeof mocks.adminClient,
          access: typeof mocks.access,
        ) => Promise<unknown>,
      ) => handler(mocks.adminClient, mocks.access),
    );

    await expect(POST(request({}))).rejects.toMatchObject({
      name: "Error",
      message: "A feature id, loaded version, and updates are required.",
    });
    expect(mocks.updateAdminFeature).not.toHaveBeenCalled();
  });
});
