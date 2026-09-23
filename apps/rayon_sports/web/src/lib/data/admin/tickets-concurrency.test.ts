// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { AdminMutationConflictError } from "./helpers";
import {
  bulkUpdateTicketStatus,
  updateTicketStatus,
} from "./tickets";

const access = {
  hasAccess: true,
  isAuthenticated: true,
  isSuperAdmin: false,
  userId: "00000000-0000-4000-8000-000000000024",
  role: "club_admin",
  clubId: "24",
  availableClubIds: ["24"],
  canSelectClub: false,
  assignmentCount: 1,
} as AdminAccess;

describe("ticket optimistic-concurrency RPC contract", () => {
  it("sends the reviewed version with a single status mutation", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: 1, error: null });

    await updateTicketStatus(
      { rpc } as never,
      access,
      { id: "ticket-1", updatedAt: "2026-08-09T08:17:07Z" },
      "valid",
    );

    expect(rpc).toHaveBeenCalledWith(
      "admin_bulk_update_ticket_status_if_unchanged",
      {
        p_ticket_ids: ["ticket-1"],
        p_expected_updated_ats: ["2026-08-09T08:17:07.000Z"],
        p_status: "valid",
        p_club_id: 24,
        p_actor_id: "00000000-0000-4000-8000-000000000024",
        p_role: "club_admin",
        p_is_super_admin: false,
      },
    );
  });

  it("keeps ids and loaded versions aligned in a bulk status mutation", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: 2, error: null });

    await bulkUpdateTicketStatus(
      { rpc } as never,
      access,
      [
        { id: "ticket-1", updatedAt: "2026-08-09T08:17:07Z" },
        { id: "ticket-2", updatedAt: "2026-08-09T08:18:07Z" },
      ],
      "cancelled",
    );

    expect(rpc).toHaveBeenCalledWith(
      "admin_bulk_update_ticket_status_if_unchanged",
      expect.objectContaining({
        p_ticket_ids: ["ticket-1", "ticket-2"],
        p_expected_updated_ats: [
          "2026-08-09T08:17:07.000Z",
          "2026-08-09T08:18:07.000Z",
        ],
      }),
    );
  });

  it("maps an atomic stale-version rejection to the shared conflict", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "Ticket changed after it was loaded." },
    });

    await expect(
      updateTicketStatus(
        { rpc } as never,
        access,
        { id: "ticket-1", updatedAt: "2026-08-09T08:17:07Z" },
        "valid",
      ),
    ).rejects.toBeInstanceOf(AdminMutationConflictError);
  });

  it("rejects a mutation without a loaded version before calling the RPC", async () => {
    const rpc = vi.fn();

    await expect(
      updateTicketStatus(
        { rpc } as never,
        access,
        { id: "ticket-1", updatedAt: "" },
        "valid",
      ),
    ).rejects.toBeInstanceOf(AdminMutationConflictError);
    expect(rpc).not.toHaveBeenCalled();
  });
});
