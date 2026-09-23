#!/usr/bin/env node
/**
 * LiveScore web sync runner.
 *
 * Required env:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional env:
 *   LIVESCORE_WEB_URLS=https://www.livescore.com/en/
 *   LIVESCORE_CLUB_ID
 *   LIVESCORE_FIXTURE_ARRAY_PATH=data.fixtures
 *   LIVESCORE_ENABLE_OPENAI_WEB_SEARCH=false
 *   LIVESCORE_SEARCH_QUERY="site:livescore.com/en/ football live scores fixtures results today"
 *   OPENAI_API_KEY
 *   OPENAI_WEB_SEARCH_MODEL=gpt-4.1-mini
 *   OPENAI_WEB_SEARCH_TOOL=web_search_preview
 *   LIVESCORE_POLL_MS=60000
 *   LIVESCORE_RUN_ONCE=true
 *   LIVESCORE_MIRROR_ASSETS=true
 *   LIVESCORE_ASSET_BUCKET=football-assets
 *   LIVESCORE_DRY_RUN=true
 */

const PROVIDER = "livescore";
const MIN_POLL_MS = 60_000;

const env = {
  supabaseUrl: requiredEnv("SUPABASE_URL").replace(/\/+$/, ""),
  serviceRoleKey: requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
  webUrls: parseUrlList(
    process.env.LIVESCORE_WEB_URLS?.trim() || "https://www.livescore.com/en/",
  ),
  clubId: process.env.LIVESCORE_CLUB_ID?.trim() || "",
  fixtureArrayPath: process.env.LIVESCORE_FIXTURE_ARRAY_PATH?.trim() || "",
  openaiApiKey: process.env.OPENAI_API_KEY?.trim() || "",
  openaiSearchEnabled: parseBoolean(process.env.LIVESCORE_ENABLE_OPENAI_WEB_SEARCH, false),
  openaiSearchQuery:
    process.env.LIVESCORE_SEARCH_QUERY?.trim() ||
    "site:livescore.com/en/ football live scores fixtures results today",
  openaiModel: process.env.OPENAI_WEB_SEARCH_MODEL?.trim() || "gpt-4.1-mini",
  openaiSearchTool: process.env.OPENAI_WEB_SEARCH_TOOL?.trim() || "web_search_preview",
  pollMs: Math.max(
    Number(process.env.LIVESCORE_POLL_MS ?? MIN_POLL_MS) || MIN_POLL_MS,
    MIN_POLL_MS,
  ),
  runOnce: parseBoolean(process.env.LIVESCORE_RUN_ONCE, false),
  mirrorAssets: parseBoolean(process.env.LIVESCORE_MIRROR_ASSETS, false),
  dryRun: parseBoolean(process.env.LIVESCORE_DRY_RUN, false),
  assetBucket: process.env.LIVESCORE_ASSET_BUCKET?.trim() || "football-assets",
};

main().catch((error) => {
  console.error("[livescore-sync] fatal:", error);
  process.exitCode = 1;
});

async function main() {
  if (env.dryRun) {
    console.warn("[livescore-sync] DRY RUN: no Supabase writes will be made.");
  }
  if (env.mirrorAssets && !env.dryRun) {
    await ensureStorageBucket();
  }

  do {
    const startedAt = new Date();
    const summary = await syncAllFeeds();
    await writeSyncLog(startedAt, summary);
    console.log(
      JSON.stringify(
        {
          source: PROVIDER,
          started_at: startedAt.toISOString(),
          finished_at: new Date().toISOString(),
          ...summary,
        },
        null,
        2,
      ),
    );

    if (env.runOnce) break;
    await sleep(env.pollMs);
  } while (true);
}

