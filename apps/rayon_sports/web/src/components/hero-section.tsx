import Link from "next/link";
import { ArrowRight, ShieldCheck, Ticket } from "lucide-react";
import { PageHero } from "@/components/page-hero";
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
import { resolveFanAppHref } from "@/lib/config";
import { getSiteCopy } from "@/lib/site-copy";
import { ui } from "@/design-system";

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
  const copy = getSiteCopy(club.defaultLanguage);
  const heroGroup = contributionGroups[0] ?? null;
  const premiumTier =
    membershipPackages.find((entry) => entry.tier === "platinum") ??
    membershipPackages[membershipPackages.length - 1] ??
    null;

  const matchLabel = featuredMatch
    ? formatMatchStatusLabel(featuredMatch.matchStatus)
    : club.league;
  const matchSummary = featuredMatch
    ? isLiveMatch(featuredMatch.matchStatus)
      ? `${featuredMatch.homeScore} - ${featuredMatch.awayScore}${featuredMatch.liveMinute != null ? ` • ${featuredMatch.liveMinute}'` : ""
      }`
      : isResultMatch(featuredMatch.matchStatus)
        ? `${featuredMatch.homeScore} - ${featuredMatch.awayScore} final score`
        : `${formatDateTime(featuredMatch.matchDate)} • ${featuredMatch.venue}`
    : `${club.shortName} supporters hub`;

  return (
    <section className="page-shell section-grid">
      <PageHero
        eyebrow={heroTagline || `${club.nickname || club.shortName} live in the browser`}
        title={heroHeadline || `This is ${club.nickname || club.shortName}.`}
        description={
          heroDescription ||
          "Tickets, membership, supporter Groups, and live matchday coverage in one club-branded experience."
        }
        actions={
          <>
            <Link
              href="/tickets"
              prefetch={false}
              className={`${ui.buttonPrimary} cta-glow sm:px-6 sm:py-3`}
            >
              {copy.buyTickets} <Ticket size={16} />
            </Link>
            <Link
              href="/membership"
              prefetch={false}
              className={`${ui.buttonSecondary} sm:px-6 sm:py-3`}
            >
              {copy.membership} <ShieldCheck size={16} />
            </Link>
            <Link
              href={resolveFanAppHref()}
              prefetch={false}
              className={`${ui.buttonSecondary} sm:px-6 sm:py-3`}
            >
              {copy.fanApp} <ArrowRight size={16} />
            </Link>
          </>
        }
        stats={[
          { label: "Languages", value: club.supportedLanguages.length.toString() },
          { label: "Fan clubs", value: formatCompactNumber(fanClubs.length) },
          { label: "Match state", value: matchLabel },
        ]}
        media={
          <div className="grid gap-3 p-3 sm:p-4">
            <div className={`${ui.panelInset} rounded-[24px] p-4 sm:p-5`}>
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className={ui.kicker}>
                    {featuredMatch
                      ? isLiveMatch(featuredMatch.matchStatus)
                        ? "Live now"
                        : isResultMatch(featuredMatch.matchStatus)
                          ? "Last result"
                          : "Next fixture"
                      : "Club focus"}
                  </p>
                  <h2 className="mt-3 font-display text-3xl font-bold uppercase leading-none tracking-[-0.05em] text-white">
                    {featuredMatch
                      ? `${featuredMatch.homeTeam} vs ${featuredMatch.awayTeam}`
                      : `${club.shortName} matchday`}
                  </h2>
                </div>
                <span className={`${ui.chip} ${ui.chipSignal} text-[10px]`}>
                  {matchLabel}
                </span>
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-300">{matchSummary}</p>
              {featuredMatch ? (
                <div className="mt-4 flex flex-wrap gap-2">
                  <span className={`${ui.chip} ${ui.chipMuted} text-[10px]`}>
                    {featuredMatch.competition}
                  </span>
                  <span className={`${ui.chip} ${ui.chipMuted} text-[10px]`}>
                    {formatCurrency(featuredMatch.generalPrice, club.currencyCode)}
                  </span>
                </div>
              ) : null}
            </div>

            <div className={`${ui.panelInset} rounded-[24px] p-4 sm:p-5`}>
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className={ui.kicker}>Support Groups</p>
                  <h2 className="mt-3 font-display text-2xl font-bold uppercase leading-none tracking-[-0.05em] text-white">
                    {heroGroup?.name ?? "Back the next tifo push"}
                  </h2>
                </div>
                {premiumTier ? (
                  <span className={`${ui.chip} ${ui.chipSignal} text-[10px]`}>
                    {premiumTier.title}
                  </span>
                ) : null}
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {heroGroup?.description ??
                  "Supporters pool money for tifos, away travel, and community projects across the club ecosystem."}
              </p>
              {heroGroup ? (
                <div className="mt-4 space-y-3">
                  <div className="grid grid-cols-3 gap-2 text-sm text-white">
                    <div className="rounded-2xl border border-white/8 bg-black/15 p-3">
                      <p className={ui.meta}>Current</p>
                      <p className="mt-2 font-semibold">
                        {formatCurrency(heroGroup.currentTotal, heroGroup.currency)}
                      </p>
                    </div>
                    <div className="rounded-2xl border border-white/8 bg-black/15 p-3">
                      <p className={ui.meta}>Target</p>
                      <p className="mt-2 font-semibold">
                        {formatCurrency(heroGroup.targetAmount, heroGroup.currency)}
                      </p>
                    </div>
                    <div className="rounded-2xl border border-white/8 bg-black/15 p-3">
                      <p className={ui.meta}>Members</p>
                      <p className="mt-2 font-semibold">{heroGroup.memberCount}</p>
                    </div>
                  </div>
                  <ProgressBar
                    value={heroGroup.currentTotal}
                    max={heroGroup.targetAmount}
                    label="Group progress"
                  />
                </div>
              ) : null}
              <div className="mt-4 flex flex-wrap gap-2">
                <Link
                  href="/Groups"
                  prefetch={false}
                  className={`${ui.buttonSecondary} min-h-10 px-4 py-2 text-sm`}
                >
                  {copy.supportGroups} <ArrowRight size={14} />
                </Link>
                <Link
                  href="/fan-clubs"
                  prefetch={false}
                  className={`${ui.buttonSecondary} min-h-10 px-4 py-2 text-sm`}
                >
                  Meet the chapters
                </Link>
              </div>
            </div>
          </div>
        }
      />
    </section>
  );
}
