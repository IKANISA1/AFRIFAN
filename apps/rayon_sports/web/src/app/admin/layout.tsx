import type { Metadata } from "next";
import type { ReactNode } from "react";
import { AdminPortalProvider } from "@/components/admin/admin-portal-provider";
import { AdminShell } from "@/components/admin/admin-shell";
import { AdminToastProvider } from "@/components/admin/admin-toast";
import { DeferredPwaShell } from "@/components/pwa/deferred-pwa-shell";
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
        url: `${siteConfig.siteUrl}/media/rayon-crest.png`,
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
    images: [`${siteConfig.siteUrl}/media/rayon-crest.png`],
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
  return (
    <AdminPortalProvider>
      <DeferredPwaShell />
      <AdminShell>{children}</AdminShell>
      <AdminToastProvider />
    </AdminPortalProvider>
  );
}
