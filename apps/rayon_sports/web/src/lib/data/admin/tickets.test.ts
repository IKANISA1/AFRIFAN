import { describe, expect, it } from "vitest";
import type { AdminAccess } from "@/lib/types";
import {
  canAdminTransitionTicketStatus,
  getAdminTicketBulkEligibility,
  getAdminTicketTargetPermission,
  isAdminTicketStatusAction,
} from "./tickets";

const clubAdmin = {
  hasAccess: true,
  isSuperAdmin: false,
  role: "club_admin",
} as AdminAccess;
const moderator = {
  hasAccess: true,
  isSuperAdmin: false,
  role: "club_moderator",
} as AdminAccess;

describe("ticket status safety contract", () => {
  it("accepts only the three supported operator actions", () => {
    expect(isAdminTicketStatusAction("valid")).toBe(true);
    expect(isAdminTicketStatusAction("used")).toBe(true);
    expect(isAdminTicketStatusAction("cancelled")).toBe(true);
    expect(isAdminTicketStatusAction("pending")).toBe(false);
    expect(isAdminTicketStatusAction("refunded")).toBe(false);
    expect(isAdminTicketStatusAction("arbitrary")).toBe(false);
  });

  it("enforces forward-only transitions and terminal states", () => {
    expect(canAdminTransitionTicketStatus(clubAdmin, "pending", "valid").allowed).toBe(true);
    expect(canAdminTransitionTicketStatus(clubAdmin, "valid", "used").allowed).toBe(true);
    expect(canAdminTransitionTicketStatus(clubAdmin, "used", "valid").allowed).toBe(false);
    expect(canAdminTransitionTicketStatus(clubAdmin, "cancelled", "valid").allowed).toBe(false);
  });

  it("allows moderators to validate or consume but not cancel tickets", () => {
    expect(getAdminTicketTargetPermission(moderator, "valid").allowed).toBe(true);
    expect(getAdminTicketTargetPermission(moderator, "used").allowed).toBe(true);
    expect(getAdminTicketTargetPermission(moderator, "cancelled")).toEqual({
      allowed: false,
      reason: "Ticket cancellation requires club-admin authority.",
    });
  });

  it("fails a bulk action when any selected record is stale or ineligible", () => {
    expect(
      getAdminTicketBulkEligibility(
        clubAdmin,
        [{ status: "pending" }, { status: "pending" }],
        "valid",
      ),
    ).toEqual({ allowed: true, blocked: 0, total: 2 });
    expect(
      getAdminTicketBulkEligibility(
        clubAdmin,
        [{ status: "pending" }, { status: "used" }],
        "valid",
      ),
    ).toEqual({ allowed: false, blocked: 1, total: 2 });
    expect(
      getAdminTicketBulkEligibility(
        clubAdmin,
        Array.from({ length: 101 }, () => ({ status: "pending" })),
        "valid",
      ),
    ).toEqual({ allowed: false, blocked: 101, total: 101 });
  });
});
