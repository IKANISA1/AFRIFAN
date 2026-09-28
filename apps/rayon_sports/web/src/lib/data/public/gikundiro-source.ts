import type { MatchItem, NewsArticle } from "@/lib/types";

type SourceFixture = {
  sourceId: string;
  homeTeam: string;
  awayTeam: string;
  competition: string;
  venue: string;
  kickoffAt: string;
  roundLabel: string;
  sourceUrl: string;
};

type SourceNews = {
  sourceId: string;
  title: string;
  excerpt: string;
  category: string;
  publishedAt: string;
  publisher: string;
  sourceUrl: string;
};

type SourcePayload = {
  schemaVersion: number;
  fixtures: SourceFixture[];
  news: SourceNews[];
};

const sourceHost = "loxcwbfukbqziuxgkfcm.supabase.co";
const stagingHost = "africlub-rayon-public-staging.ikanisa.workers.dev";

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function validHttpsUrl(value: unknown): string {
  try {
    const url = new URL(text(value));
    return url.protocol === "https:" ? url.href : "";
  } catch {
    return "";
  }
}

function kigaliDateParts(value: string) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Africa/Kigali",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(value));
  const fields = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    date: `${fields.year}-${fields.month}-${fields.day}`,
    time: `${fields.hour}:${fields.minute}`,
  };
}

export function mapGikundiroFixtures(value: unknown, now = new Date()): MatchItem[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  return value.flatMap((candidate) => {
    if (!record(candidate)) return [];
    const id = text(candidate.sourceId);
    const kickoffAt = text(candidate.kickoffAt);
    const kickoff = Date.parse(kickoffAt);
    if (!id || seen.has(id) || !Number.isFinite(kickoff) || kickoff <= now.getTime()
      || !text(candidate.homeTeam) || !text(candidate.awayTeam)
      || !text(candidate.competition) || !validHttpsUrl(candidate.sourceUrl)) return [];
    seen.add(id);
    const local = kigaliDateParts(kickoffAt);
    return [{
      id: `gikundiro-${id}`,
      homeTeam: text(candidate.homeTeam),
      awayTeam: text(candidate.awayTeam),
      competition: text(candidate.competition),
      venue: text(candidate.venue) || "Venue TBC",
      matchDate: local.date,
      kickoffTime: local.time,
      isOnSale: false,
      generalPrice: 0,
      vipPrice: 0,
      imageUrl: null,
      matchStatus: "scheduled",
      homeScore: 0,
      awayScore: 0,
      liveMinute: null,
      matchSummary: text(candidate.roundLabel) || null,
      liveEvents: [],
      liveStats: {},
      isFeatured: false,
    } satisfies MatchItem];
  }).sort((left, right) => `${left.matchDate}T${left.kickoffTime}`.localeCompare(`${right.matchDate}T${right.kickoffTime}`));
}

export function mapGikundiroNews(value: unknown, now = new Date()): NewsArticle[] {
  if (!Array.isArray(value)) return [];
  const cutoff = new Date(now);
  cutoff.setUTCMonth(cutoff.getUTCMonth() - 3);
  const seen = new Set<string>();
  return value.flatMap((candidate) => {
    if (!record(candidate)) return [];
    const id = text(candidate.sourceId);
    const publishedAt = text(candidate.publishedAt);
    const published = Date.parse(publishedAt);
    const sourceUrl = validHttpsUrl(candidate.sourceUrl);
    if (!id || seen.has(id) || !Number.isFinite(published)
      || published > now.getTime() || published < cutoff.getTime()
      || !text(candidate.title) || !text(candidate.excerpt)
      || !text(candidate.publisher) || !sourceUrl) return [];
    seen.add(id);
    return [{
      id: `gikundiro-${id}`,
      title: text(candidate.title),
      excerpt: text(candidate.excerpt),
      content: text(candidate.excerpt),
      category: text(candidate.category) || "Club news",
      coverImageUrl: null,
      publishedAt,
      author: text(candidate.publisher),
      sourceUrl,
    } satisfies NewsArticle];
  }).sort((left, right) => Date.parse(right.publishedAt) - Date.parse(left.publishedAt));
}

