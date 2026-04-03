import {
  fallbackClubProfile,
  fallbackContributionGroups,
  fallbackFanClubs,
  fallbackMatches,
  fallbackMembershipPackages,
  fallbackNewsArticles,
  fallbackProducts,
  fallbackStandings,
  fallbackSquad,
  staticSearchItems,
} from "@/lib/content";
import { rayonClub } from "@/lib/config";
import { getAdminSupabase } from "@/lib/supabase/admin";
import type {
  ClubProfile,
  ContributionGroup,
  FanClubItem,
  MatchItem,
  MembershipPackage,
  NewsArticle,
  SearchIndexItem,
  ShopProduct,
  SquadPlayer,
  StandingRow,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";

const newsTableCandidates = ["news_articles", "rs_news_articles"];
const productTableCandidates = ["shop_products", "rs_shop_products"];
const squadTableCandidates = [
  "squad_players",
  "players",
  "club_players",
  "rs_squad_players",
];
const standingsTableCandidates = [
  "standings",
  "league_standings",
  "club_standings",
  "rs_standings",
];

function sanitizeMediaUrl(value: unknown, fallback: string) {
  const candidate = safeString(value);
  if (!candidate) {
    return fallback;
  }

  if (candidate.startsWith("/")) {
    return candidate;
  }

  try {
    const parsed = new URL(candidate);
    if (parsed.hostname.endsWith(".supabase.co")) {
      return candidate;
    }
  } catch {}

  return fallback;
}

function mapClubRow(row: Record<string, unknown>): ClubProfile {
  return {
    id: safeNumber(row.id, rayonClub.numericId),
    clubName: safeString(row.club_name, fallbackClubProfile.clubName),
    clubSlug: safeString(row.club_slug, fallbackClubProfile.clubSlug),
    shortName: fallbackClubProfile.shortName,
    nickname: safeString(
      row.nickname_brand_identity,
      fallbackClubProfile.nickname,
    ),
    countryCode: safeString(
      row.country_iso_code,
      fallbackClubProfile.countryCode,
    ),
    league: safeString(row.league, fallbackClubProfile.league),
    region: safeString(row.region, fallbackClubProfile.region),
    currencyCode: safeString(
      row.currency_code,
      fallbackClubProfile.currencyCode,
    ),
    currencySymbol: safeString(
      row.currency_symbol,
      fallbackClubProfile.currencySymbol,
    ),
    defaultLanguage: safeString(
      row.default_language,
      fallbackClubProfile.defaultLanguage,
    ),
    supportedLanguages: Array.isArray(row.supported_languages)
      ? row.supported_languages
          .map((entry) => safeString(entry))
          .filter(Boolean)
      : fallbackClubProfile.supportedLanguages,
    officialContact: safeString(
      row.official_contact,
      fallbackClubProfile.officialContact,
    ),
    facebookUrl: safeString(row.facebook_url) || null,
    xUrl: safeString(row.x_twitter_url) || null,
    instagramUrl: safeString(row.instagram_url) || null,
    tiktokUrl: safeString(row.tiktok_url) || null,
    officialLogoUrl: sanitizeMediaUrl(
      row.official_logo_url,
      fallbackClubProfile.officialLogoUrl ?? "/media/rayon-crest.png",
    ),
    primaryColorHex: safeString(
      row.primary_color_hex,
      fallbackClubProfile.primaryColorHex,
    ),
    secondaryColorHex: safeString(
      row.secondary_color_hex,
      fallbackClubProfile.secondaryColorHex,
    ),
    accentColorHex: safeString(
      row.accent_color_hex,
      fallbackClubProfile.accentColorHex,
    ),
    featureFlags:
      typeof row.feature_flags == "object" && row.feature_flags != null
        ? (row.feature_flags as Record<string, boolean>)
        : fallbackClubProfile.featureFlags,
  };
}

function mapMatchRow(row: Record<string, unknown>): MatchItem {
  const liveEvents = Array.isArray(row.live_events)
    ? row.live_events
        .map((event, index) => {
          if (typeof event != "object" || event == null) {
            return {
              minute: `${index + 1}'`,
              event: "Match event",
              side: "home" as const,
            };
          }
          return {
            minute: safeString(
              (event as Record<string, unknown>).minute,
              `${index + 1}'`,
            ),
            event: safeString(
              (event as Record<string, unknown>).event,
              "Live event",
            ),
            side:
              safeString((event as Record<string, unknown>).side) == "away"
                ? ("away" as const)
                : ("home" as const),
          };
        })
        .slice(0, 6)
    : [];

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    homeTeam: safeString(row.home_team, "Rayon Sports"),
    awayTeam: safeString(row.away_team, "Opponent"),
    competition: safeString(row.competition, "League"),
    venue: safeString(row.venue, "Kigali"),
    matchDate: safeString(row.match_date, new Date().toISOString()),
    kickoffTime: safeString(row.kickoff_time) || null,
    isOnSale: Boolean(row.is_on_sale),
    generalPrice: safeNumber(row.ticket_general_price, 0),
    vipPrice: safeNumber(row.ticket_vip_price, 0),
    imageUrl: sanitizeMediaUrl(row.image_url, "/media/stadium-hero.jpg"),
    matchStatus: safeString(row.match_status, "scheduled"),
    homeScore: safeNumber(row.home_score, 0),
    awayScore: safeNumber(row.away_score, 0),
    liveMinute:
      row.live_minute == null ? null : safeNumber(row.live_minute, 0),
    matchSummary: safeString(row.match_summary) || null,
    liveEvents,
    liveStats:
      typeof row.live_stats == "object" && row.live_stats != null
        ? (row.live_stats as Record<string, number | string>)
        : {},
    isFeatured: Boolean(row.is_featured),
  };
}

