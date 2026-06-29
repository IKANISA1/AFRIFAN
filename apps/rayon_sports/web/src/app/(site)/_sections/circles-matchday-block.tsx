import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { ProgressBar } from "@/components/progress-bar";
import { SectionHeading } from "@/components/section-heading";
import {
  getClubProfile,
  getContributionGroups,
  getFanClubs,
  getMatches,
  getMembershipPackages,
  getNewsArticles,
} from "@/lib/data/public";
import { formatCompactNumber, formatCurrency } from "@/lib/utils";

export async function GroupsAndMatchdayBlock() {
  const [
    club,
    matches,
    contributionGroups,
    fanClubs,
    membershipPackages,
    news,
  ] = await Promise.all([
    getClubProfile(),
    getMatches(),
    getContributionGroups(),
    getFanClubs(),
    getMembershipPackages(),
    getNewsArticles(),
  ]);

  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    matches.find((m) => m.matchStatus !== "fulltime") ??
    matches[0] ??
    null;

  return (
    <section className="page-shell">
      <div className="grid gap-8 lg:grid-cols-12">
        {/* Support Circles: The Engine */}
        <div className="lg:col-span-7">
          <header className="mb-10 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.3em] text-[var(--club-accent)] mb-2">Crowdfunding</p>
              <h2 className="font-display text-4xl font-black uppercase italic text-white tracking-tight">Support Circles</h2>
            </div>
            <Link href="/Groups" className="text-xs font-bold uppercase tracking-widest text-white/60 hover:text-white transition-colors flex items-center gap-2">
              View All Goals <ArrowRight size={14} />
            </Link>
          </header>

          <div className="grid gap-6">
            {contributionGroups.map((group) => (
              <article key={group.id} className="relative overflow-hidden rounded-3xl bg-white/5 border border-white/10 p-8 transition-all hover:bg-white/[0.08]">
                <div className="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
                  <div className="max-w-md">
                    <h3 className="font-display text-2xl font-black uppercase italic text-white mb-2">{group.name}</h3>
                    <p className="text-sm text-white/60 leading-relaxed">{group.description}</p>
                  </div>
                  <div className="shrink-0 text-right">
                    <p className="text-[10px] font-bold uppercase tracking-widest text-[var(--club-accent)] mb-1">Status</p>
                    <span className="inline-block rounded-full bg-[var(--club-accent)]/10 px-4 py-1.5 text-[10px] font-black uppercase tracking-widest text-[var(--club-accent)] border border-[var(--club-accent)]/20">
                      {group.groupType}
                    </span>
                  </div>
                </div>

                <div className="mt-8 grid grid-cols-2 gap-8 md:grid-cols-3">
                  <div>
                    <p className="text-[10px] font-bold uppercase tracking-widest text-white/40 mb-2">Funded</p>
                    <p className="text-2xl font-black text-white italic">{formatCurrency(group.currentTotal, group.currency)}</p>
                  </div>
                  <div>
                    <p className="text-[10px] font-bold uppercase tracking-widest text-white/40 mb-2">Target</p>
                    <p className="text-2xl font-black text-white italic">{formatCurrency(group.targetAmount, group.currency)}</p>
                  </div>
                  <div className="hidden md:block">
                    <p className="text-[10px] font-bold uppercase tracking-widest text-white/40 mb-2">Supporters</p>
                    <p className="text-2xl font-black text-white italic">{formatCompactNumber(group.memberCount)}</p>
                  </div>
                </div>

                <div className="mt-8">
                  <div className="flex items-center justify-between mb-3">
                    <p className="text-[10px] font-bold uppercase tracking-widest text-white/60">Overall Progress</p>
                    <p className="text-[10px] font-bold text-[var(--club-accent)] uppercase">{Math.round((group.currentTotal / group.targetAmount) * 100)}% Complete</p>
                  </div>
                  <ProgressBar value={group.currentTotal} max={group.targetAmount} compact />
                </div>
              </article>
            ))}
          </div>
        </div>

        {/* Club Stats & Identity */}
        <div className="lg:col-span-5 flex flex-col gap-8">
          <article className="flex-1 rounded-3xl bg-[var(--club-accent)] p-10 text-[var(--club-primary)]">
            <p className="text-xs font-bold uppercase tracking-[0.3em] mb-4">Membership</p>
            <h2 className="font-display text-4xl font-black uppercase italic leading-[0.9] tracking-tighter mb-6">
              Become a<br/>Beloved Member.
            </h2>
            <p className="text-sm font-bold leading-relaxed mb-8 opacity-80">
              Unlock priority ticketing, exclusive content, and a direct voice in the club&apos;s future. Join the elite rank of Gikundiro supporters today.
            </p>
            <div className="flex flex-wrap gap-2 mb-10">
              {membershipPackages.map(tier => (
                <span key={tier.id} className="rounded-lg border border-[var(--club-primary)]/20 bg-white/20 px-3 py-1.5 text-[9px] font-black uppercase tracking-widest">
                  {tier.title}
                </span>
              ))}
            </div>
            <Link href="/membership" className="inline-flex items-center gap-3 rounded-full bg-[var(--club-primary)] px-8 py-4 text-xs font-black uppercase tracking-widest text-white transition-all hover:scale-105 active:scale-95">
              Explore Plans <ArrowRight size={16} />
            </Link>
          </article>

          <div className="rounded-3xl border border-white/10 bg-white/5 p-10">
            <p className="text-xs font-bold uppercase tracking-[0.3em] text-white/40 mb-8 text-center">Global Impact</p>
            <div className="grid grid-cols-3 gap-4 divide-x divide-white/10">
              <div className="text-center px-2">
                <p className="font-display text-4xl font-black italic text-white">{fanClubs.length}</p>
                <p className="mt-2 text-[9px] font-bold uppercase tracking-widest text-white/40">Chapters</p>
              </div>
              <div className="text-center px-2">
                <p className="font-display text-4xl font-black italic text-white">{formatCompactNumber(contributionGroups.reduce((a,b) => a + b.memberCount, 0))}</p>
                <p className="mt-2 text-[9px] font-bold uppercase tracking-widest text-white/40">Backers</p>
              </div>
              <div className="text-center px-2">
                <p className="font-display text-4xl font-black italic text-white">50+</p>
                <p className="mt-2 text-[9px] font-bold uppercase tracking-widest text-white/40">Years</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
