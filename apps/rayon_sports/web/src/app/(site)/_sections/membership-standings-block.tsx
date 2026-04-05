import Link from "next/link";
import { ShieldCheck, Trophy, Users } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";
import {
  getClubProfile,
  getFanClubs,
  getMembershipPackages,
  getStandings,
} from "@/lib/data/public";
import { formatCurrency } from "@/lib/utils";

export async function MembershipAndStandingsBlock() {
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
          prefetch={false}
          className="mt-6 inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
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
            prefetch={false}
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
            prefetch={false}
            className="mt-5 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Explore chapters <Users size={18} />
          </Link>
        </div>
      </div>
    </section>
  );
}