async function syncAllFeeds() {
  const summary = emptySummary();
  const allowedCompetitions = await loadAllowedCompetitionSources(summary);
  if (allowedCompetitions.length === 0) {
    summary.errors.push(
      "No active LiveScore competition sources are configured in public.livescore_competition_sources.",
    );
    return summary;
  }

  const rawFixtures = await collectFixtureRows(summary, allowedCompetitions);
  summary.raw_rows_seen = rawFixtures.length;

  for (const raw of rawFixtures) {
    const fixture = normalizeFixture(raw, allowedCompetitions);
    if (!fixture) {
      summary.rows_skipped += 1;
      continue;
    }
    if (!fixture.allowedCompetition) {
      summary.competitions_filtered += 1;
      continue;
    }

    const result = await upsertFixtureGraph(fixture);
    mergeSummary(summary, result);
  }

  return summary;
}

async function writeSyncLog(startedAt, summary) {
  if (env.dryRun) return;

  try {
    const completedAt = new Date();
    const status = summary.errors.length > 0 ? "completed_with_errors" : "completed";
    const response = await fetch(`${env.supabaseUrl}/rest/v1/football_sync_log`, {
      method: "POST",
      headers: {
        ...jsonHeaders(),
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        sync_type: "livescore_web",
        status,
        records_fetched: summary.raw_rows_seen,
        records_upserted: summary.fixtures_upserted,
        api_requests_used: summary.web_pages_processed + summary.openai_search_used,
        error_message: summary.errors.length > 0 ? summary.errors.slice(0, 5).join(" | ") : null,
        metadata: {
          ...summary,
          source_provider: PROVIDER,
        },
        started_at: startedAt.toISOString(),
        completed_at: completedAt.toISOString(),
      }),
    });
    if (!response.ok) {
      console.warn(`[livescore-sync] sync log write failed: ${response.status} ${await response.text()}`);
    }
  } catch (error) {
    console.warn(`[livescore-sync] sync log write failed: ${messageOf(error)}`);
  }
}

function emptySummary() {
  return {
    web_pages_processed: 0,
    json_documents_seen: 0,
    openai_search_used: 0,
    allowed_competitions_loaded: 0,
    raw_rows_seen: 0,
    rows_skipped: 0,
    competitions_filtered: 0,
    competitions_upserted: 0,
    seasons_upserted: 0,
    teams_upserted: 0,
    fixtures_upserted: 0,
    assets_mirrored: 0,
    pools_settled: 0,
    errors: [],
  };
}

function mergeSummary(target, source) {
  for (const [key, value] of Object.entries(source)) {
    if (Array.isArray(value)) target[key].push(...value);
    else if (typeof value === "number") target[key] += value;
  }
}

async function collectFixtureRows(summary, allowedCompetitions) {
  const rows = [];

  rows.push(...(await collectRowsFromWebPages(summary, allowedCompetitions)));

  if (env.openaiSearchEnabled || (rows.length === 0 && env.openaiApiKey)) {
    rows.push(...(await collectRowsFromOpenAIWebSearch(summary)));
  }

  return rows;
}

async function collectRowsFromWebPages(summary, allowedCompetitions) {
  const rows = [];
  const webUrls = resolveLiveScoreWebUrls(allowedCompetitions);

  for (const webUrl of webUrls) {
    try {
      const html = await fetchLiveScoreHtml(webUrl);
      const documents = extractJsonDocumentsFromHtml(html);
      summary.web_pages_processed += 1;
      summary.json_documents_seen += documents.length;

      for (const document of documents) {
        rows.push(...extractFixtureRows(document));
      }
    } catch (error) {
      summary.errors.push(`${webUrl}: ${messageOf(error)}`);
    }
  }

  return rows;
}

async function loadAllowedCompetitionSources(summary) {
  const query = new URLSearchParams({
    select:
      "id,club_id,source_key,display_name,match_aliases,country_aliases,external_competition_ids,source_urls,priority,metadata",
    is_active: "eq.true",
    order: "priority.asc,display_name.asc",
  });
  let queryString = query.toString();
  if (env.clubId) {
    queryString += `&or=(club_id.is.null,club_id.eq.${encodeURIComponent(env.clubId)})`;
  }

  try {
    const rows = await selectRows("public", "livescore_competition_sources", queryString);
    const sources = Array.isArray(rows)
      ? rows.map(mapAllowedCompetitionSource).filter(Boolean)
      : [];
    summary.allowed_competitions_loaded = sources.length;
    return sources;
  } catch (error) {
    summary.errors.push(`LiveScore competition source config: ${messageOf(error)}`);
    return [];
  }
}

