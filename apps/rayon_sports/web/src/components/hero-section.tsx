import Link from "next/link";
import { ArrowRight, ShieldCheck, Ticket } from "lucide-react";
import { DynamicHeroImage } from "@/components/dynamic-hero-image";
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
  heroTagline?: string;
  heroHeadline?: string;
  heroDescription?: string;
}

export function HeroSection({
  club,
  featuredMatch,
  contributionGroups,
  fanClubs,
  membershipPackages,
  heroTagline,
  heroHeadline,
  heroDescription,
}: HeroSectionProps) {
  // Build image rotation list: match-specific → stadium variants
  const heroImages: string[] = [];
  if (featuredMatch?.imageUrl) heroImages.push(featuredMatch.imageUrl);
  heroImages.push("/media/stadium-hero.jpg", "/media/stadium-hero-2.jpg");
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
      <div className="glass-panel-elevated relative overflow-hidden rounded-[34px] border border-border-soft shadow-[0_24px_80px_rgba(1,8,24,0.45)] sm:rounded-[40px]">
        <div className="absolute inset-0">
          <DynamicHeroImage images={heroImages} intervalMs={7000} />
          <div className="absolute inset-0 bg-[linear-gradient(110deg,rgba(2,11,24,0.95)_10%,rgba(2,11,24,0.78)_42%,rgba(2,11,24,0.46)_72%,rgba(2,11,24,0.82)_100%)]" />
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(0,56,168,0.28),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(212,160,23,0.18),transparent_28%)]" />
        </div>

        <div className="relative grid gap-6 px-5 py-7 sm:gap-8 sm:px-8 sm:py-10 lg:min-h-[580px] lg:grid-cols-[1.2fr_0.8fr] lg:px-10 lg:py-12">
          {/* ── Left column: Headline + CTAs ── */}
          <div className="flex flex-col justify-between gap-6">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full bg-club-accent/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.28em] text-club-accent sm:px-4 sm:py-1.5 sm:text-[11px]">
                  {statusLabel}
                </span>
                <span className="rounded-full border border-white/12 bg-white/6 px-3 py-1 text-[10px] uppercase tracking-[0.26em] text-slate-200 sm:px-4 sm:py-1.5 sm:text-[11px]">
                  {club.shortName} • {club.league}
                </span>
              </div>

              <div className="space-y-3">
                <p className="font-mono text-[10px] uppercase tracking-[0.34em] text-slate-300 sm:text-xs">
                  {heroTagline || "The Beloved, live in the browser"}
                </p>
                <h1 className="fluid-hero font-display font-bold uppercase text-white text-balance">
                  {heroHeadline || "This is Gikundiro."}
                </h1>
                <p className="max-w-2xl text-sm leading-7 text-slate-200 sm:text-base sm:leading-8">
                  {heroDescription || "Get tickets, follow live matches, back supporter circles, and join the Rayon Sports family — all from your browser."}
                </p>
              </div>

              {/* CTAs — stack on mobile, row on desktop */}
              <div className="flex flex-wrap gap-2 sm:gap-3">
                <Link
                  href="/tickets"
                  prefetch={false}
                  className="cta-glow inline-flex min-h-11 items-center gap-2 rounded-full bg-club-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-club-primary-light sm:px-6 sm:py-3"
                >
                  Get tickets <Ticket size={16} />
                </Link>
                <Link
                  href="/membership"
                  prefetch={false}
                  className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft bg-black/15 px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10 sm:px-6 sm:py-3"
                >
                  Membership <ShieldCheck size={16} />
                </Link>
                <Link
                  href={siteConfig.fansUrl}
                  prefetch={false}
                  className="inline-flex min-h-11 items-center gap-2 rounded-full border border-white/12 bg-white/6 px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-white/12 sm:px-6 sm:py-3"
                >
                  Fan portal <ArrowRight size={16} />
                </Link>
              </div>
            </div>

            {/* Stat chips — compact horizontal row on mobile, grid on desktop */}
            <div className="flex gap-2 overflow-x-auto sm:grid sm:grid-cols-3 sm:gap-3 sm:overflow-visible">
              <div className="shrink-0 rounded-2xl border border-white/10 bg-black/20 px-3 py-3 backdrop-blur-md sm:rounded-[26px] sm:px-4 sm:py-4">
                <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400 sm:text-[11px]">
                  Languages
                </p>
                <p className="mt-1 font-score text-2xl font-bold uppercase text-white sm:mt-3 sm:text-3xl">
                  {club.supportedLanguages.length}
                </p>
                <p className="mt-0.5 text-xs text-slate-400 sm:mt-1 sm:text-sm sm:text-slate-300">
                  {club.supportedLanguages.join(" / ")}
                </p>
              </div>
              <div className="shrink-0 rounded-2xl border border-white/10 bg-black/20 px-3 py-3 backdrop-blur-md sm:rounded-[26px] sm:px-4 sm:py-4">
                <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400 sm:text-[11px]">
                  Fan clubs
                </p>
                <p className="mt-1 font-score text-2xl font-bold uppercase text-white sm:mt-3 sm:text-3xl">
                  {formatCompactNumber(fanClubs.length)}
                </p>
                <p className="mt-0.5 text-xs text-slate-400 sm:mt-1 sm:text-sm sm:text-slate-300">
                  Chapters and diaspora
                </p>
              </div>
              <div className="shrink-0 rounded-2xl border border-white/10 bg-black/20 px-3 py-3 backdrop-blur-md sm:rounded-[26px] sm:px-4 sm:py-4">
                <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400 sm:text-[11px]">
                  Match state
                </p>
                <p className="mt-1 font-score text-2xl font-bold uppercase text-white sm:mt-3 sm:text-3xl">
                  {featuredMatch ? statusLabel : "Club"}
                </p>
                <p className="mt-0.5 text-xs text-slate-400 sm:mt-1 sm:text-sm sm:text-slate-300">{statusSummary}</p>
              </div>
            </div>
          </div>

          {/* ── Right column: Featured match + Support circle — HIDDEN on small mobile, visible from sm: up ── */}
          <div className="hidden gap-4 self-end sm:grid">
            {/* Featured match card */}
            <article className="rounded-[28px] border border-white/10 bg-[#051228]/78 p-5 backdrop-blur-xl sm:rounded-[30px]">
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
                      <h2 className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white lg:text-4xl">
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
                  <div className="rounded-[22px] border border-white/10 bg-black/20 px-4 py-3 text-right">
                    <p className="text-[10px] uppercase tracking-[0.24em] text-slate-300">
                      Status
                    </p>
                    <p className="mt-2 font-score text-3xl font-bold uppercase text-white lg:text-4xl">
                      {isLiveMatch(featuredMatch.matchStatus) ||
                      isResultMatch(featuredMatch.matchStatus)
                        ? `${featuredMatch.homeScore}-${featuredMatch.awayScore}`
                        : formatCurrency(featuredMatch.generalPrice, club.currencyCode)}
                    </p>
                  </div>
                ) : null}
              </div>
              {featuredMatch ? (
                <div className="mt-4 flex flex-wrap gap-2">
                  <span className="rounded-full border border-white/10 bg-white/6 px-3 py-1.5 text-xs uppercase tracking-[0.22em] text-slate-200">
                    {statusSummary}
                  </span>
                  <span className="rounded-full border border-white/10 bg-white/6 px-3 py-1.5 text-xs uppercase tracking-[0.22em] text-slate-200">
                    {featuredMatch.competition}
                  </span>
                </div>
              ) : null}
            </article>

            {/* Support circles card */}
            <article className="rounded-[28px] border border-white/10 bg-[#051228]/78 p-5 backdrop-blur-xl sm:rounded-[30px]">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-[11px] uppercase tracking-[0.24em] text-club-accent">
                    Support circles
                  </p>
                  <h2 className="mt-3 font-display text-2xl font-bold uppercase leading-none text-white lg:text-3xl">
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
                  "Supporters pool money for away travel, stadium tifos, and community projects."}
              </p>
              {heroCircle ? (
                <>
                  <div className="mt-4 grid grid-cols-3 gap-2">
                    <div className="rounded-xl bg-black/20 p-3">
                      <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400">
                        Current
                      </p>
                      <p className="mt-1 text-sm font-semibold text-white">
                        {formatCurrency(heroCircle.currentTotal, heroCircle.currency)}
                      </p>
                    </div>
                    <div className="rounded-xl bg-black/20 p-3">
                      <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400">
                        Target
                      </p>
                      <p className="mt-1 text-sm font-semibold text-white">
                        {formatCurrency(heroCircle.targetAmount, heroCircle.currency)}
                      </p>
                    </div>
                    <div className="rounded-xl bg-black/20 p-3">
                      <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400">
                        Members
                      </p>
                      <p className="mt-1 text-sm font-semibold text-white">
                        {heroCircle.memberCount}
                      </p>
                    </div>
                  </div>
                  <div className="mt-3">
                    <ProgressBar
                      value={heroCircle.currentTotal}
                      max={heroCircle.targetAmount}
                      label="Circle progress"
                    />
                  </div>
                </>
              ) : null}
              <div className="mt-4 flex flex-wrap gap-2">
                <Link
                  href="/circles"
                  prefetch={false}
                  className="inline-flex min-h-10 items-center gap-2 rounded-full bg-club-accent px-4 py-2 text-sm font-semibold text-slate-950 transition hover:brightness-110"
                >
                  Explore circles <ArrowRight size={14} />
                </Link>
                <Link
                  href="/fan-clubs"
                  prefetch={false}
                  className="inline-flex min-h-10 items-center gap-2 rounded-full border border-white/12 bg-white/6 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/12"
                >
                  Meet the chapters
                </Link>
              </div>
            </article>
          </div>

          {/* ── Mobile-only: Compact featured match card (visible only on small screens) ── */}
          <div className="sm:hidden">
            {featuredMatch ? (
              <Link
                href="/tickets"
                className="block rounded-2xl border border-white/10 bg-[#051228]/78 p-4 backdrop-blur-xl"
              >
                <p className="text-[10px] uppercase tracking-[0.24em] text-club-accent">
                  {isLiveMatch(featuredMatch.matchStatus)
                    ? "Live now"
                    : isResultMatch(featuredMatch.matchStatus)
                      ? "Last result"
                      : "Next fixture"}
                </p>
                <div className="mt-2 flex items-center justify-between gap-3">
                  <h2 className="font-display text-xl font-bold uppercase leading-tight text-white">
                    {featuredMatch.homeTeam} <span className="text-white/60">vs</span> {featuredMatch.awayTeam}
                  </h2>
                  <div className="shrink-0 rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-center">
                    <p className="font-score text-xl font-bold text-white">
                      {isLiveMatch(featuredMatch.matchStatus) || isResultMatch(featuredMatch.matchStatus)
                        ? `${featuredMatch.homeScore}-${featuredMatch.awayScore}`
                        : formatCurrency(featuredMatch.generalPrice, club.currencyCode)}
                    </p>
                  </div>
                </div>
                <div className="mt-2 flex items-center gap-2 text-xs text-slate-400">
                  <span>{featuredMatch.competition}</span>
                  <span>•</span>
                  <span>{statusSummary}</span>
                </div>
              </Link>
            ) : null}
          </div>
        </div>
      </div>
    </section>
  );
}
