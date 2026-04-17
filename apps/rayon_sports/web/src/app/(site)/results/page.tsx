import Link from "next/link";
import { ArrowRight, Trophy } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getMatches } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { isResultMatch } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.results.metaTitle(club),
    description: copy.pages.results.metaDescription(club),
    path: "/results",
  });
}

function getClubScoreline(
  match: Awaited<ReturnType<typeof getMatches>>[number],
  clubName: string,
) {
  const clubIsHome = match.homeTeam.toLowerCase().includes(clubName.toLowerCase());
  return {
    goalsFor: clubIsHome ? match.homeScore : match.awayScore,
    goalsAgainst: clubIsHome ? match.awayScore : match.homeScore,
  };
}

export default async function ResultsPage() {
  const featureGate = await getFeaturePageGuard("live");
  if (featureGate) {
    return featureGate;
  }

  const [club, matches] = await Promise.all([getClubProfile(), getMatches()]);
  const copy = getSiteCopy(club.defaultLanguage);
  const results = matches.filter((match) => isResultMatch(match.matchStatus));
  const wins = results.filter((match) => {
    const scoreline = getClubScoreline(match, club.shortName);
    return scoreline.goalsFor > scoreline.goalsAgainst;
  }).length;
  const goalsFor = results.reduce(
    (total, match) => total + getClubScoreline(match, club.shortName).goalsFor,
    0,
  );

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.results.eyebrow}
        title={copy.pages.results.title}
        description={copy.pages.results.description(club)}
        actions={
          <>
            <Link
              href="/fixtures"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.backToFixtures}
            </Link>
            <Link
              href="/tickets"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.buyNextTickets}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.completed, value: results.length.toString() },
          { label: copy.common.wins, value: wins.toString() },
          { label: copy.common.goalsFor, value: goalsFor.toString() },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <div className="grid gap-5 lg:grid-cols-2">
          {results.map((match) => (
            <MatchCard
              key={match.id}
              match={match}
              clubName={club.shortName}
              clubLogoUrl={club.officialLogoUrl}
            />
          ))}
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            {copy.pages.results.recentForm}
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
            {copy.pages.results.resultsWithContext}
          </h2>
          <div className="mt-5 grid gap-4">
            {copy.pages.results.contextPoints.map((point) => (
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
            className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            {copy.common.leagueTable} <Trophy size={18} />
          </Link>
          <Link
            href="/news"
            className="mt-3 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            {copy.common.matchdayCoverage} <ArrowRight size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
