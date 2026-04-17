import type { Metadata } from "next";
import type { ReactNode } from "react";
import { AdminClientFrame } from "./admin-client-frame";
import { siteConfig } from "@/lib/config";
import { getAdminPortalInitialState } from "@/lib/data/admin/bootstrap";

export const metadata: Metadata = {
  title: "Admin workspace",
  description:
    "Desktop-first admin workspace for club operations, publishing, supporter management, and white-label configuration.",
  applicationName: "AfriClub Admin",
  metadataBase: new URL(siteConfig.adminUrl),
  alternates: {
    canonical: siteConfig.adminUrl,
  },
  openGraph: {
    title: "AfriClub Admin",
    description:
      "Desktop-first admin workspace for club operations, publishing, supporter management, and white-label configuration.",
    url: siteConfig.adminUrl,
    siteName: "AfriClub Admin",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: `${siteConfig.siteUrl}/icons/icon-512x512.png`,
        width: 512,
        height: 512,
        alt: "AfriClub admin crest",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "AfriClub Admin",
    description:
      "Desktop-first admin workspace for club operations, publishing, supporter management, and white-label configuration.",
    images: [`${siteConfig.siteUrl}/icons/icon-512x512.png`],
  },
  appleWebApp: {
    capable: true,
    title: "AfriClub Admin",
    statusBarStyle: "black-translucent",
  },
  robots: {
    index: false,
    follow: false,
  },
};

export default async function AdminLayout({ children }: { children: ReactNode }) {
  const initialState = await getAdminPortalInitialState();
  return <AdminClientFrame initialState={initialState}>{children}</AdminClientFrame>;
}
