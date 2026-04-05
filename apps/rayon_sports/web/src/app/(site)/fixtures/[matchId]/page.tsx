import Image from "next/image";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { MatchCard } from "@/components/match-card";
import { MatchPoll } from "@/components/engagement/match-poll";
import { MotmVoting } from "@/components/engagement/motm-voting";
import { ScorePrediction } from "@/components/engagement/score-prediction";
import { NotificationOptInCard } from "@/components/pwa/notification-opt-in-card";
import { ShareActionButton } from "@/components/pwa/share-action-button";
import { getMatchById, getMatches } from "@/lib/data/public";
import { buildMatchJsonLd, buildPageMetadata } from "@/lib/metadata";
import {
  formatCurrency,
  formatDateTime,
  formatMatchStatusLabel,
  isLiveMatch,
  isResultMatch,
} from "@/lib/utils";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ matchId: string }>;
}): Promise<Metadata> {
  const { matchId } = await params;
  const match = await getMatchById(matchId);

  return buildPageMetadata({
    title: match
      ? `${match.homeTeam} vs ${match.awayTeam}`
      : "Fixture detail",
    description: match?.matchSummary ?? "Fixture detail and ticketing context.",
    path: `/fixtures/${matchId}`,
    imagePath: match?.imageUrl ?? "/media/stadium-hero.jpg",
  });
}

