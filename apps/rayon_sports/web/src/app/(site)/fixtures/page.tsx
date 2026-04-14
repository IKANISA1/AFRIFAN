import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getMatches } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { isLiveMatch, isResultMatch } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.fixtures.metaTitle(club),
    description: copy.pages.fixtures.metaDescription(club),
    path: "/fixtures",
  });
}

export default async function FixturesPage() {
  const [club, matches] = await Promise.all([getClubProfile(), getMatches()]);
  const copy = getSiteCopy(club.defaultLanguage);
  const liveMatches = matches.filter((match) => isLiveMatch(match.matchStatus));
  const upcomingMatches = matches.filter(
    (match) => !isLiveMatch(match.matchStatus) && !isResultMatch(match.matchStatus),
  );
  const results = matches.filter((match) => isResultMatch(match.matchStatus));

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.fixtures.eyebrow}
        title={copy.pages.fixtures.title}
        description={copy.pages.fixtures.description(club)}
        actions={
          <>
            <Link
              href="/tickets"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.buyTickets}
            </Link>
            <Link
              href="/results"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.recentResults}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.live, value: liveMatches.length.toString() },
          {
            label: copy.common.onSale,
            value: matches.filter((match) => match.isOnSale).length.toString(),
          },
          { label: copy.common.listed, value: matches.length.toString() },
        ]}
      />

      {liveMatches.length > 0 ? (
        <section className="section-grid">
          <div className="flex items-end justify-between gap-4">
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                {copy.common.live}
              </p>
              <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
                {copy.pages.fixtures.liveNowTitle}
              </h2>
            </div>
          </div>
          <div className="grid gap-5 lg:grid-cols-2">
            {liveMatches.map((match) => (
              <MatchCard
                key={match.id}
                match={match}
                clubName={club.shortName}
                clubLogoUrl={club.officialLogoUrl}
              />
            ))}
          </div>
        </section>
      ) : null}

      <section className="section-grid">
        <div className="flex items-end justify-between gap-4">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.next}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.pages.fixtures.upcomingTitle}
            </h2>
          </div>
          <Link
            href="/tickets"
            className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            {copy.buyTickets} <ArrowRight size={16} />
          </Link>
        </div>
        <div className="grid gap-5 lg:grid-cols-3">
          {upcomingMatches.map((match) => (
            <MatchCard
              key={match.id}
              match={match}
              clubName={club.shortName}
              clubLogoUrl={club.officialLogoUrl}
            />
          ))}
        </div>
      </section>

      {results.length > 0 ? (
        <section className="section-grid">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.pages.results.eyebrow}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.common.recentScorelines}
            </h2>
          </div>
          <div className="grid gap-5 lg:grid-cols-3">
            {results.map((match) => (
              <MatchCard
                key={match.id}
                match={match}
                clubName={club.shortName}
                clubLogoUrl={club.officialLogoUrl}
              />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