function mapNewsRow(row: Record<string, unknown>): NewsArticle {
  const content =
    safeString(row.content) ||
    safeString(row.body) ||
    safeString(row.summary) ||
    safeString(row.excerpt) ||
    "Club article body not available yet.";
  const excerptCandidate =
    safeString(row.excerpt) ||
    safeString(row.summary) ||
    safeString(content)
      .replace(/\s+/g, " ")
      .slice(0, 180)
      .trim();

  return {
    id:
      safeString(row.slug) ||
      safeString(row.article_id) ||
      toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, "Club update"),
    excerpt: excerptCandidate || "Rayon Sports club update.",
    content,
    category: safeString(row.category, "Club"),
    coverImageUrl: sanitizeMediaUrl(
      safeString(row.cover_image_url) || safeString(row.image_url),
      "/media/stadium-hero.jpg",
    ),
    publishedAt: safeString(
      row.published_at,
      safeString(row.created_at, new Date().toISOString()),
    ),
    author: safeString(row.author_name, "Club Media"),
  };
}

function mapProductRow(row: Record<string, unknown>): ShopProduct {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Supporter product"),
    subtitle: safeString(row.subtitle, "Official club merchandise"),
    description:
      safeString(row.description) ||
      safeString(row.subtitle) ||
      "Official product listing.",
    category: safeString(row.category, "Merch"),
    price: safeNumber(row.price, 0),
    imageUrl: sanitizeMediaUrl(row.image_url, "/media/stadium-hero.jpg"),
    sizes: Array.isArray(row.sizes)
      ? row.sizes.map((entry) => safeString(entry)).filter(Boolean)
      : ["One Size"],
    isActive: row.is_active !== false,
    collection: safeString(row.collection) || null,
  };
}

function mapStandingRow(row: Record<string, unknown>, index: number): StandingRow {
  const club = safeString(
    row.club_name,
    safeString(row.club, safeString(row.team_name, `Club ${index + 1}`)),
  );
  const form = Array.isArray(row.form)
    ? row.form.map((entry) => safeString(entry)).filter(Boolean).slice(0, 5)
    : [];

  return {
    position: safeNumber(row.position, index + 1),
    club,
    played: safeNumber(row.played, safeNumber(row.matches_played, 0)),
    goalDifference: safeNumber(
      row.goal_difference,
      safeNumber(row.gd, safeNumber(row.goal_diff, 0)),
    ),
    points: safeNumber(row.points, safeNumber(row.pts, 0)),
    form,
    highlight:
      safeString(row.club_slug) === rayonClub.slug ||
      club.toLowerCase().includes("rayon"),
  };
}

