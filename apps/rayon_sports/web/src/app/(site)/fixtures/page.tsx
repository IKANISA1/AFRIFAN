import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { PageHero } from "@/components/page-hero";
import { getMatches } from "@/lib/data/public";
import { isLiveMatch, isResultMatch } from "@/lib/utils";

export default async function FixturesPage() {
  const matches = await getMatches();
  const liveMatches = matches.filter((match) => isLiveMatch(match.matchStatus));
  const upcomingMatches = matches.filter(
    (match) => !isLiveMatch(match.matchStatus) && !isResultMatch(match.matchStatus),
  );
  const results = matches.filter((match) => isResultMatch(match.matchStatus));

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Fixtures"
        title="Live, upcoming, and recent match context in one schedule."
        description="The public fixture hub should answer matchday questions immediately, keep live hooks visible, and move ticket buyers into the portal without friction."
        actions={
          <>
            <Link
              href="/tickets"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Buy tickets
            </Link>
            <Link
              href="/results"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Recent results
            </Link>
          </>
        }
        stats={[
          { label: "Live now", value: liveMatches.length.toString() },
          {
            label: "On sale",
            value: matches.filter((match) => match.isOnSale).length.toString(),
          },
          { label: "Listed", value: matches.length.toString() },
        ]}
      />

      {liveMatches.length > 0 ? (
        <section className="section-grid">
          <div className="flex items-end justify-between gap-4">
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                Live now
              </p>
              <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
                Matchday at full speed
              </h2>
            </div>
          </div>
          <div className="grid gap-5 lg:grid-cols-2">
            {liveMatches.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        </section>
      ) : null}

      <section className="section-grid">
        <div className="flex items-end justify-between gap-4">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Upcoming
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              Ticket-ready fixtures
            </h2>
          </div>
          <Link
            href="/tickets"
            className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Open ticket hub <ArrowRight size={16} />
          </Link>
        </div>
        <div className="grid gap-5 lg:grid-cols-3">
          {upcomingMatches.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </div>
      </section>

      {results.length > 0 ? (
        <section className="section-grid">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Results
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              Recent scorelines
            </h2>
          </div>
          <div className="grid gap-5 lg:grid-cols-3">
            {results.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
