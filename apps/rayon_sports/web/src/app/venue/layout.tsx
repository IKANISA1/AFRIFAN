import type { Metadata } from "next";
import type { ReactNode } from "react";
import { resolveVenueAccess } from "@/lib/data/venue-access";
import {
  controlledVenueAccess,
  isControlledVenueEvidenceRequest,
} from "./_components/controlled-venue-request";
import { VenueAccessBoundary } from "./_components/venue-shell";
import { VenueShellClient } from "./_components/venue-shell-client";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Venue operations",
  description: "Authenticated venue-scoped matchday operations.",
  robots: { index: false, follow: false },
};

export default async function VenueLayout({
  children,
}: {
  children: ReactNode;
}) {
  if (await isControlledVenueEvidenceRequest()) {
    return (
      <VenueShellClient access={controlledVenueAccess}>
        {children}
      </VenueShellClient>
    );
  }
  const result = await resolveVenueAccess();
  return <VenueAccessBoundary result={result}>{children}</VenueAccessBoundary>;
}
