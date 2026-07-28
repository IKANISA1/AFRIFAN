import { describe, expect, it } from "vitest";
import type { User } from "@supabase/supabase-js";
import { deriveVenueAccess } from "./venue-access";
import { assertVenueScope } from "./venue-operations";

const user = { id: "11111111-1111-4111-8111-111111111111" } as User;
const membership = {
  club_id: 24,
  venue_id: "22222222-2222-4222-8222-222222222222",
  role: "manager",
};
const venue = {
  id: "22222222-2222-4222-8222-222222222222",
  club_id: 24,
  display_name: "Kigali Partner Venue",
  city: "Kigali",
};

describe("venue access boundary", () => {
  it("derives capabilities only from a matching active assignment and venue", () => {
    expect(deriveVenueAccess(user, membership, venue)).toMatchObject({
      userId: user.id,
      clubId: 24,
      venueId: membership.venue_id,
      role: "manager",
      canManageMenu: true,
      canOperateOrders: true,
      canLaunchPromotions: true,
    });
  });

  it("fails closed when the venue differs from the membership", () => {
    expect(
      deriveVenueAccess(user, membership, {
        ...venue,
        id: "33333333-3333-4333-8333-333333333333",
      }),
    ).toBeNull();
  });

  it("fails closed when the club differs from the membership", () => {
    expect(deriveVenueAccess(user, membership, { ...venue, club_id: 25 })).toBeNull();
  });

  it("rejects an unsupported or metadata-only role", () => {
    expect(deriveVenueAccess(user, { ...membership, role: "admin" }, venue)).toBeNull();
  });

  it("rejects cross-venue rows even after a query returns data", () => {
    const access = deriveVenueAccess(user, membership, venue);
    expect(access).not.toBeNull();
    expect(() =>
      assertVenueScope(
        { club_id: 24, venue_id: "33333333-3333-4333-8333-333333333333" },
        access!,
      ),
    ).toThrow("Venue scope mismatch");
  });

  it("rejects cross-club rows even when the venue id matches", () => {
    const access = deriveVenueAccess(user, membership, venue);
    expect(() => assertVenueScope({ club_id: 25, venue_id: membership.venue_id }, access!)).toThrow(
      "Venue scope mismatch",
    );
  });
});
