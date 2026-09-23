import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import {
  normalizeAdminPredictionsWorkspace,
  saveAdminFixture,
  saveAdminPredictionMarket,
} from "./predictions";

const timestamp = "2026-07-30T09:00:00.000Z";
const dummyClient = {} as SupabaseClient;
const clubAdminAccess: AdminAccess = {
  hasAccess: true,
  isAuthenticated: true,
  isSuperAdmin: false,
  userId: "club-admin-1",
  role: "club_admin",
  clubId: "24",
  availableClubIds: ["24"],
  canSelectClub: false,
  assignmentCount: 1,
};
const platformAdminAccess: AdminAccess = {
  ...clubAdminAccess,
  isSuperAdmin: true,
  role: "super_admin",
};

const market = {
  id: "market-1",
  slug: "match-result",
  name: "Match result",
  short_name: "WDW",
  market_group: "match_result",
  market_category: "result",
  bet_type: "single",
  difficulty_tier: "entry",
  default_fet_value: 100,
  description: "Home win, draw, or away win.",
  is_active: true,
  league_availability: ["RPL"],
  sort_order: 1,
  created_at: timestamp,
  updated_at: timestamp,
  private_formula: "not-public",
};

const competition = {
  id: "competition-1",
  slug: "rwanda-premier-league",
  name: "Rwanda Premier League",
  short_name: "RPL",
  competition_kind: "league",
  region: "Africa",
  country_code: "RW",
  country_name: "Rwanda",
  is_active: true,
  created_at: timestamp,
  updated_at: timestamp,
  provider_secret: "not-public",
};

const season = {
  id: "season-1",
  competition_id: "competition-1",
  competition_name: "Rwanda Premier League",
  slug: "2026-27",
  label: "2026/27",
  year_start: 2026,
  year_end: 2027,
  starts_on: "2026-08-01",
  ends_on: "2027-06-30",
  status: "active",
  is_active: true,
  created_at: timestamp,
  updated_at: timestamp,
};

const fixture = {
  id: "fixture-1",
  competition_name: "Rwanda Premier League",
  season_label: "2026/27",
  round_name: "Round 1",
  kickoff_at: "2026-08-15T16:00:00.000Z",
  venue_name: "Kigali Pelé Stadium",
  home_team_name: "Rayon Sports",
  home_team_short_name: "Rayon",
  away_team_name: "APR FC",
  away_team_short_name: "APR",
  home_score: null,
  away_score: null,
  status: "scheduled",
  updated_at: timestamp,
  internal_provider_payload: { token: "not-public" },
};

const partner = {
  id: "partner-1",
  name: "Verified Mobility",
  slug: "verified-mobility",
  category: "mobility",
  private_contact: "not-public@example.com",
};

const partnerPool = {
  id: "pool-1",
  club_id: 24,
  partner_id: "partner-1",
  partner_name: "Verified Mobility",
  partner_slug: "verified-mobility",
  initiative_id: null,
  fixture_id: "fixture-1",
  title: "Derby WDW pool",
  prediction_kind: "wdw",
  partner_stake_fet: 5_000,
  fan_entry_fet: 100,
  eligibility_mode: "partner_earn_required",
  status: "open",
  lock_at: "2026-08-15T15:55:00.000Z",
  total_entries: 12,
  total_fan_entry_fet: 1_200,
  settlement: null,
  viewer_entry: { supporter_id: "private" },
  metadata: { token: "not-public" },
};

