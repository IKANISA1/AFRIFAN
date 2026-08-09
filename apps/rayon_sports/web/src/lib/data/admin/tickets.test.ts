import { describe, expect, it } from "vitest";
import type { AdminAccess } from "@/lib/types";
import {
  MAX_ADMIN_TICKET_ORDERS,
  canAdminTransitionTicketStatus,
  getAdminTicketBulkEligibility,
  getAdminTicketTargetPermission,
  isAdminTicketStatusAction,
  normalizeAdminTicketOrders,
  normalizeAdminTicketVersions,
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
  const validOrder = {
    id: "ticket-1",
    matchId: "match-1",
    userId: "user-1",
    seatType: "Standard",
    amountPaid: 15_000,
    status: "pending",
    qrCode: "must-not-cross-the-boundary",
    purchasedAt: "2026-07-30T09:00:00.000Z",
    updatedAt: "2026-07-30T09:05:00.000Z",
    userName: "Verified Supporter",
    userPhone: "+250700000000",
    matchTitle: "Rayon Sports vs APR FC",
    momoReference: "momo-1",
  };

  it("accepts strict ticket DTOs while removing unused QR payloads", () => {
    expect(normalizeAdminTicketOrders([validOrder])).toEqual([
      { ...validOrder, qrCode: null },
    ]);
  });

  it.each([
    ["duplicate ids", [validOrder, validOrder]],
    ["invalid status", [{ ...validOrder, status: "arbitrary" }]],
    ["invalid timestamp", [{ ...validOrder, purchasedAt: "not-a-time" }]],
    ["missing loaded version", [{ ...validOrder, updatedAt: null }]],
    ["invalid loaded version", [{ ...validOrder, updatedAt: "not-a-time" }]],
    ["negative amount", [{ ...validOrder, amountPaid: -1 }]],
  ])("rejects %s instead of returning a partial queue", (_label, value) => {
    expect(() => normalizeAdminTicketOrders(value)).toThrow();
  });

  it("rejects an oversized ticket queue", () => {
    expect(() =>
      normalizeAdminTicketOrders(
        Array.from(
          { length: MAX_ADMIN_TICKET_ORDERS + 1 },
          (_, index) => ({ ...validOrder, id: `ticket-${index}` }),
        ),
      ),
    ).toThrow("safe limit");
  });

  it("accepts only the three supported operator actions", () => {
    expect(isAdminTicketStatusAction("valid")).toBe(true);
    expect(isAdminTicketStatusAction("used")).toBe(true);
    expect(isAdminTicketStatusAction("cancelled")).toBe(true);
    expect(isAdminTicketStatusAction("pending")).toBe(false);
    expect(isAdminTicketStatusAction("refunded")).toBe(false);
    expect(isAdminTicketStatusAction("arbitrary")).toBe(false);
  });

  it("normalizes one version token per distinct reviewed ticket", () => {
    expect(
      normalizeAdminTicketVersions([
        { id: "ticket-1", updatedAt: "2026-07-30T09:05:00Z" },
        { id: "ticket-2", updatedAt: "2026-07-30T09:06:00Z" },
      ]),
    ).toEqual([
      {
        id: "ticket-1",
        expectedUpdatedAt: "2026-07-30T09:05:00.000Z",
      },
      {
        id: "ticket-2",
        expectedUpdatedAt: "2026-07-30T09:06:00.000Z",
      },
    ]);
    expect(() =>
      normalizeAdminTicketVersions([
        { id: "ticket-1", updatedAt: "2026-07-30T09:05:00Z" },
        { id: "ticket-1", updatedAt: "2026-07-30T09:06:00Z" },
      ]),
    ).toThrow("duplicate");
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
