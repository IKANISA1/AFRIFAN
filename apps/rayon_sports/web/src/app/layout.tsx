import type { Metadata, Viewport } from "next";
import { Barlow_Condensed, Inter, Space_Mono, Bebas_Neue } from "next/font/google";
import "./globals.css";
import { PwaShell } from "@/components/pwa/pwa-shell";
import { absoluteUrl, siteConfig } from "@/lib/config";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

const barlow = Barlow_Condensed({
  variable: "--font-barlow",
  subsets: ["latin"],
  weight: ["400", "600", "700", "800"],
});

const bebasNeue = Bebas_Neue({
  variable: "--font-bebas",
  subsets: ["latin"],
  weight: "400",
});

const spaceMono = Space_Mono({
  variable: "--font-space-mono",
  subsets: ["latin"],
  weight: ["400", "700"],
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
    "Rayon Sports",
    "Gikundiro",
    "Rwanda football",
    "football club web app",
    "fan portal",
    "tickets",
    "membership",
  ],
  openGraph: {
    title: siteConfig.title,
    description: siteConfig.description,
    url: siteConfig.siteUrl,
    siteName: siteConfig.shortTitle,
    locale: "en_US",
    type: "website",
    images: [
      {
        url: absoluteUrl("/media/rayon-crest.png"),
        width: 512,
        height: 512,
        alt: "Rayon Sports crest",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: siteConfig.title,
    description: siteConfig.description,
    images: [absoluteUrl("/media/rayon-crest.png")],
  },
  alternates: {
    canonical: siteConfig.siteUrl,
  },
  icons: {
    icon: "/media/rayon-crest.png",
    apple: "/media/rayon-crest.png",
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
  return (
    <html
      lang="en"
      className={`${inter.variable} ${barlow.variable} ${spaceMono.variable} ${bebasNeue.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <PwaShell />
        {children}
      </body>
    </html>
  );
}
