import Link from "next/link";
import { MapPin, Smartphone } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { resolveFanAppHref } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import { getApprovedPublicVenues } from "@/lib/data/venue";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";

export async function generateMetadata() {
  return buildPageMetadata({
    title: "Partner venues",
    description:
      "Approved Rayon Sports partner venues with fan-app handoff for check-in and matchday ordering.",
    path: "/venues",
  });
}

export default async function PublicVenuesPage() {
  const featureGate = await getFeaturePageGuard("venue_app");
  if (featureGate) {
    return featureGate;
  }

  const [club, venues] = await Promise.all([
    getClubProfile(),
    getApprovedPublicVenues(),
  ]);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Partner venues"
        title={`${club.shortName} matchday venues`}
        description="Approved venues appear here for discovery only. Check-in, rewards, and drinks ordering continue in the secure supporter app."
        actions={
          <Link
            href={resolveFanAppHref()}
            className="inline-flex min-h-12 items-center justify-center rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            <Smartphone size={18} aria-hidden="true" />
            <span className="ml-2">Open supporter app</span>
          </Link>
        }
        stats={[
          { label: "Approved", value: venues.length.toString() },
          { label: "Check-in", value: "Mobile" },
          { label: "Orders", value: "Mobile" },
        ]}
      />

      {venues.length > 0 ? (
        <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {venues.map((venue) => (
            <article key={venue.id} className="glass-panel rounded-[30px] p-6">
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-club-primary/15 text-club-accent">
                <MapPin size={20} aria-hidden="true" />
              </span>
              <h2 className="mt-5 font-display text-2xl font-bold uppercase text-white">
                {venue.displayName}
              </h2>
              <p className="mt-2 text-xs font-bold uppercase tracking-[0.18em] text-slate-400">
                {venue.city}
              </p>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {venue.summary}
              </p>
            </article>
          ))}
        </section>
      ) : (
        <section className="glass-panel rounded-[30px] p-6 text-sm leading-7 text-slate-300">
          Approved partner venue profiles will appear after club review. Public web never performs authenticated check-in and never shows live order queues.
        </section>
      )}
    </div>
  );
}
