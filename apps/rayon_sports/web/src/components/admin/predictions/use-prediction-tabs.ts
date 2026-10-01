"use client";

import { useAdminCollection } from "@/lib/use-admin-collection";
import type { AdminCompetition, AdminFixture, AdminPredictionMarket, AdminSeason } from "@/lib/data/admin/predictions";
import type { AdminPartnerPredictionPool } from "@/lib/data/admin/partner-pools";

export function useFixtureTab(records: readonly AdminFixture[]) {
  return useAdminCollection({
    records,
    getId: (fixture) => fixture.id,
    getSearchValues: (fixture) => [
      fixture.homeTeamShortName,
      fixture.awayTeamShortName,
      fixture.competitionName,
      fixture.status,
    ],
    getSortValue: (
      fixture,
      key: "match" | "competition" | "kickoff" | "status",
    ) => {
      switch (key) {
        case "match":
          return `${fixture.homeTeamShortName} ${fixture.awayTeamShortName}`;
        case "competition":
          return fixture.competitionName;
        case "kickoff":
          return new Date(fixture.kickoffAt);
        case "status":
          return fixture.status;
      }
    },
    initialSortKey: "kickoff" as const,
    initialSortDirection: "ascending",
    pageSize: 25,
  });
}

export function useHistoricalPoolsTab(records: readonly AdminPartnerPredictionPool[]) {
  return useAdminCollection({
    records,
    getId: (pool) => pool.id,
    getSearchValues: (pool) => [
      pool.title,
      pool.partnerName,
      pool.status,
      pool.eligibilityMode,
      pool.fixtureId,
    ],
    getSortValue: (
      pool,
      key: "title" | "partner" | "status" | "stake" | "entries",
    ) => {
      switch (key) {
        case "title":
          return pool.title;
        case "partner":
          return pool.partnerName;
        case "status":
          return pool.status;
        case "stake":
          return pool.partnerStakeFet;
        case "entries":
          return pool.totalEntries;
      }
    },
    initialSortKey: "title" as const,
    pageSize: 25,
  });
}

export function usePredictionTemplatesTab(records: readonly AdminPredictionMarket[]) {
  return useAdminCollection({
    records,
    getId: (market) => market.id,
    getSearchValues: (market) => [
      market.name,
      market.marketCategory,
      market.difficultyTier,
      market.leagueAvailability.join(" "),
      market.isActive ? "active" : "disabled",
    ],
    getSortValue: (
      market,
      key: "name" | "category" | "difficulty" | "value" | "status",
    ) => {
      switch (key) {
        case "name":
          return market.name;
        case "category":
          return market.marketCategory;
        case "difficulty":
          return market.difficultyTier;
        case "value":
          return market.defaultFetValue;
        case "status":
          return market.isActive;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });
}

export function useCompetitionTab(records: readonly AdminCompetition[]) {
  return useAdminCollection({
    records,
    getId: (competition) => competition.id,
    getSearchValues: (competition) => [
      competition.name,
      competition.shortName,
      competition.competitionKind,
      competition.countryName,
      competition.region,
      competition.isActive ? "active" : "disabled",
    ],
    getSortValue: (competition, key: "name" | "kind" | "region" | "status") => {
      switch (key) {
        case "name":
          return competition.name;
        case "kind":
          return competition.competitionKind;
        case "region":
          return competition.countryName || competition.region;
        case "status":
          return competition.isActive;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });
}

export function useSeasonTab(records: readonly AdminSeason[]) {
  return useAdminCollection({
    records,
    getId: (season) => season.id,
    getSearchValues: (season) => [
      season.competitionName,
      season.label,
      season.status,
      season.startsOn,
      season.endsOn,
      season.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      season,
      key: "competition" | "label" | "start" | "end" | "status",
    ) => {
      switch (key) {
        case "competition":
          return season.competitionName;
        case "label":
          return season.label;
        case "start":
          return season.startsOn ? new Date(season.startsOn) : null;
        case "end":
          return season.endsOn ? new Date(season.endsOn) : null;
        case "status":
          return season.status;
      }
    },
    initialSortKey: "start" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

}

