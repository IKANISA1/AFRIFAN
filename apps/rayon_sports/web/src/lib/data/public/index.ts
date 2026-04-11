/**
 * Public data layer — barrel re-export.
 *
 * Stable import path: `@/lib/data/public`
 *
 * Decomposed from the 738-line monolithic public.ts:
 *   ✅ helpers.ts     — table resolution, media URL sanitizer
 *   ✅ club.ts        — club profile
 *   ✅ matches.ts     — fixtures
 *   ✅ news.ts        — news articles
 *   ✅ shop.ts        — shop products
 *   ✅ community.ts   — membership, fan clubs, contributions, standings, squad
 */
import { cache } from "react";
import { staticSearchItems } from "@/lib/content";
import type { SearchIndexItem } from "@/lib/types";

// Domain re-exports
export { getClubProfile } from "./club";
export { getMatches, getMatchById } from "./matches";
export { getNewsArticles, getNewsArticleById } from "./news";
export { getProducts, getProductById } from "./shop";
export {
  getHomeBanners,
  getCmsContent,
  getCmsContentBlock,
  getAppConfig,
  getConfigValue,
} from "./cms";
export {
  getFantasyCompetitions,
  getFeaturedFantasyCompetition,
  getFantasyCompetitionBySlug,
  getFantasyLeaderboard,
} from "./fantasy";
export {
  getMembershipPackages,
  getFanClubs,
  getContributionGroups,
  getStandings,
  getSquad,
} from "./community";

// Composite fetchers (import from extracted modules)
import { getClubProfile } from "./club";
import { getMatches } from "./matches";
import { getNewsArticles } from "./news";
import { getProducts } from "./shop";
import { getFantasyCompetitions } from "./fantasy";
import {
  getMembershipPackages,
  getFanClubs,
  getContributionGroups,
  getStandings,
} from "./community";

export const getHomePageData = cache(async function getHomePageData() {
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
});

export const getSiteSearchIndex = cache(async function getSiteSearchIndex(): Promise<SearchIndexItem[]> {
  const [matches, news, products, groups, fantasyCompetitions] = await Promise.all([
    getMatches(),
    getNewsArticles(),
    getProducts(),
    getContributionGroups(),
    getFantasyCompetitions(),
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
    ...fantasyCompetitions.slice(0, 6).map((competition) => ({
      id: `fantasy-${competition.id}`,
      title: competition.name,
      description: competition.description,
      href: `/fantasy/${competition.slug}`,
      category: "Fantasy" as const,
      meta: competition.season,
    })),
  ];
});
