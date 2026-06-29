import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireAdminCaller } from "../_shared/auth.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import {
  createAdminClient,
  createFootballAdminClient,
} from "../_shared/supabase.ts";

const PROVIDER = "livescore";
const SYNC_TYPE = "livescore_openai_web";
const MAX_FIXTURES_PER_RUN = 100;

type AdminClient = ReturnType<typeof createAdminClient>;
type FootballClient = ReturnType<typeof createFootballAdminClient>;

type LiveScoreSource = {
  id: string;
  clubId: number | null;
  key: string;
  name: string;
  aliases: string[];
  countryAliases: string[];
  externalIds: string[];
  sourceUrls: string[];
  priority: number;
};

type OpenAiFixturePayload = {
  fixtures: OpenAiFixture[];
  source_notes: string[];
  access_issues: string[];
};

type OpenAiFixture = {
  id: string | null;
  source_url: string | null;
  competition: {
    id: string | null;
    name: string;
    country: { name: string | null; code: string | null };
    logo: string | null;
  };
  season: string | null;
  homeTeam: {
    id: string | null;
    name: string;
    shortName: string | null;
    logo: string | null;
  };
  awayTeam: {
    id: string | null;
    name: string;
    shortName: string | null;
    logo: string | null;
  };
  kickoffAt: string | null;
  status: "scheduled" | "live" | "finished" | "postponed" | "cancelled";
  homeScore: number | null;
  awayScore: number | null;
  round: string | null;
  venue: { name: string | null; city: string | null };
  confidence: number;
};

type NormalizedFixture = {
  externalFixtureId: string;
  sourceUrl: string;
  allowedCompetition: LiveScoreSource | null;
  competition: {
    externalId: string;
    name: string;
    shortName: string;
    slug: string;
    countryName: string | null;
    countryCode: string | null;
    logoUrl: string | null;
  };
  season: {
    label: string;
    slug: string;
    yearStart: number;
    yearEnd: number;
  };
  home: TeamPayload;
  away: TeamPayload;
  status: OpenAiFixture["status"];
  kickoffAt: string | null;
  roundName: string | null;
  venueName: string | null;
  venueCity: string | null;
  homeScore: number | null;
  awayScore: number | null;
  metadata: Record<string, unknown>;
};

type TeamPayload = {
  externalId: string;
  name: string;
  shortName: string | null;
  slug: string;
  logoUrl: string | null;
};

type SyncRequest = {
  mode?: unknown;
  dry_run?: unknown;
  dryRun?: unknown;
  club_id?: unknown;
  clubId?: unknown;
  source_keys?: unknown;
  sourceKeys?: unknown;
  limit?: unknown;
  settle_pools?: unknown;
  settlePools?: unknown;
};

type SyncOptions = {
  mode: "preview" | "sync";
  dryRun: boolean;
  clubId: number | null;
  sourceKeys: string[];
  limit: number;
  settlePools: boolean;
};

type SyncSummary = {
  allowed_competitions_loaded: number;
  openai_requests_used: number;
  raw_rows_seen: number;
  rows_skipped: number;
  non_livescore_rows_rejected: number;
  competitions_filtered: number;
  competitions_upserted: number;
  seasons_upserted: number;
  teams_upserted: number;
  fixtures_upserted: number;
  pools_settled: number;
  source_notes: string[];
  access_issues: string[];
  errors: string[];
};

type Dependencies = {
  createAdminClient: typeof createAdminClient;
  createFootballAdminClient: typeof createFootballAdminClient;
  fetch: typeof fetch;
  requireAdminCaller: typeof requireAdminCaller;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  createFootballAdminClient,
  fetch,
  requireAdminCaller,
};

const openAiFixtureSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    fixtures: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: { type: ["string", "null"] },
          source_url: { type: ["string", "null"] },
          competition: {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: ["string", "null"] },
              name: { type: "string" },
              country: {
                type: "object",
                additionalProperties: false,
                properties: {
                  name: { type: ["string", "null"] },
                  code: { type: ["string", "null"] },
                },
                required: ["name", "code"],
              },
              logo: { type: ["string", "null"] },
            },
            required: ["id", "name", "country", "logo"],
          },
          season: { type: ["string", "null"] },
          homeTeam: {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: ["string", "null"] },
              name: { type: "string" },
              shortName: { type: ["string", "null"] },
              logo: { type: ["string", "null"] },
            },
            required: ["id", "name", "shortName", "logo"],
          },
          awayTeam: {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: ["string", "null"] },
              name: { type: "string" },
              shortName: { type: ["string", "null"] },
              logo: { type: ["string", "null"] },
            },
            required: ["id", "name", "shortName", "logo"],
          },
          kickoffAt: { type: ["string", "null"] },
          status: {
            type: "string",
            enum: ["scheduled", "live", "finished", "postponed", "cancelled"],
          },
          homeScore: { type: ["integer", "null"] },
          awayScore: { type: ["integer", "null"] },
          round: { type: ["string", "null"] },
          venue: {
            type: "object",
            additionalProperties: false,
            properties: {
              name: { type: ["string", "null"] },
              city: { type: ["string", "null"] },
            },
            required: ["name", "city"],
          },
          confidence: { type: "number", minimum: 0, maximum: 1 },
        },
        required: [
          "id",
          "source_url",
          "competition",
          "season",
          "homeTeam",
          "awayTeam",
          "kickoffAt",
          "status",
          "homeScore",
          "awayScore",
          "round",
          "venue",
          "confidence",
        ],
      },
    },
    source_notes: { type: "array", items: { type: "string" } },
    access_issues: { type: "array", items: { type: "string" } },
  },
  required: ["fixtures", "source_notes", "access_issues"],
};

export function createLiveScoreOpenAiSyncHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = { ...defaultDependencies, ...dependencies };

  return async (request: Request) => {
    if (request.method === "OPTIONS") return corsPreflightResponse();
    if (request.method === "GET") {
      return jsonOk({ success: true, function: "livescore-openai-sync" });
    }
    if (request.method !== "POST") return jsonError("Method not allowed", 405);

    const startedAt = new Date();
    let options: SyncOptions | null = null;
    let summary = emptySummary();

    try {
      await authorizeRequest(request, deps);
      options = normalizeRequest(await readJsonBody(request));

      const adminClient = deps.createAdminClient();
      const footballClient = deps.createFootballAdminClient();
      const sources = await loadAllowedCompetitionSources(adminClient, options);
      summary.allowed_competitions_loaded = sources.length;

      if (sources.length === 0) {
        summary.errors.push(
          "No active LiveScore competition sources are configured.",
        );
        await writeSyncLog(adminClient, startedAt, summary, options);
        return jsonOk({ success: false, dry_run: options.dryRun, summary });
      }

      const payload = await collectFixturesWithOpenAi(deps.fetch, sources, options);
      summary.openai_requests_used += 1;
      summary.raw_rows_seen = payload.fixtures.length;
      summary.source_notes.push(...payload.source_notes);
      summary.access_issues.push(...payload.access_issues);

      const seen = new Set<string>();
      for (const raw of payload.fixtures.slice(0, options.limit)) {
        const normalized = normalizeOpenAiFixture(raw, sources);
        if (!normalized) {
          summary.rows_skipped += 1;
          continue;
        }
        if (!isLiveScoreUrl(normalized.sourceUrl)) {
          summary.non_livescore_rows_rejected += 1;
          continue;
        }
        if (!normalized.allowedCompetition) {
          summary.competitions_filtered += 1;
          continue;
        }
        if (seen.has(normalized.externalFixtureId)) continue;
        seen.add(normalized.externalFixtureId);

        const result = await upsertFixtureGraph(
          footballClient,
          adminClient,
          normalized,
          options,
        );
        mergeSummary(summary, result);
      }

      await writeSyncLog(adminClient, startedAt, summary, options);
      return jsonOk({ success: summary.errors.length === 0, dry_run: options.dryRun, summary });
    } catch (error) {
      summary.errors.push(messageOf(error));
      try {
        if (options) {
          await writeSyncLog(deps.createAdminClient(), startedAt, summary, options);
        }
      } catch (logError) {
        console.error("livescore-openai-sync log failure:", logError);
      }

      const status = error instanceof HttpError ? error.status : 500;
      console.error("livescore-openai-sync failed:", error);
      return jsonError(messageOf(error), status);
    }
  };
}

