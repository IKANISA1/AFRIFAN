import type { Metadata } from "next";
import { absoluteUrl, rayonClub, siteConfig } from "@/lib/config";
import type { MatchItem, NewsArticle, ShopProduct } from "@/lib/types";

interface PageMetadataOptions {
  title: string;
  description: string;
  path?: string;
  imagePath?: string;
  type?: "website" | "article";
  robots?: Metadata["robots"];
}

export function renderJsonLdScriptContent(value: unknown) {
  return JSON.stringify(value)
    .replace(/</g, "\\u003C")
    .replace(/>/g, "\\u003E")
    .replace(/&/g, "\\u0026")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

export function buildPageMetadata({
  title,
  description,
  path = "/",
  imagePath = "/icons/icon-512x512.png",
  type = "website",
  robots,
}: PageMetadataOptions): Metadata {
  const canonical = absoluteUrl(path);
  const image = absoluteUrl(imagePath);

  return {
    title,
    description,
    alternates: {
      canonical,
    },
    robots,
    openGraph: {
      title,
      description,
      url: canonical,
      siteName: siteConfig.shortTitle,
      locale: "en_US",
      type,
      images: [
        {
          url: image,
          width: 1200,
          height: 630,
          alt: title,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [image],
    },
  };
}

export function buildNewsArticleJsonLd(article: NewsArticle) {
  return {
    "@context": "https://schema.org",
    "@type": "NewsArticle",
    headline: article.title,
    description: article.excerpt,
    image: absoluteUrl(article.coverImageUrl ?? "/media/stadium-hero.jpg"),
    datePublished: article.publishedAt,
    dateModified: article.publishedAt,
    author: {
      "@type": "Person",
      name: article.author,
    },
    publisher: {
      "@type": "SportsOrganization",
      name: siteConfig.shortTitle,
      logo: {
        "@type": "ImageObject",
        url: absoluteUrl("/icons/icon-192x192.png"),
      },
    },
    mainEntityOfPage: absoluteUrl(`/news/${article.id}`),
  };
}

export function buildMatchJsonLd(match: MatchItem) {
  return {
    "@context": "https://schema.org",
    "@type": "SportsEvent",
    name: `${match.homeTeam} vs ${match.awayTeam}`,
    description: match.matchSummary ?? `${match.competition} at ${match.venue}.`,
    startDate: match.matchDate,
    eventStatus:
      match.matchStatus === "live"
        ? "https://schema.org/EventScheduled"
        : match.matchStatus === "fulltime"
          ? "https://schema.org/EventCompleted"
          : "https://schema.org/EventScheduled",
    location: {
      "@type": "Place",
      name: match.venue,
    },
    image: absoluteUrl(match.imageUrl ?? "/media/stadium-hero.jpg"),
    competitor: [
      { "@type": "SportsTeam", name: match.homeTeam },
      { "@type": "SportsTeam", name: match.awayTeam },
    ],
    offers: match.isOnSale
      ? [
          {
            "@type": "Offer",
            priceCurrency: rayonClub.currencyCode,
            price: match.generalPrice,
            availability: "https://schema.org/InStock",
            url: absoluteUrl(`/tickets/${match.id}`),
          },
        ]
      : undefined,
    url: absoluteUrl(`/fixtures/${match.id}`),
  };
}

export function buildProductJsonLd(product: ShopProduct) {
  return {
    "@context": "https://schema.org",
    "@type": "Product",
    name: product.name,
    description: product.description,
    image: absoluteUrl(product.imageUrl ?? "/media/stadium-hero.jpg"),
    brand: {
      "@type": "Brand",
      name: siteConfig.shortTitle,
    },
    category: product.category,
    sku: product.id,
    offers: {
      "@type": "Offer",
      priceCurrency: rayonClub.currencyCode,
      price: product.price,
      availability: product.isActive
        ? "https://schema.org/InStock"
        : "https://schema.org/OutOfStock",
      url: absoluteUrl(`/shop/${product.id}`),
    },
  };
}

export function buildSquadJsonLd(club: ClubProfile, squad: SquadPlayer[]) {
  return {
    "@context": "https://schema.org",
    "@type": "SportsTeam",
    name: club.clubName,
    sport: "Association Football",
    member: squad.map((player) => ({
      "@type": "OrganizationRole",
      member: {
        "@type": "Person",
        name: player.name,
        jobTitle: player.role,
        image: player.imageUrl ? absoluteUrl(player.imageUrl) : undefined,
      },
      roleName: player.role,
      numberedPosition: player.number,
    })),
  };
}

export function buildSiteJsonLd() {
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        name: siteConfig.shortTitle,
        alternateName: siteConfig.title,
        url: siteConfig.siteUrl,
        description: siteConfig.description,
        inLanguage: ["en", "fr", "rw"],
      },
      {
        "@type": "SportsOrganization",
        name: siteConfig.title,
        alternateName: siteConfig.shortTitle,
        url: siteConfig.siteUrl,
        logo: absoluteUrl("/icons/icon-192x192.png"),
        sport: "Association football",
        description: siteConfig.description,
      },
    ],
  };
}
