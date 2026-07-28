import Link from "next/link";
import { ClipboardList, GlassWater, Monitor, QrCode, ShieldCheck, Users } from "lucide-react";
import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueOverview } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { VenueDataError, VenuePageHeader } from "./_components/venue-shell";

const workflows = [
  ["Orders queue", "/venue/orders", ClipboardList, "Accept, prepare, ready, serve, or cancel drinks orders."],
  ["Top-10 drinks", "/venue/menu", GlassWater, "Maintain the active drinks menu within the enforced ten-item limit."],
  ["Check-ins", "/venue/checkins", QrCode, "Review recent check-ins, location states, and FET awards."],
  ["TV code", "/venue/tv-code", Monitor, "Monitor the current hashed-code contract and expiry without exposing private data."],
  ["Promotions", "/venue/promotions", ShieldCheck, "Review approved campaign windows, budgets, and launch readiness."],
  ["Staff", "/venue/staff", Users, "See active assignments and role boundaries for this venue."],
] as const;

export default async function VenuePortalPage() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(() => getVenueOverview(result.client, result.access), "overview");
  if (!loaded.ok) return <main className="mx-auto max-w-7xl px-5 py-8"><VenueDataError correlationId={loaded.correlationId} /></main>;
  const overview = loaded.data;
  return (
      <main className="mx-auto grid max-w-7xl gap-8 px-5 py-8 lg:px-8">
        <VenuePageHeader eyebrow="Venue operations" title="Today at the venue" description="Every count and action below is scoped to your active staff assignment. Club-wide oversight remains in admin." />
        <section className="grid gap-4 md:grid-cols-3" aria-label="Today summary">
          {[["Campaigns", overview.activeCampaigns], ["Open orders", overview.openOrders], ["Check-ins today", overview.checkinsToday]].map(([label, value]) => (
            <div key={label} className={`${ui.panel} rounded-lg p-4`}><p className={ui.meta}>{label}</p><p className="mt-3 font-display text-3xl font-bold">{value}</p></div>
          ))}
        </section>
        <section className="grid gap-4 lg:grid-cols-3">
          {workflows.map(([title, href, Icon, body]) => (
            <Link key={href} href={href} className={`${ui.cardInteractive} rounded-lg p-5`}>
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-white/10 text-club-accent"><Icon size={20} aria-hidden="true" /></span>
              <h2 className="mt-5 text-lg font-bold uppercase">{title}</h2><p className="mt-3 text-sm leading-6 text-slate-300">{body}</p>
            </Link>
          ))}
        </section>
      </main>
  );
}
