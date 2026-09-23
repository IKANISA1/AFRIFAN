import { describe, expect, it } from "vitest";
import { normalizeAdminMatches } from "./matches";

const validMatch = {
  id: "match-1",
  clubId: 24,
  partnerId: "partner-1",
  homeTeam: "Rayon Sports",
  awayTeam: "APR FC",
  competition: "Premier League",
  venue: "Kigali Pelé Stadium",
  matchDate: "2026-08-01T15:00:00.000Z",
  kickoffTime: "15:00:00",
  isOnSale: true,
  generalPrice: 5_000,
  vipPrice: 20_000,
  saleStartsAt: "2026-07-29T12:00:00.000Z",
  capacity: 20_000,
  soldCount: 1_250,
  imageUrl: "https://cdn.example.com/match.webp",
  matchStatus: "scheduled",
  homeScore: 0,
  awayScore: 0,
  liveMinute: null,
  matchSummary: "Confirmed fixture.",
  liveStats: { privateMetric: "must be dropped" },
  liveEvents: [{ privateActorId: "must be dropped" }],
  isFeatured: true,
  updatedAt: "2026-07-29T12:00:00.000Z",
  accessToken: "private-token",
};

describe("admin match response normalization", () => {
  it("keeps only bounded operational fields and drops private extras", () => {
    const [result] = normalizeAdminMatches([validMatch]);

    expect(result).toMatchObject({
      id: "match-1",
      homeTeam: "Rayon Sports",
      awayTeam: "APR FC",
      matchStatus: "scheduled",
      soldCount: 1_250,
      capacity: 20_000,
      liveStats: {},
      liveEvents: [],
    });
    expect(result).not.toHaveProperty("accessToken");
    expect(JSON.stringify(result)).not.toContain("private");
  });

  it("rejects invalid status, unsafe media, over-capacity, and malformed rows", () => {
    expect(
      normalizeAdminMatches([
        { ...validMatch, id: "bad-status", matchStatus: "secret" },
        { ...validMatch, id: "bad-capacity", soldCount: 20_001 },
        null,
      ]),
    ).toEqual([]);

    const [safeMedia] = normalizeAdminMatches([
      { ...validMatch, imageUrl: "javascript:alert(1)" },
    ]);
    expect(safeMedia.imageUrl).toBeNull();
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminMatches({ data: [validMatch] })).toEqual([]);
  });
});
