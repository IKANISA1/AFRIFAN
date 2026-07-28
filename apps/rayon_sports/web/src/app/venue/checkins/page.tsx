import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueCheckins } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { VenueDataError, VenueEmptyState, VenuePageHeader } from "../_components/venue-shell";

export default async function VenueCheckinsPage() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(() => getVenueCheckins(result.client, result.access), "checkins");
  if (!loaded.ok) return <main className="mx-auto max-w-7xl px-5 py-8"><VenueDataError correlationId={loaded.correlationId} /></main>;
  const checkins = loaded.data;
  return <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader eyebrow="Recent activity" title="Check-ins" description="Review check-in status, location verification, and awarded FET. Identity details remain outside this operational list." />
      {checkins.length === 0 ? <VenueEmptyState title="No check-ins" body="No supporters have checked in at this assigned venue yet." /> : <section className="overflow-x-auto rounded-lg border border-white/10"><table className="min-w-full text-left text-sm"><thead className="bg-white/5 text-xs uppercase tracking-wider text-slate-400"><tr><th className="p-4">Time</th><th className="p-4">Status</th><th className="p-4">Location</th><th className="p-4">FET</th><th className="p-4">Review</th></tr></thead><tbody>{checkins.map((checkin) => <tr key={checkin.id} className="border-t border-white/10"><td className="p-4">{new Date(checkin.checkedInAt).toLocaleString()}</td><td className="p-4"><span className={ui.chip}>{checkin.status}</span></td><td className="p-4">{checkin.locationStatus}</td><td className="p-4">{checkin.fetAwarded}</td><td className="p-4 text-slate-300">{checkin.reviewReason || "—"}</td></tr>)}</tbody></table></section>}
  </main>;
}