async function authorizeRequest(
  request: Request,
  deps: Dependencies,
) {
  const providedSecret = request.headers.get("x-cron-secret")?.trim();
  const configuredSecret =
    Deno.env.get("LIVESCORE_SYNC_SECRET")?.trim() ||
    Deno.env.get("CRON_JOB_SECRET")?.trim();
  if (providedSecret && configuredSecret && providedSecret === configuredSecret) {
    return;
  }

  const authorization = request.headers.get("authorization") ??
    request.headers.get("Authorization") ??
    "";
  const bearer = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (bearer && serviceRole && bearer === serviceRole) return;

  await deps.requireAdminCaller(request);
}

async function readJsonBody(request: Request): Promise<SyncRequest> {
  try {
    return await request.json() as SyncRequest;
  } catch (_) {
    return {};
  }
}

function normalizeRequest(body: SyncRequest): SyncOptions {
  const mode = asTrimmedString(body.mode) === "preview" ? "preview" : "sync";
  const dryRun = mode === "preview" ||
    parseBoolean(body.dryRun ?? body.dry_run, false);
  return {
    mode,
    dryRun,
    clubId: parsePositiveInteger(body.clubId ?? body.club_id),
    sourceKeys: arrayOfStrings(body.sourceKeys ?? body.source_keys)
      .map((key) => key.toLowerCase()),
    limit: clamp(parsePositiveInteger(body.limit) ?? 50, 1, MAX_FIXTURES_PER_RUN),
    settlePools: parseBoolean(body.settlePools ?? body.settle_pools, true),
  };
}

async function loadAllowedCompetitionSources(
  adminClient: AdminClient,
  options: SyncOptions,
): Promise<LiveScoreSource[]> {
  let query = adminClient
    .from("livescore_competition_sources")
    .select(
      "id,club_id,source_key,display_name,match_aliases,country_aliases,external_competition_ids,source_urls,priority",
    )
    .eq("is_active", true)
    .order("priority", { ascending: true })
    .order("display_name", { ascending: true });

  if (options.clubId != null) {
    query = query.or(`club_id.is.null,club_id.eq.${options.clubId}`);
  }
  if (options.sourceKeys.length > 0) {
    query = query.in("source_key", options.sourceKeys);
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  return (Array.isArray(data) ? data : [])
    .map((row) => mapSource(row as Record<string, unknown>))
    .filter((source): source is LiveScoreSource => source != null);
}

function mapSource(row: Record<string, unknown>): LiveScoreSource | null {
  const displayName = asTrimmedString(row.display_name);
  const sourceKey = asTrimmedString(row.source_key);
  const aliases = arrayOfStrings(row.match_aliases);
  const sourceUrls = arrayOfStrings(row.source_urls).filter(isLiveScoreUrl);
  if (!displayName || !sourceKey || aliases.length === 0 || sourceUrls.length === 0) {
    return null;
  }

  return {
    id: String(row.id ?? ""),
    clubId: parsePositiveInteger(row.club_id),
    key: sourceKey,
    name: displayName,
    aliases: aliases.map(normalizeSearchText).filter(Boolean),
    countryAliases: arrayOfStrings(row.country_aliases).map(normalizeSearchText)
      .filter(Boolean),
    externalIds: arrayOfStrings(row.external_competition_ids).map(normalizeSearchText)
      .filter(Boolean),
    sourceUrls,
    priority: parsePositiveInteger(row.priority) ?? 100,
  };
}

async function collectFixturesWithOpenAi(
  fetchFn: typeof fetch,
  sources: LiveScoreSource[],
  options: SyncOptions,
): Promise<OpenAiFixturePayload> {
  const apiKey = requireEnv("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_LIVESCORE_MODEL")?.trim() || "gpt-4.1-mini";
  const tool = Deno.env.get("OPENAI_LIVESCORE_WEB_SEARCH_TOOL")?.trim() ||
    "web_search_preview";

  const response = await fetchFn("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      tools: [{ type: tool, search_context_size: "medium" }],
      tool_choice: "auto",
      max_output_tokens: 6000,
      input: buildOpenAiPrompt(sources, options),
      text: {
        format: {
          type: "json_schema",
          name: "livescore_fixture_sync",
          schema: openAiFixtureSchema,
          strict: true,
        },
      },
      metadata: {
        product: "africlub",
        sync_type: SYNC_TYPE,
      },
    }),
  });

  const responseBody = await response.json();
  if (!response.ok) {
    throw new Error(`OpenAI LiveScore sync failed with ${response.status}: ${truncateForLog(JSON.stringify(responseBody))}`);
  }

  const text = extractOpenAiText(responseBody);
  const parsed = JSON.parse(text) as OpenAiFixturePayload;
  return {
    fixtures: Array.isArray(parsed.fixtures) ? parsed.fixtures : [],
    source_notes: Array.isArray(parsed.source_notes) ? parsed.source_notes : [],
    access_issues: Array.isArray(parsed.access_issues) ? parsed.access_issues : [],
  };
}

