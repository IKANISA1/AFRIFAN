import { describe, expect, it } from "vitest";
import {
  normalizeAdminFootballSyncSnapshot,
  normalizeAdminLiveScoreCompetitionSourceInput,
  normalizeAdminLiveScoreCompetitionSources,
  normalizeAdminSyncLogs,
  normalizeAdminSyncOverview,
} from "./football-sync";

const source = {
  id: "source-1",
  clubId: 24,
  sourceKey: "rwanda-premier-league",
  displayName: "Rwanda Premier League",
  matchAliases: ["Rwanda Premier League"],
  countryAliases: ["Rwanda"],
  externalCompetitionIds: ["rpl"],
  sourceUrls: ["https://www.livescore.com/en/football/rwanda/"],
  priority: 10,
  isActive: true,
  updatedAt: "2026-07-29T10:00:00.000Z",
};

const log = {
  id: "log-1",
  syncType: "livescore_web",
  status: "failed",
  recordsFetched: 20,
  recordsUpserted: 18,
  webRequestsUsed: 4,
  errorMessage: "database.internal token=private",
  startedAt: "2026-07-29T10:00:00.000Z",
  completedAt: "2026-07-29T10:00:03.000Z",
  metadata: { accessToken: "private" },
};

const overview = {
  totalSources: 2,
  activeSources: 1,
  totalFixtures: 100,
  scheduledFixtures: 50,
  liveFixtures: 5,
  finishedFixtures: 45,
  totalTeams: 20,
  lastSyncAt: "2026-07-29T10:00:00.000Z",
  webRequestsToday: 12,
  errorsToday: 1,
  inspectedLogRowsToday: 10,
};

describe("football sync admin normalization", () => {
  it("keeps only strict source fields and approved LiveScore URLs", () => {
    const normalized = normalizeAdminLiveScoreCompetitionSources([
      {
        ...source,
        privateToken: "private",
        sourceUrls: [
          "https://www.livescore.com/en/football/rwanda/#today",
          "https://evil.example/internal",
        ],
      },
      { ...source, id: "", sourceKey: "broken key" },
    ]);

    expect(normalized).toEqual([
      {
        ...source,
        sourceUrls: ["https://www.livescore.com/en/football/rwanda/"],
      },
    ]);
    expect(JSON.stringify(normalized)).not.toContain("private");
    expect(JSON.stringify(normalized)).not.toContain("evil.example");
  });

  it("sanitizes operational failures and drops malformed logs", () => {
    const normalized = normalizeAdminSyncLogs([
      log,
      { ...log, id: "log-2", status: "unknown-provider-state" },
    ]);

    expect(normalized).toHaveLength(1);
    expect(normalized[0]).toMatchObject({
      id: "log-1",
      durationMs: 3_000,
      errorMessage:
        "Sync reported an operational error. Review authorized server logs.",
    });
    expect(JSON.stringify(normalized)).not.toContain("database.internal");
    expect(JSON.stringify(normalized)).not.toContain("accessToken");
  });

  it("bounds the overview and rejects inconsistent source counts", () => {
    expect(normalizeAdminSyncOverview(overview)).toEqual(overview);
    expect(
      normalizeAdminSyncOverview({
        ...overview,
        activeSources: 3,
      }),
    ).toEqual({
      totalSources: 0,
      activeSources: 0,
      totalFixtures: 0,
      scheduledFixtures: 0,
      liveFixtures: 0,
      finishedFixtures: 0,
      totalTeams: 0,
      lastSyncAt: null,
      webRequestsToday: 0,
      errorsToday: 0,
      inspectedLogRowsToday: 0,
    });
  });

  it("normalizes the combined snapshot and excludes unapproved extras", () => {
    const normalized = normalizeAdminFootballSyncSnapshot({
      overview,
      sources: [{ ...source, serviceRoleKey: "private" }],
      logs: [log],
      internalDiagnostics: "private",
    });

    expect(normalized.overview).toEqual(overview);
    expect(normalized.sources).toHaveLength(1);
    expect(normalized.logs).toHaveLength(1);
    expect(JSON.stringify(normalized)).not.toContain("serviceRoleKey");
    expect(JSON.stringify(normalized)).not.toContain("internalDiagnostics");
  });

  it("normalizes safe mutation input and rejects unsafe providers", () => {
    expect(
      normalizeAdminLiveScoreCompetitionSourceInput({
        sourceKey: "",
        displayName: " Rwanda Premier League ",
        matchAliases: ["RPL", "RPL"],
        countryAliases: [" Rwanda "],
        externalCompetitionIds: [" 123 "],
        sourceUrls: ["https://www.livescore.com/en/football/rwanda/#matches"],
        priority: 15,
        isActive: true,
      }),
    ).toEqual({
      id: null,
      expectedUpdatedAt: null,
      clubId: null,
      sourceKey: "rwanda-premier-league",
      displayName: "Rwanda Premier League",
      matchAliases: ["RPL"],
      countryAliases: ["Rwanda"],
      externalCompetitionIds: ["123"],
      sourceUrls: ["https://www.livescore.com/en/football/rwanda/"],
      priority: 15,
      isActive: true,
    });

    expect(() =>
      normalizeAdminLiveScoreCompetitionSourceInput({
        sourceKey: "rpl",
        displayName: "RPL",
        matchAliases: ["RPL"],
        sourceUrls: ["http://169.254.169.254/latest/meta-data"],
        isActive: true,
      }),
    ).toThrow(/approved LiveScore HTTPS URL/i);
  });
});
