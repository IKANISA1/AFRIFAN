import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ShieldCheck, Ticket } from "lucide-react";
import { ProgressBar } from "@/components/progress-bar";
import type {
  ClubProfile,
  ContributionGroup,
  FanClubItem,
  MatchItem,
  MembershipPackage,
} from "@/lib/types";
import {
  formatCompactNumber,
  formatCurrency,
  formatDateTime,
  formatMatchStatusLabel,
  isLiveMatch,
  isResultMatch,
} from "@/lib/utils";
import { siteConfig } from "@/lib/config";

interface HeroSectionProps {
  club: ClubProfile;
  featuredMatch: MatchItem | null;
  contributionGroups: ContributionGroup[];
  fanClubs: FanClubItem[];
  membershipPackages: MembershipPackage[];
}

export function HeroSection({
  club,
  featuredMatch,
  contributionGroups,
  fanClubs,
  membershipPackages,
}: HeroSectionProps) {
  const heroImage = featuredMatch?.imageUrl ?? "/media/stadium-hero.jpg";
  const heroCircle = contributionGroups[0] ?? null;
  const premiumTier =
    membershipPackages.find((entry) => entry.tier === "platinum") ??
    membershipPackages[membershipPackages.length - 1] ??
    null;
  const statusLabel = featuredMatch
    ? formatMatchStatusLabel(featuredMatch.matchStatus)
    : "Club"
  const statusSummary = featuredMatch
    ? isLiveMatch(featuredMatch.matchStatus)
      ? `${featuredMatch.homeScore} - ${featuredMatch.awayScore}${
          featuredMatch.liveMinute != null ? ` • ${featuredMatch.liveMinute}'` : ""
        }`
      : isResultMatch(featuredMatch.matchStatus)
        ? `${featuredMatch.homeScore} - ${featuredMatch.awayScore} final score`
        : `${formatDateTime(featuredMatch.matchDate)} • ${featuredMatch.venue}`
    : club.league;

  return (
    <section className="page-shell">
      <div className="glass-panel-elevated relative overflow-hidden rounded-[40px] border border-border-soft shadow-[0_24px_80px_rgba(1,8,24,0.45)]">
        <div className="absolute inset-0">
          <Image
            src={heroImage}
            alt="Rayon Sports matchday atmosphere"
            fill
            priority
            sizes="(min-width: 1280px) 80rem, calc(100vw - 2rem)"
            quality={60}
            className="object-cover"
          />
          <div className="absolute inset-0 bg-[linear-gradient(110deg,rgba(2,11,24,0.95)_10%,rgba(2,11,24,0.78)_42%,rgba(2,11,24,0.46)_72%,rgba(2,11,24,0.82)_100%)]" />
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(0,56,168,0.28),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(212,160,23,0.18),transparent_28%)]" />
        </div>

        <div className="relative grid gap-8 px-6 py-8 sm:px-8 sm:py-10 lg:min-h-[640px] lg:grid-cols-[1.2fr_0.8fr] lg:px-10 lg:py-12">
          <div className="flex flex-col justify-between gap-8">
            <div className="space-y-5">
              <div className="flex flex-wrap items-center gap-3">
                <span className="rounded-full bg-club-accent/20 px-4 py-1.5 text-[11px] font-semibold uppercase tracking-[0.28em] text-club-accent">
                  {statusLabel}
                </span>
                <span className="rounded-full border border-white/12 bg-white/6 px-4 py-1.5 text-[11px] uppercase tracking-[0.26em] text-slate-200">
                  {club.shortName} • {club.league}
                </span>
              </div>

              <div className="space-y-4">
                <p className="font-mono text-xs uppercase tracking-[0.34em] text-slate-300">
                  The Beloved, live in the browser
                </p>
                <h1 className="fluid-hero font-display font-bold uppercase text-white text-balance">
                  This is Gikundiro.
                </h1>
                <p className="max-w-3xl text-base leading-8 text-slate-200 sm:text-lg">
                  Get tickets, follow live matches, back supporter circles, and join
                  the Rayon Sports family — all from your browser. The beloved lives here.
                </p>
              </div>

              <div className="flex flex-wrap gap-3">
                <Link
                  href="/tickets"
                  prefetch={false}
                  className="cta-glow inline-flex min-h-11 items-center gap-2 rounded-full bg-club-primary px-6 py-3 font-semibold text-white transition hover:bg-club-primary-light"
                >
                  Get tickets <Ticket size={18} />
                </Link>
                <Link
                  href="/membership"
                  prefetch={false}
                  className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-black/15 px-6 py-3 font-semibold text-white transition hover:bg-white/10"
                >
                  Join membership <ShieldCheck size={18} />
                </Link>
                <Link
                  href={siteConfig.fansUrl}
                  prefetch={false}
                  className="inline-flex min-h-11 items-center gap-2 rounded-full border border-white/12 bg-white/6 px-6 py-3 font-semibold text-white transition hover:bg-white/12"
                >
                  Open fan portal <ArrowRight size={18} />
                </Link>
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              <article className="rounded-[26px] border border-white/10 bg-black/20 px-4 py-4 backdrop-blur-md">
                <p className="text-[11px] uppercase tracking-[0.22em] text-slate-300">
                  Languages
                </p>
                <p className="mt-3 font-score text-3xl font-bold uppercase text-white">
                  {club.supportedLanguages.length}
                </p>
                <p className="mt-1 text-sm text-slate-300">
                  {club.supportedLanguages.join(" / ")}
                </p>
              </article>
              <article className="rounded-[26px] border border-white/10 bg-black/20 px-4 py-4 backdrop-blur-md">
                <p className="text-[11px] uppercase tracking-[0.22em] text-slate-300">
                  Fan clubs
                </p>
                <p className="mt-3 font-score text-3xl font-bold uppercase text-white">
                  {formatCompactNumber(fanClubs.length)}
                </p>
                <p className="mt-1 text-sm text-slate-300">
                  Public chapters and diaspora community
                </p>
              </article>
              <article className="rounded-[26px] border border-white/10 bg-black/20 px-4 py-4 backdrop-blur-md">
                <p className="text-[11px] uppercase tracking-[0.22em] text-slate-300">
                  Match state
                </p>
                <p className="mt-3 font-score text-3xl font-bold uppercase text-white">
                  {featuredMatch ? statusLabel : "Club"}
                </p>
                <p className="mt-1 text-sm text-slate-300">{statusSummary}</p>
              </article>
            </div>
          </div>

          <div className="grid gap-4 self-end">
            <article className="rounded-[30px] border border-white/10 bg-[#051228]/78 p-5 backdrop-blur-xl">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-[11px] uppercase tracking-[0.24em] text-club-accent">
                    {featuredMatch
                      ? isLiveMatch(featuredMatch.matchStatus)
                        ? "Live now"
                        : isResultMatch(featuredMatch.matchStatus)
                          ? "Last result"
                          : "Next fixture"
                      : "Club focus"}
                  </p>
                  {featuredMatch ? (
                    <>
                      <h2 className="mt-3 font-display text-4xl font-bold uppercase leading-none text-white">
                        {featuredMatch.homeTeam}
                        <span className="block text-white/65">vs {featuredMatch.awayTeam}</span>
                      </h2>
                      <p className="mt-3 text-sm leading-7 text-slate-300">
                        {featuredMatch.matchSummary ?? "Match context coming soon."}
                      </p>
                    </>
                  ) : (
                    <h2 className="mt-3 font-display text-4xl font-bold uppercase leading-none text-white">
                      Rayon Sports
                    </h2>
                  )}
                </div>
                {featuredMatch ? (
                  <div className="rounded-[24px] border border-white/10 bg-black/20 px-4 py-3 text-right">
                    <p className="text-[10px] uppercase tracking-[0.24em] text-slate-300">
                      Status
                    </p>
                    <p className="mt-2 font-score text-4xl font-bold uppercase text-white">
                      {isLiveMatch(featuredMatch.matchStatus) ||
                      isResultMatch(featuredMatch.matchStatus)
                        ? `${featuredMatch.homeScore}-${featuredMatch.awayScore}`
                        : formatCurrency(featuredMatch.generalPrice, club.currencyCode)}
                    </p>
                  </div>
                ) : null}
              </div>
              {featuredMatch ? (
                <div className="mt-5 flex flex-wrap gap-2">
                  <span className="rounded-full border border-white/10 bg-white/6 px-3 py-1.5 text-xs uppercase tracking-[0.22em] text-slate-200">
                    {statusSummary}
                  </span>
                  <span className="rounded-full border border-white/10 bg-white/6 px-3 py-1.5 text-xs uppercase tracking-[0.22em] text-slate-200">
                    {featuredMatch.competition}
                  </span>
                </div>
              ) : null}
            </article>

            <article className="rounded-[30px] border border-white/10 bg-[#051228]/78 p-5 backdrop-blur-xl">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-[11px] uppercase tracking-[0.24em] text-club-accent">
                    Support circles
                  </p>
                  <h2 className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white">
                    {heroCircle?.name ?? "Back the next tifo push"}
                  </h2>
                </div>
                {premiumTier ? (
                  <span className="rounded-full bg-club-accent/15 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                    {premiumTier.title}
                  </span>
                ) : null}
              </div>
              <p className="mt-3 text-sm leading-7 text-slate-300">
                {heroCircle?.description ??
                  "Supporters pool money for away travel, stadium tifos, and community projects. Contribute to real causes that grow the club."}
              </p>
              {heroCircle ? (
                <>
                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    <div className="rounded-[22px] bg-black/20 p-4">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                        Current
                      </p>
                      <p className="mt-2 text-sm font-semibold text-white">
                        {formatCurrency(heroCircle.currentTotal, heroCircle.currency)}
                      </p>
                    </div>
                    <div className="rounded-[22px] bg-black/20 p-4">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                        Target
                      </p>
                      <p className="mt-2 text-sm font-semibold text-white">
                        {formatCurrency(heroCircle.targetAmount, heroCircle.currency)}
                      </p>
                    </div>
                    <div className="rounded-[22px] bg-black/20 p-4">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                        Members
                      </p>
                      <p className="mt-2 text-sm font-semibold text-white">
                        {heroCircle.memberCount}
                      </p>
                    </div>
                  </div>
                  <div className="mt-4">
                    <ProgressBar
                      value={heroCircle.currentTotal}
                      max={heroCircle.targetAmount}
                      label="Circle progress"
                    />
                  </div>
                </>
              ) : null}
              <div className="mt-5 flex flex-wrap gap-3">
                <Link
                  href="/circles"
                  prefetch={false}
                  className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-4 py-2.5 font-semibold text-slate-950 transition hover:brightness-110"
                >
                  Explore circles <ArrowRight size={16} />
                </Link>
                <Link
                  href="/fan-clubs"
                  prefetch={false}
                  className="inline-flex min-h-11 items-center gap-2 rounded-full border border-white/12 bg-white/6 px-4 py-2.5 font-semibold text-white transition hover:bg-white/12"
                >
                  Meet the chapters
                </Link>
              </div>
            </article>
          </div>
        </div>
      </div>
    </section>
  );
}