function buildOpenAiPrompt(sources: LiveScoreSource[], options: SyncOptions): string {
  const sourceLines = sources.map((source) =>
    [
      `- key: ${source.key}`,
      `name: ${source.name}`,
      `aliases: ${source.aliases.join(", ")}`,
      source.countryAliases.length > 0
        ? `countries: ${source.countryAliases.join(", ")}`
        : "countries: global",
      `urls: ${source.sourceUrls.join(", ")}`,
    ].join(" | ")
  );

  return [
    "You are a production football data extraction worker for AFRICLUB.",
    "Use web search to inspect only LiveScore pages under https://www.livescore.com/.",
    "Do not use betting, casino, social media, Wikipedia, search snippets without LiveScore backing, or non-LiveScore data.",
    "Return only football fixtures/results/live match states that belong to the configured competition sources below.",
    "For each fixture, source_url must be a LiveScore URL supporting the row.",
    "If LiveScore does not expose fixtures for a configured source, do not invent data; add a short access_issues item instead.",
    "Use W/D/W result semantics only: scheduled, live, finished, postponed, or cancelled.",
    "Include team crest/logo URLs and competition logos only when visible from LiveScore; otherwise use null.",
    `Maximum fixtures to return: ${options.limit}.`,
    "",
    "Configured LiveScore sources:",
    ...sourceLines,
    "",
    "Return JSON only matching the supplied schema.",
  ].join("\n");
}

function extractOpenAiText(responseBody: Record<string, unknown>): string {
  if (typeof responseBody["output_text"] === "string") {
    return normalizeJsonText(responseBody["output_text"]);
  }

  const output = responseBody["output"];
  if (!Array.isArray(output)) {
    throw new Error("OpenAI response did not contain output text.");
  }

  for (const item of output) {
    if (!isRecord(item)) continue;
    const content = item["content"];
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (!isRecord(part)) continue;
      const text = part["text"];
      if (typeof text === "string" && text.trim().length > 0) {
        return normalizeJsonText(text);
      }
    }
  }

  throw new Error("OpenAI response did not contain structured fixture JSON.");
}

function normalizeOpenAiFixture(
  raw: OpenAiFixture,
  sources: LiveScoreSource[],
): NormalizedFixture | null {
  const sourceUrl = asTrimmedString(raw.source_url);
  const competitionName = asTrimmedString(raw.competition?.name);
  const homeName = asTrimmedString(raw.homeTeam?.name);
  const awayName = asTrimmedString(raw.awayTeam?.name);
  if (!sourceUrl || !competitionName || !homeName || !awayName) return null;

  const competition = {
    externalId: asTrimmedString(raw.competition.id) ||
      slugify(`${competitionName}-${raw.competition.country.name ?? "global"}`),
    name: competitionName,
    shortName: competitionName.length > 24
      ? competitionName.slice(0, 24)
      : competitionName,
    slug: slugify(`${competitionName}-${raw.competition.country.name ?? "global"}`),
    countryName: asTrimmedString(raw.competition.country.name),
    countryCode: asTrimmedString(raw.competition.country.code),
    logoUrl: urlValue(raw.competition.logo),
  };
  const allowedCompetition = matchAllowedCompetition(raw, competition, sources);
  if (!allowedCompetition) {
    return {
      externalFixtureId: "",
      sourceUrl,
      allowedCompetition: null,
      competition,
      season: normalizeSeason(raw.season, competition),
      home: normalizeTeam(raw.homeTeam, "home"),
      away: normalizeTeam(raw.awayTeam, "away"),
      status: raw.status,
      kickoffAt: dateValue(raw.kickoffAt),
      roundName: asTrimmedString(raw.round),
      venueName: asTrimmedString(raw.venue?.name),
      venueCity: asTrimmedString(raw.venue?.city),
      homeScore: numberOrNull(raw.homeScore),
      awayScore: numberOrNull(raw.awayScore),
      metadata: {},
    };
  }

  const externalFixtureId = asTrimmedString(raw.id) ||
    slugify([
      competition.externalId,
      raw.season ?? new Date().getFullYear(),
      homeName,
      awayName,
      raw.kickoffAt ?? "unscheduled",
    ].join("-"));
  const season = normalizeSeason(raw.season, competition);

  return {
    externalFixtureId,
    sourceUrl,
    allowedCompetition,
    competition,
    season,
    home: normalizeTeam(raw.homeTeam, "home"),
    away: normalizeTeam(raw.awayTeam, "away"),
    status: raw.status,
    kickoffAt: dateValue(raw.kickoffAt),
    roundName: asTrimmedString(raw.round),
    venueName: asTrimmedString(raw.venue?.name),
    venueCity: asTrimmedString(raw.venue?.city),
    homeScore: numberOrNull(raw.homeScore),
    awayScore: numberOrNull(raw.awayScore),
    metadata: {
      source: PROVIDER,
      sync_type: SYNC_TYPE,
      livescore_fixture_id: externalFixtureId,
      livescore_source_url: sourceUrl,
      allowed_competition_key: allowedCompetition.key,
      allowed_competition_name: allowedCompetition.name,
      openai_confidence: numberOrNull(raw.confidence),
      synced_at: new Date().toISOString(),
    },
  };
}

