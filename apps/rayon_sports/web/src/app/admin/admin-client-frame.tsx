"use client";

import type { ReactNode } from "react";
import { AdminPortalProvider } from "@/components/admin/admin-portal-provider";
import { AdminShell } from "@/components/admin/admin-shell";
import { AdminToastProvider } from "@/components/admin/admin-toast";
import { DeferredPwaShell } from "@/components/pwa/deferred-pwa-shell";
import { WebVitalsReporter } from "@/components/pwa/web-vitals-reporter";

export function AdminClientFrame({ children }: { children: ReactNode }) {
  return (
    <div className="admin-workspace">
      <AdminPortalProvider>
        <DeferredPwaShell />
        <WebVitalsReporter />
        <AdminShell>{children}</AdminShell>
        <AdminToastProvider />
      </AdminPortalProvider>
    </div>
  );
}
