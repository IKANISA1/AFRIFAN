import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { ProgressBar } from "@/components/progress-bar";
import { getClubProfile, getContributionGroups, getFanClubs } from "@/lib/data/public";
import { getFeaturePageGuard } from "@/lib/feature-page-guard";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { formatCompactNumber } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.fanClubs.metaTitle(club),
    description: copy.pages.fanClubs.metaDescription(club),
    path: "/fan-clubs",
  });
}

export default async function FanClubsPage() {
  const featureGate = await getFeaturePageGuard("fan_clubs");
  if (featureGate) {
    return featureGate;
  }

  const [club, fanClubs, groups] = await Promise.all([
    getClubProfile(),
    getFanClubs(),
    getContributionGroups(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const totalMembers = fanClubs.reduce((total, club) => total + club.memberCount, 0);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.fanClubs.eyebrow}
        title={copy.pages.fanClubs.title}
        description={copy.pages.fanClubs.description(club)}
        actions={
          <>
            <Link
              href="/Groups"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.exploreGroups}
            </Link>
            <Link
              href="/supporters"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.joinInFanApp}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.chapters, value: fanClubs.length.toString() },
          { label: copy.common.members, value: formatCompactNumber(totalMembers) },
          { label: copy.common.Groups, value: groups.length.toString() },
        ]}
      />

      <div className="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="grid gap-5">
          {fanClubs.map((club) => (
            <article
              key={club.id}
              className="glass-panel card-interactive rounded-[30px] p-6"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-start gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-club-primary to-club-primary-light text-base font-bold text-white" aria-hidden="true">
                    {club.name.charAt(0)}
                  </div>
                  <div>
                    <p className="font-display text-3xl font-bold uppercase leading-none text-white sm:text-4xl">
                      {club.name}
                    </p>
                    <p className="mt-2 text-sm uppercase tracking-[0.24em] text-club-accent">
                      {club.region}
                    </p>
                  </div>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-white/6 px-4 py-3 text-right">
                  <p className="font-display text-3xl font-bold uppercase">
                    {club.memberCount}
                  </p>
                  <p className="text-xs uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.members}
                  </p>
                </div>
              </div>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {club.description}
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {club.eventCount} {copy.pages.fanClubs.events}
                </span>
                <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                  {club.rating.toFixed(1)} {copy.pages.fanClubs.rating}
                </span>
              </div>
            </article>
          ))}
        </div>
        <div className="glass-panel rounded-[30px] p-6">
          <p className="font-display text-4xl font-bold uppercase leading-none">
            {copy.pages.fanClubs.activeSupportGroups}
          </p>
          <div className="mt-5 grid gap-4">
            {groups.map((group) => (
              <div
                key={group.id}
                className="rounded-[22px] border border-border-soft bg-white/6 p-4"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-club-accent/15 text-sm font-bold text-club-accent" aria-hidden="true">
                    {group.name.charAt(0)}
                  </div>
                  <p className="font-semibold text-white">{group.name}</p>
                </div>
                <p className="mt-2 text-sm leading-6 text-slate-300">
                  {group.description}
                </p>
                <div className="mt-4">
                  <ProgressBar
                    value={group.currentTotal}
                    max={group.targetAmount}
                    label="Funded"
                    compact
                  />
                </div>
              </div>
            ))}
          </div>
          <Link
            href="/Groups"
            className="mt-6 inline-flex rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {copy.common.supportAGroup}
          </Link>
          <Link
            href="/supporters"
            className="mt-3 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            {copy.common.joinFromFanApp} <ArrowRight size={18} />
          </Link>
        </div>
      </div>
    </div>
  );
}
