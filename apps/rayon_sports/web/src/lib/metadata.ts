import type { Metadata } from "next";
import { absoluteUrl, rayonClub, siteConfig } from "@/lib/config";
import { getSupportedClubProfile } from "@/lib/content";
import type {
  ClubProfile,
  MatchItem,
  NewsArticle,
  ShopProduct,
  SquadPlayer,
} from "@/lib/types";

interface PageMetadataOptions {
  club?: ClubProfile;
  title: string;
  description: string;
  path?: string;
  imagePath?: string;
  type?: "website" | "article";
  robots?: Metadata["robots"];
}

export function getClubWebsiteIdentity(club: ClubProfile) {
  const isDefault = club.id === siteConfig.defaultClubId;
  const retainedRayonBrand = isDefault && club.id === rayonClub.numericId;
  const configuredHost = Object.entries(siteConfig.clubHostMap).find(
    ([host, value]) => typeof value === "string"
      && /^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$/.test(host)
      && host.includes(".") && getSupportedClubProfile(value)?.id === club.id,
  )?.[0];
  return {
    name: retainedRayonBrand ? siteConfig.shortTitle : club.shortName,
    title: retainedRayonBrand ? siteConfig.title : `${club.clubName} | Official club website`,
    description: retainedRayonBrand ? siteConfig.description
      : `${club.clubName} website for fixtures, tickets, membership, news, shop, supporter Groups, and fan app journeys.`,
    // Only configured deployment origins may become canonical. A request Host
    // header or another club's default URL is not publication evidence.
    url: isDefault ? siteConfig.siteUrl : configuredHost ? `https://${configuredHost}` : undefined,
  };
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
  club,
  title,
  description,
  path = "/",
  imagePath = "/brand-mark.svg",
  type = "website",
  robots,
}: PageMetadataOptions): Metadata {
  const website = club ? getClubWebsiteIdentity(club) : {
    name: siteConfig.shortTitle, url: siteConfig.siteUrl,
  };
  const canonical = website.url ? new URL(path, website.url).toString() : undefined;
  const image = website.url ? new URL(imagePath, website.url).toString() : undefined;

  return {
    title: club ? { absolute: `${title} | ${website.name}` } : title,
    description,
    alternates: {
      canonical,
    },
    robots: robots ?? (website.url ? undefined : { index: false, follow: false }),
    openGraph: {
      title,
      description,
      url: canonical,
      siteName: website.name,
      locale: "en_US",
      type,
      images: image ? [
        {
          url: image,
          width: 1200,
          height: 630,
          alt: title,
        },
      ] : [],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: image ? [image] : [],
    },
  };
}

export function buildNewsArticleJsonLd(article: NewsArticle) {
  return {
    "@context": "https://schema.org",
    "@type": "NewsArticle",
    headline: article.title,
    description: article.excerpt,
    image: absoluteUrl(article.coverImageUrl ?? "/brand-surface.svg"),
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
        url: absoluteUrl("/brand-mark.svg"),
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
    image: absoluteUrl(match.imageUrl ?? "/brand-surface.svg"),
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
    image: absoluteUrl(product.imageUrl ?? "/brand-surface.svg"),
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

export function buildSiteJsonLd(club?: ClubProfile) {
  const website = club ? getClubWebsiteIdentity(club) : {
    name: siteConfig.shortTitle, title: siteConfig.title,
    description: siteConfig.description, url: siteConfig.siteUrl,
  };
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        name: website.name,
        alternateName: website.title,
        url: website.url,
        description: website.description,
        inLanguage: ["en"],
      },
      {
        "@type": "SportsOrganization",
        name: club?.clubName ?? website.title,
        alternateName: website.name,
        url: website.url,
        logo: website.url ? new URL("/brand-mark.svg", website.url).toString() : undefined,
        sport: "Association football",
        description: website.description,
      },
    ],
  };
}
