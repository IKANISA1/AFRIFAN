import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  handleAdminApiRoute: vi.fn(),
  rpc: vi.fn(),
  access: {
    hasAccess: true,
    isAuthenticated: true,
    isSuperAdmin: false,
    role: "club_admin",
    clubId: "24",
    userId: "11111111-1111-4111-8111-111111111111",
  },
}));

vi.mock("@/lib/admin-api-handler", () => ({
  AdminApiAuthorizationError: class AdminApiAuthorizationError extends Error {},
  AdminApiValidationError: class AdminApiValidationError extends Error {
    constructor(message: string, readonly code?: string) {
      super(message);
    }
  },
  handleAdminApiRoute: mocks.handleAdminApiRoute,
}));

import { POST } from "./route";

const eventId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const assignmentId = "44444444-4444-4444-8444-444444444444";

function request(body: Record<string, unknown>) {
  return new NextRequest(
    "https://admin.gikundiro.com/api/admin/ticket-verifiers",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    },
  );
}

describe("admin ticket verifier route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.access.role = "club_admin";
    mocks.access.clubId = "24";
    mocks.access.isSuperAdmin = false;
    mocks.handleAdminApiRoute.mockImplementation(
      async (
        _request: NextRequest,
        handler: (client: { rpc: typeof mocks.rpc }, access: typeof mocks.access) => Promise<unknown>,
      ) => handler({ rpc: mocks.rpc }, mocks.access),
    );
  });

  it("forwards a normalized, club-scoped verifier grant to the service RPC", async () => {
    mocks.rpc.mockResolvedValue({
      data: assignmentId,
      error: null,
    });

    await expect(POST(request({
      action: "grant",
      ticketEventId: eventId,
      userId,
      gateCode: "gate_a",
      startsAt: "2026-08-13T14:00:00Z",
      endsAt: "2026-08-13T20:00:00Z",
    }))).resolves.toBe(assignmentId);

    expect(mocks.rpc).toHaveBeenCalledWith(
      "grant_ticket_verifier_assignment",
      {
        p_actor_id: mocks.access.userId,
        p_club_id: 24,
        p_ticket_event_id: eventId,
        p_target_user_id: userId,
        p_gate_code: "GATE_A",
        p_starts_at: "2026-08-13T14:00:00.000Z",
        p_ends_at: "2026-08-13T20:00:00.000Z",
      },
    );
  });

  it("forwards optimistic assignment revocation", async () => {
    mocks.rpc.mockResolvedValue({ data: true, error: null });
    await expect(POST(request({
      action: "revoke",
      assignmentId,
      expectedUpdatedAt: "2026-08-13T12:00:00Z",
    }))).resolves.toEqual({ success: true });
    expect(mocks.rpc).toHaveBeenCalledWith(
      "revoke_ticket_verifier_assignment",
      expect.objectContaining({
        p_actor_id: mocks.access.userId,
        p_club_id: 24,
        p_assignment_id: assignmentId,
        p_expected_updated_at: "2026-08-13T12:00:00.000Z",
      }),
    );
  });

  it("keeps club moderators read-only before calling the RPC", async () => {
    mocks.access.role = "club_moderator";
    await expect(POST(request({
      action: "grant",
      ticketEventId: eventId,
      userId,
      startsAt: "2026-08-13T14:00:00Z",
      endsAt: "2026-08-13T20:00:00Z",
    }))).rejects.toThrow(/club-admin authority/i);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("rejects an invalid shift before calling the RPC", async () => {
    await expect(POST(request({
      action: "grant",
      ticketEventId: eventId,
      userId,
      startsAt: "2026-08-13T20:00:00Z",
      endsAt: "2026-08-13T14:00:00Z",
    }))).rejects.toThrow(/shift end/i);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
