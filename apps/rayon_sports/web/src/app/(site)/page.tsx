import { Suspense } from "react";
import Link from "next/link";
import {
  ArrowRight,
  ShieldCheck,
  Trophy,
  Users,
} from "lucide-react";
import { HeroSection } from "@/components/hero-section";
import { MatchCard } from "@/components/match-card";
import { NewsCard } from "@/components/news-card";
import { ProductCard } from "@/components/product-card";
import { ProgressBar } from "@/components/progress-bar";
import { SectionHeading } from "@/components/section-heading";
import { SkeletonCard } from "@/components/skeleton";
import {
  clubHistoryMoments,
  fallbackContributionGroups,
} from "@/lib/content";
import {
  getClubProfile,
  getContributionGroups,
  getFanClubs,
  getMatches,
  getMembershipPackages,
  getNewsArticles,
  getProducts,
  getStandings,
} from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { formatCompactNumber, formatCurrency } from "@/lib/utils";

export const metadata = buildPageMetadata({
  title: "Official Rayon Sports website",
  description:
    "Official Rayon Sports website for live fixtures, tickets, membership, supporter circles, club news, and matchday coverage.",
});

/* ────────────────────────────────────────────────────────────
   SKELETON FALLBACKS — shown while sections stream in
   ──────────────────────────────────────────────────────────── */

