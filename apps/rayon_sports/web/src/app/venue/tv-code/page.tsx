import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueTvCode } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { ControlledVenueRoutePage } from "../_components/controlled-venue-route";
import {
  controlledVenueEvidenceState,
  type VenueEvidenceSearchParams,
} from "../_components/controlled-venue-request";
import {
  VenueDataError,
  VenueEmptyState,
  VenuePageHeader,
} from "../_components/venue-shell";

export default async function VenueTvCodePage({
  searchParams,
}: {
  searchParams: VenueEvidenceSearchParams;
}) {
  const evidenceState = await controlledVenueEvidenceState(searchParams);
  if (evidenceState != null) {
    return (
      <ControlledVenueRoutePage route="tv-code" initialState={evidenceState} />
    );
  }
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(
    () => getVenueTvCode(result.client, result.access),
    "tv-code",
  );
  if (!loaded.ok)
    return (
      <main className="mx-auto max-w-7xl px-5 py-8">
        <VenueDataError correlationId={loaded.correlationId} />
      </main>
    );
  const code = loaded.data;
  return (
    <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader
        eyebrow="Paired display"
        title="TV code status"
        description="Check whether the assigned venue display has an active rotating code. The readable code appears only on the paired display."
      />
      {code == null ? (
        <VenueEmptyState
          title="No active TV code"
          body="Ask a club administrator to pair the display and issue an approved rotating code."
        />
      ) : (
        <section className={`${ui.panelElevated} rounded-lg p-7`}>
          <p className={ui.kicker}>{code.status}</p>
          <h2 className="mt-3 text-3xl font-bold">{code.campaignName}</h2>
          <dl className="mt-6 grid gap-4 md:grid-cols-2">
            <div className={`${ui.panelInset} rounded-lg p-4`}>
              <dt className="text-sm text-slate-400">Expires</dt>
              <dd className="mt-2 text-lg font-bold">
                {new Date(code.expiresAt).toLocaleString()}
              </dd>
            </div>
            <div className={`${ui.panelInset} rounded-lg p-4`}>
              <dt className="text-sm text-slate-400">Next rotation</dt>
              <dd className="mt-2 text-lg font-bold">
                {code.rotatesAt
                  ? new Date(code.rotatesAt).toLocaleString()
                  : "Managed by club admin"}
              </dd>
            </div>
          </dl>
          <p className="mt-5 text-sm text-slate-300">
            Use the paired venue display to show the readable code. This portal
            shows only its safe operational status.
          </p>
        </section>
      )}
    </main>
  );
}