export default async function FixtureDetailPage({
  params,
}: {
  params: Promise<{ matchId: string }>;
}) {
  const { matchId } = await params;
  const [match, matches] = await Promise.all([getMatchById(matchId), getMatches()]);

  if (match == null) {
    notFound();
  }

  const relatedMatches = matches
    .filter((candidate) => candidate.id !== match.id)
    .slice(0, 2);
  const live = isLiveMatch(match.matchStatus);
  const result = isResultMatch(match.matchStatus);

  return (
    <div className="page-shell section-grid py-12">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(buildMatchJsonLd(match)),
        }}
      />
      <section className="glass-panel-elevated overflow-hidden rounded-[38px] border border-border-soft">
        <div className="grid gap-8 lg:grid-cols-[1.02fr_0.98fr]">
          <div className="p-6 sm:p-8">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {match.competition}
            </p>
            <h1 className="mt-4 font-display text-6xl font-bold uppercase leading-none text-white text-balance">
              {match.homeTeam}
              <span className="block text-white/70">vs {match.awayTeam}</span>
            </h1>
            <div className="mt-5 flex flex-wrap gap-2">
              <span className={live ? "badge-live" : result ? "badge-fulltime" : "badge-scheduled"}>
                {formatMatchStatusLabel(match.matchStatus)}
              </span>
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                {formatDateTime(match.matchDate)}
              </span>
              <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                {match.venue}
              </span>
            </div>
            <p className="mt-6 max-w-3xl text-sm leading-8 text-slate-300 sm:text-base">
              {match.matchSummary}
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/app/tickets"
                className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
              >
                Purchase in fan portal
              </Link>
              <Link
                href="/fixtures"
                className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              >
                Back to fixtures
              </Link>
              <ShareActionButton
                title={`${match.homeTeam} vs ${match.awayTeam}`}
                text={match.matchSummary ?? `${match.competition} at ${match.venue}.`}
                url={`/fixtures/${match.id}`}
                className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
              />
            </div>
          </div>

          <div className="img-zoom relative min-h-[20rem]">
            <Image
              src={match.imageUrl ?? "/media/stadium-hero.jpg"}
              alt={`${match.homeTeam} vs ${match.awayTeam}`}
              fill
              sizes="(min-width: 1024px) 48vw, 100vw"
              className="object-cover"
            />
            <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent_30%,rgba(3,10,24,0.72)_100%)]" />
            <div className="absolute bottom-5 right-5 rounded-[26px] border border-white/10 bg-[#051228]/82 px-5 py-4 text-center backdrop-blur-xl">
              <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                Score
              </p>
              <p className="mt-2 font-score text-6xl text-white">
                {live || result
                  ? `${match.homeScore}-${match.awayScore}`
                  : formatCurrency(match.generalPrice)}
              </p>
            </div>
          </div>
        </div>
      </section>

      <div className="grid gap-8 lg:grid-cols-[1.05fr_0.95fr]">
        <div className="space-y-6">
          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-display text-4xl font-bold uppercase leading-none text-white">
              Match detail
            </p>
            <div className="mt-5 grid gap-4 sm:grid-cols-3">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-300">
                  Kickoff
                </p>
                <p className="mt-2 text-sm text-slate-200">
                  {formatDateTime(match.matchDate)}
                </p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-300">
                  Venue
                </p>
                <p className="mt-2 text-sm text-slate-200">{match.venue}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-300">
                  Match status
                </p>
                <p className="mt-2 text-sm text-slate-200">
                  {formatMatchStatusLabel(match.matchStatus)}
                </p>
              </div>
            </div>
            <p className="mt-6 text-sm leading-7 text-slate-300">
              {match.matchSummary}
            </p>
          </div>
        </div>

        <div className="space-y-6">
          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-display text-4xl font-bold uppercase leading-none">
              Ticketing
            </p>
            <div className="mt-5 grid gap-4 sm:grid-cols-2">
              <div className="rounded-[24px] border border-border-soft bg-white/6 p-5">
                <p className="text-xs uppercase tracking-[0.2em] text-slate-300">
                  General
                </p>
                <p className="mt-3 font-display text-3xl font-bold uppercase">
                  {formatCurrency(match.generalPrice)}
                </p>
              </div>
              <div className="rounded-[24px] border border-border-soft bg-white/6 p-5">
                <p className="text-xs uppercase tracking-[0.2em] text-slate-300">
                  VIP
                </p>
                <p className="mt-3 font-display text-3xl font-bold uppercase">
                  {formatCurrency(match.vipPrice)}
                </p>
              </div>
            </div>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/app/tickets"
                className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
              >
                Purchase in fan portal
              </Link>
              <Link
                href={`/app/live/${match.id}`}
                className="rounded-full border border-border-soft px-5 py-3 font-semibold text-white transition hover:bg-white/8"
              >
                Open live center
              </Link>
            </div>
          </div>

          <NotificationOptInCard
            surface="site"
            path={`/fixtures/${match.id}`}
            title="Turn on live match alerts."
            description="Enable browser notifications after you have opened a real match context, so goals, kickoff updates, and ticketing reminders can reach you without forcing first-load permission prompts."
          />

          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-display text-4xl font-bold uppercase leading-none">
              Live events
            </p>
            <div className="mt-5 grid gap-3">
              {match.liveEvents.length > 0 ? (
                match.liveEvents.map((event) => (
                  <div
                    key={`${event.minute}-${event.event}`}
                    className="rounded-[22px] border border-border-soft bg-white/6 p-4"
                  >
                    <p className="font-mono text-xs uppercase tracking-[0.2em] text-club-accent">
                      {event.minute} • {event.side}
                    </p>
                    <p className="mt-2 text-sm text-slate-200">{event.event}</p>
                  </div>
                ))
              ) : (
                <p className="text-sm leading-7 text-slate-300">
                  Live events will appear here when the admin desk updates the
                  match feed.
                </p>
              )}
            </div>
          </div>

          {/* ── Fan engagement hub ── */}
          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
              Fan engagement
            </p>
            <h2 className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white sm:text-4xl">
              Get involved
            </h2>
            <p className="mt-3 text-sm leading-7 text-slate-300">
              Predict scores, vote for your man of the match, and share your opinion. Earn FAT for every interaction.
            </p>

            <div className="mt-6 grid gap-5">
              {/* Score prediction — shown for upcoming/live matches */}
              {!result && (
                <ScorePrediction
                  matchId={match.id}
                  homeTeam={match.homeTeam}
                  awayTeam={match.awayTeam}
                  locked={live}
                />
              )}

              {/* MotM voting — shown for live/completed matches */}
              {(live || result) && (
                <MotmVoting
                  matchId={match.id}
                  open={live || result}
                  candidates={[
                    { id: "p1", name: "Mugiraneza", position: "Forward", number: 9 },
                    { id: "p2", name: "Ndayisaba", position: "Midfielder", number: 8 },
                    { id: "p3", name: "Nshimiyimana", position: "Defender", number: 4 },
                    { id: "p4", name: "Manzi", position: "Goalkeeper", number: 1 },
                    { id: "p5", name: "Habimana", position: "Midfielder", number: 10 },
                    { id: "p6", name: "Uwimana", position: "Forward", number: 11 },
                  ]}
                />
              )}

              {/* Quick poll — always available */}
              <MatchPoll
                pollId={`poll-${match.id}`}
                question="Who controls the midfield today?"
                options={[
                  { id: "home", label: match.homeTeam, votes: 156 },
                  { id: "away", label: match.awayTeam, votes: 89 },
                  { id: "even", label: "Evenly matched", votes: 42 },
                ]}
              />
            </div>
          </div>

          {relatedMatches.length > 0 ? (
            <div className="space-y-6">
              <div className="glass-panel rounded-[32px] p-6">
                <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                  Related matches
                </p>
                <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
                  Keep the supporter moving
                </h2>
                <p className="mt-4 text-sm leading-7 text-slate-300">
                  Match detail leads straight into the next step: another
                  fixture, a ticketed game, or the latest result.
                </p>
              </div>
              <div className="grid gap-5">
                {relatedMatches.map((relatedMatch) => (
                  <MatchCard key={relatedMatch.id} match={relatedMatch} />
                ))}
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}