function mapMembershipRow(row: Record<string, unknown>): MembershipPackage {
  const title = safeString(row.title, "Membership tier");
  const description = safeString(
    row.description,
    "Priority access and supporter benefits across club channels.",
  );
  const tierValue = safeString(row.tier).toLowerCase();
  const benefits = Array.isArray(row.benefits)
    ? row.benefits
        .map((item) => safeString(item))
        .filter(Boolean)
        .slice(0, 4)
    : [];
  const fallbackTier =
    fallbackMembershipPackages.find((entry) => entry.tier === tierValue) ??
    fallbackMembershipPackages.find(
      (entry) => entry.title.toLowerCase() === title.toLowerCase(),
    ) ??
    null;
  const annualPrice = safeNumber(
    row.annual_price,
    safeNumber(row.price, fallbackTier?.annualPrice ?? 0),
  );

  return {
    id: toIdString(row.id, crypto.randomUUID()),
    tier:
      tierValue == "gold"
        ? "gold"
        : tierValue == "platinum"
          ? "platinum"
          : tierValue == "bronze"
            ? "bronze"
            : "fan",
    title,
    description,
    sortOrder: safeNumber(row.sort_order, 0),
    annualPrice,
    perks:
      benefits.length > 0
        ? benefits
        : description.split(/[.;]/).filter((item) => item.trim().length > 2).length > 0
        ? description
            .split(/[.;]/)
            .map((item) => item.trim())
            .filter((item) => item.length > 2)
            .slice(0, 4)
        : ["Priority access", "Supporter identity", "Club communications"],
  };
}

function mapSquadRow(row: Record<string, unknown>): SquadPlayer {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Squad player"),
    role:
      safeString(row.role) ||
      safeString(row.position) ||
      safeString(row.primary_position, "Player"),
    number: safeNumber(row.number, safeNumber(row.shirt_number, 0)),
    nationality: safeString(row.nationality, "Rwanda"),
    bio:
      safeString(row.bio) ||
      safeString(row.description) ||
      safeString(row.player_summary) ||
      "Rayon Sports first-team squad member.",
  };
}

function mapFanClubRow(row: Record<string, unknown>): FanClubItem {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Supporter chapter"),
    region: safeString(row.region, "Official"),
    description: safeString(
      row.description,
      "A Rayon Sports supporter chapter.",
    ),
    memberCount: safeNumber(row.member_count, 0),
    eventCount: safeNumber(row.event_count, 0),
    rating: safeNumber(row.rating, 0),
    bannerImageUrl: sanitizeMediaUrl(row.banner_image_url, "/media/stadium-hero.jpg"),
  };
}

function mapContributionGroupRow(row: Record<string, unknown>): ContributionGroup {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Support circle"),
    description: safeString(
      row.description,
      "Supporters pooling funds around club activity.",
    ),
    privacy: safeString(row.privacy) == "public" ? "public" : "private",
    groupType:
      safeString(row.group_type) == "project" ||
      safeString(row.group_type) == "savings" ||
      safeString(row.group_type) == "emergency"
        ? (safeString(row.group_type) as ContributionGroup["groupType"])
        : "general",
    targetAmount: safeNumber(row.target_amount, 0),
    currentTotal: safeNumber(row.current_total, 0),
    currency: safeString(row.currency, "RWF"),
    memberCount: safeNumber(row.member_count, 0),
    inviteCode: safeString(row.invite_code) || null,
    isActive: row.is_closed !== true && row.is_active !== false,
  };
}

async function resolveAccessibleTable(
  client: NonNullable<ReturnType<typeof getAdminSupabase>>,
  candidates: string[],
) {
  for (const table of candidates) {
    const { error } = await client.from(table).select("id").limit(1);
    if (!error) {
      return table;
    }
  }

  return candidates[0];
}