function matchAllowedCompetition(
  raw: OpenAiFixture,
  competition: NormalizedFixture["competition"],
  sources: LiveScoreSource[],
): LiveScoreSource | null {
  const externalIdText = normalizeSearchText(competition.externalId);
  const haystack = normalizeSearchText([
    competition.externalId,
    competition.name,
    competition.shortName,
    competition.slug,
    competition.countryName,
    competition.countryCode,
    raw.source_url,
  ].filter(Boolean).join(" "));
  const countryText = normalizeSearchText(
    [competition.countryName, competition.countryCode].filter(Boolean).join(" "),
  );

  for (const source of sources) {
    if (externalIdText && source.externalIds.includes(externalIdText)) {
      return source;
    }
    if (source.sourceUrls.some((url) => raw.source_url?.startsWith(url))) {
      return source;
    }

    const aliasMatches = source.aliases.some((alias) => haystack.includes(alias));
    if (!aliasMatches) continue;
    if (source.countryAliases.length === 0) return source;
    const countryMatches = source.countryAliases.some(
      (country) => countryText.includes(country) || haystack.includes(country),
    );
    if (countryMatches) return source;
  }

  return null;
}

function normalizeSeason(
  seasonLabel: string | null,
  competition: NormalizedFixture["competition"],
) {
  const raw = asTrimmedString(seasonLabel) || String(new Date().getFullYear());
  const year = Number(raw.match(/\d{4}/)?.[0] ?? new Date().getFullYear());
  return {
    label: raw,
    slug: slugify(`${competition.slug}-${raw}`),
    yearStart: year,
    yearEnd: year,
  };
}

function normalizeTeam(
  team: OpenAiFixture["homeTeam"],
  side: "home" | "away",
): TeamPayload {
  const name = asTrimmedString(team?.name) ?? `${side} team`;
  return {
    externalId: asTrimmedString(team?.id) || slugify(name),
    name,
    shortName: asTrimmedString(team?.shortName) || name.slice(0, 3).toUpperCase(),
    slug: slugify(name),
    logoUrl: urlValue(team?.logo),
  };
}

