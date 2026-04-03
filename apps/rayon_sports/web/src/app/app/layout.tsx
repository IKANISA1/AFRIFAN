import type { ReactNode } from "react";
import { FanPortalProvider } from "@/components/portal/fan-portal-provider";
import { PortalShell } from "@/components/portal/portal-shell";

export default function FanPortalLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <FanPortalProvider>
      <PortalShell>{children}</PortalShell>
    </FanPortalProvider>
  );
}
