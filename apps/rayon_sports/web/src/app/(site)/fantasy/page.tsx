import Link from "next/link";
import { Globe2, Smartphone, Trophy } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getFantasyCompetitions } from "@/lib/data/public";
import { resolveFanAppHref } from "@/lib/config";
import { buildPageMetadata } from "@/lib/metadata";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: `${club.shortName} fantasy football`,
    description:
      `Official ${club.shortName} fantasy football hub for published competitions, public leaderboards, and authenticated gameplay in the fan app.`,
    path: "/fantasy",
  });
}

function modeLabel(mode: string) {
  return mode === "tournament" ? "Tournament" : "Season long";
}

function statusLabel(status: string, isPlayable: boolean) {
  if (isPlayable) {
    return "Live";
  }
  switch (status) {
    case "preview":
      return "Preview";
    case "archived":
      return "Archived";
    case "playable":
      return "Playable";
    default:
      return "Planned";
  }
}

export default async function FantasyPage() {
  const [club, competitions] = await Promise.all([
    getClubProfile(),
    getFantasyCompetitions(),
  ]);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Fantasy football"
        title="Official fantasy football hub."
        description={`Browse every published ${club.shortName} fantasy competition, follow public leaderboard snapshots, and continue into the fan app for squad management and live play.`}
        actions={
          <>
            <Link
              href={resolveFanAppHref()}
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Continue in fan app
            </Link>
            <Link
              href="/"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Back to homepage
            </Link>
          </>
        }
        stats={[
          { label: "Competitions", value: competitions.length.toString() },
          {
            label: "Playable",
            value: competitions
              .filter((competition) => competition.isPlayable)
              .length
              .toString(),
          },
          {
            label: "Preview",
            value: competitions
              .filter((competition) => !competition.isPlayable)
              .length
              .toString(),
          },
        ]}
      />

      <section className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="grid gap-5">
          {competitions.length === 0 ? (
            <article className="glass-panel rounded-[34px] p-6">
              <p className="font-display text-3xl font-bold uppercase leading-none text-white">
                No published competitions
              </p>
              <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300">
                Fantasy competitions will appear here once they are enabled for this club. The fan app remains the place for authenticated squad management when a competition goes live.
              </p>
            </article>
          ) : (
            competitions.map((competition) => (
              <Link
                key={competition.id}
                href={`/fantasy/${competition.slug}`}
                prefetch={false}
                className="glass-panel card-interactive rounded-[34px] p-6"
              >
                <div className="flex flex-wrap items-center gap-2">
                  {competition.badgeLabel ? (
                    <span className="rounded-full bg-club-accent/15 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-club-accent">
                      {competition.badgeLabel}
                    </span>
                  ) : null}
                  <span className="rounded-full border border-border-soft px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                    {competition.countryCode ?? "Global"}
                  </span>
                  <span className="rounded-full border border-border-soft px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                    {statusLabel(competition.status, competition.isPlayable)}
                  </span>
                </div>
                <div className="mt-5 flex items-start justify-between gap-4">
                  <div>
                    <p className="font-display text-4xl font-bold uppercase leading-none text-white">
                      {competition.name}
                    </p>
                    <p className="mt-2 text-sm text-club-accent">
                      {competition.season} • {modeLabel(competition.mode)}
                    </p>
                  </div>
                  <div
                    className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-white/10"
                    style={{ backgroundColor: `${competition.primaryColor}22` }}
                  >
                    <Trophy size={20} style={{ color: competition.primaryColor }} />
                  </div>
                </div>
                <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300">
                  {competition.promoBody ?? competition.description}
                </p>
              </Link>
            ))
          )}
        </div>

        <aside className="grid gap-5">
          <article className="glass-panel rounded-[34px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              How it works
            </p>
            <div className="mt-5 grid gap-4">
              {[
                "Browse published competitions and public leaderboard snapshots on the web.",
                "Open the fan app to create an entry, build a squad, and manage transfers.",
                "Competitions only appear here when the club has enabled them for supporters.",
              ].map((item) => (
                <div
                  key={item}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300"
                >
                  {item}
                </div>
              ))}
            </div>
          </article>

          <article className="glass-panel rounded-[34px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Delivery surfaces
            </p>
            <div className="mt-5 grid gap-4 sm:grid-cols-2">
              <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
                <Globe2 className="text-club-accent" size={18} />
                <p className="mt-4 font-display text-2xl font-bold uppercase leading-none text-white">
                  Web
                </p>
                <p className="mt-2 text-sm leading-7 text-slate-300">
                  Competition discovery, public leaderboard views, and competition details.
                </p>
              </div>
              <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
                <Smartphone className="text-club-accent" size={18} />
                <p className="mt-4 font-display text-2xl font-bold uppercase leading-none text-white">
                  App
                </p>
                <p className="mt-2 text-sm leading-7 text-slate-300">
                  Entry creation, squad building, transfers, chips, and live scoring.
                </p>
              </div>
            </div>
          </article>
        </aside>
      </section>
    </div>
  );
}