function mapAllowedCompetitionSource(row) {
  if (!isRecord(row)) return null;
  const displayName = stringValue(row.display_name);
  const sourceKey = stringValue(row.source_key) || slugify(displayName || "livescore-source");
  const aliases = arrayOfStrings(row.match_aliases);
  const countryAliases = arrayOfStrings(row.country_aliases);
  const externalIds = arrayOfStrings(row.external_competition_ids);
  if (!displayName || aliases.length === 0) return null;

  return {
    id: stringValue(row.id),
    key: sourceKey,
    name: displayName,
    aliases: aliases.map(normalizeSearchText).filter(Boolean),
    countryAliases: countryAliases.map(normalizeSearchText).filter(Boolean),
    externalIds: externalIds.map(normalizeSearchText).filter(Boolean),
    sourceUrls: arrayOfStrings(row.source_urls),
  };
}

function resolveLiveScoreWebUrls(allowedCompetitions) {
  const urls = new Set();
  for (const source of allowedCompetitions) {
    for (const sourceUrl of source.sourceUrls ?? []) {
      urls.add(sourceUrl);
    }
  }
  if (urls.size === 0) {
    for (const webUrl of env.webUrls) urls.add(webUrl);
  }
  return [...urls];
}

async function fetchLiveScoreHtml(webUrl) {
  const response = await fetch(webUrl, {
    headers: {
      Accept: "text/html,application/xhtml+xml,application/json;q=0.8,*/*;q=0.5",
      "User-Agent": "AFRICLUB-LiveScore-WebSync/1.0",
    },
  });
  if (!response.ok) {
    throw new Error(`web HTTP ${response.status}: ${truncateForLog(await response.text())}`);
  }
  return await response.text();
}

function truncateForLog(value, maxLength = 500) {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
}


function extractJsonDocumentsFromHtml(html) {
  const documents = [];
  const scriptPattern = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = scriptPattern.exec(html))) {
    const attrs = match[1] || "";
    const body = decodeHtmlEntities(match[2].trim());
    if (!body) continue;

    if (isJsonScript(attrs)) {
      appendJsonDocument(body, documents);
    }

    for (const jsonText of extractJsonParseArguments(body)) {
      appendJsonDocument(jsonText, documents);
    }
  }

  return documents;
}

