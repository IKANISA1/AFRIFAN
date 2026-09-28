import { afterEach, describe, expect, it, vi } from "vitest";
import {
  loadGikundiroPublicSource,
  mapGikundiroFixtures,
  mapGikundiroNews,
} from "./gikundiro-source";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe("standalone Gikundiro public source", () => {
  it("maps only sourced future fixtures and keeps Kigali match dates", () => {
    const now = new Date("2026-09-23T12:00:00Z");
    const fixture = {
      sourceId: "fixture-1",
      homeTeam: "Rayon Sports FC",
      awayTeam: "APR FC",
      competition: "Rwanda Premier League",
      venue: "Kigali Pelé Stadium",
      kickoffAt: "2026-09-23T22:30:00Z",
      sourceUrl: "https://rwandapremierleague.rw/fixtures/1",
    };
    expect(mapGikundiroFixtures([
      fixture,
      { ...fixture, sourceId: "past", kickoffAt: "2026-09-20T15:00:00Z" },
      { ...fixture, sourceId: "unattributed", sourceUrl: "http://example.test/fixture" },
    ], now)).toEqual([expect.objectContaining({
      id: "gikundiro-fixture-1",
      matchDate: "2026-09-24",
      kickoffTime: "00:30",
      isOnSale: false,
      matchStatus: "scheduled",
    })]);
  });

  it("keeps complete recent stories linked to the original publisher", () => {
    const now = new Date("2026-09-23T12:00:00Z");
    const story = {
      sourceId: "story-1",
      title: "Rayon Sports win",
      excerpt: "A sourced match report.",
      publishedAt: "2026-09-22T10:00:00Z",
      publisher: "Example News",
      sourceUrl: "https://example.org/rayon-win",
    };
    expect(mapGikundiroNews([
      story,
      { ...story, sourceId: "future", publishedAt: "2026-09-24T10:00:00Z" },
      { ...story, sourceId: "empty", excerpt: "" },
    ], now)).toEqual([expect.objectContaining({
      id: "gikundiro-story-1",
      sourceUrl: "https://example.org/rayon-win",
      coverImageUrl: null,
    })]);
  });

  it("reads only approved public Rayon rows from the source project", async () => {
    vi.stubEnv("RAYON_PUBLIC_CLOUDFLARE_URL", "");
    vi.stubEnv("GIKUNDIRO_PUBLIC_SUPABASE_URL", "https://loxcwbfukbqziuxgkfcm.supabase.co");
    vi.stubEnv("GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY", "public-test-key");
    const tables: Record<string, unknown[]> = {
      clubs: [{ id: "club-1" }],
      prediction_teams: [
        { id: "rayon", name: "Rayon Sports FC", is_rayon_sports: true },
        { id: "apr", name: "APR FC", is_rayon_sports: false },
      ],
      prediction_competitions: [{ id: "league", name: "Rwanda Premier League" }],
      prediction_fixtures: [{
        id: "fixture-1", home_team_id: "rayon", away_team_id: "apr", competition_id: "league",
        starts_at: "2099-09-25T15:00:00Z", source_publication_id: "source-1",
        source_url: "https://rwandapremierleague.rw/fixtures/1",
      }],
      news_posts: [{
        id: "story-1", title: "Rayon Sports update", excerpt: "Sourced report.",
        published_at: new Date(Date.now() - 60_000).toISOString(),
        source_url: "https://umuseke.rw/story", source_label: "Umuseke",
      }],
    };
    const fetchMock = vi.fn(async (input) => {
      const url = new URL(input);
      const table = url.pathname.split("/").at(-1) || "";
      return new Response(JSON.stringify(tables[table] || []), { status: 200 });
    });
    vi.stubGlobal("fetch", fetchMock);
    const payload = await loadGikundiroPublicSource();
    expect(payload?.fixtures).toHaveLength(1);
    expect(payload?.news).toHaveLength(1);
    const fixtureRequest = fetchMock.mock.calls.map(([input]) => new URL(input)).find((url) => url.pathname.endsWith("prediction_fixtures"));
    expect(fixtureRequest?.searchParams.get("schedule_status")).toBe("eq.confirmed");
    expect(fixtureRequest?.searchParams.get("approval_status")).toBe("eq.approved");
    vi.stubEnv("GIKUNDIRO_PUBLIC_SUPABASE_URL", "http://example.test");
    await expect(loadGikundiroPublicSource()).rejects.toThrow(/url is invalid/i);
  });

  it("uses the Cloudflare staging source without contacting Supabase when enabled", async () => {
    vi.stubEnv("RAYON_PUBLIC_CLOUDFLARE_URL", "https://africlub-rayon-public-staging.ikanisa.workers.dev/");
    vi.stubEnv("GIKUNDIRO_PUBLIC_SUPABASE_URL", "https://loxcwbfukbqziuxgkfcm.supabase.co");
    vi.stubEnv("GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY", "public-test-key");
    const capturedAt = new Date().toISOString();
    const fetchMock = vi.fn(async (input) => {
      const url = new URL(input);
      const route = url.pathname.split("/").at(-1);
      const rows = route === "fixtures" ? [{
        sourceId: "fixture-1", homeTeam: "Rayon Sports FC", awayTeam: "APR FC",
        competition: "Rwanda Premier League", kickoffAt: "2099-09-25T15:00:00Z",
        sourceUrl: "https://rwandapremierleague.rw/fixtures/1",
      }] : [{
        id: "gikundiro-story-1", title: "Club update", excerpt: "A sourced report.",
        publishedAt: new Date(Date.now() - 60_000).toISOString(),
        author: "Umuseke", sourceUrl: "https://umuseke.rw/story",
      }];
      return new Response(JSON.stringify({ schemaVersion: 1, route, sourceCapturedAt: capturedAt, rows }));
    });
    vi.stubGlobal("fetch", fetchMock);
    const payload = await loadGikundiroPublicSource();
    expect(payload?.fixtures).toHaveLength(1);
    expect(payload?.news).toEqual([expect.objectContaining({ sourceId: "story-1", publisher: "Umuseke" })]);
    expect(fetchMock.mock.calls).toHaveLength(2);
    expect(fetchMock.mock.calls.every(([input]) => new URL(input).hostname ===
      "africlub-rayon-public-staging.ikanisa.workers.dev")).toBe(true);
  });

  it("rejects stale Cloudflare rows instead of silently using Supabase", async () => {
    vi.stubEnv("RAYON_PUBLIC_CLOUDFLARE_URL", "https://africlub-rayon-public-staging.ikanisa.workers.dev/");
    const fetchMock = vi.fn(async (input) => new Response(JSON.stringify({
      schemaVersion: 1, route: new URL(input).pathname.split("/").at(-1),
      sourceCapturedAt: new Date(Date.now() - 25 * 60 * 60_000).toISOString(), rows: [],
    })));
    vi.stubGlobal("fetch", fetchMock);
    await expect(loadGikundiroPublicSource()).rejects.toThrow(/stale/i);
    expect(fetchMock.mock.calls.every(([input]) => new URL(input).hostname ===
      "africlub-rayon-public-staging.ikanisa.workers.dev")).toBe(true);
  });

  it.skipIf(process.env.GIKUNDIRO_LIVE_SMOKE !== "true")(
    "reads live approved public Rayon data with the app source adapter",
    async () => {
      const payload = await loadGikundiroPublicSource();
      expect(payload?.schemaVersion).toBe(1);
      expect(mapGikundiroFixtures(payload?.fixtures).length).toBeGreaterThan(0);
      expect(mapGikundiroNews(payload?.news).length).toBeGreaterThan(0);
    },
  );
});
