import type { Metadata } from "next";
import type { ReactNode } from "react";
import { resolveVenueAccess } from "@/lib/data/venue-access";
import { getActiveTicketVerifierAssignments } from "@/lib/data/ticket-verification";
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
  if (result.status === "ready") {
    let canVerifyTickets = false;
    try {
      canVerifyTickets =
        (await getActiveTicketVerifierAssignments(result.client, result.access))
          .length > 0;
    } catch {
      // Ticket verification is an optional, fail-closed capability. A migration
      // or verifier-service issue must not take down unrelated venue workflows.
      console.error("Ticket verifier capability lookup failed");
    }
    return (
      <VenueAccessBoundary
        result={{
          ...result,
          access: { ...result.access, canVerifyTickets },
        }}
      >
        {children}
      </VenueAccessBoundary>
    );
  }
  return <VenueAccessBoundary result={result}>{children}</VenueAccessBoundary>;
}