function isJsonScript(attrs) {
  return /id=["']__NEXT_DATA__["']/i.test(attrs) || /type=["']application\/(?:ld\+)?json["']/i.test(attrs);
}

function decodeHtmlEntities(value) {
  return value
    .replace(/&quot;/g, '"')
    .replace(/&#34;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/gi, "'")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");
}

function appendJsonDocument(jsonText, documents) {
  try {
    const parsed = JSON.parse(jsonText);
    if (isRecord(parsed) || Array.isArray(parsed)) documents.push(parsed);
  } catch {
    // Ignore non-fixture JSON fragments and malformed hydration chunks.
  }
}

function extractJsonParseArguments(scriptBody) {
  const values = [];
  const pattern = /JSON\.parse\((["'])([\s\S]*?)\1\)/g;
  let match;

  while ((match = pattern.exec(scriptBody))) {
    const decoded = decodeJsString(match[2], match[1]);
    if (decoded) values.push(decoded);
  }

  return values;
}

function decodeJsString(value, quote) {
  try {
    return JSON.parse(`${quote}${value}${quote}`);
  } catch {
    return value
      .replace(/\\(["'\\/bfnrt])/g, (_, char) => {
        const replacements = { b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };
        return replacements[char] ?? char;
      })
      .replace(/\\u([0-9a-f]{4})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
  }
}

async function collectRowsFromOpenAIWebSearch(summary) {
  if (!env.openaiApiKey) return [];

  const prompt = [
    "Use web search to inspect only LiveScore pages under https://www.livescore.com/en/.",
    "Return current football fixtures, live match states, final results, competitions, teams, kickoff time, scores, and logo or crest URLs when visible.",
    "Return JSON only with this shape:",
    '{"fixtures":[{"id":"string","competition":{"id":"string","name":"string","country":{"name":"string","code":"string"},"logo":"url"},"season":"string","homeTeam":{"id":"string","name":"string","shortName":"string","logo":"url"},"awayTeam":{"id":"string","name":"string","shortName":"string","logo":"url"},"kickoffAt":"ISO datetime","status":"scheduled|live|finished|postponed|cancelled","homeScore":0,"awayScore":0,"round":"string","venue":{"name":"string","city":"string"}}]}',
    `Search query: ${env.openaiSearchQuery}`,
  ].join("\n");

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.openaiApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: env.openaiModel,
      tools: [{ type: env.openaiSearchTool }],
      input: prompt,
    }),
  });

  if (!response.ok) {
    summary.errors.push(`OpenAI web search HTTP ${response.status}: ${await response.text()}`);
    return [];
  }

  summary.openai_search_used += 1;
  const payload = await response.json();
  const text = collectOpenAIText(payload);
  const parsed = parseFirstJsonObject(text);
  if (!parsed) return [];
  summary.json_documents_seen += 1;
  return extractFixtureRows(parsed);
}

function collectOpenAIText(payload) {
  if (typeof payload.output_text === "string") return payload.output_text;
  const pieces = [];
  for (const item of payload.output ?? []) {
    for (const content of item.content ?? []) {
      if (typeof content.text === "string") pieces.push(content.text);
    }
  }
  return pieces.join("\n");
}

function parseFirstJsonObject(text) {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

function extractFixtureRows(payload) {
  if (env.fixtureArrayPath) {
    const value = getPath(payload, env.fixtureArrayPath);
    if (!Array.isArray(value)) {
      throw new Error(
        `LIVESCORE_FIXTURE_ARRAY_PATH did not resolve to an array: ${env.fixtureArrayPath}`,
      );
    }
    return value.filter(isRecord);
  }

  if (Array.isArray(payload)) return payload.filter(isRecord);

  const candidates = [];
  collectFixtureArrays(payload, candidates);
  candidates.sort((a, b) => b.length - a.length);
  return candidates[0] ?? [];
}

function collectFixtureArrays(value, candidates, depth = 0) {
  if (depth > 8 || value == null) return;
  if (Array.isArray(value)) {
    const records = value.filter(isRecord);
    if (records.length > 0 && records.some(looksLikeFixture)) {
      candidates.push(records);
    }
    for (const item of records.slice(0, 5)) {
      collectFixtureArrays(item, candidates, depth + 1);
    }
    return;
  }
  if (isRecord(value)) {
    for (const child of Object.values(value)) {
      collectFixtureArrays(child, candidates, depth + 1);
    }
  }
}

function looksLikeFixture(row) {
  return Boolean(
    pick(row, ["id", "Id", "eventId", "EventId", "matchId", "MatchId", "fixture.id"]) &&
      (pick(row, ["homeTeam.name", "home.name", "teams.home.name", "HomeTeam.Name"]) ||
        pick(row, ["awayTeam.name", "away.name", "teams.away.name", "AwayTeam.Name"])),
  );
}

function normalizeFixture(row, allowedCompetitions) {
  const fixtureId = stringValue(
    pick(row, [
      "id",
      "Id",
      "eventId",
      "EventId",
      "matchId",
      "MatchId",
      "fixture.id",
      "fixtureId",
    ]),
  );
  if (!fixtureId) return null;

  const competition = normalizeCompetition(row);
  const allowedCompetition = matchAllowedCompetition(row, competition, allowedCompetitions);
  const season = normalizeSeason(row, competition);
  const home = normalizeTeam(row, "home");
  const away = normalizeTeam(row, "away");
  if (!competition.name || !home.name || !away.name) return null;

  const score = normalizeScore(row);
  const status = mapStatus(
    stringValue(
      pick(row, [
        "status",
        "Status",
        "state",
        "State",
        "matchStatus",
        "fixture.status.short",
        "fixture.status.type",
        "status.short",
        "status.type",
        "status.name",
      ]),
    ),
  );

  return {
    externalFixtureId: fixtureId,
    competition,
    allowedCompetition,
    season,
    home,
    away,
    status,
    kickoffAt: dateValue(
      pick(row, [
        "kickoff",
        "kickoffAt",
        "startTime",
        "StartTime",
        "date",
        "fixture.date",
        "matchTime",
      ]),
    ),
    roundName: stringValue(
      pick(row, ["round", "Round", "league.round", "competition.round"]),
    ),
    venueName: stringValue(
      pick(row, ["venue.name", "Venue.Name", "fixture.venue.name"]),
    ),
    venueCity: stringValue(
      pick(row, ["venue.city", "Venue.City", "fixture.venue.city"]),
    ),
    homeScore: score.home,
    awayScore: score.away,
    metadata: {
      raw_status: stringValue(pick(row, ["status", "Status", "state", "State"])),
      livescore_fixture_id: fixtureId,
      allowed_competition_key: allowedCompetition?.key,
      allowed_competition_name: allowedCompetition?.name,
      source_url_count: sourceUrlCount(),
      synced_at: new Date().toISOString(),
    },
  };
}

function normalizeCompetition(row) {
  const obj =
    firstRecord(row, ["competition", "Competition", "league", "League", "tournament", "Tournament"]) ??
    {};
  const id = stringValue(
    pick(obj, ["id", "Id", "competitionId", "leagueId"]) ??
      pick(row, ["competitionId", "leagueId", "LeagueId"]),
  );
  const name =
    stringValue(pick(obj, ["name", "Name", "title", "Title"])) ||
    stringValue(pick(row, ["competitionName", "leagueName", "LeagueName"])) ||
    "LiveScore Competition";
  const countryName =
    stringValue(pick(obj, ["country.name", "countryName", "CountryName", "country"])) ||
    stringValue(pick(row, ["country.name", "countryName"])) ||
    null;
  const countryCode =
    stringValue(pick(obj, ["country.code", "countryCode", "CountryCode"])) ||
    stringValue(pick(row, ["country.code", "countryCode"])) ||
    null;
  const logoUrl =
    urlValue(pick(obj, ["logo", "logoUrl", "LogoUrl", "image", "badge"])) ||
    urlValue(pick(row, ["competitionLogo", "leagueLogo"]));

  return {
    externalId: id || slugify(`${name}-${countryName ?? "global"}`),
    name,
    shortName: name.length > 24 ? name.slice(0, 24) : name,
    slug: slugify(`${name}-${countryName ?? "global"}`),
    countryName,
    countryCode,
    logoUrl,
  };
}

function matchAllowedCompetition(row, competition, allowedCompetitions) {
  const obj =
    firstRecord(row, ["competition", "Competition", "league", "League", "tournament", "Tournament"]) ??
    {};
  const externalIdText = normalizeSearchText(competition.externalId);
  const haystack = normalizeSearchText(
    [
      competition.externalId,
      competition.name,
      competition.shortName,
      competition.slug,
      competition.countryName,
      competition.countryCode,
      pick(row, ["competitionName", "leagueName", "LeagueName", "tournamentName"]),
      pick(row, ["country.name", "countryName", "CountryName", "category.name"]),
      pick(row, ["country.code", "countryCode", "CountryCode", "category.code"]),
      pick(obj, ["id", "Id", "slug", "Slug", "name", "Name", "title", "Title"]),
      pick(obj, ["country.name", "countryName", "CountryName", "country"]),
      pick(obj, ["country.code", "countryCode", "CountryCode"]),
    ]
      .filter(Boolean)
      .join(" "),
  );
  const countryText = normalizeSearchText(
    [competition.countryName, competition.countryCode].filter(Boolean).join(" "),
  );

  for (const entry of allowedCompetitions) {
    if (externalIdText && entry.externalIds.includes(externalIdText)) {
      return entry;
    }

    const aliasMatches = entry.aliases.some((alias) => haystack.includes(alias));
    if (!aliasMatches) continue;

    if (entry.countryAliases.length === 0) return entry;
    const countryMatches = entry.countryAliases.some(
      (country) => countryText.includes(country) || haystack.includes(country),
    );
    if (countryMatches) return entry;
  }

  return null;
}

function normalizeSeason(row, competition) {
  const raw =
    stringValue(
      pick(row, [
        "season",
        "Season",
        "season.name",
        "season.year",
        "league.season",
        "competition.season",
      ]),
    ) || String(new Date().getFullYear());
  const year = Number(raw.match(/\d{4}/)?.[0] ?? new Date().getFullYear());
  return {
    label: raw,
    slug: slugify(`${competition.slug}-${raw}`),
    yearStart: year,
    yearEnd: year,
  };
}

function normalizeTeam(row, side) {
  const upper = side === "home" ? "Home" : "Away";
  const obj =
    firstRecord(row, [
      `${side}Team`,
      side,
      `teams.${side}`,
      `${upper}Team`,
      `${upper}`,
    ]) ?? {};
  const id = stringValue(
    pick(obj, ["id", "Id", "teamId", "TeamId"]) ??
      pick(row, [`${side}TeamId`, `${upper}TeamId`]),
  );
  const name =
    stringValue(pick(obj, ["name", "Name", "teamName", "TeamName"])) ||
    stringValue(pick(row, [`${side}TeamName`, `${upper}TeamName`]));
  const shortName =
    stringValue(pick(obj, ["shortName", "ShortName", "code", "Code"])) ||
    (name ? name.slice(0, 3).toUpperCase() : null);
  const logoUrl =
    urlValue(pick(obj, ["logo", "logoUrl", "LogoUrl", "crest", "badge", "image"])) ||
    urlValue(pick(row, [`${side}TeamLogo`, `${upper}TeamLogo`]));

  return {
    externalId: id || slugify(name ?? `${side}-team`),
    name,
    shortName,
    slug: slugify(name ?? `${side}-team`),
    logoUrl,
  };
}

function normalizeScore(row) {
  const home = numberOrNull(
    pick(row, [
      "homeScore",
      "HomeScore",
      "score.home",
      "goals.home",
      "scores.home",
      "home.score",
      "teams.home.score",
    ]),
  );
  const away = numberOrNull(
    pick(row, [
      "awayScore",
      "AwayScore",
      "score.away",
      "goals.away",
      "scores.away",
      "away.score",
      "teams.away.score",
    ]),
  );
  return { home, away };
}

function mapStatus(raw) {
  const value = String(raw ?? "").trim().toLowerCase();
  if (!value) return "scheduled";
  if (["ft", "aet", "pen", "finished", "fulltime", "ended", "complete", "completed"].includes(value)) {
    return "finished";
  }
  if (["1h", "2h", "ht", "et", "live", "in_play", "in-play", "playing"].includes(value)) {
    return "live";
  }
  if (["pst", "postponed", "delayed"].includes(value)) return "postponed";
  if (["canc", "cancelled", "canceled", "abd", "abandoned"].includes(value)) return "cancelled";
  return "scheduled";
}

async function upsertFixtureGraph(fixture) {
  const summary = emptySummary();

  const competitionAssetUrl = await maybeMirrorAsset(
    fixture.competition.logoUrl,
    `livescore/competitions/${fixture.competition.externalId}`,
  );
  if (competitionAssetUrl) summary.assets_mirrored += 1;

  const competition = await upsertOne(
    "football",
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
        storage_logo_url: competitionAssetUrl,
        source: PROVIDER,
      }),
    },
    "external_provider,external_competition_id",
    "id,slug",
  );
  summary.competitions_upserted += 1;

  const season = await upsertOne(
    "football",
    "seasons",
    {
      competition_id: competition.id,
      slug: fixture.season.slug,
      label: fixture.season.label,
      year_start: fixture.season.yearStart,
      year_end: fixture.season.yearEnd,
      status: "active",
      is_active: true,
      metadata: { source: PROVIDER },
    },
    "competition_id,label",
    "id,slug",
  );
  summary.seasons_upserted += 1;

  const home = await upsertTeam(fixture.home, summary);
  const away = await upsertTeam(fixture.away, summary);

  await upsertOne(
    "football",
    "season_teams",
    {
      season_id: season.id,
      team_id: home.id,
      is_active: true,
      metadata: { source: PROVIDER },
    },
    "season_id,team_id",
    "id",
  );
  await upsertOne(
    "football",
    "season_teams",
    {
      season_id: season.id,
      team_id: away.id,
      is_active: true,
      metadata: { source: PROVIDER },
    },
    "season_id,team_id",
    "id",
  );

  const savedFixture = await upsertOne(
    "football",
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

  if (savedFixture.status === "finished") {
    summary.pools_settled += await settlePoolsForFixture(savedFixture.id, summary);
  }

  return summary;
}

async function upsertTeam(team, summary) {
  const assetUrl = await maybeMirrorAsset(team.logoUrl, `livescore/teams/${team.externalId}`);
  if (assetUrl) summary.assets_mirrored += 1;

  const saved = await upsertOne(
    "football",
    "teams",
    {
      slug: team.slug,
      name: team.name,
      short_name: team.shortName,
      team_type: "club",
      crest_url: assetUrl ?? team.logoUrl,
      external_provider: PROVIDER,
      external_team_id: team.externalId,
      is_active: true,
      metadata: compactObject({
        livescore_logo_url: team.logoUrl,
        storage_logo_url: assetUrl,
        source: PROVIDER,
      }),
    },
    "external_provider,external_team_id",
    "id,slug",
  );
  summary.teams_upserted += 1;
  return saved;
}

async function settlePoolsForFixture(fixtureId, summary) {
  if (env.dryRun) return 0;

  const pools = await selectRows(
    "football",
    "partner_prediction_pools",
    `select=id,status&fixture_id=eq.${encodeURIComponent(fixtureId)}&status=in.(open,locked)`,
  );

  let settled = 0;
  for (const pool of pools) {
    try {
      if (!env.dryRun) {
        await rpc("partner_prediction_pool_settle", { p_pool_id: pool.id });
      }
      settled += 1;
    } catch (error) {
      summary.errors.push(`Pool ${pool.id}: ${messageOf(error)}`);
    }
  }
  return settled;
}

async function maybeMirrorAsset(sourceUrl, basePath) {
  if (!env.mirrorAssets || !sourceUrl) return null;
  const url = new URL(sourceUrl);
  const ext = extensionFromPath(url.pathname) || ".png";
  const storagePath = `${basePath}${ext}`;
  if (env.dryRun) return publicStorageUrl(storagePath);

  const response = await fetch(sourceUrl, {
    headers: { "User-Agent": "AFRICLUB-LiveScore-WebSync/1.0" },
  });
  if (!response.ok) {
    throw new Error(`asset HTTP ${response.status}: ${sourceUrl}`);
  }
  const contentType = response.headers.get("content-type") || contentTypeForExt(ext);
  const bytes = await response.arrayBuffer();

  const upload = await fetch(
    `${env.supabaseUrl}/storage/v1/object/${env.assetBucket}/${storagePath}`,
    {
      method: "POST",
      headers: {
        apikey: env.serviceRoleKey,
        Authorization: `Bearer ${env.serviceRoleKey}`,
        "Content-Type": contentType,
        "x-upsert": "true",
      },
      body: bytes,
    },
  );
  if (!upload.ok) {
    throw new Error(`storage upload HTTP ${upload.status}: ${await upload.text()}`);
  }
  return publicStorageUrl(storagePath);
}

async function ensureStorageBucket() {
  const response = await fetch(`${env.supabaseUrl}/storage/v1/bucket`, {
    method: "POST",
    headers: jsonHeaders(),
    body: JSON.stringify({
      id: env.assetBucket,
      name: env.assetBucket,
      public: true,
    }),
  });
  if (!response.ok && response.status !== 409) {
    const text = await response.text();
    if (!/already exists/i.test(text)) {
      throw new Error(`Could not ensure storage bucket: ${response.status} ${text}`);
    }
  }
}

async function upsertOne(schema, table, row, onConflict, select) {
  if (env.dryRun) {
    return {
      id: `dry-run-${schema}-${table}-${slugify(JSON.stringify(row).slice(0, 40))}`,
      ...row,
    };
  }
  const rows = await rest(
    schema,
    table,
    `on_conflict=${encodeURIComponent(onConflict)}&select=${encodeURIComponent(select)}`,
    {
      method: "POST",
      headers: {
        ...jsonHeaders(schema),
        Prefer: "resolution=merge-duplicates,return=representation",
      },
      body: JSON.stringify([row]),
    },
  );
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error(`Upsert returned no rows for ${schema}.${table}`);
  }
  return rows[0];
}

async function selectRows(schema, table, query) {
  return await rest(schema, table, query, {
    method: "GET",
    headers: jsonHeaders(schema),
  });
}

async function rpc(functionName, payload) {
  return await rest("public", `rpc/${functionName}`, "", {
    method: "POST",
    headers: jsonHeaders(),
    body: JSON.stringify(payload),
  });
}

async function rest(schema, table, query, init) {
  const glue = query ? `?${query}` : "";
  const response = await fetch(`${env.supabaseUrl}/rest/v1/${table}${glue}`, init);
  if (!response.ok) {
    throw new Error(`${schema}.${table} HTTP ${response.status}: ${await response.text()}`);
  }
  if (response.status === 204) return null;
  return await response.json();
}

function jsonHeaders(schema = "public") {
  const headers = {
    apikey: env.serviceRoleKey,
    Authorization: `Bearer ${env.serviceRoleKey}`,
    "Content-Type": "application/json",
  };
  if (schema !== "public") {
    headers["Accept-Profile"] = schema;
    headers["Content-Profile"] = schema;
  }
  return headers;
}

function parseUrlList(value) {
  return String(value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function sourceUrlCount() {
  return env.webUrls.length;
}

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function parseBoolean(value, fallback) {
  if (value == null || value === "") return fallback;
  return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

function pick(obj, paths) {
  for (const path of paths) {
    const value = getPath(obj, path);
    if (value != null && value !== "") return value;
  }
  return null;
}

function firstRecord(obj, paths) {
  for (const path of paths) {
    const value = getPath(obj, path);
    if (isRecord(value)) return value;
  }
  return null;
}

function getPath(obj, path) {
  return path.split(".").reduce((current, segment) => {
    if (current == null) return undefined;
    return current[segment];
  }, obj);
}

function isRecord(value) {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function arrayOfStrings(value) {
  if (Array.isArray(value)) {
    return value.map(stringValue).filter(Boolean);
  }
  const text = stringValue(value);
  if (!text) return [];
  return text
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function stringValue(value) {
  if (value == null) return null;
  const text = String(value).trim();
  return text === "" ? null : text;
}

function urlValue(value) {
  const text = stringValue(value);
  if (!text) return null;
  try {
    return new URL(text).toString();
  } catch {
    return null;
  }
}

function numberOrNull(value) {
  if (value == null || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function dateValue(value) {
  const text = stringValue(value);
  if (!text) return null;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 90) || "unknown";
}

function normalizeSearchText(value) {
  return String(value ?? "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function compactObject(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([, value]) => value != null && value !== ""),
  );
}

function extensionFromPath(pathname) {
  const match = pathname.match(/\.(png|jpg|jpeg|webp|svg)$/i);
  return match ? `.${match[1].toLowerCase()}` : "";
}

function contentTypeForExt(ext) {
  switch (ext) {
    case ".svg":
      return "image/svg+xml";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".webp":
      return "image/webp";
    default:
      return "image/png";
  }
}

function publicStorageUrl(path) {
  return `${env.supabaseUrl}/storage/v1/object/public/${env.assetBucket}/${path}`;
}

function messageOf(error) {
  return error instanceof Error ? error.message : String(error);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
