import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueTvCode } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { VenueDataError, VenueEmptyState, VenuePageHeader } from "../_components/venue-shell";

export default async function VenueTvCodePage() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(() => getVenueTvCode(result.client, result.access), "tv-code");
  if (!loaded.ok) return <main className="mx-auto max-w-7xl px-5 py-8"><VenueDataError correlationId={loaded.correlationId} /></main>;
  const code = loaded.data;
  return <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader eyebrow="Screen-safe contract" title="TV code status" description="Raw check-in codes are never stored or exposed here. This page confirms the active hashed-code lifecycle for the assigned venue." />
      {code == null ? <VenueEmptyState title="No active TV code" body="Ask club admin to pair the display and issue an approved rotating code." /> : <section className={`${ui.panelElevated} rounded-lg p-7`}><p className={ui.kicker}>{code.status}</p><h2 className="mt-3 text-3xl font-bold">{code.campaignName}</h2><dl className="mt-6 grid gap-4 md:grid-cols-2"><div className={`${ui.panelInset} rounded-lg p-4`}><dt className="text-sm text-slate-400">Expires</dt><dd className="mt-2 text-lg font-bold">{new Date(code.expiresAt).toLocaleString()}</dd></div><div className={`${ui.panelInset} rounded-lg p-4`}><dt className="text-sm text-slate-400">Next rotation</dt><dd className="mt-2 text-lg font-bold">{code.rotatesAt ? new Date(code.rotatesAt).toLocaleString() : "Managed by admin"}</dd></div></dl><p className="mt-5 text-sm text-slate-300">To display or rotate the human-readable code, use the paired native TV and admin game controls. This portal intentionally cannot recover a raw code from its stored hash.</p></section>}
  </main>;
}
