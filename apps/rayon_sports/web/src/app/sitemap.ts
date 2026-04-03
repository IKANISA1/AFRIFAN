import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/config";
import { fallbackNewsArticles, fallbackProducts, fallbackMatches } from "@/lib/content";

export default function sitemap(): MetadataRoute.Sitemap {
  const staticRoutes = [
    "",
    "/news",
    "/fixtures",
    "/results",
    "/standings",
    "/squad",
    "/tickets",
    "/shop",
    "/membership",
    "/circles",
    "/fan-clubs",
    "/history",
    "/contact",
    "/privacy",
    "/terms",
    "/app",
    "/app/profile",
    "/app/membership",
    "/app/tickets",
    "/app/shop",
    "/app/contributions",
    "/app/fan-clubs",
    "/app/xp",
  ];

  return [
    ...staticRoutes.map((route) => ({
      url: absoluteUrl(route || "/"),
      lastModified: new Date(),
    })),
    ...fallbackNewsArticles.map((article) => ({
      url: absoluteUrl(`/news/${article.id}`),
      lastModified: new Date(article.publishedAt),
    })),
    ...fallbackProducts.map((product) => ({
      url: absoluteUrl(`/shop/${product.id}`),
      lastModified: new Date(),
    })),
    ...fallbackMatches.map((match) => ({
      url: absoluteUrl(`/fixtures/${match.id}`),
      lastModified: new Date(match.matchDate),
    })),
  ];
}
