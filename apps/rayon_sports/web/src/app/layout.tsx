import type { Metadata, Viewport } from "next";
import { Inter, Manrope, Space_Grotesk } from "next/font/google";
import "./globals.css";
import { absoluteUrl, siteConfig } from "@/lib/config";
import { buildSiteJsonLd, renderJsonLdScriptContent } from "@/lib/metadata";

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
        url: absoluteUrl("/brand-mark.svg"),
        width: 512,
        height: 512,
        alt: `${siteConfig.shortTitle} brand mark`,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: siteConfig.title,
    description: siteConfig.description,
    images: [absoluteUrl("/brand-mark.svg")],
  },
  alternates: {
    canonical: siteConfig.siteUrl,
  },
  icons: {
    icon: "/brand-mark.svg",
    apple: "/brand-mark.svg",
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
  themeColor: "#0A111B",
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
      className={`${manrope.variable} ${spaceGrotesk.variable} ${inter.variable} h-full antialiased`}
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
