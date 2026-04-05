import Link from "next/link";
import { ArrowRight, ShieldCheck, Zap } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getSquad } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";

export const metadata = buildPageMetadata({
  title: "Rayon Sports squad",
  description:
    "Official Rayon Sports squad list with player numbers, roles, and nationalities.",
  path: "/squad",
});

export default async function SquadPage() {
  const squad = await getSquad();
  const grouped = {
    goalkeepers: squad.filter((player) => player.role.toLowerCase().includes("keeper")),
    defenders: squad.filter((player) =>
      /back|defender/.test(player.role.toLowerCase()),
    ),
    midfielders: squad.filter((player) => player.role.toLowerCase().includes("mid")),
    attackers: squad.filter(
      (player) =>
        /wing|forward|striker/.test(player.role.toLowerCase()) ||
        !/keeper|back|defender|mid/.test(player.role.toLowerCase()),
    ),
  };
  const uniqueNationalities = new Set(squad.map((player) => player.nationality)).size;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Squad"
        title="Squad, numbers, and roles."
        description="Meet the Rayon Sports squad with player numbers, positions, and the shape of the group behind every matchday."
        actions={
          <>
            <Link
              href="/fixtures"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Next fixtures
            </Link>
            <Link
              href="/news"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Player stories
            </Link>
          </>
        }
        stats={[
          { label: "Players", value: squad.length.toString() },
          { label: "Nationalities", value: uniqueNationalities.toString() },
          {
            label: "Core units",
            value: "4",
          },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {squad.map((player) => (
            <article
              key={player.id}
              className="glass-panel card-interactive rounded-[30px] border border-border-soft p-6"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-display text-3xl font-bold uppercase leading-none text-white">
                    {player.name}
                  </p>
                  <p className="mt-2 text-sm uppercase tracking-[0.24em] text-club-accent">
                    {player.role}
                  </p>
                </div>
                <span className="font-score text-6xl font-bold uppercase text-white/80">
                  {player.number}
                </span>
              </div>
              <p className="mt-4 text-sm uppercase tracking-[0.2em] text-slate-300">
                {player.nationality}
              </p>
              <p className="mt-4 text-sm leading-7 text-slate-300">{player.bio}</p>
            </article>
          ))}
        </div>

        <div className="glass-panel rounded-[30px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Unit view
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
            Tactical shape at a glance
          </h2>
          <div className="mt-5 grid gap-4">
            {[
              { title: "Goalkeepers", count: grouped.goalkeepers.length, icon: ShieldCheck },
              { title: "Defenders", count: grouped.defenders.length, icon: ShieldCheck },
              { title: "Midfielders", count: grouped.midfielders.length, icon: Zap },
              { title: "Attackers", count: grouped.attackers.length, icon: ArrowRight },
            ].map(({ title, count, icon: Icon }) => (
              <div
                key={title}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4"
              >
                <div className="flex items-center justify-between gap-4">
                  <div className="flex items-center gap-3">
                    <span className="flex h-10 w-10 items-center justify-center rounded-full bg-club-primary/16 text-club-accent">
                      <Icon size={18} />
                    </span>
                    <p className="text-sm font-semibold uppercase tracking-[0.18em] text-white">
                      {title}
                    </p>
                  </div>
                  <span className="font-score text-4xl text-white">{count}</span>
                </div>
              </div>
            ))}
          </div>
          <p className="mt-5 text-sm leading-7 text-slate-300">
            This roster becomes even stronger with photography, player stats,
            and direct links into matchday and editorial coverage.
          </p>
        </div>
      </section>
    </div>
  );
}
