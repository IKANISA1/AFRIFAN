import type { ReactNode } from "react";
import { DeferredPwaShell } from "@/components/pwa/deferred-pwa-shell";
import { FanPortalProvider } from "@/components/portal/fan-portal-provider";
import { PortalShell } from "@/components/portal/portal-shell";

export default function FanPortalLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <FanPortalProvider>
      <DeferredPwaShell />
      <PortalShell>{children}</PortalShell>
    </FanPortalProvider>
  );
}
