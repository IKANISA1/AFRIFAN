import type { Metadata } from "next";
import type { ReactNode } from "react";
import { AdminClientLoader } from "./admin-client-loader";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: "Admin workspace",
  description:
    "Touch-first admin workspace for Rayon Sports operations, publishing, and supporter management.",
  applicationName: "Gikundiro Admin",
  metadataBase: new URL(siteConfig.adminUrl),
  alternates: {
    canonical: siteConfig.adminUrl,
  },
  openGraph: {
    title: "Gikundiro Admin",
    description:
      "Touch-first admin workspace for Rayon Sports operations, publishing, and supporter management.",
    url: siteConfig.adminUrl,
    siteName: "Gikundiro Admin",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: `${siteConfig.siteUrl}/icons/icon-512x512.png`,
        width: 512,
        height: 512,
        alt: "Gikundiro admin crest",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "Gikundiro Admin",
    description:
      "Touch-first admin workspace for Rayon Sports operations, publishing, and supporter management.",
    images: [`${siteConfig.siteUrl}/icons/icon-512x512.png`],
  },
  appleWebApp: {
    capable: true,
    title: "Gikundiro Admin",
    statusBarStyle: "black-translucent",
  },
  robots: {
    index: false,
    follow: false,
  },
};

export default function AdminLayout({ children }: { children: ReactNode }) {
  return <AdminClientLoader>{children}</AdminClientLoader>;
}
