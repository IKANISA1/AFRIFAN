import { resolveVenueAccess } from "@/lib/data/venue-access";
import {
  getActiveTicketVerifierAssignments,
  uniqueAssignedGateCodes,
} from "@/lib/data/ticket-verification";
import { ui } from "@/ui-kit";
import { ControlledVenueRoutePage } from "../../_components/controlled-venue-route";
import {
  controlledVenueEvidenceState,
  type VenueEvidenceSearchParams,
} from "../../_components/controlled-venue-request";
import { VenueDataError, VenuePageHeader } from "../../_components/venue-shell";
import { TicketVerifier } from "./ticket-verifier";

export const dynamic = "force-dynamic";

export default async function TicketVerificationPage({
  searchParams,
}: {
  searchParams: VenueEvidenceSearchParams;
}) {
  const evidenceState = await controlledVenueEvidenceState(searchParams);
  if (evidenceState != null) {
    return (
      <ControlledVenueRoutePage
        route="ticket-verification"
        initialState={evidenceState}
      />
    );
  }
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;

  let assignments;
  try {
    assignments = await getActiveTicketVerifierAssignments(
      result.client,
      result.access,
    );
  } catch {
    return (
      <main className="mx-auto max-w-7xl px-5 py-8">
        <VenueDataError
          correlationId={`ticket-verify-${crypto.randomUUID()}`}
        />
      </main>
    );
  }

  if (assignments.length === 0) {
    return (
      <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
        <VenuePageHeader
          eyebrow="Restricted operation"
          title="Ticket verification"
          description="Admission verification is available only to selected users with a live organization, event, venue, gate, and shift assignment."
        />
        <section
          className={`${ui.panelElevated} rounded-lg border border-amber-300/30 p-6`}
          role="alert"
        >
          <h2 className="text-xl font-bold uppercase">
            No active verifier assignment
          </h2>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-300">
            Ask the ticket organization administrator to assign this account.
            Venue staff membership by itself does not authorize ticket
            admission.
          </p>
        </section>
      </main>
    );
  }

  return (
    <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader
        eyebrow={`${assignments.length} active assignment${assignments.length === 1 ? "" : "s"}`}
        title="Ticket verification"
        description="Scan the current Google Wallet rotating QR. Each result is checked against authoritative payment, ticket state, event window, venue, gate, and your live assignment before admission is recorded."
      />
      <TicketVerifier gates={uniqueAssignedGateCodes(assignments)} />
    </main>
  );
}
