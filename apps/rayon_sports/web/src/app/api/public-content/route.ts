import {
  controlledApiFailureResponse,
  controlledApiJson,
  withControlledApiTimeout,
} from "@/lib/controlled-api-response";
import {
  getCmsContentStrict,
  getContributionGroupsStrict,
  getFanClubsStrict,
  getMatchByIdStrict,
  getMatchesStrict,
  getMembershipPackagesStrict,
  getNewsArticleByIdStrict,
  getNewsArticlesStrict,
  getProductByIdStrict,
  getProductsStrict,
  getSquadStrict,
  getStandingsStrict,
} from "@/lib/data/public";
import type { ShopProduct } from "@/lib/types";
import {
  getFanEngagementLeaderboardStrict,
  getFanEngagementTokensStrict,
} from "@/lib/data/public/gamification";

const supportedResources = [
  "home",
  "fixtures",
  "fixture-detail",
  "history",
  "circles",
  "fan-clubs",
  "membership",
  "news",
  "news-article",
  "shop",
  "shop-product",
  "squad",
  "standings",
  "supporters",
] as const;

type PublicContentResource = (typeof supportedResources)[number];

function isPublicContentResource(
  value: string | null,
): value is PublicContentResource {
  return (
    value != null && supportedResources.includes(value as PublicContentResource)
  );
}

function projectPublicProduct(product: ShopProduct) {
  const id = product.id.trim().slice(0, 200);
  const name = product.name.trim().slice(0, 160);
  const subtitle = product.subtitle.trim().slice(0, 500);
  const description = product.description.trim().slice(0, 2_000);
  const category = product.category.trim().slice(0, 100);
  const collection = product.collection?.trim().slice(0, 100) || null;
  const price = Number(product.price);
  const imageUrl =
    typeof product.imageUrl === "string"
      ? product.imageUrl.trim().slice(0, 2_000)
      : null;
  const sizes = Array.from(
    new Set(
      product.sizes
        .map((size) => size.trim().slice(0, 40))
        .filter(Boolean),
    ),
  ).slice(0, 8);

  if (
    !id ||
    !name ||
    !subtitle ||
    !description ||
    !category ||
    !Number.isFinite(price) ||
    price < 0 ||
    price > 1_000_000_000_000 ||
    sizes.length === 0 ||
    (imageUrl != null &&
      !imageUrl.startsWith("/") &&
      !/^https:\/\/[^/]+\.supabase\.co(?:\/|$)/i.test(imageUrl))
  ) {
    return null;
  }

  return {
    id,
    name,
    subtitle,
    description,
    category,
    collection,
    price,
    imageUrl,
    sizes,
    isAvailable: product.isActive === true,
  };
}

