import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueStaff } from "@/lib/data/venue-operations";
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

export default async function VenueStaffPage({
  searchParams,
}: {
  searchParams: VenueEvidenceSearchParams;
}) {
  const evidenceState = await controlledVenueEvidenceState(searchParams);
  if (evidenceState != null) {
    return (
      <ControlledVenueRoutePage route="staff" initialState={evidenceState} />
    );
  }
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(
    () => getVenueStaff(result.client, result.access),
    "staff",
  );
  if (!loaded.ok)
    return (
      <main className="mx-auto max-w-7xl px-5 py-8">
        <VenueDataError correlationId={loaded.correlationId} />
      </main>
    );
  const staff = loaded.data;
  return (
    <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader
        eyebrow="Active assignments"
        title="Venue staff"
        description="This read-only roster shows active role assignments. Club admin owns granting, changing, and revoking access."
      />
      {staff.length === 0 ? (
        <VenueEmptyState
          title="No visible staff"
          body="No active assignments are visible to this account."
        />
      ) : (
        <section className="grid gap-4 md:grid-cols-2">
          {staff.map((member, index) => (
            <article key={member.id} className={`${ui.panel} rounded-lg p-5`}>
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className={ui.kicker}>{member.role}</p>
                  <h2 className="mt-2 text-base font-bold">
                    Active assignment {index + 1}
                  </h2>
                </div>
                {member.isCurrentUser ? (
                  <span className={ui.chipSignal}>You</span>
                ) : null}
              </div>
              <p className="mt-4 text-sm text-slate-400">
                Assigned {new Date(member.grantedAt).toLocaleDateString()}
              </p>
            </article>
          ))}
        </section>
      )}
    </main>
  );
}
