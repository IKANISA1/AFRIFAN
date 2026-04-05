"use client";

import type { ReactNode } from "react";
import { DeferredPwaShell } from "@/components/pwa/deferred-pwa-shell";
import { WebVitalsReporter } from "@/components/pwa/web-vitals-reporter";
import { FanPortalProvider } from "@/components/portal/fan-portal-provider";
import { PortalShell } from "@/components/portal/portal-shell";

export function FanPortalFrame({ children }: { children: ReactNode }) {
  return (
    <FanPortalProvider>
      <DeferredPwaShell />
      <WebVitalsReporter />
      <PortalShell>{children}</PortalShell>
    </FanPortalProvider>
  );
}
