import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { headers } from "next/headers";
import "./globals.css";
import { getClubProfile } from "@/lib/data/public";
import { buildSiteJsonLd, getClubWebsiteIdentity, renderJsonLdScriptContent } from "@/lib/metadata";
import { validCspNonce } from "@/lib/content-security-policy";

const inter = localFont({
  src: "../../public/fonts/inter-latin-wght-normal.woff2",
  variable: "--font-inter",
  weight: "100 900",
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
  themeColor: "#000000",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const siteJsonLd = buildSiteJsonLd(await getClubProfile());
  const requestNonce = (await headers()).get("x-africlub-csp-nonce");
  const nonce = validCspNonce(requestNonce) ? requestNonce : undefined;

  return (
    <html
      lang="en"
      className={`${inter.variable} h-full antialiased`}
    >
      <head />
      <body className="min-h-full flex flex-col">
        <script
          type="application/ld+json"
          nonce={nonce}
          dangerouslySetInnerHTML={{
            __html: renderJsonLdScriptContent(siteJsonLd),
          }}
        />
        {children}
      </body>
    </html>
  );
}
