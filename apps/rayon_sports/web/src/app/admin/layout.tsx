import type { Metadata } from "next";
import type { ReactNode } from "react";
import { AdminPortalProvider } from "@/components/admin/admin-portal-provider";
import { AdminShell } from "@/components/admin/admin-shell";
import { AdminToastProvider } from "@/components/admin/admin-toast";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: "Admin workspace",
  description:
    "Touch-first admin workspace for Rayon Sports operations, publishing, and supporter management.",
  metadataBase: new URL(siteConfig.adminUrl),
  alternates: {
    canonical: siteConfig.adminUrl,
  },
  robots: {
    index: false,
    follow: false,
  },
};

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <AdminPortalProvider>
      <AdminShell>{children}</AdminShell>
      <AdminToastProvider />
    </AdminPortalProvider>
  );
}
