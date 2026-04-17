import Image from "next/image";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { MatchCard } from "@/components/match-card";
import { MatchPoll } from "@/components/engagement/match-poll";
import { MotmVoting } from "@/components/engagement/motm-voting";
import { ScorePrediction } from "@/components/engagement/score-prediction";
import { MatchLineups } from "@/components/engagement/match-lineups";
import { MatchTimeline } from "@/components/engagement/match-timeline";
import { LiveTableContext } from "@/components/engagement/live-table-context";
import { NotificationOptInCard } from "@/components/pwa/notification-opt-in-card";
import { ShareActionButton } from "@/components/pwa/share-action-button";
import { getClubProfile, getMatchById, getMatches, getStandings } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import {
  buildMatchJsonLd,
  buildPageMetadata,
  renderJsonLdScriptContent,
} from "@/lib/metadata";
import {
  cn,
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
  const featureGate = await getFeaturePageGuard("live");
  if (featureGate) {
    return featureGate;
  }

  const { matchId } = await params;
  const [club, match, matches, standings] = await Promise.all([
    getClubProfile(),
    getMatchById(matchId),
    getMatches(),
    getStandings(),
  ]);

  if (match == null) {
    notFound();
  }

  const relatedMatches = matches
    .filter((candidate) => candidate.id !== match.id)
    .slice(0, 2);
  const live = isLiveMatch(match.matchStatus);
  const result = isResultMatch(match.matchStatus);

  return (
    <div className="bg-[var(--club-primary)] min-h-screen pt-24 pb-20 lg:pt-32">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: renderJsonLdScriptContent(buildMatchJsonLd(match)),
        }}
      />
      
      <div className="page-shell">
        {/* Elite Scoreboard Header */}
        <section className="relative overflow-hidden rounded-[40px] border border-white/10 bg-black/40 p-8 shadow-2xl lg:p-16">
          <div className="absolute inset-0 opacity-20 grayscale mix-blend-overlay">
             <Image src="/media/stadium-hero.jpg" alt="Stadium" fill className="object-cover" />
          </div>
          
          <div className="relative z-10 flex flex-col items-center justify-between gap-12 lg:flex-row">
            <div className="flex flex-1 flex-col items-center gap-6 text-center lg:items-end lg:text-right">
              <div className="h-24 w-24 rounded-full bg-white p-2 lg:h-32 lg:w-32 shadow-2xl">
                <div className="h-full w-full rounded-full border-4 border-dashed border-slate-100 flex items-center justify-center">
                  <span className="font-black text-slate-200">CREST</span>
                </div>
              </div>
              <div>
                <h2 className="font-display text-4xl font-black uppercase italic tracking-tighter text-white lg:text-6xl">{match.homeTeam}</h2>
                <p className="mt-2 text-xs font-black uppercase tracking-[0.4em] text-[var(--club-accent)]">Home Team</p>
              </div>
            </div>

            <div className="flex flex-col items-center justify-center gap-4">
               <div className="rounded-full bg-white/10 px-6 py-2 backdrop-blur-xl border border-white/20">
                 <span className={cn(
                   "text-[10px] font-black uppercase tracking-[0.3em]",
                   live ? "text-rose-500 animate-pulse" : "text-white/60"
                 )}>
                   {live ? `${match.liveMinute}' LIVE` : formatMatchStatusLabel(match.matchStatus)}
                 </span>
               </div>
               <p className="font-display text-8xl font-black italic tracking-tighter text-white lg:text-[10rem]">
                 {live || result ? `${match.homeScore}-${match.awayScore}` : "VS"}
               </p>
               <time className="text-xs font-bold uppercase tracking-widest text-white/40">
                 {formatDateTime(match.matchDate)}
               </time>
            </div>

            <div className="flex flex-1 flex-col items-center gap-6 text-center lg:items-start lg:text-left">
              <div className="h-24 w-24 rounded-full bg-white p-2 lg:h-32 lg:w-32 shadow-2xl">
                <div className="h-full w-full rounded-full border-4 border-dashed border-slate-100 flex items-center justify-center">
                  <span className="font-black text-slate-200">CREST</span>
                </div>
              </div>
              <div>
                <h2 className="font-display text-4xl font-black uppercase italic tracking-tighter text-white lg:text-6xl">{match.awayTeam}</h2>
                <p className="mt-2 text-xs font-black uppercase tracking-[0.4em] text-[var(--club-accent)]">Away Team</p>
              </div>
            </div>
          </div>
        </section>

        <div className="mt-12 grid gap-8 lg:grid-cols-12">
          {/* Main Content Area */}
          <div className="lg:col-span-8 space-y-12">
            {/* Timeline */}
            <section>
              <div className="mb-8 flex items-center justify-between border-b border-white/10 pb-4">
                <h3 className="font-display text-3xl font-black uppercase italic text-white tracking-tight">Match Timeline</h3>
                <span className="text-[10px] font-black text-[var(--club-accent)] uppercase tracking-widest italic">Live Updates</span>
              </div>
              <MatchTimeline events={match.liveEvents} homeTeam={match.homeTeam} awayTeam={match.awayTeam} />
            </section>

            {/* Lineups */}
            <MatchLineups 
              home={{
                teamName: match.homeTeam,
                formation: "4-3-3",
                manager: "Julien Mette",
                color: club.primaryColorHex,
                startingXI: [
                  { id: "h1", name: "Hategekimana", number: 1, position: "GK" },
                  { id: "h2", name: "Nshutinamagara", number: 22, position: "DEF" },
                  { id: "h3", name: "Ndayishimiye", number: 4, position: "DEF" },
                  { id: "h4", name: "Rwatubyaye", number: 15, position: "DEF", isCaptain: true },
                  { id: "h5", name: "Iradukunda", number: 3, position: "DEF" },
                  { id: "h6", name: "Muhire", number: 8, position: "MID" },
                  { id: "h7", name: "Kwizera", number: 10, position: "MID" },
                  { id: "h8", name: "Niyonzima", number: 21, position: "MID" },
                  { id: "h9", name: "Luvumbu", number: 11, position: "FWD" },
                  { id: "h10", name: "Mussaa", number: 27, position: "FWD" },
                  { id: "h11", name: "Willy", number: 9, position: "FWD" },
                ],
                subs: [
                  { id: "s1", name: "Khaled", number: 31, position: "GK" },
                  { id: "s2", name: "Bimenyimana", number: 14, position: "MID" },
                  { id: "s3", name: "Hakizimana", number: 7, position: "FWD" }
                ]
              }}
              away={{
                teamName: match.awayTeam,
                formation: "4-2-3-1",
                manager: "Away Coach",
                startingXI: [
                  { id: "a1", name: "Ntwali", number: 1, position: "GK" },
                  { id: "a2", name: "Omborenga", number: 25, position: "DEF" },
                  { id: "a3", name: "Buregeya", number: 5, position: "DEF", isCaptain: true },
                  { id: "a4", name: "Manzi", number: 4, position: "DEF" },
                  { id: "a5", name: "Ishimwe", number: 2, position: "DEF" },
                  { id: "a6", name: "Ruboneka", number: 8, position: "MID" },
                  { id: "a7", name: "Mugisha", number: 20, position: "MID" },
                  { id: "a8", name: "Bizimana", number: 10, position: "MID" },
                  { id: "a9", name: "Niyibizi", number: 11, position: "FWD" },
                  { id: "a10", name: "Byiringiro", number: 14, position: "FWD" },
                  { id: "a11", name: "Mugunga", number: 19, position: "FWD" },
                ],
                subs: [
                  { id: "as1", name: "Mutabaruka", number: 30, position: "GK" },
                  { id: "as2", name: "Nshuti", number: 9, position: "FWD" },
                  { id: "as3", name: "Tuyisenge", number: 3, position: "DEF" }
                ]
              }}
            />
          </div>

          {/* Sidebar Area */}
          <aside className="lg:col-span-4 space-y-8">
            <LiveTableContext standings={standings} currentClub={club.shortName} />

            <div className="glass-panel rounded-[32px] p-8 bg-[var(--club-accent)] text-[var(--club-primary)]">
               <p className="text-[10px] font-black uppercase tracking-[0.3em] mb-4">Tickets & Access</p>
               <h3 className="font-display text-3xl font-black uppercase italic leading-none mb-6">Experience the<br/>Magic live.</h3>
               <div className="space-y-4 mb-8">
                  <div className="flex justify-between border-b border-black/10 pb-2">
                    <span className="text-xs font-bold uppercase">General Admission</span>
                    <span className="font-black italic">{formatCurrency(match.generalPrice)}</span>
                  </div>
                  <div className="flex justify-between border-b border-black/10 pb-2">
                    <span className="text-xs font-bold uppercase">Platinum VIP</span>
                    <span className="font-black italic">{formatCurrency(match.vipPrice)}</span>
                  </div>
               </div>
               <Link href="/supporters" className="block w-full rounded-xl bg-[var(--club-primary)] py-4 text-center text-xs font-black uppercase tracking-widest text-white shadow-xl transition-transform hover:scale-[1.02] active:scale-95">
                 Continue to Checkout
               </Link>
            </div>

            <div className="glass-panel rounded-[32px] p-8">
               <p className="text-[10px] font-black uppercase tracking-[0.3em] text-[var(--club-accent)] mb-4">Get Involved</p>
               <h3 className="font-display text-2xl font-black uppercase italic leading-none text-white mb-6">Predict the outcome</h3>
               {!result && (
                <ScorePrediction
                  matchId={match.id}
                  homeTeam={match.homeTeam}
                  awayTeam={match.awayTeam}
                  locked={live}
                />
              )}
            </div>

            <NotificationOptInCard
              surface="site"
              path={`/fixtures/${match.id}`}
              title="Never miss a goal."
              description="Enable browser notifications to get real-time goal alerts and matchday updates directly from the Cathedral."
            />
          </aside>
        </div>
      </div>
    </div>
  );
}
