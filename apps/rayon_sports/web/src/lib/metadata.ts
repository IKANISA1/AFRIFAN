import type { Metadata } from "next";
import { absoluteUrl, siteConfig } from "@/lib/config";

interface PageMetadataOptions {
  title: string;
  description: string;
  path?: string;
  imagePath?: string;
  type?: "website" | "article";
}

export function buildPageMetadata({
  title,
  description,
  path = "/",
  imagePath = "/media/rayon-crest.png",
  type = "website",
}: PageMetadataOptions): Metadata {
  const canonical = absoluteUrl(path);
  const image = absoluteUrl(imagePath);

  return {
    title,
    description,
    alternates: {
      canonical,
    },
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

export function buildSiteJsonLd() {
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        name: siteConfig.shortTitle,
        alternateName: "Rayon Sports FC",
        url: siteConfig.siteUrl,
        description: siteConfig.description,
        inLanguage: ["en", "fr", "rw"],
      },
      {
        "@type": "SportsOrganization",
        name: "Rayon Sports FC",
        alternateName: siteConfig.shortTitle,
        url: siteConfig.siteUrl,
        logo: absoluteUrl("/media/rayon-crest.png"),
        sport: "Association football",
        description: siteConfig.description,
        sameAs: [
          "https://fb.com/RayonSportsOfficial",
          "https://x.com/rayon_sports",
          "https://instagram.com/rayonsports_official",
          "https://tiktok.com/@rayonsports",
        ],
      },
    ],
  };
}
