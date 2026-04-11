import Link from "next/link";
import { ArrowRight, Globe2, Trophy } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";
import {
  getFantasyCompetitions,
  getFeaturedFantasyCompetition,
} from "@/lib/data/public";

function statusLabel(status: string, isPlayable: boolean) {
  if (isPlayable) {
    return "Live";
  }

  switch (status) {
    case "preview":
      return "Preview";
    case "archived":
      return "Archive";
    case "playable":
      return "Playable";
    default:
      return "Planned";
  }
}

export async function FantasyBlock() {
  const [featuredCompetition, competitions] = await Promise.all([
    getFeaturedFantasyCompetition(),
    getFantasyCompetitions(),
  ]);

  if (featuredCompetition == null || competitions.length === 0) {
    return null;
  }

  return (
    <section className="page-shell grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
      <article className="glass-panel relative overflow-hidden rounded-[36px] p-6 sm:p-8">
        <div
          className="pointer-events-none absolute inset-0 opacity-90"
          style={{
            background: `radial-gradient(circle at top left, ${featuredCompetition.primaryColor}66, transparent 34%), radial-gradient(circle at bottom right, rgba(255,255,255,0.12), transparent 38%)`,
          }}
        />
        <div className="relative space-y-6">
          <SectionHeading
            eyebrow="Fantasy football"
            title={featuredCompetition.promoTitle ?? featuredCompetition.name}
            description={
              featuredCompetition.promoBody ??
              featuredCompetition.description
            }
          />
          <div className="flex flex-wrap gap-2">
            <span className="rounded-full border border-white/15 bg-white/8 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-white">
              {featuredCompetition.season}
            </span>
            <span className="rounded-full border border-white/15 bg-white/8 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-white">
              {featuredCompetition.mode === "tournament"
                ? "Tournament"
                : "Season long"}
            </span>
            <span className="rounded-full border border-white/15 bg-white/8 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-white">
              {statusLabel(featuredCompetition.status, featuredCompetition.isPlayable)}
            </span>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <article className="rounded-[24px] border border-white/10 bg-white/5 p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-300">
                Matchday
              </p>
              <p className="mt-3 font-display text-2xl font-bold uppercase leading-none text-white">
                Public hub
              </p>
            </article>
            <article className="rounded-[24px] border border-white/10 bg-white/5 p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-300">
                Gameplay
              </p>
              <p className="mt-3 font-display text-2xl font-bold uppercase leading-none text-white">
                Fan app
              </p>
            </article>
            <article className="rounded-[24px] border border-white/10 bg-white/5 p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-300">
                Ranking
              </p>
              <p className="mt-3 font-display text-2xl font-bold uppercase leading-none text-white">
                Live tables
              </p>
            </article>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              href={`/fantasy/${featuredCompetition.slug}`}
              prefetch={false}
              className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
            >
              {featuredCompetition.ctaLabel ?? "View competition"} <ArrowRight size={18} />
            </Link>
            <Link
              href="/fantasy"
              prefetch={false}
              className="inline-flex min-h-11 items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
            >
              All fantasy competitions <Globe2 size={18} />
            </Link>
          </div>
        </div>
      </article>

      <article className="glass-panel rounded-[36px] p-6">
        <div className="flex items-end justify-between gap-4">
          <SectionHeading
            eyebrow="Competition slate"
            title="Published competitions"
            description="Only competitions that have been enabled for this club appear here."
          />
          <Link
            href="/fantasy"
            prefetch={false}
            className="hidden rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/8 sm:inline-flex"
          >
            View all
          </Link>
        </div>
        <div className="mt-6 grid gap-3">
          {competitions.map((competition) => (
            <Link
              key={competition.id}
              href={`/fantasy/${competition.slug}`}
              prefetch={false}
              className="group rounded-[24px] border border-border-soft bg-white/5 p-4 transition hover:bg-white/8"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    {competition.badgeLabel ? (
                      <span className="rounded-full bg-club-accent/15 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-[0.18em] text-club-accent">
                        {competition.badgeLabel}
                      </span>
                    ) : null}
                    <span className="rounded-full border border-white/10 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-[0.18em] text-slate-300">
                      {competition.countryCode ?? "Global"}
                    </span>
                  </div>
                  <p className="mt-3 font-display text-2xl font-bold uppercase leading-none text-white">
                    {competition.name}
                  </p>
                  <p className="mt-2 line-clamp-2 text-sm leading-7 text-slate-300">
                    {competition.description}
                  </p>
                </div>
                <div className="shrink-0 rounded-full border border-white/10 bg-white/5 p-3 text-slate-300 transition group-hover:text-white">
                  <Trophy size={18} />
                </div>
              </div>
              <div className="mt-4 flex flex-wrap gap-2">
                <span className="rounded-full border border-white/10 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  {competition.season}
                </span>
                <span className="rounded-full border border-white/10 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  {competition.mode === "tournament" ? "Tournament" : "Season long"}
                </span>
                <span className="rounded-full border border-white/10 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  {statusLabel(competition.status, competition.isPlayable)}
                </span>
              </div>
            </Link>
          ))}
        </div>
      </article>
    </section>
  );
}
