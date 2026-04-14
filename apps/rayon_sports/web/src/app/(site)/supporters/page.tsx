import Link from "next/link";
import { Download, ShieldCheck, Smartphone } from "lucide-react";
import { FatLeaderboard } from "@/components/engagement/fat-leaderboard";
import { PageHero } from "@/components/page-hero";
import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { getClubProfile } from "@/lib/data/public";
import {
  getFanEngagementLeaderboard,
  getFanEngagementTokens,
} from "@/lib/data/public/gamification";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.supporters.metaTitle,
    description: copy.pages.supporters.metaDescription,
    path: "/supporters",
  });
}

export default async function SupportersPage() {
  const fanAppHref = resolveFanAppHref();
  const hasExternalAppUrl = siteConfig.fanAppUrl.length > 0;
  const [club, catalog, leaderboard] = await Promise.all([
    getClubProfile(),
    getFanEngagementTokens(8),
    getFanEngagementLeaderboard(10),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const categories = new Set(catalog.map((item) => item.category)).size;
  const highestReward = catalog.reduce(
    (current, item) => Math.max(current, item.fetValue),
    0,
  );

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.supporters.eyebrow}
        title={copy.pages.supporters.title}
        description={copy.pages.supporters.description}
        actions={
          <>
            <Link
              href={fanAppHref}
              className="inline-flex min-h-12 items-center justify-center rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {hasExternalAppUrl ? copy.openFanApp : copy.common.appLinksComingSoon}
            </Link>
            <Link
              href="/tickets"
              className="inline-flex min-h-12 items-center justify-center rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.browseTicketsFirst}
            </Link>
          </>
        }
        stats={[
          { label: copy.tickets, value: copy.common.mobile },
          { label: copy.membership, value: copy.common.mobile },
          { label: copy.common.bioPay, value: copy.common.mobile },
        ]}
      />

      <section className="grid gap-5 lg:grid-cols-3">
        {[
          {
            icon: Smartphone,
            title: copy.pages.supporters.supporterIdentity,
            copy: copy.pages.supporters.identityBody,
          },
          {
            icon: ShieldCheck,
            title: copy.pages.supporters.secureActions,
            copy: copy.pages.supporters.secureActionsBody,
          },
          {
            icon: Download,
            title: copy.pages.supporters.rolloutReady,
            copy: hasExternalAppUrl
              ? copy.pages.supporters.rolloutReadyConfigured
              : copy.pages.supporters.rolloutReadyPending,
          },
        ].map(({ icon: Icon, title, copy }) => (
          <article
            key={title}
            className="glass-panel rounded-[30px] p-6"
          >
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-club-primary/15 text-club-accent">
              <Icon size={20} />
            </span>
            <h2 className="mt-5 font-display text-3xl font-bold uppercase leading-none text-white">
              {title}
            </h2>
            <p className="mt-4 text-sm leading-7 text-slate-300">{copy}</p>
          </article>
        ))}
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        <article className="glass-panel rounded-[30px] p-6">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p className="font-mono text-[11px] uppercase tracking-[0.3em] text-club-accent">
                {copy.pages.supporters.liveFetCatalog}
              </p>
              <h2 className="mt-3 font-display text-3xl font-bold uppercase text-white">
                {copy.pages.supporters.adminManagedRewards}
              </h2>
              <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300">
                {copy.pages.supporters.catalogIntro}
              </p>
            </div>
            <div className="grid gap-3 sm:grid-cols-3">
              <div className="rounded-2xl border border-white/8 bg-white/4 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400">
                  {copy.pages.supporters.activeRewards}
                </p>
                <p className="mt-2 font-display text-3xl font-bold text-white">
                  {catalog.length}
                </p>
              </div>
              <div className="rounded-2xl border border-white/8 bg-white/4 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400">
                  {copy.common.categories}
                </p>
                <p className="mt-2 font-display text-3xl font-bold text-white">
                  {categories}
                </p>
              </div>
              <div className="rounded-2xl border border-white/8 bg-white/4 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400">
                  {copy.pages.supporters.topReward}
                </p>
                <p className="mt-2 font-display text-3xl font-bold text-white">
                  {highestReward.toLocaleString()}
                </p>
                <p className="text-[10px] uppercase tracking-[0.18em] text-club-accent">
                  FET
                </p>
              </div>
            </div>
          </div>

          {catalog.length > 0 ? (
            <div className="mt-6 grid gap-3 md:grid-cols-2">
              {catalog.map((item) => (
                <article
                  key={item.id}
                  className="rounded-[24px] border border-white/8 bg-white/4 p-4"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="font-mono text-[10px] uppercase tracking-[0.18em] text-slate-400">
                        {item.code} • {item.category}
                      </p>
                      <h3 className="mt-2 text-lg font-semibold text-white">
                        {item.itemName}
                      </h3>
                    </div>
                    <div className="rounded-full bg-club-accent/15 px-3 py-1 text-[11px] font-bold text-club-accent">
                      {item.fetValue.toLocaleString()} FET
                    </div>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-slate-300">
                    {item.description}
                  </p>
                  <div className="mt-4 grid gap-2 text-xs text-slate-400">
                    <p>
                      <span className="font-semibold text-slate-200">
                        {copy.pages.supporters.trigger}:
                      </span>{" "}
                      {item.triggerCondition}
                    </p>
                    <p>
                      <span className="font-semibold text-slate-200">
                        {copy.pages.supporters.timing}:
                      </span>{" "}
                      {item.activationTiming}
                    </p>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="mt-6 rounded-[24px] border border-white/8 bg-white/4 p-5 text-sm leading-7 text-slate-300">
              {copy.pages.supporters.noCatalog}
            </div>
          )}
        </article>

        <article className="glass-panel rounded-[30px] p-6">
          <p className="font-mono text-[11px] uppercase tracking-[0.3em] text-club-accent">
            {copy.pages.supporters.supporterLeaderboard}
          </p>
          <h2 className="mt-3 font-display text-3xl font-bold uppercase text-white">
            {copy.pages.supporters.currentFetRanking}
          </h2>
          <p className="mt-4 text-sm leading-7 text-slate-300">
            {copy.pages.supporters.leaderboardIntro}
          </p>

          {leaderboard.length > 0 ? (
            <div className="mt-6">
              <FatLeaderboard
                entries={leaderboard.map((entry) => ({
                  rank: entry.rank,
                  name: `#${entry.supporterAlias}`,
                  score: entry.totalFet,
                  level: entry.tier.toUpperCase(),
                  isCurrentUser: entry.isCurrentUser,
                }))}
                scoreLabel="FET"
              />
            </div>
          ) : (
            <div className="mt-6 rounded-[24px] border border-white/8 bg-white/4 p-5 text-sm leading-7 text-slate-300">
              {copy.pages.supporters.noLeaderboard}
            </div>
          )}
        </article>
      </section>
    </div>
  );
}