async function upsertFixtureGraph(
  footballClient: FootballClient,
  adminClient: AdminClient,
  fixture: NormalizedFixture,
  options: SyncOptions,
): Promise<SyncSummary> {
  const summary = emptySummary();
  if (options.dryRun) {
    summary.competitions_upserted += 1;
    summary.seasons_upserted += 1;
    summary.teams_upserted += 2;
    summary.fixtures_upserted += 1;
    return summary;
  }

  const competition = await upsertOne(
    footballClient,
    "competitions",
    {
      slug: fixture.competition.slug,
      name: fixture.competition.name,
      short_name: fixture.competition.shortName,
      competition_kind: "league",
      region: fixture.competition.countryName ? "domestic" : "global",
      country_code: fixture.competition.countryCode,
      country_name: fixture.competition.countryName,
      external_provider: PROVIDER,
      external_competition_id: fixture.competition.externalId,
      is_active: true,
      metadata: compactObject({
        livescore_logo_url: fixture.competition.logoUrl,
        source: PROVIDER,
        sync_type: SYNC_TYPE,
      }),
    },
    "external_provider,external_competition_id",
    "id,slug",
  );
  summary.competitions_upserted += 1;

  const season = await upsertOne(
    footballClient,
    "seasons",
    {
      competition_id: competition.id,
      slug: fixture.season.slug,
      label: fixture.season.label,
      year_start: fixture.season.yearStart,
      year_end: fixture.season.yearEnd,
      status: "active",
      is_active: true,
      metadata: { source: PROVIDER, sync_type: SYNC_TYPE },
    },
    "competition_id,label",
    "id,slug",
  );
  summary.seasons_upserted += 1;

  const home = await upsertTeam(footballClient, fixture.home);
  const away = await upsertTeam(footballClient, fixture.away);
  summary.teams_upserted += 2;

  await upsertOne(
    footballClient,
    "season_teams",
    { season_id: season.id, team_id: home.id, is_active: true, metadata: { source: PROVIDER } },
    "season_id,team_id",
    "id",
  );
  await upsertOne(
    footballClient,
    "season_teams",
    { season_id: season.id, team_id: away.id, is_active: true, metadata: { source: PROVIDER } },
    "season_id,team_id",
    "id",
  );

  const savedFixture = await upsertOne(
    footballClient,
    "fixtures",
    {
      competition_id: competition.id,
      season_id: season.id,
      stage_name: "regular_season",
      group_name: "",
      round_name: fixture.roundName,
      kickoff_at: fixture.kickoffAt,
      venue_name: fixture.venueName,
      venue_city: fixture.venueCity,
      home_team_id: home.id,
      away_team_id: away.id,
      home_score: fixture.homeScore,
      away_score: fixture.awayScore,
      status: fixture.status,
      external_provider: PROVIDER,
      external_fixture_id: fixture.externalFixtureId,
      metadata: fixture.metadata,
    },
    "external_provider,external_fixture_id",
    "id,status,home_score,away_score",
  );
  summary.fixtures_upserted += 1;

  if (options.settlePools && savedFixture.status === "finished") {
    summary.pools_settled += await settlePoolsForFixture(
      footballClient,
      adminClient,
      String(savedFixture.id),
      summary,
    );
  }

  return summary;
}

async function upsertTeam(
  footballClient: FootballClient,
  team: TeamPayload,
): Promise<Record<string, unknown>> {
  return await upsertOne(
    footballClient,
    "teams",
    {
      slug: team.slug,
      name: team.name,
      short_name: team.shortName,
      team_type: "club",
      crest_url: team.logoUrl,
      external_provider: PROVIDER,
      external_team_id: team.externalId,
      is_active: true,
      metadata: compactObject({
        livescore_logo_url: team.logoUrl,
        source: PROVIDER,
        sync_type: SYNC_TYPE,
      }),
    },
    "external_provider,external_team_id",
    "id,slug",
  );
}

async function upsertOne(
  client: FootballClient,
  table: string,
  row: Record<string, unknown>,
  onConflict: string,
  select: string,
): Promise<Record<string, unknown>> {
  const { data, error } = await client
    .from(table)
    .upsert(row, { onConflict })
    .select(select)
    .single();
  if (error) throw new Error(`${table}: ${error.message}`);
  if (!data) throw new Error(`${table}: upsert returned no row`);
  return data as unknown as Record<string, unknown>;
}

async function settlePoolsForFixture(
  footballClient: FootballClient,
  adminClient: AdminClient,
  fixtureId: string,
  summary: SyncSummary,
): Promise<number> {
  const { data, error } = await footballClient
    .from("partner_prediction_pools")
    .select("id,status")
    .eq("fixture_id", fixtureId)
    .in("status", ["open", "locked"]);
  if (error) {
    summary.errors.push(`Pool lookup for fixture ${fixtureId}: ${error.message}`);
    return 0;
  }

  let settled = 0;
  for (const pool of Array.isArray(data) ? data : []) {
    const { error: settleError } = await adminClient.rpc(
      "partner_prediction_pool_settle",
      { p_pool_id: pool["id"] },
    );
    if (settleError) {
      summary.errors.push(`Pool ${pool["id"]}: ${settleError.message}`);
    } else {
      settled += 1;
    }
  }
  return settled;
}

