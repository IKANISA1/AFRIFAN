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
    title: copy.pages.Groups.metaTitle(club),
    description: copy.pages.Groups.metaDescription(club),
    path: "/Groups",
  });
}

export default async function GroupsPage() {
  const [club, groups, fanClubs] = await Promise.all([
    getClubProfile(),
    getContributionGroups(),
    getFanClubs(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <div className="bg-white min-h-screen pt-24 pb-20 lg:pt-32">
      <div className="page-shell">
        <header className="mb-16 border-b border-slate-100 pb-12">
          <p className="text-xs font-bold uppercase tracking-[0.4em] text-[var(--club-primary)] mb-4">{copy.pages.Groups.eyebrow}</p>
          <h1 className="font-display text-6xl font-black uppercase italic leading-none tracking-tighter text-slate-900 lg:text-9xl">
            {copy.pages.Groups.title}
          </h1>
          <div className="mt-8 max-w-2xl text-lg font-medium text-slate-600">
            {copy.pages.Groups.description(club)}
          </div>
        </header>

        <div className="grid gap-12 lg:grid-cols-12">
          <div className="lg:col-span-8 space-y-12">
            {groups.map((group) => (
              <article key={group.id} className="group relative overflow-hidden rounded-3xl border border-slate-100 bg-slate-50 p-10 transition-all hover:border-[var(--club-primary)]/20 hover:bg-white hover:shadow-2xl">
                <div className="flex flex-col gap-8 sm:flex-row sm:items-start sm:justify-between">
                  <div className="max-w-xl">
                    <div className="flex items-center gap-3 mb-4">
                      <span className="rounded-full bg-[var(--club-primary)] px-4 py-1 text-[10px] font-black uppercase tracking-widest text-white">
                        {group.groupType}
                      </span>
                      <span className="text-[10px] font-bold uppercase tracking-widest text-slate-400">{group.privacy}</span>
                    </div>
                    <h2 className="font-display text-4xl font-black uppercase italic leading-none text-slate-900 mb-4">{group.name}</h2>
                    <p className="text-base text-slate-600 leading-relaxed">{group.description}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-[10px] font-black uppercase tracking-[0.3em] text-slate-400 mb-2">Backers</p>
                    <p className="font-display text-5xl font-black italic text-[var(--club-primary)]">{group.memberCount}</p>
                  </div>
                </div>

                <div className="mt-12 grid grid-cols-2 gap-8 border-t border-slate-200 pt-10">
                  <div>
                    <p className="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-2">Total Raised</p>
                    <p className="text-3xl font-black text-slate-900 italic">{formatCurrency(group.currentTotal, group.currency)}</p>
                  </div>
                  <div>
                    <p className="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-2">Campaign Goal</p>
                    <p className="text-3xl font-black text-slate-900 italic">{formatCurrency(group.targetAmount, group.currency)}</p>
                  </div>
                </div>

                <div className="mt-10">
                  <div className="flex items-center justify-between mb-4">
                    <p className="text-[10px] font-black uppercase tracking-widest text-slate-500">Mobilization Progress</p>
                    <p className="text-[10px] font-black text-[var(--club-primary)] uppercase italic">{Math.round((group.currentTotal / group.targetAmount) * 100)}% Reached</p>
                  </div>
                  <div className="h-3 w-full bg-slate-200 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-[var(--club-primary)] transition-all duration-1000 ease-out"
                      style={{ width: `${Math.round((group.currentTotal / group.targetAmount) * 100)}%` }}
                    />
                  </div>
                </div>

                <Link href="/supporters" className="mt-10 block w-full rounded-xl bg-[var(--club-primary)] py-5 text-center text-xs font-black uppercase tracking-[0.3em] text-white transition-all hover:bg-[var(--club-primary-light)] active:scale-95">
                  Back This Movement
                </Link>
              </article>
            ))}
          </div>

          <aside className="lg:col-span-4 space-y-8">
            <div className="rounded-3xl bg-slate-900 p-10 text-white shadow-2xl">
              <h3 className="font-display text-3xl font-black uppercase italic leading-none mb-6">Why Support?</h3>
              <ul className="space-y-6">
                {[
                  { title: "Direct Impact", body: "100% of your contribution goes directly to the specified club project." },
                  { title: "Collective Power", body: "Turn individual passion into visible matchday choreography and club heritage." },
                  { title: "Member Status", body: "Backers earn exclusive digital badges and priority access to project events." }
                ].map((item, i) => (
                  <li key={i} className="border-b border-white/10 pb-6 last:border-0">
                    <p className="text-[var(--club-accent)] text-xs font-black uppercase tracking-widest mb-2">{item.title}</p>
                    <p className="text-sm text-white/60 leading-relaxed">{item.body}</p>
                  </li>
                ))}
              </ul>
            </div>

            <div className="rounded-3xl border-2 border-slate-100 p-10">
              <h3 className="font-display text-2xl font-black uppercase italic leading-none mb-6 text-slate-900">Chapter Network</h3>
              <div className="space-y-4">
                {fanClubs.map(ch => (
                  <div key={ch.id} className="flex items-center justify-between py-3 border-b border-slate-100 last:border-0">
                    <p className="text-sm font-bold text-slate-700 uppercase tracking-tight">{ch.name}</p>
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{ch.region}</span>
                  </div>
                ))}
              </div>
              <Link href="/fan-clubs" className="mt-8 inline-flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.3em] text-[var(--club-primary)] hover:translate-x-1 transition-transform">
                Explore All Chapters <ArrowRight size={14} />
              </Link>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}