describe("admin prediction workspace normalization", () => {
  it("projects only strict schema-owned fields across the complete workspace", () => {
    const normalized = normalizeAdminPredictionsWorkspace({
      markets: [market],
      competitions: [competition],
      seasons: [season],
      fixtures: [fixture],
      partnerPools: [partnerPool],
      partners: [partner],
    });

    expect(normalized).toEqual({
      markets: [
        {
          id: "market-1",
          slug: "match-result",
          name: "Match result",
          shortName: "WDW",
          marketGroup: "match_result",
          marketCategory: "result",
          betType: "single",
          difficultyTier: "entry",
          defaultFetValue: 100,
          description: "Home win, draw, or away win.",
          isActive: true,
          leagueAvailability: ["RPL"],
          sortOrder: 1,
          createdAt: timestamp,
          updatedAt: timestamp,
        },
      ],
      competitions: [
        {
          id: "competition-1",
          slug: "rwanda-premier-league",
          name: "Rwanda Premier League",
          shortName: "RPL",
          competitionKind: "league",
          region: "Africa",
          countryCode: "RW",
          countryName: "Rwanda",
          isActive: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        },
      ],
      seasons: [
        {
          id: "season-1",
          competitionId: "competition-1",
          competitionName: "Rwanda Premier League",
          slug: "2026-27",
          label: "2026/27",
          yearStart: 2026,
          yearEnd: 2027,
          startsOn: "2026-08-01",
          endsOn: "2027-06-30",
          status: "active",
          isActive: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        },
      ],
      fixtures: [
        {
          id: "fixture-1",
          competitionName: "Rwanda Premier League",
          seasonLabel: "2026/27",
          roundName: "Round 1",
          kickoffAt: "2026-08-15T16:00:00.000Z",
          venueName: "Kigali Pelé Stadium",
          homeTeamName: "Rayon Sports",
          homeTeamShortName: "Rayon",
          awayTeamName: "APR FC",
          awayTeamShortName: "APR",
          homeScore: null,
          awayScore: null,
          status: "scheduled",
          updatedAt: timestamp,
        },
      ],
      partnerPools: [
        {
          id: "pool-1",
          clubId: 24,
          partnerId: "partner-1",
          partnerName: "Verified Mobility",
          partnerSlug: "verified-mobility",
          initiativeId: null,
          fixtureId: "fixture-1",
          title: "Derby WDW pool",
          predictionKind: "wdw",
          partnerStakeFet: 5_000,
          fanEntryFet: 100,
          eligibilityMode: "partner_earn_required",
          status: "open",
          lockAt: "2026-08-15T15:55:00.000Z",
          totalEntries: 12,
          totalFanEntryFet: 1_200,
          settlement: null,
        },
      ],
      partners: [
        {
          id: "partner-1",
          name: "Verified Mobility",
          slug: "verified-mobility",
          category: "mobility",
        },
      ],
    });
    expect(JSON.stringify(normalized)).not.toContain("not-public");
    expect(JSON.stringify(normalized)).not.toContain("metadata");
    expect(JSON.stringify(normalized)).not.toContain("viewer_entry");
  });

  it("accepts already-normalized API values without changing them", () => {
    const first = normalizeAdminPredictionsWorkspace({
      markets: [market],
      competitions: [competition],
      seasons: [season],
      fixtures: [fixture],
      partnerPools: [partnerPool],
      partners: [partner],
    });

    expect(normalizeAdminPredictionsWorkspace(first)).toEqual(first);
  });

  it("drops invalid enums, dates, score pairs, and reversed seasons", () => {
    const normalized = normalizeAdminPredictionsWorkspace({
      markets: [{ ...market, id: "market-invalid", market_group: "unowned" }],
      competitions: [
        {
          ...competition,
          id: "competition-invalid",
          competition_kind: "friendly",
        },
      ],
      seasons: [
        {
          ...season,
          id: "season-invalid",
          starts_on: "2027-08-01",
          ends_on: "2026-06-30",
        },
      ],
      fixtures: [
        { ...fixture, id: "fixture-old-status", status: "completed" },
        { ...fixture, id: "fixture-half-score", home_score: 2 },
        { ...fixture, id: "fixture-bad-date", kickoff_at: "not-a-date" },
      ],
      partnerPools: [
        { ...partnerPool, id: "pool-invalid", status: "complete" },
      ],
      partners: [{ ...partner, id: "", slug: "" }],
    });

    expect(normalized).toEqual({
      markets: [],
      competitions: [],
      seasons: [],
      fixtures: [],
      partnerPools: [],
      partners: [],
    });
  });

  it("deduplicates each collection by its confirmed identifier", () => {
    const normalized = normalizeAdminPredictionsWorkspace({
      markets: [market, { ...market, name: "Duplicate" }],
      competitions: [competition, { ...competition, name: "Duplicate" }],
      seasons: [season, { ...season, label: "Duplicate" }],
      fixtures: [fixture, { ...fixture, venue_name: "Duplicate" }],
      partnerPools: [partnerPool, { ...partnerPool, title: "Duplicate" }],
      partners: [partner, { ...partner, name: "Duplicate" }],
    });

    expect(normalized.markets).toHaveLength(1);
    expect(normalized.competitions).toHaveLength(1);
    expect(normalized.seasons).toHaveLength(1);
    expect(normalized.fixtures).toHaveLength(1);
    expect(normalized.partnerPools).toHaveLength(1);
    expect(normalized.partners).toHaveLength(1);
  });

  it("caps catalogs, seasons, fixtures, and partners at 500 and pools at 100", () => {
    const normalized = normalizeAdminPredictionsWorkspace({
      markets: Array.from({ length: 510 }, (_, index) => ({
        ...market,
        id: `market-${index}`,
        slug: `market-${index}`,
      })),
      competitions: Array.from({ length: 510 }, (_, index) => ({
        ...competition,
        id: `competition-${index}`,
        slug: `competition-${index}`,
      })),
      seasons: Array.from({ length: 510 }, (_, index) => ({
        ...season,
        id: `season-${index}`,
        slug: `season-${index}`,
      })),
      fixtures: Array.from({ length: 510 }, (_, index) => ({
        ...fixture,
        id: `fixture-${index}`,
      })),
      partnerPools: Array.from({ length: 110 }, (_, index) => ({
        ...partnerPool,
        id: `pool-${index}`,
      })),
      partners: Array.from({ length: 510 }, (_, index) => ({
        ...partner,
        id: `partner-${index}`,
        slug: `partner-${index}`,
      })),
    });

    expect(normalized.markets).toHaveLength(500);
    expect(normalized.competitions).toHaveLength(500);
    expect(normalized.seasons).toHaveLength(500);
    expect(normalized.fixtures).toHaveLength(500);
    expect(normalized.partnerPools).toHaveLength(100);
    expect(normalized.partners).toHaveLength(500);
  });

  it("keeps only structurally valid settlement evidence", () => {
    const validSettlement = {
      official_outcome: "home_win",
      logical_winners: 10,
      eligible_winners: 8,
      ineligible_winners: 2,
      total_paid_fet: 4_000,
      total_refunded_fet: 0,
      unawarded_partner_fet: 1_000,
      settlement_mode: "equal_split",
      settled_at: timestamp,
      private_winner_ids: ["supporter-1"],
    };
    const normalized = normalizeAdminPredictionsWorkspace({
      partnerPools: [
        {
          ...partnerPool,
          status: "settled",
          settlement: validSettlement,
        },
        {
          ...partnerPool,
          id: "pool-bad-settlement",
          settlement: { ...validSettlement, eligible_winners: -1 },
        },
      ],
    });

    expect(normalized.partnerPools).toEqual([
      expect.objectContaining({
        id: "pool-1",
        settlement: {
          officialOutcome: "home_win",
          logicalWinners: 10,
          eligibleWinners: 8,
          ineligibleWinners: 2,
          totalPaidFet: 4_000,
          totalRefundedFet: 0,
          unawardedPartnerFet: 1_000,
          settlementMode: "equal_split",
          settledAt: timestamp,
        },
      }),
    ]);
    expect(JSON.stringify(normalized)).not.toContain("supporter-1");
  });

  it("returns an empty fail-closed workspace for non-object input", () => {
    expect(normalizeAdminPredictionsWorkspace(null)).toEqual({
      markets: [],
      competitions: [],
      seasons: [],
      fixtures: [],
      partnerPools: [],
      partners: [],
    });
  });

  it("rejects club-scoped attempts to change the platform prediction catalog", async () => {
    vi.stubGlobal("window", undefined);
    try {
      await expect(
        saveAdminPredictionMarket(dummyClient, clubAdminAccess, {
          id: "market-1",
          expectedUpdatedAt: timestamp,
          slug: "match-result",
          name: "Match result",
          shortName: "WDW",
          marketGroup: "match_result",
          marketCategory: "result",
          betType: "single",
          difficultyTier: "entry",
          defaultFetValue: 100,
          description: "Verified",
          isActive: false,
          leagueAvailability: ["RPL"],
          sortOrder: 1,
        }),
      ).rejects.toThrow(/platform admin access is required/i);
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it("rejects fixture saves without a validated change before touching storage", async () => {
    vi.stubGlobal("window", undefined);
    try {
      await expect(
        saveAdminFixture(dummyClient, platformAdminAccess, {
          id: "fixture-1",
          expectedUpdatedAt: timestamp,
        }),
      ).rejects.toThrow(/no fixture change was supplied/i);
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
