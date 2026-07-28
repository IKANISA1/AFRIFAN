import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueCampaigns } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { PromotionLaunchForm } from "../_components/venue-forms";
import { VenueDataError, VenueEmptyState, VenuePageHeader } from "../_components/venue-shell";

export default async function VenuePromotionsPage() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(() => getVenueCampaigns(result.client, result.access), "promotions");
  if (!loaded.ok) return <main className="mx-auto max-w-7xl px-5 py-8"><VenueDataError correlationId={loaded.correlationId} /></main>;
  const campaigns = loaded.data;
  return <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader eyebrow="Approved controls" title="Promotions" description="Venue staff can monitor approved check-in campaigns. Creation, approval, and budget changes remain club-admin controls." />
      {campaigns.length === 0 ? <VenueEmptyState title="No campaigns" body="No campaign is assigned to this venue. Club admin must create and approve one before launch." /> : <section className="grid gap-4 lg:grid-cols-2">{campaigns.map((campaign) => {
        const remaining = Math.max(0, campaign.budget - campaign.awarded);
        const launchable = campaign.isLaunchable;
        return <article key={campaign.id} className={`${ui.panel} rounded-lg p-5`}><div className="flex items-start justify-between gap-4"><div><p className={ui.kicker}>{campaign.status}</p><h2 className="mt-2 text-xl font-bold">{campaign.name}</h2></div><span className={ui.chip}>{campaign.fetAward} FET/check-in</span></div><dl className="mt-5 grid gap-3 text-sm md:grid-cols-2"><div><dt className="text-slate-400">Window</dt><dd>{new Date(campaign.startsAt).toLocaleString()} – {new Date(campaign.endsAt).toLocaleString()}</dd></div><div><dt className="text-slate-400">Budget remaining</dt><dd>{remaining.toLocaleString()} FET</dd></div><div><dt className="text-slate-400">Location</dt><dd>{campaign.requireLocation ? "Required" : "Not required"}</dd></div><div><dt className="text-slate-400">Launch readiness</dt><dd>{launchable ? "Ready" : "Unavailable"}</dd></div></dl>{result.access.canLaunchPromotions && launchable ? <PromotionLaunchForm campaignId={campaign.id} /> : null}</article>;
      })}</section>}
  </main>;
}