export async function getClubProfile() {
  const client = getAdminSupabase();
  if (client == null) return fallbackClubProfile;

  try {
    const { data } = await client
      .from("african_football_clubs")
      .select("*")
      .eq("club_slug", rayonClub.slug)
      .maybeSingle();

    return data ? mapClubRow(data) : fallbackClubProfile;
  } catch {
    return fallbackClubProfile;
  }
}

export async function getMatches() {
  const client = getAdminSupabase();
  if (client == null) return fallbackMatches;

  try {
    const { data } = await client
      .from("matches")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("match_date", { ascending: true })
      .limit(12);

    if (!data || data.length == 0) return fallbackMatches;
    return data.map((row) => mapMatchRow(row));
  } catch {
    return fallbackMatches;
  }
}

export async function getMatchById(matchId: string) {
  const matches = await getMatches();
  return matches.find((match) => match.id === matchId) ?? null;
}

export async function getNewsArticles() {
  const client = getAdminSupabase();
  if (client == null) return fallbackNewsArticles;

  try {
    const table = await resolveAccessibleTable(client, newsTableCandidates);
    const { data } = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .eq("is_published", true)
      .order("published_at", { ascending: false })
      .limit(12);

    if (!data || data.length == 0) return fallbackNewsArticles;
    return data.map((row) => mapNewsRow(row));
  } catch {
    return fallbackNewsArticles;
  }
}

export async function getNewsArticleById(articleId: string) {
  const articles = await getNewsArticles();
  return articles.find((article) => article.id === articleId) ?? null;
}

export async function getProducts() {
  const client = getAdminSupabase();
  if (client == null) return fallbackProducts;

  try {
    const table = await resolveAccessibleTable(client, productTableCandidates);
    const { data } = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(12);

    if (!data || data.length == 0) return fallbackProducts;
    return data.map((row) => mapProductRow(row));
  } catch {
    return fallbackProducts;
  }
}

export async function getProductById(productId: string) {
  const products = await getProducts();
  return products.find((product) => product.id === productId) ?? null;
}

export async function getMembershipPackages() {
  const client = getAdminSupabase();
  if (client == null) return fallbackMembershipPackages;

  try {
    const scoped = await client
      .from("membership_packages")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(6);

    if (scoped.data && scoped.data.length > 0) {
      return scoped.data.map((row) => mapMembershipRow(row));
    }

    const fallbackQuery = await client
      .from("membership_packages")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(6);

    if (!fallbackQuery.data || fallbackQuery.data.length == 0) {
      return fallbackMembershipPackages;
    }

    return fallbackQuery.data.map((row) => mapMembershipRow(row));
  } catch {
    return fallbackMembershipPackages;
  }
}

export async function getFanClubs() {
  const client = getAdminSupabase();
  if (client == null) return fallbackFanClubs;

  try {
    const scoped = await client
      .from("fan_clubs")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("member_count", { ascending: false })
      .limit(12);

    if (scoped.data && scoped.data.length > 0) {
      return scoped.data.map((row) => mapFanClubRow(row));
    }

    const fallbackQuery = await client
      .from("fan_clubs")
      .select("*")
      .order("member_count", { ascending: false })
      .limit(12);

    if (!fallbackQuery.data || fallbackQuery.data.length == 0) {
      return fallbackFanClubs;
    }

    return fallbackQuery.data.map((row) => mapFanClubRow(row));
  } catch {
    return fallbackFanClubs;
  }
}

export async function getContributionGroups() {
  const client = getAdminSupabase();
  if (client == null) return fallbackContributionGroups;

  try {
    const scoped = await client
      .from("contribution_groups")
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .eq("is_active", true)
      .order("created_at", { ascending: false })
      .limit(8);

    if (scoped.data && scoped.data.length > 0) {
      return scoped.data.map((row) => mapContributionGroupRow(row));
    }

    const fallbackQuery = await client
      .from("contribution_groups")
      .select("*")
      .eq("is_closed", false)
      .order("created_at", { ascending: false })
      .limit(8);

    if (!fallbackQuery.data || fallbackQuery.data.length == 0) {
      return fallbackContributionGroups;
    }

    return fallbackQuery.data.map((row) => mapContributionGroupRow(row));
  } catch {
    return fallbackContributionGroups;
  }
}

