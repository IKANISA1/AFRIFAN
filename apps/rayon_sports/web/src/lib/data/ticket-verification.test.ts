import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  getActiveTicketVerifierAssignments,
  uniqueAssignedGateCodes,
} from "./ticket-verification";
import type { VenueAccess } from "./venue-access";

const access: VenueAccess = {
  userId: "00000000-0000-4000-8000-000000000101",
  clubId: 7,
  venueId: "00000000-0000-4000-8000-000000000201",
  venueName: "Contract Stadium",
  venueCity: "Kigali",
  role: "staff",
  canManageMenu: false,
  canOperateOrders: true,
  canLaunchPromotions: false,
  canVerifyTickets: true,
};

function clientReturning(data: Array<Record<string, unknown>>): SupabaseClient {
  const query = {
    select: () => query,
    eq: () => query,
    lte: () => query,
    gt: () => query,
    order: () => query,
    limit: async () => ({ data, error: null }),
  };
  return { from: () => query } as unknown as SupabaseClient;
}

describe("ticket verifier assignment loading", () => {
  it("keeps only assignments that match the authenticated venue scope", async () => {
    const now = new Date("2026-08-13T18:00:00Z");
    const valid = {
      id: "00000000-0000-4000-8000-000000000301",
      ticket_event_id: "00000000-0000-4000-8000-000000000401",
      user_id: access.userId,
      venue_id: access.venueId,
      club_id: access.clubId,
      gate_code: "gate_a",
      starts_at: "2026-08-13T17:00:00Z",
      ends_at: "2026-08-13T19:00:00Z",
    };

    const assignments = await getActiveTicketVerifierAssignments(
      clientReturning([
        valid,
        { ...valid, id: "not-a-uuid" },
        {
          ...valid,
          id: "00000000-0000-4000-8000-000000000302",
          user_id: "00000000-0000-4000-8000-000000000999",
        },
        {
          ...valid,
          id: "00000000-0000-4000-8000-000000000303",
          gate_code: "invalid gate",
        },
      ]),
      access,
      now,
    );

    expect(assignments).toEqual([
      {
        id: valid.id,
        ticketEventId: valid.ticket_event_id,
        gateCode: "GATE_A",
        startsAt: valid.starts_at,
        endsAt: valid.ends_at,
      },
    ]);
  });

  it("deduplicates assigned gates while preserving an all-gates assignment", () => {
    expect(
      uniqueAssignedGateCodes([
        {
          id: "a",
          ticketEventId: "event",
          gateCode: "GATE_A",
          startsAt: "start",
          endsAt: "end",
        },
        {
          id: "b",
          ticketEventId: "event",
          gateCode: "GATE_A",
          startsAt: "start",
          endsAt: "end",
        },
        {
          id: "c",
          ticketEventId: "event",
          gateCode: null,
          startsAt: "start",
          endsAt: "end",
        },
      ]),
    ).toEqual(["GATE_A", null]);
  });
});
