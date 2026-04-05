import Link from "next/link";
import { ShieldCheck } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { PageHero } from "@/components/page-hero";
import { getMatches } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { formatCurrency } from "@/lib/utils";

export const metadata = buildPageMetadata({
  title: "Rayon Sports tickets",
  description:
    "Official Rayon Sports ticket hub with fixture detail, live pricing, and secure checkout in the fan portal.",
  path: "/tickets",
});

export default async function TicketsPage() {
  const matches = await getMatches();
  const ticketed = matches.filter((match) => match.isOnSale || match.matchStatus === "live");
  const cheapest = ticketed.reduce(
    (lowest, match) => Math.min(lowest, match.generalPrice),
    ticketed[0]?.generalPrice ?? 0,
  );

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Ticketing"
        title="Tickets and matchday access."
        description="See venue, kickoff, pricing, and availability before moving into secure checkout in the fan portal."
        actions={
          <>
            <Link
              href="/app/tickets"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Purchase in portal
            </Link>
            <Link
              href="/membership"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Unlock priority access
            </Link>
          </>
        }
        stats={[
          { label: "On sale", value: ticketed.length.toString() },
          {
            label: "From",
            value: cheapest ? formatCurrency(cheapest) : formatCurrency(0),
          },
          { label: "Portal", value: "Secure" },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <div className="grid gap-5 lg:grid-cols-2">
          {ticketed.map((match) => (
            <MatchCard
              key={match.id}
              match={match}
              href={`/tickets/${match.id}`}
            />
          ))}
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Matchday essentials
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
            Buy with confidence
          </h2>
          <div className="mt-5 grid gap-4">
            {[
              "Pricing stays visible before sign-in.",
              "Venue, competition, and kickoff stay attached to every fixture.",
              "Membership priority is visible before checkout opens.",
            ].map((point) => (
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
            Membership benefits <ShieldCheck size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
