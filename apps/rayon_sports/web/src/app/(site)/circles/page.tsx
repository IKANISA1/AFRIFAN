import Link from "next/link";
import { ArrowRight, ShieldCheck, Users } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { ProgressBar } from "@/components/progress-bar";
import { getContributionGroups, getFanClubs } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { formatCompactNumber, formatCurrency } from "@/lib/utils";

export const metadata = buildPageMetadata({
  title: "Rayon Sports supporter circles",
  description:
    "Official Rayon Sports supporter circles for tifos, away travel, club campaigns, and community fundraising.",
  path: "/circles",
});

export default async function CirclesPage() {
  const [groups, fanClubs] = await Promise.all([
    getContributionGroups(),
    getFanClubs(),
  ]);

  const fundedTotal = groups.reduce((total, group) => total + group.currentTotal, 0);
  const totalMembers = groups.reduce((total, group) => total + group.memberCount, 0);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Support Circles"
        title="Supporter circles and live campaigns."
        description="Back tifos, away travel, and club projects through official Rayon Sports supporter circles."
        actions={
          <>
            <Link
              href="/app/contributions"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Join in portal
            </Link>
            <Link
              href="/fan-clubs"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Fan clubs
            </Link>
          </>
        }
        stats={[
          { label: "Circles", value: groups.length.toString() },
          { label: "Members", value: formatCompactNumber(totalMembers) },
          { label: "Raised", value: formatCurrency(fundedTotal) },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.12fr_0.88fr]">
        <div className="grid gap-5">
          {groups.map((group) => (
            <article
              key={group.id}
              className="glass-panel card-interactive rounded-[32px] border border-border-soft p-6"
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
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    Members
                  </p>
                  <p className="mt-2 font-score text-5xl text-white">
                    {group.memberCount}
                  </p>
                </div>
              </div>

              <div className="mt-5 grid gap-3 sm:grid-cols-3">
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
                    Invite
                  </p>
                  <p className="mt-2 text-sm font-semibold text-white">
                    {group.inviteCode ?? "Portal"}
                  </p>
                </div>
              </div>

              <div className="mt-5">
                <ProgressBar
                  value={group.currentTotal}
                  max={group.targetAmount}
                  label="Campaign progress"
                />
              </div>
            </article>
          ))}
        </div>

        <div className="grid gap-6">
          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Why circles matter
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              Back the campaign together
            </h2>
            <div className="mt-5 grid gap-4">
              {[
                "Circles turn supporter energy into visible collective action.",
                "Live funding progress keeps every campaign legible.",
                "The public page tells the story and the portal handles the contribution.",
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
              href="/app/contributions"
              className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-club-ink transition hover:brightness-110"
            >
              Contribute now <ArrowRight size={18} />
            </Link>
          </div>

          <div className="glass-panel rounded-[32px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Community bridge
            </p>
            <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
              Chapters that amplify every campaign
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
                      <p className="mt-1 text-xs uppercase tracking-[0.22em] text-slate-400">
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
              See fan clubs <ShieldCheck size={18} />
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
