import type { Metadata, Viewport } from "next";
import {
  Barlow_Condensed,
  Inter,
  Manrope,
  Space_Grotesk,
} from "next/font/google";
import "./globals.css";
import { getClubProfile } from "@/lib/data/public";
import { buildSiteJsonLd, getClubWebsiteIdentity, renderJsonLdScriptContent } from "@/lib/metadata";

const manrope = Manrope({
  variable: "--font-manrope",
  subsets: ["latin"],
  display: "swap",
});

const spaceGrotesk = Space_Grotesk({
  variable: "--font-space-grotesk",
  subsets: ["latin"],
  display: "swap",
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const barlowCondensed = Barlow_Condensed({
  variable: "--font-matchday",
  subsets: ["latin"],
  weight: ["900"],
  display: "swap",
});

export async function generateMetadata(): Promise<Metadata> {
  const website = getClubWebsiteIdentity(await getClubProfile());
  const image = website.url ? new URL("/brand-mark.svg", website.url).toString() : undefined;
  return {
    metadataBase: website.url ? new URL(website.url) : undefined,
    robots: website.url ? undefined : { index: false, follow: false },
    title: {
      default: website.title,
      template: `%s | ${website.name}`,
    },
    description: website.description,
    applicationName: website.name,
    keywords: [
      website.name,
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
      title: website.title,
      description: website.description,
      url: website.url,
      siteName: website.name,
      locale: "en_US",
      type: "website",
      images: image ? [
        {
          url: image,
          width: 512,
          height: 512,
          alt: `${website.name} brand mark`,
        },
      ] : [],
    },
    twitter: {
      card: "summary_large_image",
      title: website.title,
      description: website.description,
      images: image ? [image] : [],
    },
    alternates: {
      canonical: website.url,
    },
    icons: {
      icon: "/brand-mark.svg",
      apple: "/brand-mark.svg",
    },
    appleWebApp: {
      capable: true,
      title: website.name,
      statusBarStyle: "black-translucent",
    },
  };
}

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0A111B",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const siteJsonLd = buildSiteJsonLd(await getClubProfile());

  return (
    <html
      lang="en"
      className={`${manrope.variable} ${spaceGrotesk.variable} ${inter.variable} ${barlowCondensed.variable} h-full antialiased`}
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
