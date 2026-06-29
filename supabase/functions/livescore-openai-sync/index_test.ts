import { assertEquals } from "jsr:@std/assert";

import { createLiveScoreOpenAiSyncHandler } from "./index.ts";

const sourceRow = {
  id: "source-1",
  club_id: null,
  source_key: "premier_league",
  display_name: "Premier League",
  match_aliases: ["Premier League", "EPL"],
  country_aliases: ["England"],
  external_competition_ids: ["premier-league"],
  source_urls: ["https://www.livescore.com/en/football/england/premier-league/"],
  priority: 10,
};

function withEnv(values: Record<string, string>, fn: () => Promise<void>) {
  return async () => {
    const previous = new Map<string, string | undefined>();
    for (const [key, value] of Object.entries(values)) {
      previous.set(key, Deno.env.get(key));
      Deno.env.set(key, value);
    }

    try {
      await fn();
    } finally {
      for (const [key, value] of previous.entries()) {
        if (value == null) {
          Deno.env.delete(key);
        } else {
          Deno.env.set(key, value);
        }
      }
    }
  };
}

function fakeSourceAdminClient(rows = [sourceRow]) {
  const query = {
    select: () => query,
    eq: () => query,
    order: () => query,
    or: () => query,
    in: () => query,
    then: (
      resolve: (
        value: { data: typeof rows; error: null },
      ) => unknown,
    ) => Promise.resolve(resolve({ data: rows, error: null })),
  };

  return {
    from: (table: string) => {
      assertEquals(table, "livescore_competition_sources");
      return query;
    },
    rpc: () => {
      throw new Error("rpc should not be called during preview");
    },
  };
}

Deno.test(
  "livescore-openai-sync preview builds an OpenAI web-search request and dry-runs fixture counts",
  withEnv(
    {
      LIVESCORE_SYNC_SECRET: "cron-secret",
      OPENAI_API_KEY: "test-openai-key",
      OPENAI_LIVESCORE_MODEL: "gpt-4.1-mini",
    },
    async () => {
      let openAiRequestJson = "";
      const handler = createLiveScoreOpenAiSyncHandler({
        createAdminClient: () => fakeSourceAdminClient() as never,
        createFootballAdminClient: () => ({}) as never,
        requireAdminCaller: async () => {
          throw new Error("admin auth fallback should not be called");
        },
        fetch: async (_url, init) => {
          openAiRequestJson = String((init as { body?: BodyInit })?.body ?? "");
          return Response.json({
            output_text: JSON.stringify({
              fixtures: [
                {
                  id: "premier-league-arsenal-chelsea",
                  source_url:
                    "https://www.livescore.com/en/football/england/premier-league/",
                  competition: {
                    id: "premier-league",
                    name: "Premier League",
                    country: { name: "England", code: "GB-ENG" },
                    logo: "https://www.livescore.com/static/epl.png",
                  },
                  season: "2026",
                  homeTeam: {
                    id: "arsenal",
                    name: "Arsenal",
                    shortName: "ARS",
                    logo: "https://www.livescore.com/static/arsenal.png",
                  },
                  awayTeam: {
                    id: "chelsea",
                    name: "Chelsea",
                    shortName: "CHE",
                    logo: "https://www.livescore.com/static/chelsea.png",
                  },
                  kickoffAt: "2026-07-01T18:00:00Z",
                  status: "scheduled",
                  homeScore: null,
                  awayScore: null,
                  round: "Matchday 1",
                  venue: { name: "Emirates Stadium", city: "London" },
                  confidence: 0.92,
                },
              ],
              source_notes: ["LiveScore source used."],
              access_issues: [],
            }),
          });
        },
      });

      const response = await handler(
        new Request("https://example.test/livescore-openai-sync", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-cron-secret": "cron-secret",
          },
          body: JSON.stringify({ mode: "preview", limit: 5 }),
        }),
      );
      const body = await response.json();
      const openAiRequest = JSON.parse(openAiRequestJson) as {
        model?: string;
        tools?: Array<{ type?: string }>;
      };

      assertEquals(response.status, 200);
      assertEquals(body.success, true);
      assertEquals(body.dry_run, true);
      assertEquals(body.summary.allowed_competitions_loaded, 1);
      assertEquals(body.summary.openai_requests_used, 1);
      assertEquals(body.summary.raw_rows_seen, 1);
      assertEquals(body.summary.fixtures_upserted, 1);
      assertEquals(body.summary.teams_upserted, 2);
      assertEquals(body.summary.non_livescore_rows_rejected, 0);
      assertEquals(openAiRequest.model, "gpt-4.1-mini");
      assertEquals(
        Array.isArray(openAiRequest.tools) && openAiRequest.tools[0]?.type,
        "web_search_preview",
      );
    },
  ),
);

Deno.test(
  "livescore-openai-sync rejects non-LiveScore OpenAI rows before upsert",
  withEnv(
    {
      LIVESCORE_SYNC_SECRET: "cron-secret",
      OPENAI_API_KEY: "test-openai-key",
    },
    async () => {
      const handler = createLiveScoreOpenAiSyncHandler({
        createAdminClient: () => fakeSourceAdminClient() as never,
        createFootballAdminClient: () => ({}) as never,
        requireAdminCaller: async () => {
          throw new Error("admin auth fallback should not be called");
        },
        fetch: async () =>
          Response.json({
            output_text: JSON.stringify({
              fixtures: [
                {
                  id: "external-row",
                  source_url: "https://example.com/premier-league",
                  competition: {
                    id: "premier-league",
                    name: "Premier League",
                    country: { name: "England", code: "GB-ENG" },
                    logo: null,
                  },
                  season: "2026",
                  homeTeam: { id: "a", name: "A", shortName: "A", logo: null },
                  awayTeam: { id: "b", name: "B", shortName: "B", logo: null },
                  kickoffAt: "2026-07-01T18:00:00Z",
                  status: "scheduled",
                  homeScore: null,
                  awayScore: null,
                  round: null,
                  venue: { name: null, city: null },
                  confidence: 0.5,
                },
              ],
              source_notes: [],
              access_issues: [],
            }),
          }),
      });

      const response = await handler(
        new Request("https://example.test/livescore-openai-sync", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-cron-secret": "cron-secret",
          },
          body: JSON.stringify({ mode: "preview", limit: 5 }),
        }),
      );
      const body = await response.json();

      assertEquals(response.status, 200);
      assertEquals(body.summary.non_livescore_rows_rejected, 1);
      assertEquals(body.summary.fixtures_upserted, 0);
    },
  ),
);

Deno.test(
  "livescore-openai-sync falls back to admin auth when cron secret is absent",
  withEnv(
    {
      LIVESCORE_SYNC_SECRET: "cron-secret",
      OPENAI_API_KEY: "test-openai-key",
    },
    async () => {
      let adminAuthCalled = false;
      const handler = createLiveScoreOpenAiSyncHandler({
        createAdminClient: () => fakeSourceAdminClient([]) as never,
        createFootballAdminClient: () => ({}) as never,
        requireAdminCaller: async () => {
          adminAuthCalled = true;
          return {} as never;
        },
        fetch: async () => Response.json({ output_text: "{}" }),
      });

      const response = await handler(
        new Request("https://example.test/livescore-openai-sync", {
          method: "POST",
          body: JSON.stringify({ mode: "preview" }),
        }),
      );
      const body = await response.json();

      assertEquals(adminAuthCalled, true);
      assertEquals(response.status, 200);
      assertEquals(body.success, false);
      assertEquals(body.summary.allowed_competitions_loaded, 0);
    },
  ),
);
