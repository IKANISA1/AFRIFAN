import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { ProgressBar } from "@/components/progress-bar";
import { SectionHeading } from "@/components/section-heading";
import { fallbackContributionGroups } from "@/lib/content";
import {
  getClubProfile,
  getContributionGroups,
  getFanClubs,
  getMatches,
  getMembershipPackages,
  getNewsArticles,
} from "@/lib/data/public";
import { formatCompactNumber, formatCurrency } from "@/lib/utils";

export async function CirclesAndMatchdayBlock() {
  const [club, matches, contributionGroups, fanClubs, membershipPackages, news] =
    await Promise.all([
      getClubProfile(),
      getMatches(),
      getContributionGroups(),
      getFanClubs(),
      getMembershipPackages(),
      getNewsArticles(),
    ]);

  const activeCircles =
    contributionGroups.length > 0 ? contributionGroups : fallbackContributionGroups;

  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    matches.find((m) => m.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  return (
    <section className="page-shell grid gap-6 lg:grid-cols-[0.95fr_1.05fr]">
      <div className="glass-panel-elevated rounded-[34px] p-6">
        <SectionHeading
          eyebrow="Support circles"
          title="Back the movement. Fund the next tifo."
        />
        <div className="mt-6 grid gap-4">
          {activeCircles.map((group) => (
            <article
              key={group.id}
              className="py-5 first:pt-0 last:pb-0 border-b border-border-soft last:border-0"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-display text-3xl font-bold uppercase leading-none text-white">
                    {group.name}
                  </p>
                  <p className="mt-2 line-clamp-1 text-sm leading-7 text-slate-300">
                    {group.description}
                  </p>
                </div>
                <span className="rounded-full bg-club-accent/15 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                  {group.groupType}
                </span>
              </div>
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                <div>
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    Current
                  </p>
                  <p className="mt-1 text-lg font-semibold text-white">
                    {formatCurrency(group.currentTotal, group.currency)}
                  </p>
                </div>
                <div>
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    Target
                  </p>
                  <p className="mt-1 text-lg font-semibold text-white">
                    {formatCurrency(group.targetAmount, group.currency)}
                  </p>
                </div>
                <div>
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    Members
                  </p>
                  <p className="mt-1 text-lg font-semibold text-white">
                    {formatCompactNumber(group.memberCount)}
                  </p>
                </div>
              </div>
              <div className="mt-4">
                <ProgressBar
                  value={group.currentTotal}
                  max={group.targetAmount}
                  label="Funded"
                />
              </div>
            </article>
          ))}
        </div>
      </div>

      <div className="grid gap-6">
        <article className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Matchday"
            title="What's next. How to get in."
          />
          <div className="mt-6 grid gap-4 md:grid-cols-2">
            <div className="rounded-[26px] border border-border-soft bg-white/5 p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-club-accent">
                Featured fixture
              </p>
              <p className="mt-3 font-display text-4xl font-bold uppercase leading-none text-white">
                {featuredMatch?.homeTeam}
                <span className="block text-white/65">vs {featuredMatch?.awayTeam}</span>
              </p>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {featuredMatch?.matchSummary ?? "Live updates & ticketing."}
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                <span className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {featuredMatch?.competition ?? club.league}
                </span>
                <span className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {featuredMatch ? formatCurrency(featuredMatch.generalPrice, club.currencyCode) : "Tickets"}
                </span>
              </div>
              <Link
                href={featuredMatch ? `/fixtures/${featuredMatch.id}` : "/fixtures"}
                prefetch={false}
                className="mt-5 inline-flex items-center gap-2 rounded-full bg-club-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-club-primary-light"
              >
                Open match center <ArrowRight size={16} />
              </Link>
            </div>
            <div className="rounded-[26px] border border-border-soft bg-white/5 p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-club-accent">
                Supporter identity
              </p>
              <p className="mt-3 font-display text-4xl font-bold uppercase leading-none text-white">
                {membershipPackages.length} tiers
              </p>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                One portal for membership, tickets, and status.
              </p>
              <div className="mt-5 flex flex-wrap gap-2">
                {membershipPackages.slice(0, 4).map((tier) => (
                  <span
                    key={tier.id}
                    className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200"
                  >
                    {tier.title}
                  </span>
                ))}
              </div>
              <Link
                href="/membership"
                prefetch={false}
                className="mt-5 inline-flex items-center gap-2 rounded-full border border-border-soft px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/8"
              >
                View membership <ArrowRight size={16} />
              </Link>
            </div>
          </div>
        </article>

        <div className="glass-panel rounded-[34px] p-6">
          <div className="grid gap-5 lg:grid-cols-[1fr_auto]">
            <div>
              <SectionHeading
                eyebrow="Quick stats"
                title="The club in numbers."
              />
              <div className="grid gap-3 sm:grid-cols-3 divide-x divide-border-soft">
                <div className="px-4 text-center">
                  <p className="font-score text-5xl font-bold text-white">
                    {fanClubs.length}
                  </p>
                  <p className="mt-2 text-xs text-slate-400">
                    Chapters
                  </p>
                </div>
                <div className="px-4 text-center">
                  <p className="font-score text-5xl font-bold text-white">
                    {matches.filter((m) => m.isOnSale).length}
                  </p>
                  <p className="mt-2 text-xs text-slate-400">
                    On sale
                  </p>
                </div>
                <div className="px-4 text-center">
                  <p className="font-score text-5xl font-bold text-white">
                    {news.length}
                  </p>
                  <p className="mt-2 text-xs text-slate-400">
                    Stories
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
