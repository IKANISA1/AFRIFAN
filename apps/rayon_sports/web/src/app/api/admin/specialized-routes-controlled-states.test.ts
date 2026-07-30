import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const getUser = vi.fn();
  return {
    getUser,
    resolveAdminAccess: vi.fn(),
    rejectInsecureMutation: vi.fn(),
    rejectRateLimitedRequest: vi.fn(),
    enforceFeatureState: vi.fn(),
    getAdminContentBlocks: vi.fn(),
    deleteAdminContentBlock: vi.fn(),
    saveAdminContentBlock: vi.fn(),
    getAdminFeatures: vi.fn(),
    updateAdminFeature: vi.fn(),
    reviewMembershipApplication: vi.fn(),
    bulkUpdateTicketStatus: vi.fn(),
    updateTicketStatus: vi.fn(),
    adminClient: { kind: "admin-client" },
    serverClient: {
      kind: "server-client",
      auth: { getUser },
    },
  };
});

vi.mock("@/lib/supabase/server", () => ({
  getServerSupabase: vi.fn(async () => mocks.serverClient),
}));
vi.mock("@/lib/supabase/admin", () => ({
  getAdminSupabase: vi.fn(() => mocks.adminClient),
}));
vi.mock("@/lib/data/admin/access", () => ({
  resolveAdminAccess: mocks.resolveAdminAccess,
}));
vi.mock("@/lib/security", () => ({
  rejectInsecureMutation: mocks.rejectInsecureMutation,
  rejectRateLimitedRequest: mocks.rejectRateLimitedRequest,
}));
vi.mock("@/lib/server-feature-guard", () => ({
  enforceFeatureState: mocks.enforceFeatureState,
}));
vi.mock("@/lib/data/admin/content-blocks", () => ({
  getAdminContentBlocks: mocks.getAdminContentBlocks,
  deleteAdminContentBlock: mocks.deleteAdminContentBlock,
  saveAdminContentBlock: mocks.saveAdminContentBlock,
}));
vi.mock("@/lib/data/admin/features", () => ({
  AdminFeatureValidationError: class AdminFeatureValidationError extends Error {},
  getAdminFeatures: mocks.getAdminFeatures,
  normalizeAdminFeatureUpdate: (value: unknown) => value,
  updateAdminFeature: mocks.updateAdminFeature,
}));
vi.mock("@/lib/data/admin/membership-ops", () => ({
  reviewMembershipApplication: mocks.reviewMembershipApplication,
}));
vi.mock("@/lib/data/admin/tickets", () => ({
  bulkUpdateTicketStatus: mocks.bulkUpdateTicketStatus,
  updateTicketStatus: mocks.updateTicketStatus,
  isAdminTicketStatusAction: (status: string) => status === "checked_in",
}));

import { AdminMutationConflictError } from "@/lib/data/admin/helpers";
import { GET as getContentBlocks } from "./content-blocks/route";
import { POST as deleteContentBlock } from "./content-blocks/delete/route";
import { POST as saveContentBlock } from "./content-blocks/save/route";
import { GET as getFeatures } from "./features/route";
import { POST as updateFeature } from "./features/update/route";
import { POST as reviewMembership } from "./membership-applications/review/route";
import { POST as updateTicketBulk } from "./tickets/bulk-status/route";
import { POST as updateTicket } from "./tickets/status/route";

