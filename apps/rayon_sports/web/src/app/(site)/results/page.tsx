import Link from "next/link";
import { ArrowRight, Trophy } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { PageHero } from "@/components/page-hero";
import { getMatches } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { isResultMatch } from "@/lib/utils";

export const metadata = buildPageMetadata({
  title: "Rayon Sports results",
  description:
    "Official Rayon Sports results with recent scorelines, match context, and links into the next fixture.",
  path: "/results",
});

function getRayonScoreline(match: Awaited<ReturnType<typeof getMatches>>[number]) {
  const rayonIsHome = match.homeTeam.toLowerCase().includes("rayon");
  return {
    goalsFor: rayonIsHome ? match.homeScore : match.awayScore,
    goalsAgainst: rayonIsHome ? match.awayScore : match.homeScore,
  };
}

export default async function ResultsPage() {
  const matches = await getMatches();
  const results = matches.filter((match) => isResultMatch(match.matchStatus));
  const wins = results.filter((match) => {
    const scoreline = getRayonScoreline(match);
    return scoreline.goalsFor > scoreline.goalsAgainst;
  }).length;
  const goalsFor = results.reduce(
    (total, match) => total + getRayonScoreline(match).goalsFor,
    0,
  );

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Results"
        title="Recent results and match momentum."
        description="See final scores, match summaries, and the direct route into the next Rayon Sports fixture."
        actions={
          <>
            <Link
              href="/fixtures"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Back to fixtures
            </Link>
            <Link
              href="/tickets"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Buy next tickets
            </Link>
          </>
        }
        stats={[
          { label: "Completed", value: results.length.toString() },
          { label: "Wins", value: wins.toString() },
          { label: "Goals for", value: goalsFor.toString() },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <div className="grid gap-5 lg:grid-cols-2">
          {results.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Recent form
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
            Results with context
          </h2>
          <div className="mt-5 grid gap-4">
            {[
              "Final score, venue, and competition stay visible at a glance.",
              "Key moments stay attached to the match instead of disappearing into a feed.",
              "Every completed fixture points toward the next action.",
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
            href="/standings"
            className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-club-ink transition hover:brightness-110"
          >
            League table <Trophy size={18} />
          </Link>
          <Link
            href="/news"
            className="mt-3 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Matchday coverage <ArrowRight size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
