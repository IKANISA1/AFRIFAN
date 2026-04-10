import type { Metadata, Viewport } from "next";
import { Bebas_Neue, Oswald, Outfit, Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";
import { absoluteUrl, siteConfig } from "@/lib/config";
import { buildSiteJsonLd, renderJsonLdScriptContent } from "@/lib/metadata";

const plusJakarta = Plus_Jakarta_Sans({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const oswald = Oswald({
  variable: "--font-barlow",
  subsets: ["latin"],
  display: "swap",
});

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
  display: "swap",
});

const bebasNeue = Bebas_Neue({
  variable: "--font-bebas",
  subsets: ["latin"],
  weight: "400",
  display: "swap",
  preload: false,
});

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.siteUrl),
  title: {
    default: siteConfig.title,
    template: `%s | ${siteConfig.shortTitle}`,
  },
  description: siteConfig.description,
  applicationName: siteConfig.shortTitle,
  keywords: [
    siteConfig.shortTitle,
    "football club",
    "white-label sports website",
    "fan app",
    "tickets",
    "membership",
  ],
  verification: {
    google: process.env.NEXT_PUBLIC_GSC_TOKEN ?? undefined,
  },
  openGraph: {
    title: siteConfig.title,
    description: siteConfig.description,
    url: siteConfig.siteUrl,
    siteName: siteConfig.shortTitle,
    locale: "en_US",
    type: "website",
    images: [
      {
        url: absoluteUrl("/icons/icon-512x512.png"),
        width: 512,
        height: 512,
        alt: `${siteConfig.shortTitle} crest`,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: siteConfig.title,
    description: siteConfig.description,
    images: [absoluteUrl("/icons/icon-512x512.png")],
  },
  alternates: {
    canonical: siteConfig.siteUrl,
  },
  icons: {
    icon: "/icons/icon-192x192.png",
    apple: "/icons/icon-192x192.png",
  },
  appleWebApp: {
    capable: true,
    title: siteConfig.shortTitle,
    statusBarStyle: "black-translucent",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0038a8",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const siteJsonLd = buildSiteJsonLd();

  return (
    <html
      lang="en"
      className={`${plusJakarta.variable} ${oswald.variable} ${outfit.variable} ${bebasNeue.variable} h-full antialiased`}
    >
      <head />
      <body className="min-h-full flex flex-col">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: renderJsonLdScriptContent(siteJsonLd),
          }}
        />
        {children}
      </body>
    </html>
  );
}