export async function GET(request: Request) {
  const resource = new URL(request.url).searchParams.get("resource");
  if (!isPublicContentResource(resource)) {
    return controlledApiJson(
      {
        code: "PUBLIC_CONTENT_INVALID_RESOURCE",
        error: "Unsupported public content resource.",
        retryable: false,
        change_confirmed: false,
      },
      400,
    );
  }

  try {
    if (resource === "home") {
      const [matchRows, articleRows, productRows, membershipRows] =
        await withControlledApiTimeout(
          Promise.all([
            getMatchesStrict(),
            getNewsArticlesStrict(),
            getProductsStrict(),
            getMembershipPackagesStrict(),
          ]),
        );

      const matchIds = new Set<string>();
      const matches = matchRows
        .map((match) => ({
          id: match.id.trim().slice(0, 200),
          homeTeam: match.homeTeam.trim().slice(0, 160),
          awayTeam: match.awayTeam.trim().slice(0, 160),
          competition: match.competition.trim().slice(0, 160),
          venue: match.venue.trim().slice(0, 200),
          matchDate: match.matchDate.trim().slice(0, 100),
          kickoffTime: match.kickoffTime?.trim().slice(0, 40) || null,
          matchStatus: match.matchStatus.trim().slice(0, 40),
        }))
        .filter((match) => {
          const valid =
            match.id &&
            match.homeTeam &&
            match.awayTeam &&
            match.competition &&
            match.venue &&
            match.matchDate &&
            match.matchStatus &&
            !matchIds.has(match.id);
          if (valid) matchIds.add(match.id);
          return Boolean(valid);
        })
        .slice(0, 3);

      const articleIds = new Set<string>();
      const news = articleRows
        .map((article) => ({
          id: article.id.trim().slice(0, 200),
          title: article.title.trim().slice(0, 200),
          excerpt: article.excerpt.trim().slice(0, 600),
          category: article.category.trim().slice(0, 100),
          coverImageUrl: article.coverImageUrl ?? "/brand-surface.svg",
          publishedAt: article.publishedAt.trim().slice(0, 100),
          author: article.author.trim().slice(0, 160),
        }))
        .filter((article) => {
          const valid =
            article.id &&
            article.title &&
            article.excerpt &&
            article.category &&
            article.publishedAt &&
            article.author &&
            !articleIds.has(article.id);
          if (valid) articleIds.add(article.id);
          return Boolean(valid);
        })
        .slice(0, 3);

      const productIds = new Set<string>();
      const products = productRows
        .map(projectPublicProduct)
        .filter((item): item is NonNullable<typeof item> => {
          if (item == null || productIds.has(item.id)) return false;
          productIds.add(item.id);
          return true;
        })
        .slice(0, 3);

      const membershipIds = new Set<string>();
      const memberships = membershipRows
        .map((membership) => ({
          id: membership.id.trim().slice(0, 200),
          tier: membership.tier.trim().slice(0, 80),
          title: membership.title.trim().slice(0, 160),
          description: membership.description.trim().slice(0, 600),
          annualPrice: membership.annualPrice,
          perks: Array.from(
            new Set(
              membership.perks
                .map((perk) => perk.trim().slice(0, 200))
                .filter(Boolean),
            ),
          ).slice(0, 3),
        }))
        .filter((membership) => {
          const valid =
            membership.id &&
            membership.tier &&
            membership.title &&
            membership.description &&
            Number.isFinite(membership.annualPrice) &&
            membership.annualPrice >= 0 &&
            membership.annualPrice <= 1_000_000_000_000 &&
            membership.perks.length > 0 &&
            !membershipIds.has(membership.id);
          if (valid) membershipIds.add(membership.id);
          return Boolean(valid);
        })
        .slice(0, 3);

      const hasContent =
        matches.length > 0 ||
        news.length > 0 ||
        products.length > 0 ||
        memberships.length > 0;
      return controlledApiJson(
        {
          code: hasContent ? "PUBLIC_HOME_READY" : "PUBLIC_HOME_EMPTY",
          matches,
          news,
          products,
          memberships,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=60, stale-while-revalidate=120",
        },
      );
    }

    if (resource === "fixture-detail") {
      const matchId = new URL(request.url).searchParams.get("matchId")?.trim();
      if (!matchId || matchId.length > 200) {
        return controlledApiJson(
          {
            code: "PUBLIC_FIXTURE_DETAIL_INVALID_ID",
            error: "A valid fixture identifier is required.",
            retryable: false,
            change_confirmed: false,
          },
          400,
        );
      }

      const match = await withControlledApiTimeout(getMatchByIdStrict(matchId));
      const item =
        match == null
          ? null
          : {
              id: match.id,
              homeTeam: match.homeTeam,
              awayTeam: match.awayTeam,
              competition: match.competition,
              venue: match.venue,
              matchDate: match.matchDate,
              kickoffTime: match.kickoffTime,
              isOnSale: match.isOnSale,
              generalPrice: match.generalPrice,
              vipPrice: match.vipPrice,
              matchStatus: match.matchStatus,
              homeScore: match.homeScore,
              awayScore: match.awayScore,
              liveMinute: match.liveMinute,
              matchSummary: match.matchSummary,
            };

      return controlledApiJson(
        {
          code:
            item == null
              ? "PUBLIC_FIXTURE_DETAIL_EMPTY"
              : "PUBLIC_FIXTURE_DETAIL_READY",
          item,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=60, stale-while-revalidate=120",
        },
      );
    }

    if (resource === "fixtures") {
      const matches = await withControlledApiTimeout(getMatchesStrict());
      const items = matches
        .map((match) => ({
          id: match.id,
          homeTeam: match.homeTeam,
          awayTeam: match.awayTeam,
          competition: match.competition,
          venue: match.venue,
          matchDate: match.matchDate,
          kickoffTime: match.kickoffTime,
          isOnSale: match.isOnSale,
          generalPrice: match.generalPrice,
          matchStatus: match.matchStatus,
          homeScore: match.homeScore,
          awayScore: match.awayScore,
          liveMinute: match.liveMinute,
          matchSummary: match.matchSummary,
        }))
        .filter(
          (match) =>
            match.id.trim() &&
            match.homeTeam.trim() &&
            match.awayTeam.trim() &&
            match.competition.trim() &&
            match.venue.trim() &&
            match.matchDate.trim(),
        )
        .slice(0, 20);

      return controlledApiJson(
        {
          code:
            items.length === 0
              ? "PUBLIC_FIXTURES_EMPTY"
              : "PUBLIC_FIXTURES_READY",
          items,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=60, stale-while-revalidate=120",
        },
      );
    }

    if (resource === "circles" || resource === "fan-clubs") {
      const [groupRows, chapterRows] = await withControlledApiTimeout(
        Promise.all([getContributionGroupsStrict(), getFanClubsStrict()]),
      );
      const groupIds = new Set<string>();
      const groups = groupRows
        .map((group) => ({
          id: group.id.trim().slice(0, 200),
          name: group.name.trim().slice(0, 160),
          description: group.description.trim().slice(0, 1_000),
          groupType: group.groupType === "project" ? "project" : "community",
          targetAmount: group.targetAmount,
          currentTotal: group.currentTotal,
          currency: group.currency.trim().toUpperCase().slice(0, 3),
          memberCount: group.memberCount,
        }))
        .filter((group) => {
          const valid =
            group.id &&
            group.name &&
            group.description &&
            Number.isFinite(group.targetAmount) &&
            group.targetAmount > 0 &&
            group.targetAmount <= 1_000_000_000_000 &&
            Number.isFinite(group.currentTotal) &&
            group.currentTotal >= 0 &&
            group.currentTotal <= 1_000_000_000_000 &&
            /^[A-Z]{3}$/.test(group.currency) &&
            Number.isInteger(group.memberCount) &&
            group.memberCount >= 0 &&
            group.memberCount <= 100_000_000 &&
            !groupIds.has(group.id);
          if (valid) groupIds.add(group.id);
          return Boolean(valid);
        })
        .slice(0, 8);

      const chapterIds = new Set<string>();
      const chapters = chapterRows
        .map((chapter) => ({
          id: chapter.id.trim().slice(0, 200),
          name: chapter.name.trim().slice(0, 160),
          region: chapter.region.trim().slice(0, 120),
          description: chapter.description.trim().slice(0, 1_000),
          memberCount: chapter.memberCount,
          eventCount: chapter.eventCount,
        }))
        .filter((chapter) => {
          const valid =
            chapter.id &&
            chapter.name &&
            chapter.region &&
            chapter.description &&
            Number.isInteger(chapter.memberCount) &&
            chapter.memberCount >= 0 &&
            chapter.memberCount <= 100_000_000 &&
            Number.isInteger(chapter.eventCount) &&
            chapter.eventCount >= 0 &&
            chapter.eventCount <= 1_000_000 &&
            !chapterIds.has(chapter.id);
          if (valid) chapterIds.add(chapter.id);
          return Boolean(valid);
        })
        .slice(0, 12);

      return controlledApiJson(
        {
          code:
            groups.length === 0 && chapters.length === 0
              ? resource === "fan-clubs"
                ? "PUBLIC_FAN_CLUBS_EMPTY"
                : "PUBLIC_CIRCLES_EMPTY"
              : resource === "fan-clubs"
                ? "PUBLIC_FAN_CLUBS_READY"
                : "PUBLIC_CIRCLES_READY",
          groups,
          chapters,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
        },
      );
    }

    if (resource === "membership") {
      const packageRows = await withControlledApiTimeout(
        getMembershipPackagesStrict(),
      );
      const ids = new Set<string>();
      const tiers = new Set<string>();
      const packages = packageRows
        .map((membershipPackage) => ({
          id: membershipPackage.id.trim().slice(0, 200),
          tier: membershipPackage.tier,
          title: membershipPackage.title.trim().slice(0, 160),
          description: membershipPackage.description.trim().slice(0, 1_000),
          sortOrder: membershipPackage.sortOrder,
          annualPrice: membershipPackage.annualPrice,
          perks: membershipPackage.perks
            .map((perk) => perk.trim().slice(0, 200))
            .filter(Boolean)
            .slice(0, 4),
        }))
        .filter((membershipPackage) => {
          const validTier = [
            "ingenzi-imanzi",
            "inyamibwa",
            "imena",
            "bronze",
            "silver",
            "gold",
          ].includes(membershipPackage.tier);
          const valid =
            membershipPackage.id &&
            validTier &&
            membershipPackage.title &&
            membershipPackage.description &&
            Number.isInteger(membershipPackage.sortOrder) &&
            membershipPackage.sortOrder >= 0 &&
            membershipPackage.sortOrder <= 1_000_000 &&
            Number.isFinite(membershipPackage.annualPrice) &&
            membershipPackage.annualPrice >= 0 &&
            membershipPackage.annualPrice <= 1_000_000_000_000 &&
            membershipPackage.perks.length > 0 &&
            !ids.has(membershipPackage.id) &&
            !tiers.has(membershipPackage.tier);
          if (valid) {
            ids.add(membershipPackage.id);
            tiers.add(membershipPackage.tier);
          }
          return Boolean(valid);
        })
        .sort((a, b) => a.sortOrder - b.sortOrder)
        .slice(0, 6);

      return controlledApiJson(
        {
          code:
            packages.length === 0
              ? "PUBLIC_MEMBERSHIP_EMPTY"
              : "PUBLIC_MEMBERSHIP_READY",
          packages,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=300, stale-while-revalidate=600",
        },
      );
    }

    if (resource === "shop-product") {
      const productId = new URL(request.url).searchParams
        .get("productId")
        ?.trim();
      if (!productId || productId.length > 200) {
        return controlledApiJson(
          {
            code: "PUBLIC_SHOP_PRODUCT_INVALID_ID",
            error: "A valid product identifier is required.",
            retryable: false,
            change_confirmed: false,
          },
          400,
        );
      }

      const product = await withControlledApiTimeout(
        getProductByIdStrict(productId),
      );
      const item = product == null ? null : projectPublicProduct(product);
      return controlledApiJson(
        {
          code:
            item == null
              ? "PUBLIC_SHOP_PRODUCT_EMPTY"
              : "PUBLIC_SHOP_PRODUCT_READY",
          item,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=60, stale-while-revalidate=120",
        },
      );
    }

    if (resource === "shop") {
      const rows = await withControlledApiTimeout(getProductsStrict());
      const ids = new Set<string>();
      const items = rows
        .map(projectPublicProduct)
        .filter((item): item is NonNullable<typeof item> => {
          if (item == null || ids.has(item.id)) return false;
          ids.add(item.id);
          return true;
        })
        .slice(0, 12);

      return controlledApiJson(
        {
          code: items.length === 0 ? "PUBLIC_SHOP_EMPTY" : "PUBLIC_SHOP_READY",
          items,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=60, stale-while-revalidate=120",
        },
      );
    }

    if (resource === "news-article") {
      const articleId = new URL(request.url).searchParams
        .get("articleId")
        ?.trim();
      if (!articleId || articleId.length > 200) {
        return controlledApiJson(
          {
            code: "PUBLIC_NEWS_ARTICLE_INVALID_ID",
            error: "A valid news article identifier is required.",
            retryable: false,
            change_confirmed: false,
          },
          400,
        );
      }

      const article = await withControlledApiTimeout(
        getNewsArticleByIdStrict(articleId),
      );
      const item =
        article == null
          ? null
          : {
              id: article.id,
              title: article.title,
              excerpt: article.excerpt,
              content: article.content.slice(0, 12_000),
              category: article.category,
              coverImageUrl: article.coverImageUrl ?? "/brand-surface.svg",
              publishedAt: article.publishedAt,
              author: article.author,
            };

      return controlledApiJson(
        {
          code:
            item == null
              ? "PUBLIC_NEWS_ARTICLE_EMPTY"
              : "PUBLIC_NEWS_ARTICLE_READY",
          item,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
        },
      );
    }

    if (resource === "news") {
      const articles = await withControlledApiTimeout(getNewsArticlesStrict());
      const items = articles
        .map((article) => ({
          id: article.id,
          title: article.title,
          excerpt: article.excerpt,
          category: article.category,
          coverImageUrl: article.coverImageUrl ?? "/brand-surface.svg",
          publishedAt: article.publishedAt,
          author: article.author,
        }))
        .filter(
          (article) =>
            article.id.trim() &&
            article.title.trim() &&
            article.excerpt.trim() &&
            article.category.trim() &&
            article.publishedAt.trim() &&
            article.author.trim(),
        )
        .slice(0, 24);

      return controlledApiJson(
        {
          code: items.length === 0 ? "PUBLIC_NEWS_EMPTY" : "PUBLIC_NEWS_READY",
          items,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
        },
      );
    }

    if (resource === "standings") {
      const standings = await withControlledApiTimeout(getStandingsStrict());
      const items = standings
        .map((row) => ({
          position: row.position,
          club: row.club,
          played: row.played,
          goalDifference: row.goalDifference,
          points: row.points,
          form: (row.form ?? [])
            .map((entry) => entry.trim().toUpperCase())
            .filter((entry) => ["W", "D", "L"].includes(entry))
            .slice(0, 5),
          highlight: row.highlight === true,
        }))
        .filter(
          (row) =>
            Number.isInteger(row.position) &&
            row.position > 0 &&
            row.club.trim() &&
            row.played >= 0 &&
            row.points >= 0,
        )
        .slice(0, 24);

      return controlledApiJson(
        {
          code:
            items.length === 0
              ? "PUBLIC_STANDINGS_EMPTY"
              : "PUBLIC_STANDINGS_READY",
          items,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
        },
      );
    }

    if (resource === "squad") {
      const squad = await withControlledApiTimeout(getSquadStrict());
      const items = squad
        .map((player) => ({
          id: player.id.trim(),
          name: player.name.trim(),
          role: player.role.trim(),
          number: player.number,
          nationality: player.nationality.trim(),
          bio: player.bio.trim().slice(0, 1_000),
          imageUrl: player.imageUrl ?? "/brand-surface.svg",
        }))
        .filter(
          (player) =>
            player.id &&
            player.name &&
            player.role &&
            Number.isInteger(player.number) &&
            player.number >= 0 &&
            player.number <= 999 &&
            player.nationality &&
            player.bio,
        )
        .slice(0, 40);

      return controlledApiJson(
        {
          code:
            items.length === 0 ? "PUBLIC_SQUAD_EMPTY" : "PUBLIC_SQUAD_READY",
          items,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=300, stale-while-revalidate=600",
        },
      );
    }

    if (resource === "supporters") {
      const [catalogRows, leaderboardRows] = await withControlledApiTimeout(
        Promise.all([
          getFanEngagementTokensStrict(8),
          getFanEngagementLeaderboardStrict(10),
        ]),
      );
      const catalogIds = new Set<string>();
      const catalogCodes = new Set<string>();
      const catalog = catalogRows
        .map((item) => ({
          id: item.id.trim().slice(0, 200),
          code: item.code.trim().slice(0, 64),
          category: item.category.trim().slice(0, 120),
          itemName: item.itemName.trim().slice(0, 160),
          fetValue: item.fetValue,
          triggerCondition: item.triggerCondition.trim().slice(0, 500),
          activationTiming: item.activationTiming.trim().slice(0, 300),
          description: item.description.trim().slice(0, 1_000),
        }))
        .filter((item) => {
          const valid =
            item.id &&
            item.code &&
            item.category &&
            item.itemName &&
            Number.isFinite(item.fetValue) &&
            Number.isInteger(item.fetValue) &&
            item.fetValue >= 0 &&
            item.fetValue <= 1_000_000_000 &&
            item.triggerCondition &&
            item.activationTiming &&
            item.description &&
            !catalogIds.has(item.id) &&
            !catalogCodes.has(item.code.toLowerCase());
          if (valid) {
            catalogIds.add(item.id);
            catalogCodes.add(item.code.toLowerCase());
          }
          return Boolean(valid);
        })
        .slice(0, 8);

      const ranks = new Set<number>();
      const aliases = new Set<string>();
      const leaderboard = leaderboardRows
        .map((entry) => ({
          rank: entry.rank,
          supporterAlias: entry.supporterAlias.trim().slice(0, 32),
          totalFet: entry.totalFet,
          tier: entry.tier.trim().slice(0, 40),
        }))
        .filter((entry) => {
          const normalizedAlias = entry.supporterAlias.toLowerCase();
          const valid =
            Number.isInteger(entry.rank) &&
            entry.rank > 0 &&
            entry.rank <= 100_000 &&
            /^[A-Za-z0-9_-]{2,32}$/.test(entry.supporterAlias) &&
            !/^\d{7,}$/.test(entry.supporterAlias) &&
            Number.isInteger(entry.totalFet) &&
            entry.totalFet >= 0 &&
            entry.totalFet <= 1_000_000_000_000 &&
            entry.tier &&
            !ranks.has(entry.rank) &&
            !aliases.has(normalizedAlias);
          if (valid) {
            ranks.add(entry.rank);
            aliases.add(normalizedAlias);
          }
          return Boolean(valid);
        })
        .sort((a, b) => a.rank - b.rank)
        .slice(0, 10);

      return controlledApiJson(
        {
          code:
            catalog.length === 0 && leaderboard.length === 0
              ? "PUBLIC_SUPPORTERS_EMPTY"
              : "PUBLIC_SUPPORTERS_READY",
          catalog,
          leaderboard,
        },
        200,
        {
          "Cache-Control":
            "public, max-age=0, s-maxage=120, stale-while-revalidate=300",
        },
      );
    }

    const content = await withControlledApiTimeout(
      getCmsContentStrict("club_history"),
    );
    const items = content
      .map((item) => ({
        id: item.id,
        title: item.title,
        body: item.body,
      }))
      .filter((item) => item.id.trim() && item.title.trim() && item.body.trim())
      .slice(0, 24);

    return controlledApiJson(
      {
        code:
          items.length === 0 ? "PUBLIC_HISTORY_EMPTY" : "PUBLIC_HISTORY_READY",
        items,
      },
      200,
      {
        "Cache-Control":
          "public, max-age=0, s-maxage=300, stale-while-revalidate=600",
      },
    );
  } catch (error) {
    const failurePrefix =
      resource === "home"
        ? "PUBLIC_HOME"
        : resource === "fixture-detail"
        ? "PUBLIC_FIXTURE_DETAIL"
        : resource === "shop-product"
          ? "PUBLIC_SHOP_PRODUCT"
          : resource === "shop"
            ? "PUBLIC_SHOP"
        : resource === "membership"
          ? "PUBLIC_MEMBERSHIP"
          : resource === "fan-clubs"
            ? "PUBLIC_FAN_CLUBS"
            : resource === "circles"
              ? "PUBLIC_CIRCLES"
              : resource === "fixtures"
                ? "PUBLIC_FIXTURES"
                : resource === "news-article"
                  ? "PUBLIC_NEWS_ARTICLE"
                  : resource === "news"
                    ? "PUBLIC_NEWS"
                    : resource === "standings"
                      ? "PUBLIC_STANDINGS"
                      : resource === "squad"
                        ? "PUBLIC_SQUAD"
                        : resource === "supporters"
                          ? "PUBLIC_SUPPORTERS"
                          : "PUBLIC_HISTORY";
    return controlledApiFailureResponse(error, failurePrefix);
  }
}
