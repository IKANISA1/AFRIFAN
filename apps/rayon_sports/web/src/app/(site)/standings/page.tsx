import Link from "next/link";
import { ArrowRight, Trophy } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getStandings } from "@/lib/data/public";

export default async function StandingsPage() {
  const standings = await getStandings();
  const highlighted = standings.find((row) => row.highlight) ?? standings[0] ?? null;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow="League table"
        title="Standings that show the race, not just a cropped snippet."
        description="The table should be useful in its own right: enough rows to provide context, clear highlighting for Rayon Sports, and quick form signals that make momentum visible."
        actions={
          <>
            <Link
              href="/fixtures"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              Fixture hub
            </Link>
            <Link
              href="/results"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              Recent results
            </Link>
          </>
        }
        stats={[
          { label: "Clubs shown", value: standings.length.toString() },
          { label: "Rayon position", value: highlighted ? `#${highlighted.position}` : "-" },
          { label: "Points", value: highlighted ? highlighted.points.toString() : "-" },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="glass-panel overflow-hidden rounded-[32px] border border-border-soft">
          <table className="w-full text-left text-sm">
            <thead className="bg-white/8 text-xs uppercase tracking-[0.24em] text-slate-400">
              <tr>
                <th className="px-4 py-4 text-center">Pos</th>
                <th className="px-4 py-4">Club</th>
                <th className="px-4 py-4 text-center">Played</th>
                <th className="px-4 py-4 text-center">GD</th>
                <th className="px-4 py-4 text-center">Points</th>
                <th className="px-4 py-4">Form</th>
              </tr>
            </thead>
            <tbody>
              {standings.map((row) => (
                <tr
                  key={`${row.position}-${row.club}`}
                  className={row.highlight ? "bg-club-primary/15" : "border-t border-white/6"}
                >
                  <td className="px-4 py-4 text-center font-mono text-xs text-slate-400">
                    {row.position}
                  </td>
                  <td className="px-4 py-4 font-semibold text-white">{row.club}</td>
                  <td className="px-4 py-4 text-center">{row.played}</td>
                  <td className="px-4 py-4 text-center">{row.goalDifference}</td>
                  <td className="px-4 py-4 text-center font-semibold text-white">
                    {row.points}
                  </td>
                  <td className="px-4 py-4">
                    <div className="flex flex-wrap gap-1.5">
                      {(row.form ?? []).map((entry, index) => (
                        <span
                          key={`${row.club}-${index}-${entry}`}
                          className={`flex h-7 w-7 items-center justify-center rounded-full text-[10px] font-bold uppercase ${
                            entry === "W"
                              ? "bg-emerald-500/18 text-emerald-300"
                              : entry === "L"
                                ? "bg-rose-500/18 text-rose-300"
                                : "bg-white/8 text-slate-200"
                          }`}
                        >
                          {entry}
                        </span>
                      ))}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="glass-panel rounded-[34px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Table reading
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold uppercase text-white">
            Position needs context
          </h2>
          {highlighted ? (
            <div className="mt-5 rounded-[26px] border border-border-soft bg-white/5 p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-slate-400">
                Highlighted club
              </p>
              <p className="mt-3 font-display text-4xl font-bold uppercase text-white">
                {highlighted.club}
              </p>
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    Position
                  </p>
                  <p className="mt-2 font-score text-4xl text-white">#{highlighted.position}</p>
                </div>
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    Points
                  </p>
                  <p className="mt-2 font-score text-4xl text-white">{highlighted.points}</p>
                </div>
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-400">
                    GD
                  </p>
                  <p className="mt-2 font-score text-4xl text-white">{highlighted.goalDifference}</p>
                </div>
              </div>
            </div>
          ) : null}
          <div className="mt-5 grid gap-4">
            {[
              "Show enough surrounding clubs so the position actually means something.",
              "Highlight Rayon Sports consistently across every table view.",
              "Use form indicators to make momentum visible without forcing a click into results.",
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
            href="/results"
            className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-club-ink transition hover:brightness-110"
          >
            Recent scorelines <Trophy size={18} />
          </Link>
          <Link
            href="/fixtures"
            className="mt-3 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            Upcoming matches <ArrowRight size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
