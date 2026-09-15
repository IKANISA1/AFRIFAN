import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
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

import {
  AdminApiAuthorizationError,
  AdminApiValidationError,
  handleAdminApiRoute,
} from "./admin-api-handler";
import { AdminMutationAuthorizationError, AdminMutationConflictError } from "./data/admin/helpers";

describe("handleAdminApiRoute", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

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

  it("returns a non-retryable 403 when the data layer denies a record's club scope", async () => {
    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/content-blocks"),
      async () => { throw new AdminMutationAuthorizationError(); },
    );
    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toMatchObject({
      code: "ADMIN_ACCESS_DENIED", retryable: false, change_confirmed: false,
    });
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
    expect(response.headers.get("cache-control")).toBe("no-store");
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

  it("returns a privacy-safe 504 when an admin mutation is uncertain", async () => {
    vi.useFakeTimers();
    const responsePromise = handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/tickets/status", {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      }),
      async () => new Promise<never>(() => {}),
      { operationTimeoutMs: 25 },
    );

    await vi.advanceTimersByTimeAsync(25);
    const response = await responsePromise;

    expect(response.status).toBe(504);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      code: "ADMIN_OPERATION_TIMEOUT",
      error:
        "The admin operation timed out. Check current data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
  });

  it("bounds the authentication lookup before privileged work begins", async () => {
    vi.useFakeTimers();
    getUser.mockImplementation(() => new Promise<never>(() => {}));
    const handler = vi.fn(async () => ({ success: true }));
    const responsePromise = handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/features"),
      handler,
      { operationTimeoutMs: 25 },
    );

    await vi.advanceTimersByTimeAsync(25);
    const response = await responsePromise;

    expect(response.status).toBe(504);
    expect(handler).not.toHaveBeenCalled();
    await expect(response.json()).resolves.toMatchObject({
      code: "ADMIN_OPERATION_TIMEOUT",
      change_confirmed: false,
    });
  });

  it("returns an uncached 401 when no authenticated admin exists", async () => {
    getUser.mockResolvedValue({
      data: { user: null },
      error: null,
    });
    const handler = vi.fn(async () => ({ success: true }));

    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/features"),
      handler,
    );

    expect(response.status).toBe(401);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(handler).not.toHaveBeenCalled();
    await expect(response.json()).resolves.toEqual({
      code: "ADMIN_AUTHENTICATION_REQUIRED",
      error: "Admin authentication is required.",
    });
  });

  it("returns an uncached 403 for an authenticated out-of-role user", async () => {
    resolveAdminAccessMock.mockResolvedValue({
      hasAccess: false,
      isAuthenticated: true,
      isSuperAdmin: false,
      userId: "user-1",
      role: "fan",
      clubId: null,
      availableClubIds: [],
      canSelectClub: false,
      assignmentCount: 0,
    });
    const handler = vi.fn(async () => ({ success: true }));

    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/features"),
      handler,
    );

    expect(response.status).toBe(403);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(handler).not.toHaveBeenCalled();
    await expect(response.json()).resolves.toEqual({
      code: "ADMIN_ACCESS_DENIED",
      error: "Admin access denied.",
    });
  });

  it("sanitizes unexpected privileged-operation failures", async () => {
    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/features"),
      async () => {
        throw new Error("service_role=secret-value row=user-private-id");
      },
    );
    const payload = await response.json();

    expect(response.status).toBe(500);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(payload).toEqual({
      code: "ADMIN_REQUEST_FAILED",
      error: "Admin request failed.",
      retryable: true,
      change_confirmed: false,
    });
    expect(JSON.stringify(payload)).not.toContain("secret-value");
    expect(JSON.stringify(payload)).not.toContain("user-private-id");
  });

  it("returns an uncached stale-record contract for versioned mutations", async () => {
    const response = await handleAdminApiRoute(
      new NextRequest(
        "https://admin.gikundiro.com/api/admin/content-blocks/save",
        {
          method: "POST",
          headers: {
            origin: "https://admin.gikundiro.com",
          },
        },
      ),
      async () => {
        throw new AdminMutationConflictError();
      },
    );

    expect(response.status).toBe(409);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      code: "STALE_RECORD",
      error:
        "This record changed after it was loaded. Refresh the latest data before retrying.",
      retryable: true,
      change_confirmed: false,
    });
  });

  it("returns an explicit empty state for an empty admin collection", async () => {
    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/features"),
      async () => [],
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      code: "ADMIN_RESOURCE_EMPTY",
      state: "empty",
      data: [],
    });
  });

  it("returns a stable validation response before an empty mutation", async () => {
    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/tickets/status", {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      }),
      async () => {
        throw new AdminApiValidationError(
          "Both ticket id and status are required.",
          "ADMIN_TICKET_STATUS_EMPTY",
        );
      },
    );

    expect(response.status).toBe(400);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      code: "ADMIN_TICKET_STATUS_EMPTY",
      error: "Both ticket id and status are required.",
      retryable: false,
      change_confirmed: false,
    });
  });

  it("returns a stable 403 for an explicitly denied admin operation", async () => {
    const response = await handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/features/update", {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      }),
      async () => {
        throw new AdminApiAuthorizationError(
          "Feature configuration access is required.",
        );
      },
    );

    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      code: "ADMIN_ACCESS_DENIED",
      error: "Feature configuration access is required.",
      retryable: false,
      change_confirmed: false,
    });
  });

  it("does not confirm an admin write while it remains unsettled", async () => {
    let resolveWrite: ((value: { success: true }) => void) | undefined;
    let settled = false;
    const responsePromise = handleAdminApiRoute(
      new NextRequest("https://admin.gikundiro.com/api/admin/tickets/status", {
        method: "POST",
        headers: {
          origin: "https://admin.gikundiro.com",
        },
      }),
      async () =>
        new Promise<{ success: true }>((resolve) => {
          resolveWrite = resolve;
        }),
    ).then((response) => {
      settled = true;
      return response;
    });

    await vi.waitFor(() => {
      expect(resolveWrite).toBeTypeOf("function");
    });
    expect(settled).toBe(false);

    resolveWrite?.({ success: true });
    const response = await responsePromise;
    expect(response.status).toBe(200);
    expect(settled).toBe(true);
  });
});
