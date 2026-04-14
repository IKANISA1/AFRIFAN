import Link from "next/link";
import { ArrowRight, ShieldCheck, Users } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { ProgressBar } from "@/components/progress-bar";
import { getClubProfile, getContributionGroups, getFanClubs } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { formatCompactNumber, formatCurrency } from "@/lib/utils";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.circles.metaTitle(club),
    description: copy.pages.circles.metaDescription(club),
    path: "/circles",
  });
}

export default async function CirclesPage() {
  const [club, groups, fanClubs] = await Promise.all([
    getClubProfile(),
    getContributionGroups(),
    getFanClubs(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  const fundedTotal = groups.reduce((total, group) => total + group.currentTotal, 0);
  const totalMembers = groups.reduce((total, group) => total + group.memberCount, 0);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.circles.eyebrow}
        title={copy.pages.circles.title}
        description={copy.pages.circles.description(club)}
        actions={
          <>
            <Link
              href="/supporters"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.joinInFanApp}
            </Link>
            <Link
              href="/fan-clubs"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.fanClubs}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.circles, value: groups.length.toString() },
          { label: copy.common.members, value: formatCompactNumber(totalMembers) },
          { label: copy.common.raised, value: formatCurrency(fundedTotal) },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.12fr_0.88fr]">
        <div className="grid gap-5">
          {groups.map((group) => (
            <article
              key={group.id}
              className="glass-panel card-interactive rounded-[32px] p-6"
            >
              <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="rounded-full bg-club-accent/15 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                      {group.groupType}
                    </span>
                    <span className="rounded-full border border-border-soft px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-200">
                      {group.privacy}
                    </span>
                  </div>
                  <h2 className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
                    {group.name}
                  </h2>
                  <p className="mt-4 max-w-3xl text-sm leading-8 text-slate-300 sm:text-base">
                    {group.description}
                  </p>
                </div>
                <div className="rounded-[24px] border border-border-soft bg-black/20 px-5 py-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.members}
                  </p>
                  <p className="mt-2 font-score text-5xl text-white">
                    {group.memberCount}
                  </p>
                </div>
              </div>

              <div className="mt-5 grid gap-3 sm:grid-cols-3">
                <div className="rounded-[22px] bg-white/5 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.current}
                  </p>
                  <p className="mt-2 text-sm font-semibold text-white">
                    {formatCurrency(group.currentTotal, group.currency)}
                  </p>
                </div>
                <div className="rounded-[22px] bg-white/5 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.target}
                  </p>
                  <p className="mt-2 text-sm font-semibold text-white">
                    {formatCurrency(group.targetAmount, group.currency)}
                  </p>
                </div>
                <div className="rounded-[22px] bg-white/5 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.invite}
                  </p>
                  <p className="mt-2 text-sm font-semibold text-white">
                    {group.inviteCode ?? copy.fanApp}
                  </p>
                </div>
              </div>

              <div className="mt-5">
                <ProgressBar
                  value={group.currentTotal}
                  max={group.targetAmount}
                  label={copy.pages.circles.campaignProgress}
                />
              </div>
            </article>
          ))}
        </div>

        <div className="grid gap-6">
          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.pages.circles.whyEyebrow}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.pages.circles.whyTitle}
            </h2>
            <div className="mt-5 grid gap-4">
              {[
                "Circles turn supporter energy into visible collective action.",
                "Live funding progress keeps every campaign legible.",
                "The public page tells the story and the fan app handles the contribution.",
              ].map((point) => (
                <div
                  key={point}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
                >
                  {point}
                </div>
              ))}
            </div>
            <Link
              href="/supporters"
              className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
            >
              {copy.common.supportACircle} <ArrowRight size={18} />
            </Link>
          </div>

          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              {copy.pages.circles.bridgeEyebrow}
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              {copy.pages.circles.bridgeTitle}
            </h2>
            <div className="mt-5 grid gap-3">
              {fanClubs.slice(0, 3).map((club) => (
                <div
                  key={club.id}
                  className="rounded-[22px] border border-border-soft bg-white/5 p-4"
                >
                  <div className="flex items-center justify-between gap-4">
                    <div>
                      <p className="text-sm font-semibold text-white">{club.name}</p>
                      <p className="mt-1 text-xs uppercase tracking-[0.22em] text-slate-300">
                        {club.region}
                      </p>
                    </div>
                    <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-primary/16 text-club-accent">
                      <Users size={18} />
                    </span>
                  </div>
                </div>
              ))}
            </div>
            <Link
              href="/fan-clubs"
              className="mt-6 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
            >
              {copy.common.seeFanClubs} <ShieldCheck size={18} />
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