function request(path: string, body?: unknown) {
  return new NextRequest(`https://admin.gikundiro.com${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers:
      body === undefined
        ? undefined
        : {
            origin: "https://admin.gikundiro.com",
            "content-type": "application/json",
          },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

describe("specialized admin route controlled states", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getUser.mockResolvedValue({
      data: { user: { id: "admin-1" } },
      error: null,
    });
    mocks.resolveAdminAccess.mockResolvedValue({
      hasAccess: true,
      isAuthenticated: true,
      isSuperAdmin: false,
      userId: "admin-1",
      role: "club_admin",
      clubId: "24",
      availableClubIds: ["24"],
      canSelectClub: false,
      assignmentCount: 1,
    });
    mocks.rejectInsecureMutation.mockReturnValue(null);
    mocks.rejectRateLimitedRequest.mockResolvedValue(null);
    mocks.enforceFeatureState.mockResolvedValue({ allowed: true });
  });

  it.each([
    {
      name: "content blocks",
      invoke: () => getContentBlocks(request("/api/admin/content-blocks")),
      operation: mocks.getAdminContentBlocks,
    },
    {
      name: "features",
      invoke: () => getFeatures(request("/api/admin/features")),
      operation: mocks.getAdminFeatures,
    },
  ])(
    "returns an explicit empty state for $name",
    async ({ invoke, operation }) => {
      operation.mockResolvedValueOnce([]);

      const response = await invoke();

      expect(response.status).toBe(200);
      expect(response.headers.get("cache-control")).toBe("no-store");
      await expect(response.json()).resolves.toEqual({
        code: "ADMIN_RESOURCE_EMPTY",
        state: "empty",
        data: [],
      });
    },
  );

  it.each([
    {
      name: "content block deletion",
      code: "ADMIN_CONTENT_BLOCK_EMPTY",
      invoke: () =>
        deleteContentBlock(request("/api/admin/content-blocks/delete", {})),
      operation: mocks.deleteAdminContentBlock,
    },
    {
      name: "content block save",
      code: "ADMIN_CONTENT_BLOCK_EMPTY",
      invoke: () =>
        saveContentBlock(request("/api/admin/content-blocks/save", {})),
      operation: mocks.saveAdminContentBlock,
    },
    {
      name: "feature update",
      code: "ADMIN_FEATURE_EMPTY",
      invoke: () => updateFeature(request("/api/admin/features/update", {})),
      operation: mocks.updateAdminFeature,
    },
    {
      name: "membership review",
      code: "ADMIN_MEMBERSHIP_REVIEW_EMPTY",
      invoke: () =>
        reviewMembership(
          request("/api/admin/membership-applications/review", {}),
        ),
      operation: mocks.reviewMembershipApplication,
    },
    {
      name: "bulk ticket status",
      code: "ADMIN_TICKET_BULK_EMPTY",
      invoke: () =>
        updateTicketBulk(request("/api/admin/tickets/bulk-status", {})),
      operation: mocks.bulkUpdateTicketStatus,
    },
    {
      name: "ticket status",
      code: "ADMIN_TICKET_STATUS_EMPTY",
      invoke: () => updateTicket(request("/api/admin/tickets/status", {})),
      operation: mocks.updateTicketStatus,
    },
  ])(
    "rejects empty $name before mutation",
    async ({ code, invoke, operation }) => {
      const response = await invoke();

      expect(response.status).toBe(400);
      expect(response.headers.get("cache-control")).toBe("no-store");
      await expect(response.json()).resolves.toMatchObject({
        code,
        retryable: false,
        change_confirmed: false,
      });
      expect(operation).not.toHaveBeenCalled();
    },
  );

  it.each([
    {
      name: "content blocks",
      invoke: () => getContentBlocks(request("/api/admin/content-blocks")),
      operation: mocks.getAdminContentBlocks,
    },
    {
      name: "features",
      invoke: () => getFeatures(request("/api/admin/features")),
      operation: mocks.getAdminFeatures,
    },
    {
      name: "bulk ticket status",
      invoke: () =>
        updateTicketBulk(
          request("/api/admin/tickets/bulk-status", {
            ticketIds: ["ticket-1"],
            status: "checked_in",
          }),
        ),
      operation: mocks.bulkUpdateTicketStatus,
    },
    {
      name: "ticket status",
      invoke: () =>
        updateTicket(
          request("/api/admin/tickets/status", {
            ticketId: "ticket-1",
            status: "checked_in",
          }),
        ),
      operation: mocks.updateTicketStatus,
    },
  ])(
    "returns a controlled conflict for $name",
    async ({ invoke, operation }) => {
      operation.mockRejectedValueOnce(
        new AdminMutationConflictError("raw record version"),
      );

      const response = await invoke();
      const body = await response.json();

      expect(response.status).toBe(409);
      expect(body).toEqual({
        code: "STALE_RECORD",
        error:
          "This record changed after it was loaded. Refresh the latest data before retrying.",
        retryable: true,
        change_confirmed: false,
      });
      expect(JSON.stringify(body)).not.toContain("raw record version");
    },
  );

  it.each([
    {
      name: "content blocks",
      invoke: () => getContentBlocks(request("/api/admin/content-blocks")),
      operation: mocks.getAdminContentBlocks,
      resolved: [],
    },
    {
      name: "content block deletion",
      invoke: () =>
        deleteContentBlock(
          request("/api/admin/content-blocks/delete", {
            id: "block-1",
            expectedUpdatedAt: "2026-07-29T08:00:00Z",
          }),
        ),
      operation: mocks.deleteAdminContentBlock,
      resolved: undefined,
    },
    {
      name: "content block save",
      invoke: () =>
        saveContentBlock(
          request("/api/admin/content-blocks/save", { input: {} }),
        ),
      operation: mocks.saveAdminContentBlock,
      resolved: undefined,
    },
    {
      name: "features",
      invoke: () => getFeatures(request("/api/admin/features")),
      operation: mocks.getAdminFeatures,
      resolved: [],
    },
    {
      name: "feature update",
      invoke: () =>
        updateFeature(
          request("/api/admin/features/update", {
            id: "feature-1",
            expectedUpdatedAt: "2026-07-29T08:00:00Z",
            updates: {},
          }),
        ),
      operation: mocks.updateAdminFeature,
      resolved: undefined,
    },
    {
      name: "membership review",
      invoke: () =>
        reviewMembership(
          request("/api/admin/membership-applications/review", {
            applicationId: "application-1",
            expectedUpdatedAt: "2026-07-29T08:00:00Z",
            decision: "approved",
          }),
        ),
      operation: mocks.reviewMembershipApplication,
      resolved: undefined,
    },
    {
      name: "bulk ticket status",
      invoke: () =>
        updateTicketBulk(
          request("/api/admin/tickets/bulk-status", {
            ticketIds: ["ticket-1"],
            status: "checked_in",
          }),
        ),
      operation: mocks.bulkUpdateTicketStatus,
      resolved: undefined,
    },
    {
      name: "ticket status",
      invoke: () =>
        updateTicket(
          request("/api/admin/tickets/status", {
            ticketId: "ticket-1",
            status: "checked_in",
          }),
        ),
      operation: mocks.updateTicketStatus,
      resolved: undefined,
    },
  ])(
    "does not confirm $name while its operation is syncing",
    async ({ invoke, operation, resolved }) => {
      let release: ((value: unknown) => void) | undefined;
      operation.mockReturnValueOnce(
        new Promise((resolve) => {
          release = resolve;
        }),
      );
      let settled = false;
      const responsePromise = invoke().then((response) => {
        settled = true;
        return response;
      });

      await Promise.resolve();
      await Promise.resolve();
      expect(settled).toBe(false);

      release?.(resolved);
      const response = await responsePromise;
      expect(response.status).toBe(200);
      expect(settled).toBe(true);
    },
  );
});