export async function loadGikundiroPublicSource(): Promise<SourcePayload | null> {
  const cloudflare = process.env.RAYON_PUBLIC_CLOUDFLARE_URL?.trim();
  if (cloudflare) {
    const base = new URL(cloudflare);
    if (base.protocol !== "https:" || base.hostname !== stagingHost ||
        base.pathname !== "/" || base.search || base.hash || base.username || base.password) {
      throw new Error("Rayon Cloudflare public source URL is invalid.");
    }
    async function read(route: "fixtures" | "news"): Promise<Record<string, unknown>[]> {
      const response = await fetch(new URL(`/v1/public/rayon/${route}`, base), {
        headers: { Accept: "application/json" },
        next: { revalidate: 60 },
        signal: AbortSignal.timeout(6_000),
      });
      if (!response.ok) throw new Error(`Rayon Cloudflare ${route} source is unavailable.`);
      const value: unknown = await response.json();
      if (!record(value) || value.schemaVersion !== 1 || value.route !== route ||
          !Array.isArray(value.rows)) throw new Error(`Rayon Cloudflare ${route} source is invalid.`);
      const captured = Date.parse(text(value.sourceCapturedAt));
      if (!Number.isFinite(captured) || captured > Date.now() + 5 * 60_000 ||
          Date.now() - captured > 24 * 60 * 60_000) {
        throw new Error(`Rayon Cloudflare ${route} source is stale.`);
      }
      return value.rows.filter(record);
    }
    const [fixtures, news] = await Promise.all([read("fixtures"), read("news")]);
    return {
      schemaVersion: 1,
      fixtures: fixtures.map((row) => ({
        sourceId: text(row.sourceId), homeTeam: text(row.homeTeam),
        awayTeam: text(row.awayTeam), competition: text(row.competition),
        venue: text(row.venue), kickoffAt: text(row.kickoffAt),
        roundLabel: text(row.roundLabel), sourceUrl: text(row.sourceUrl),
      })),
      news: news.map((row) => ({
        sourceId: text(row.id).replace(/^gikundiro-/, ""), title: text(row.title),
        excerpt: text(row.excerpt), category: text(row.category),
        publishedAt: text(row.publishedAt), publisher: text(row.author),
        sourceUrl: text(row.sourceUrl),
      })),
    };
  }
  const configured = process.env.GIKUNDIRO_PUBLIC_SUPABASE_URL?.trim();
  const key = process.env.GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY?.trim();
  if (!configured || !key) return null;
  const base = new URL(configured);
  if (base.protocol !== "https:" || base.hostname !== sourceHost || base.pathname !== "/") {
    throw new Error("Gikundiro public source URL is invalid.");
  }
  async function rows(table: string, params: Record<string, string>): Promise<Record<string, unknown>[]> {
    const url = new URL(`/rest/v1/${table}`, base);
    for (const [name, value] of Object.entries(params)) url.searchParams.set(name, value);
    const response = await fetch(url, {
      headers: { apikey: key!, Authorization: `Bearer ${key}`, Accept: "application/json" },
      next: { revalidate: 60 },
      signal: AbortSignal.timeout(6_000),
    });
    if (!response.ok) throw new Error(`Gikundiro public ${table} source is unavailable.`);
    const value: unknown = await response.json();
    if (!Array.isArray(value)) throw new Error(`Gikundiro public ${table} source is invalid.`);
    return value.filter(record);
  }

  const club = (await rows("clubs", { select: "id", slug: "eq.rayon-sports", limit: "1" }))[0];
  const clubId = text(club?.id);
  if (!clubId) throw new Error("Gikundiro Rayon Sports club is unavailable.");
  const now = new Date();
  const cutoff = new Date(now);
  cutoff.setUTCMonth(cutoff.getUTCMonth() - 3);
  const publicFilters = { club_id: `eq.${clubId}`, approval_status: "eq.approved", active: "eq.true", visibility: "eq.public" };
  const [teams, competitions, fixtures, posts] = await Promise.all([
    rows("prediction_teams", { select: "id,name,is_rayon_sports", club_id: `eq.${clubId}`, limit: "500" }),
    rows("prediction_competitions", { select: "id,name", club_id: `eq.${clubId}`, active: "eq.true", limit: "100" }),
    rows("prediction_fixtures", {
      select: "id,competition_id,home_team_id,away_team_id,starts_at,venue,schedule_status,round_label,source_url,source_publication_id",
      ...publicFilters,
      schedule_status: "eq.confirmed",
      starts_at: `gt.${now.toISOString()}`,
      order: "starts_at.asc",
      limit: "500",
    }),
    rows("news_posts", {
      select: "id,title,excerpt,category,source_label,source_url,published_at,post_type",
      ...publicFilters,
      status: "eq.published",
      post_type: "eq.news_feed",
      published_at: `gte.${cutoff.toISOString()}`,
      and: `(published_at.lte.${now.toISOString()})`,
      order: "published_at.desc",
      limit: "100",
    }),
  ]);
  const teamById = new Map(teams.map((team) => [text(team.id), team]));
  const competitionById = new Map(competitions.map((competition) => [text(competition.id), competition]));
  return {
    schemaVersion: 1,
    fixtures: fixtures.flatMap((row): SourceFixture[] => {
      const home = teamById.get(text(row.home_team_id));
      const away = teamById.get(text(row.away_team_id));
      const competition = competitionById.get(text(row.competition_id));
      const sourceUrl = validHttpsUrl(row.source_url);
      const kickoffAt = text(row.starts_at);
      if (!(home?.is_rayon_sports === true || away?.is_rayon_sports === true)
        || !text(row.source_publication_id) || !sourceUrl || !text(home?.name)
        || !text(away?.name) || !text(competition?.name)
        || !Number.isFinite(Date.parse(kickoffAt)) || Date.parse(kickoffAt) <= now.getTime()) return [];
      return [{
        sourceId: text(row.id), homeTeam: text(home?.name), awayTeam: text(away?.name),
        competition: text(competition?.name), venue: text(row.venue), kickoffAt,
        roundLabel: text(row.round_label), sourceUrl,
      }];
    }),
    news: posts.flatMap((row): SourceNews[] => {
      const sourceUrl = validHttpsUrl(row.source_url);
      const publishedAt = text(row.published_at);
      if (!sourceUrl || !text(row.id) || !text(row.title) || !text(row.excerpt)
        || !Number.isFinite(Date.parse(publishedAt)) || Date.parse(publishedAt) > now.getTime()) return [];
      const suppliedPublisher = text(row.source_label);
      const publisher = suppliedPublisher && !/\b(?:coverage|discovery|aggregat(?:e|or)|across\s+.+media)\b/i.test(suppliedPublisher)
        ? suppliedPublisher : new URL(sourceUrl).hostname.replace(/^www\./, "");
      return [{
        sourceId: text(row.id), title: text(row.title), excerpt: text(row.excerpt),
        category: text(row.category) || "Club news", publishedAt, publisher, sourceUrl,
      }];
    }),
  };
}