async function writeSyncLog(
  adminClient: AdminClient,
  startedAt: Date,
  summary: SyncSummary,
  options: SyncOptions,
) {
  if (options.dryRun) return;
  const status = summary.errors.length > 0 ? "completed_with_errors" : "completed";
  const { error } = await adminClient.from("football_sync_log").insert({
    sync_type: SYNC_TYPE,
    status,
    records_fetched: summary.raw_rows_seen,
    records_upserted: summary.fixtures_upserted,
    api_requests_used: summary.openai_requests_used,
    error_message: summary.errors.length > 0 ? summary.errors.slice(0, 5).join(" | ") : null,
    metadata: {
      ...summary,
      source_provider: PROVIDER,
      dry_run: options.dryRun,
      mode: options.mode,
    },
    started_at: startedAt.toISOString(),
    completed_at: new Date().toISOString(),
  });
  if (error) throw new Error(`football_sync_log: ${error.message}`);
}

function emptySummary(): SyncSummary {
  return {
    allowed_competitions_loaded: 0,
    openai_requests_used: 0,
    raw_rows_seen: 0,
    rows_skipped: 0,
    non_livescore_rows_rejected: 0,
    competitions_filtered: 0,
    competitions_upserted: 0,
    seasons_upserted: 0,
    teams_upserted: 0,
    fixtures_upserted: 0,
    pools_settled: 0,
    source_notes: [],
    access_issues: [],
    errors: [],
  };
}

function mergeSummary(target: SyncSummary, source: SyncSummary) {
  target.allowed_competitions_loaded += source.allowed_competitions_loaded;
  target.openai_requests_used += source.openai_requests_used;
  target.raw_rows_seen += source.raw_rows_seen;
  target.rows_skipped += source.rows_skipped;
  target.non_livescore_rows_rejected += source.non_livescore_rows_rejected;
  target.competitions_filtered += source.competitions_filtered;
  target.competitions_upserted += source.competitions_upserted;
  target.seasons_upserted += source.seasons_upserted;
  target.teams_upserted += source.teams_upserted;
  target.fixtures_upserted += source.fixtures_upserted;
  target.pools_settled += source.pools_settled;
  target.source_notes.push(...source.source_notes);
  target.access_issues.push(...source.access_issues);
  target.errors.push(...source.errors);
}

function isLiveScoreUrl(value: unknown): value is string {
  const text = asTrimmedString(value);
  if (!text) return false;
  try {
    const url = new URL(text);
    return url.hostname === "www.livescore.com" || url.hostname.endsWith(".livescore.com");
  } catch (_) {
    return false;
  }
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing environment variable: ${name}`);
  return value;
}

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function arrayOfStrings(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((item) => asTrimmedString(item)).filter((item): item is string => item != null);
  }
  const text = asTrimmedString(value);
  return text ? text.split(",").map((item) => item.trim()).filter(Boolean) : [];
}

function parseBoolean(value: unknown, fallback: boolean): boolean {
  if (value == null || value === "") return fallback;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    return ["1", "true", "yes", "on"].includes(value.trim().toLowerCase());
  }
  return fallback;
}

function parsePositiveInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }
  return null;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function urlValue(value: unknown): string | null {
  const text = asTrimmedString(value);
  if (!text) return null;
  try {
    return new URL(text).toString();
  } catch (_) {
    return null;
  }
}

function numberOrNull(value: unknown): number | null {
  if (value == null || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? Math.trunc(number) : null;
}

function dateValue(value: unknown): string | null {
  const text = asTrimmedString(value);
  if (!text) return null;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 90) || "unknown";
}

function normalizeSearchText(value: unknown): string {
  return String(value ?? "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function compactObject(obj: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(obj).filter(([, value]) => value != null && value !== ""),
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function normalizeJsonText(value: string): string {
  return value.trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
}

function truncateForLog(value: string, maxLength = 1000): string {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

if (import.meta.main) {
  const handler = createLiveScoreOpenAiSyncHandler();
  Deno.serve(async (req: Request) => withCors(await handler(req)));
}

function withCors(response: Response): Response {
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: {
      ...Object.fromEntries(response.headers.entries()),
      ...corsHeaders(),
    },
  });
}
