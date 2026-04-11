import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight, Globe2, Medal, Smartphone } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import {
  getFantasyCompetitionBySlug,
  getFantasyLeaderboard,
} from "@/lib/data/public";
import { resolveFanAppHref } from "@/lib/config";
import { buildPageMetadata } from "@/lib/metadata";

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

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const competition = await getFantasyCompetitionBySlug(slug);
  if (competition == null) {
    return buildPageMetadata({
      title: "Fantasy competition",
      description: "Official fantasy football competition hub.",
      path: `/fantasy/${slug}`,
    });
  }

  return buildPageMetadata({
    title: competition.name,
    description: competition.promoBody ?? competition.description,
    path: `/fantasy/${competition.slug}`,
  });
}

export default async function FantasyCompetitionDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const competition = await getFantasyCompetitionBySlug(slug);

  if (competition == null) {
    notFound();
  }

  const leaderboard = await getFantasyLeaderboard(competition.slug, 8);

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="Fantasy competition"
        title={competition.name}
        description={competition.promoBody ?? competition.description}
        actions={
          <>
            <Link
              href={resolveFanAppHref()}
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Continue in fan app
            </Link>
            <Link
              href="/fantasy"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              All competitions
            </Link>
          </>
        }
        stats={[
          { label: "Season", value: competition.season },
          { label: "Mode", value: modeLabel(competition.mode) },
          {
            label: "Status",
            value: statusLabel(competition.status, competition.isPlayable),
          },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <article className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Competition brief
          </p>
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-400">
                Country scope
              </p>
              <p className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white">
                {competition.countryCode ?? "Global"}
              </p>
            </div>
            <div className="rounded-[24px] border border-border-soft bg-white/5 p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-400">
                Provider
              </p>
              <p className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white">
                {competition.provider ?? "In setup"}
              </p>
            </div>
          </div>
          <div className="mt-6 grid gap-4">
            {[
              {
                title: "Public view",
                body:
                  "This page shows the published competition brief, schedule context, and any public leaderboard data available for supporters.",
              },
              {
                title: "Where to play",
                body:
                  "Authenticated gameplay such as entry creation, squad management, transfers, and chips continues in the fan app.",
              },
              {
                title: "Data integrity",
                body:
                  "Leaderboard rows only appear here when real competition data has been published for this competition.",
              },
            ].map((item) => (
              <div
                key={item.title}
                className="rounded-[24px] border border-border-soft bg-white/5 p-4"
              >
                <p className="font-display text-2xl font-bold uppercase leading-none text-white">
                  {item.title}
                </p>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  {item.body}
                </p>
              </div>
            ))}
          </div>
        </article>

        <aside className="grid gap-6">
          <article className="glass-panel rounded-[34px] p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                  Top managers
                </p>
                <p className="mt-2 text-sm text-slate-300">
                  Public leaderboard snapshot for this competition.
                </p>
              </div>
              <Medal className="text-club-accent" size={20} />
            </div>
            {leaderboard.length === 0 ? (
              <div className="mt-6 rounded-[24px] border border-border-soft bg-white/5 p-4 text-sm leading-7 text-slate-300">
                No public leaderboard is available for this competition yet.
              </div>
            ) : (
              <div className="mt-6 grid gap-3">
                {leaderboard.map((entry) => (
                  <div
                    key={`${entry.rank}-${entry.teamName}`}
                    className="rounded-[24px] border border-border-soft bg-white/5 p-4"
                  >
                    <div className="flex items-center justify-between gap-3">
                      <p className="font-display text-2xl font-bold uppercase leading-none text-white">
                        #{entry.rank}
                      </p>
                      <p className="font-score text-2xl font-bold uppercase text-white">
                        {entry.points}
                      </p>
                    </div>
                    <p className="mt-3 font-semibold text-white">{entry.teamName}</p>
                    <p className="mt-1 text-xs uppercase tracking-[0.22em] text-slate-400">
                      {entry.managerName}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </article>

          <article className="glass-panel rounded-[34px] p-6">
            <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
              Continue
            </p>
            <div className="mt-5 grid gap-3">
              <Link
                href={resolveFanAppHref()}
                className="flex items-center justify-between rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm font-semibold text-white transition hover:bg-white/8"
              >
                Open in fan app <Smartphone size={18} />
              </Link>
              <Link
                href="/fantasy"
                className="flex items-center justify-between rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm font-semibold text-white transition hover:bg-white/8"
              >
                Browse other competitions <Globe2 size={18} />
              </Link>
              <Link
                href="/"
                className="flex items-center justify-between rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm font-semibold text-white transition hover:bg-white/8"
              >
                Return to homepage <ArrowRight size={18} />
              </Link>
            </div>
          </article>
        </aside>
      </section>
    </div>
  );
}