function SectionSkeleton({ cols = 3 }: { cols?: number }) {
  return (
    <div className="page-shell">
      <div className={`grid gap-5 ${cols === 2 ? "lg:grid-cols-2" : "lg:grid-cols-3"}`}>
        {Array.from({ length: cols }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    </div>
  );
}

/* ────────────────────────────────────────────────────────────
   SECTION: Hero + Quick Chips
   ──────────────────────────────────────────────────────────── */

async function HeroBlock() {
  const [club, matches, fanClubs, contributionGroups, membershipPackages] =
    await Promise.all([
      getClubProfile(),
      getMatches(),
      getFanClubs(),
      getContributionGroups(),
      getMembershipPackages(),
    ]);

  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    matches.find((m) => m.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  const activeCircles =
    contributionGroups.length > 0 ? contributionGroups : fallbackContributionGroups;

  return (
    <>
      <HeroSection
        club={club}
        featuredMatch={featuredMatch}
        contributionGroups={activeCircles}
        fanClubs={fanClubs}
        membershipPackages={membershipPackages}
      />

      <div className="page-shell flex flex-wrap gap-3">
        {[
          { href: "/tickets", label: "Buy tickets" },
          { href: "/circles", label: "Support circles" },
          { href: "/membership", label: "Membership tiers" },
          { href: "/news", label: "Latest club news" },
          { href: "/shop", label: "Shop new drop" },
        ].map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className="rounded-full border border-border-soft bg-white/5 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-white/10 hover:text-white"
          >
            {item.label}
          </Link>
        ))}
      </div>
    </>
  );
}

/* ────────────────────────────────────────────────────────────
   SECTION: Circles + Matchday + Stats
   ──────────────────────────────────────────────────────────── */

async function CirclesAndMatchdayBlock() {
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

/* ────────────────────────────────────────────────────────────
   SECTION: Fixtures
   ──────────────────────────────────────────────────────────── */

async function FixturesBlock() {
  const matches = await getMatches();
  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    null;
  const upcomingMatches = matches.filter((m) => m.id !== featuredMatch?.id);

  return (
    <section className="page-shell section-grid">
      <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <SectionHeading
          eyebrow="Fixtures"
          title="Matchday schedule."
        />
        <Link
          href="/fixtures"
          className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          Full fixtures <ArrowRight size={18} />
        </Link>
      </div>
      <div className="flex gap-5 scroll-snap-x lg:grid lg:grid-cols-3 lg:overflow-visible">
        {upcomingMatches.slice(0, 3).map((match) => (
          <div key={match.id} className="min-w-[85vw] sm:min-w-[340px] lg:min-w-0">
            <MatchCard match={match} />
          </div>
        ))}
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────
   SECTION: Membership + Standings + Fan Clubs
   ──────────────────────────────────────────────────────────── */

async function MembershipAndStandingsBlock() {
  const [club, membershipPackages, standings, fanClubs] = await Promise.all([
    getClubProfile(),
    getMembershipPackages(),
    getStandings(),
    getFanClubs(),
  ]);

  return (
    <section className="page-shell grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
      <div className="glass-panel rounded-[34px] p-6">
        <SectionHeading
          eyebrow="Membership"
          title="Join the Gikundiro family."
        />
        <div className="mt-6 grid gap-4">
          {membershipPackages.map((membershipPackage) => (
            <article
              key={membershipPackage.id}
              className="py-5 border-b border-border-soft last:border-0"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-display text-3xl font-bold uppercase leading-none text-white">
                    {membershipPackage.title}
                  </p>
                  <p className="mt-2 line-clamp-1 text-sm leading-7 text-slate-300">
                    {membershipPackage.description}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-score text-3xl font-bold uppercase text-white">
                    {formatCurrency(membershipPackage.annualPrice, club.currencyCode)}
                  </p>
                  <p className="text-[10px] text-slate-400">
                    / year
                  </p>
                </div>
              </div>
              <div className="mt-4 flex flex-wrap gap-2">
                {membershipPackage.perks.map((perk) => (
                  <span
                    key={perk}
                    className="rounded-full border border-border-soft bg-white/4 px-3 py-1.5 text-[11px] uppercase tracking-[0.18em] text-slate-200"
                  >
                    {perk}
                  </span>
                ))}
              </div>
            </article>
          ))}
        </div>
        <Link
          href="/membership"
          className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-club-ink transition hover:brightness-110"
        >
          Compare plans <ShieldCheck size={18} />
        </Link>
      </div>

      <div className="grid gap-6">
        <div className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Standings"
            title="Where we stand."
          />
          <div className="mt-6 overflow-x-auto overflow-hidden rounded-[26px] border border-border-soft">
            <table className="w-full min-w-[400px] text-left text-sm">
              <thead className="bg-white/8 text-[11px] uppercase tracking-[0.24em] text-slate-400">
                <tr>
                  <th className="px-4 py-3 text-center">Pos</th>
                  <th className="px-4 py-3">Club</th>
                  <th className="px-4 py-3 text-center">P</th>
                  <th className="px-4 py-3 text-center">GD</th>
                  <th className="px-4 py-3 text-center">Pts</th>
                </tr>
              </thead>
              <tbody>
                {standings.slice(0, 8).map((row) => (
                  <tr
                    key={row.club}
                    className={row.highlight ? "bg-club-primary/15" : "bg-transparent"}
                  >
                    <td className="px-4 py-4 text-center font-mono opacity-60 text-xs">
                      {row.position}
                    </td>
                    <td className="px-4 py-4 font-semibold text-white">
                      {row.club}
                    </td>
                    <td className="px-4 py-4 text-center">{row.played}</td>
                    <td className="px-4 py-4 text-center">{row.goalDifference}</td>
                    <td className="px-4 py-4 text-center font-semibold text-white">
                      {row.points}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Link
            href="/standings"
            className="mt-5 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Full table <Trophy size={18} />
          </Link>
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Supporter network"
            title="Our chapters across Rwanda."
          />
          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            {fanClubs.slice(0, 3).map((clubItem) => (
              <article
                key={clubItem.id}
                className="py-4 border-b sm:border-b-0 sm:border-r border-border-soft last:border-0 sm:px-4 first:pl-0 last:pr-0"
              >
                <p className="font-display text-xl font-bold uppercase leading-none text-white">
                  {clubItem.name}
                </p>
                <p className="mt-1 text-sm text-club-accent">
                  {clubItem.region}
                </p>
                <p className="mt-3 line-clamp-1 text-sm leading-7 text-slate-300">
                  {clubItem.description}
                </p>
              </article>
            ))}
          </div>
          <Link
            href="/fan-clubs"
            className="mt-5 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Explore chapters <Users size={18} />
          </Link>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────
   SECTION: News
   ──────────────────────────────────────────────────────────── */

async function NewsBlock() {
  const news = await getNewsArticles();

  return (
    <section className="page-shell section-grid">
      <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <SectionHeading
          eyebrow="Editorial"
          title="Inside Rayon Sports."
        />
        <Link
          href="/news"
          className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          Newsroom <ArrowRight size={18} />
        </Link>
      </div>
      <div className="grid gap-5 xl:grid-cols-3">
        {news.slice(0, 3).map((article) => (
          <NewsCard key={article.id} article={article} />
        ))}
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────
   SECTION: Shop + Identity + Portal (mostly static)
   ──────────────────────────────────────────────────────────── */

async function ShopAndIdentityBlock() {
  const [club, products] = await Promise.all([
    getClubProfile(),
    getProducts(),
  ]);

  return (
    <section className="page-shell grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
      <div className="glass-panel rounded-[34px] p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <SectionHeading
            eyebrow="Shop"
            title="Wear the badge."
          />
          <Link
            href="/shop"
            className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Shop all <ArrowRight size={18} />
          </Link>
        </div>
        <div className="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {products.slice(0, 3).map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </div>

      <div className="grid gap-6">
        <div className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Club identity"
            title="Gikundiro — the beloved."
          />
          <div className="mt-6 grid gap-4">
            {clubHistoryMoments.map((moment) => (
              <article
                key={moment.title}
                className="rounded-[24px] border border-border-soft bg-white/5 p-5"
              >
                <p className="font-display text-2xl font-bold uppercase leading-none text-white">
                  {moment.title}
                </p>
                <p className="mt-3 line-clamp-1 text-sm leading-7 text-slate-300">
                  {moment.body}
                </p>
              </article>
            ))}
          </div>
        </div>
        <div className="glass-panel rounded-[34px] p-6">
          <SectionHeading
            eyebrow="Fan portal"
            title="Your supporter account."
          />
          <div className="mt-6 flex flex-wrap gap-3">
            <Link
              href="/app"
              className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-primary-light"
            >
              Continue to portal
            </Link>
            <Link
              href="/history"
              className="rounded-full border border-border-soft px-5 py-3 font-semibold text-white transition hover:bg-white/8"
            >
              Explore club history
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────
   PAGE: Homepage with Suspense boundaries
   ──────────────────────────────────────────────────────────── */

export default function HomePage() {
  return (
    <div className="space-y-16 pb-20 pt-6 sm:pt-8">
      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <HeroBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <CirclesAndMatchdayBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton />}>
        <FixturesBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <MembershipAndStandingsBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton />}>
        <NewsBlock />
      </Suspense>

      <Suspense fallback={<SectionSkeleton cols={2} />}>
        <ShopAndIdentityBlock />
      </Suspense>
    </div>
  );
}
