// @vitest-environment node

import { describe, expect, it } from "vitest";
import { normalizeAdminVenueOverview } from "./venues";

describe("admin venue overview", () => {
  it("accepts strict bounded counts and ignores unowned fields", () => {
    expect(
      normalizeAdminVenueOverview({
        venueCount: 4,
        activeCampaigns: 2,
        openOrders: 8,
        checkinsToday: 36,
        private_records: ["not-owned"],
      }),
    ).toEqual({
      venueCount: 4,
      activeCampaigns: 2,
      openOrders: 8,
      checkinsToday: 36,
    });
  });

  it.each([
    [
      "negative counts",
      {
        venueCount: -1,
        activeCampaigns: 0,
        openOrders: 0,
        checkinsToday: 0,
      },
    ],
    [
      "fractional counts",
      {
        venueCount: 1.5,
        activeCampaigns: 0,
        openOrders: 0,
        checkinsToday: 0,
      },
    ],
    [
      "missing counts",
      {
        venueCount: 1,
        activeCampaigns: 0,
        openOrders: 0,
      },
    ],
  ])("rejects %s instead of inventing zeroes", (_label, value) => {
    expect(() => normalizeAdminVenueOverview(value)).toThrow();
  });
});
