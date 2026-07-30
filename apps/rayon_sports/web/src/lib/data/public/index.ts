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
import type { SearchIndexItem } from "@/lib/types";
import { getPlatformConfig, getSiteSearchItems } from "@/lib/feature-config";

// Domain re-exports
export { getClubProfile } from "./club";
export {
  getMatches,
  getMatchesStrict,
  getMatchById,
  getMatchByIdStrict,
} from "./matches";
export {
  getNewsArticles,
  getNewsArticlesStrict,
  getNewsArticleById,
  getNewsArticleByIdStrict,
} from "./news";
export {
  getProducts,
  getProductsStrict,
  getProductById,
  getProductByIdStrict,
} from "./shop";
export {
  getHomeBanners,
  getCmsContent,
  getCmsContentStrict,
  getCmsContentBlock,
  getAppConfig,
  getConfigValue,
} from "./cms";
export {
  getFanEngagementTokens,
  getFanEngagementLeaderboard,
} from "./gamification";
export {
  getMembershipPackages,
  getMembershipPackagesStrict,
  getFanClubs,
  getFanClubsStrict,
  getContributionGroups,
  getContributionGroupsStrict,
  getStandings,
  getStandingsStrict,
  getSquad,
  getSquadStrict,
} from "./community";

// Composite fetchers (import from extracted modules)
import { getClubProfile } from "./club";
import { getMatches } from "./matches";
import { getNewsArticles } from "./news";
import { getProducts } from "./shop";
import { getFanEngagementLeaderboard } from "./gamification";
import {
  getMembershipPackages,
  getFanClubs,
  getContributionGroups,
  getStandings,
} from "./community";

export const getHomePageData = cache(async function getHomePageData() {
  const [
    club,
    matches,
    news,
    products,
    membershipPackages,
    fanClubs,
    groups,
    standings,
  ] = await Promise.all([
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

export const getSiteSearchIndex = cache(
  async function getSiteSearchIndex(): Promise<SearchIndexItem[]> {
    const [platformConfig, matches, news, products, groups, fetLeaderboard] =
      await Promise.all([
        getPlatformConfig(),
        getMatches(),
        getNewsArticles(),
        getProducts(),
        getContributionGroups(),
        getFanEngagementLeaderboard(5),
      ]);

    return [
      ...getSiteSearchItems(platformConfig).map((item) => ({
        id: `site-${item.search_key}`,
        title: item.title,
        description: item.description,
        href: item.href,
        category: item.category as SearchIndexItem["category"],
        meta: item.meta_label ?? undefined,
      })),
      ...matches.slice(0, 8).map((match) => ({
        id: `match-${match.id}`,
        title: `${match.homeTeam} vs ${match.awayTeam}`,
        description:
          match.matchSummary ?? `${match.competition} at ${match.venue}.`,
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
        href: "/Groups",
        category: "Community" as const,
        meta: group.groupType,
      })),
      ...fetLeaderboard.slice(0, 3).map((entry) => ({
        id: `fet-leaderboard-${entry.userId}`,
        title: `#${entry.rank} ${entry.supporterAlias}`,
        description: `${entry.totalFet.toLocaleString()} FET • ${entry.tier}`,
        href: "/supporters",
        category: "Community" as const,
        meta: "Fan leaderboard",
      })),
    ];
  },
);
