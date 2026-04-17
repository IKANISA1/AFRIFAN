import Link from "next/link";
import { ShieldCheck } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getMatches } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { formatCurrency } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.tickets.metaTitle(club),
    description: copy.pages.tickets.metaDescription(club),
    path: "/tickets",
  });
}

export default async function TicketsPage() {
  const featureGate = await getFeaturePageGuard("ticketing");
  if (featureGate) {
    return featureGate;
  }

  const [club, matches] = await Promise.all([getClubProfile(), getMatches()]);
  const copy = getSiteCopy(club.defaultLanguage);
  const ticketed = matches.filter((match) => match.isOnSale || match.matchStatus === "live");
  const cheapest = ticketed.reduce(
    (lowest, match) => Math.min(lowest, match.generalPrice),
    ticketed[0]?.generalPrice ?? 0,
  );

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.tickets.eyebrow}
        title={copy.pages.tickets.title}
        description={copy.pages.tickets.description(club)}
        actions={
          <>
            <Link
              href="/supporters"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.continueInFanApp}
            </Link>
            <Link
              href="/membership"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.unlockPriorityAccess}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.onSale, value: ticketed.length.toString() },
          {
            label: copy.common.from,
            value: cheapest ? formatCurrency(cheapest) : formatCurrency(0),
          },
          { label: copy.common.checkout, value: copy.pages.tickets.checkoutFanApp },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <div className="grid gap-5 lg:grid-cols-2">
          {ticketed.map((match) => (
            <MatchCard
              key={match.id}
              match={match}
              href={`/tickets/${match.id}`}
              clubName={club.shortName}
              clubLogoUrl={club.officialLogoUrl}
            />
          ))}
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            {copy.pages.tickets.matchdayEssentials}
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
            {copy.pages.tickets.buyWithConfidence}
          </h2>
          <div className="mt-5 grid gap-4">
            {copy.pages.tickets.confidencePoints.map((point) => (
              <div
                key={point}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
              >
                {point}
              </div>
            ))}
          </div>
          <Link
            href="/membership"
            className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            {copy.common.ticketPriority} <ShieldCheck size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
