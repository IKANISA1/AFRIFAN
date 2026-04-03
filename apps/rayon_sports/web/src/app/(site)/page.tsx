import Link from "next/link";
import {
  ArrowRight,
  ShieldCheck,
  Trophy,
  Users,
} from "lucide-react";
import { AnimateOnScroll, StaggerChildren } from "@/components/animate-on-scroll";
import { HeroSection } from "@/components/hero-section";
import { MatchCard } from "@/components/match-card";
import { NewsCard } from "@/components/news-card";
import { ProductCard } from "@/components/product-card";
import { ProgressBar } from "@/components/progress-bar";
import { SectionHeading } from "@/components/section-heading";
import {
  clubHistoryMoments,
  fallbackContributionGroups,
} from "@/lib/content";
import { getHomePageData } from "@/lib/data/public";
import { formatCompactNumber, formatCurrency } from "@/lib/utils";

export default async function HomePage() {
  const {
    club,
    featuredMatch,
    matches,
    news,
    products,
    membershipPackages,
    fanClubs,
    contributionGroups,
    standings,
  } = await getHomePageData();

  const activeCircles =
    contributionGroups.length > 0 ? contributionGroups : fallbackContributionGroups;
  const upcomingMatches = matches.filter((match) => match.id !== featuredMatch?.id);

  return (
    <div className="space-y-16 pb-20 pt-6 sm:pt-8">
      <AnimateOnScroll className="animate-fade-up">
        <HeroSection
          club={club}
          featuredMatch={featuredMatch}
          contributionGroups={activeCircles}
          fanClubs={fanClubs}
          membershipPackages={membershipPackages}
        />
      </AnimateOnScroll>

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

      <AnimateOnScroll className="page-shell">
        <section className="grid gap-6 lg:grid-cols-[0.95fr_1.05fr]">
          <div className="glass-panel-elevated rounded-[34px] p-6">
            <SectionHeading
              eyebrow="Support circles"
              title="The one feature global clubs do not have."
              description="Supporter circles are Gikundiro's strongest product differentiator. They should read like a campaign system with momentum, not a forgotten utility block."
            />
            <div className="mt-6 grid gap-4">
              {activeCircles.map((group) => (
                <article
                  key={group.id}
                  className="rounded-[26px] border border-border-soft bg-black/20 p-5"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-display text-3xl font-bold uppercase leading-none text-white">
                        {group.name}
                      </p>
                      <p className="mt-2 text-sm leading-7 text-slate-300">
                        {group.description}
                      </p>
                    </div>
                    <span className="rounded-full bg-club-accent/15 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                      {group.groupType}
                    </span>
                  </div>
                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    <div className="rounded-[22px] bg-white/5 p-4">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                        Current
                      </p>
                      <p className="mt-2 text-sm font-semibold text-white">
                        {formatCurrency(group.currentTotal, group.currency)}
                      </p>
                    </div>
                    <div className="rounded-[22px] bg-white/5 p-4">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                        Target
                      </p>
                      <p className="mt-2 text-sm font-semibold text-white">
                        {formatCurrency(group.targetAmount, group.currency)}
                      </p>
                    </div>
                    <div className="rounded-[22px] bg-white/5 p-4">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                        Members
                      </p>
                      <p className="mt-2 text-sm font-semibold text-white">
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
                title="Tickets, live hooks, and the next reason to return."
                description="The public web surface should answer the three biggest supporter questions immediately: what is next, how do I get in, and what is happening right now?"
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
                    {featuredMatch?.matchSummary ?? "Ticketing and live updates land here first."}
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
                    Digital membership should bridge the website and the portal, not hide behind app-only language.
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
                    className="mt-5 inline-flex items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10"
                  >
                    Compare tiers <ShieldCheck size={16} />
                  </Link>
                </div>
              </div>
            </article>

            <article className="glass-panel rounded-[34px] p-6">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <SectionHeading
                  eyebrow="Quick stats"
                  title="Supporters, not placeholders."
                  description="A football site earns trust through real numbers, clear next steps, and visible club momentum."
                />
                <div className="grid gap-3 sm:grid-cols-3">
                  <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4 text-center">
                    <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                      Fan clubs
                    </p>
                    <p className="mt-2 font-score text-4xl font-bold uppercase text-white">
                      {formatCompactNumber(fanClubs.length)}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4 text-center">
                    <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                      On sale
                    </p>
                    <p className="mt-2 font-score text-4xl font-bold uppercase text-white">
                      {formatCompactNumber(matches.filter((match) => match.isOnSale).length)}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4 text-center">
                    <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                      Live editorial
                    </p>
                    <p className="mt-2 font-score text-4xl font-bold uppercase text-white">
                      {formatCompactNumber(news.length)}
                    </p>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </section>
      </AnimateOnScroll>

      <AnimateOnScroll className="page-shell">
        <section className="section-grid">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <SectionHeading
              eyebrow="Fixtures"
              title="Live, upcoming, and recent match context."
              description="Fixture cards should behave like matchday UI, not generic product tiles. Scores, venue, urgency, and action labels need to read instantly."
            />
            <Link
              href="/fixtures"
              className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
            >
              Full fixtures <ArrowRight size={18} />
            </Link>
          </div>
          <StaggerChildren className="grid gap-5 lg:grid-cols-3">
            {upcomingMatches.slice(0, 3).map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </StaggerChildren>
        </section>
      </AnimateOnScroll>

      <AnimateOnScroll className="page-shell">
        <section className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
          <div className="glass-panel rounded-[34px] p-6">
            <SectionHeading
              eyebrow="Membership"
              title="Tiered supporter access that feels premium."
              description="A membership module should explain value fast, compare plans clearly, and move users into activation without hesitation."
            />
            <div className="mt-6 grid gap-4">
              {membershipPackages.map((membershipPackage) => (
                <article
                  key={membershipPackage.id}
                  className="rounded-[26px] border border-border-soft bg-white/5 p-5"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="font-display text-3xl font-bold uppercase leading-none text-white">
                        {membershipPackage.title}
                      </p>
                      <p className="mt-2 text-sm leading-7 text-slate-300">
                        {membershipPackage.description}
                      </p>
                    </div>
                    <div className="rounded-[22px] border border-border-soft bg-black/20 px-4 py-3 text-right">
                      <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                        Annual
                      </p>
                      <p className="mt-2 font-score text-4xl font-bold uppercase text-white">
                        {formatCurrency(membershipPackage.annualPrice, club.currencyCode)}
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
                title="League context that can be scanned in seconds."
                description="Rayon's position should be visible immediately, with enough surrounding rows to make the table useful."
              />
              <div className="mt-6 overflow-hidden rounded-[26px] border border-border-soft">
                <table className="w-full text-left text-sm">
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
                title="The club grows through public chapters."
                description="Fan clubs and chapter activity should feel visible, active, and easy to join."
              />
              <div className="mt-6 grid gap-4 sm:grid-cols-3">
                {fanClubs.slice(0, 3).map((clubItem) => (
                  <article
                    key={clubItem.id}
                    className="rounded-[24px] border border-border-soft bg-white/5 p-4"
                  >
                    <p className="font-display text-2xl font-bold uppercase leading-none text-white">
                      {clubItem.name}
                    </p>
                    <p className="mt-2 text-[11px] uppercase tracking-[0.22em] text-club-accent">
                      {clubItem.region}
                    </p>
                    <p className="mt-3 text-sm leading-7 text-slate-300">
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
      </AnimateOnScroll>

      <AnimateOnScroll className="page-shell">
        <section className="section-grid">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <SectionHeading
              eyebrow="Editorial"
              title="A club website should reward repeat visits."
              description="News, shop, and history should build emotional texture around the club instead of feeling like detached utility pages."
            />
            <Link
              href="/news"
              className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
            >
              Newsroom <ArrowRight size={18} />
            </Link>
          </div>
          <StaggerChildren className="grid gap-5 xl:grid-cols-3">
            {news.slice(0, 3).map((article) => (
              <NewsCard key={article.id} article={article} />
            ))}
          </StaggerChildren>
        </section>
      </AnimateOnScroll>

      <AnimateOnScroll className="page-shell">
        <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
          <div className="glass-panel rounded-[34px] p-6">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
              <SectionHeading
                eyebrow="Shop"
                title="Supporter commerce with clear visual hierarchy."
                description="The shop should feel like part of the club, not a detached product list."
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
                title="The web layer should feel rooted in the club."
                description="History, symbolism, and supporter culture should be visible everywhere, not confined to one static page."
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
                    <p className="mt-3 text-sm leading-7 text-slate-300">
                      {moment.body}
                    </p>
                  </article>
                ))}
              </div>
            </div>
            <div className="glass-panel rounded-[34px] p-6">
              <SectionHeading
                eyebrow="Conversion"
                title="Public website outside. Fan workspace inside."
                description="That split keeps the public web discoverable and keeps the supporter workflows operationally cleaner."
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
      </AnimateOnScroll>
    </div>
  );
}