export async function getStandings(): Promise<StandingRow[]> {
  const client = getAdminSupabase();
  if (client == null) {
    return fallbackStandings;
  }

  try {
    const table = await resolveAccessibleTable(client, standingsTableCandidates);
    const scopedQuery = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("position", { ascending: true })
      .limit(20);

    if (scopedQuery.data && scopedQuery.data.length >= 6) {
      return scopedQuery.data.map((row, index) => mapStandingRow(row, index));
    }

    const fallbackQuery = await client
      .from(table)
      .select("*")
      .order("position", { ascending: true })
      .limit(20);

    if (fallbackQuery.data && fallbackQuery.data.length > 0) {
      return fallbackQuery.data.map((row, index) => mapStandingRow(row, index));
    }
  } catch {}

  return fallbackStandings;
}

export async function getSquad(): Promise<SquadPlayer[]> {
  const client = getAdminSupabase();
  if (client == null) {
    return fallbackSquad;
  }

  try {
    const table = await resolveAccessibleTable(client, squadTableCandidates);
    const scopedQuery = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
      .order("shirt_number", { ascending: true })
      .limit(30);

    if (scopedQuery.data && scopedQuery.data.length > 0) {
      return scopedQuery.data.map((row) => mapSquadRow(row));
    }

    const fallbackQuery = await client
      .from(table)
      .select("*")
      .order("shirt_number", { ascending: true })
      .limit(30);

    if (fallbackQuery.data && fallbackQuery.data.length > 0) {
      return fallbackQuery.data.map((row) => mapSquadRow(row));
    }
  } catch {}

  return fallbackSquad;
}

export async function getHomePageData() {
  const [club, matches, news, products, membershipPackages, fanClubs, groups, standings] =
    await Promise.all([
      getClubProfile(),
      getMatches(),
      getNewsArticles(),
      getProducts(),
      getMembershipPackages(),
      getFanClubs(),
      getContributionGroups(),
      getStandings(),
    ]);

  const featuredMatch =
    matches.find((match) => match.matchStatus === "live") ??
    matches.find((match) => match.isFeatured) ??
    matches.find((match) => match.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  return {
    club,
    featuredMatch,
    matches,
    news,
    products,
    membershipPackages,
    fanClubs,
    contributionGroups: groups,
    standings,
  };
}

export async function getSiteSearchIndex(): Promise<SearchIndexItem[]> {
  const [matches, news, products, groups] = await Promise.all([
    getMatches(),
    getNewsArticles(),
    getProducts(),
    getContributionGroups(),
  ]);

  return [
    ...staticSearchItems,
    ...matches.slice(0, 8).map((match) => ({
      id: `match-${match.id}`,
      title: `${match.homeTeam} vs ${match.awayTeam}`,
      description:
        match.matchSummary ??
        `${match.competition} at ${match.venue}.`,
      href: `/fixtures/${match.id}`,
      category: "Match" as const,
      meta: match.matchStatus,
    })),
    ...news.slice(0, 8).map((article) => ({
      id: `news-${article.id}`,
      title: article.title,
      description: article.excerpt,
      href: `/news/${article.id}`,
      category: "News" as const,
      meta: article.category,
    })),
    ...products.slice(0, 8).map((product) => ({
      id: `product-${product.id}`,
      title: product.name,
      description: product.subtitle,
      href: `/shop/${product.id}`,
      category: "Shop" as const,
      meta: product.category,
    })),
    ...groups.slice(0, 6).map((group) => ({
      id: `group-${group.id}`,
      title: group.name,
      description: group.description,
      href: "/circles",
      category: "Community" as const,
      meta: group.groupType,
    })),
  ];
}
