import Link from "next/link";
import { ArrowRight, Trophy } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getStandings } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.standings.metaTitle(club),
    description: copy.pages.standings.metaDescription(club),
    path: "/standings",
  });
}

export default async function StandingsPage() {
  const [club, standings] = await Promise.all([
    getClubProfile(),
    getStandings(),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const highlighted = standings.find((row) => row.highlight) ?? standings[0] ?? null;

  return (
    <div className="page-shell section-grid py-12">
      <PageHero
        eyebrow={copy.pages.standings.eyebrow}
        title={copy.pages.standings.title}
        description={copy.pages.standings.description(club)}
        actions={
          <>
            <Link
              href="/fixtures"
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
            >
              {copy.common.fixtureHub}
            </Link>
            <Link
              href="/results"
              className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
            >
              {copy.common.recentResults}
            </Link>
          </>
        }
        stats={[
          { label: copy.common.clubsShown, value: standings.length.toString() },
          { label: copy.pages.standings.clubPosition(club), value: highlighted ? `#${highlighted.position}` : "-" },
          { label: copy.common.points, value: highlighted ? highlighted.points.toString() : "-" },
        ]}
      />

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="glass-panel overflow-hidden rounded-[32px]">
          <table className="w-full text-left text-sm">
            <thead className="bg-white/8 text-xs uppercase tracking-[0.24em] text-slate-300">
              <tr>
                <th className="px-3 py-4 text-center sm:px-4">{copy.common.position}</th>
                <th className="px-3 py-4 sm:px-4">{copy.common.club}</th>
                <th className="hidden px-4 py-4 text-center sm:table-cell">{copy.common.played}</th>
                <th className="hidden px-4 py-4 text-center sm:table-cell">{copy.common.goalDifference}</th>
                <th className="px-3 py-4 text-center sm:px-4">{copy.common.points}</th>
                <th className="hidden px-4 py-4 sm:table-cell">{copy.common.form}</th>
              </tr>
            </thead>
            <tbody>
              {standings.map((row) => (
                <tr
                  key={`${row.position}-${row.club}`}
                  className={row.highlight ? "bg-club-primary/15" : "border-t border-white/6"}
                >
                  <td className="px-3 py-3 text-center font-mono text-xs text-slate-300 sm:px-4 sm:py-4">
                    {row.position}
                  </td>
                  <td className="px-3 py-3 text-sm font-semibold text-white sm:px-4 sm:py-4">
                    {row.club}
                  </td>
                  <td className="hidden px-4 py-4 text-center sm:table-cell">{row.played}</td>
                  <td className="hidden px-4 py-4 text-center sm:table-cell">{row.goalDifference}</td>
                  <td className="px-3 py-3 text-center font-semibold text-white sm:px-4 sm:py-4">
                    {row.points}
                  </td>
                  <td className="hidden px-4 py-4 sm:table-cell">
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
            {club.shortName}
          </p>
          <h2 className="mt-3 font-display text-4xl font-bold text-white">
            {copy.pages.standings.positionInRace}
          </h2>
          {highlighted ? (
            <div className="mt-5 rounded-[26px] border border-border-soft bg-white/5 p-5">
              <p className="text-[11px] uppercase tracking-[0.22em] text-slate-300">
                {copy.pages.standings.highlightedClub}
              </p>
              <p className="mt-3 font-display text-4xl font-bold uppercase text-white">
                {highlighted.club}
              </p>
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.position}
                  </p>
                  <p className="mt-2 font-score text-4xl text-white">#{highlighted.position}</p>
                </div>
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.points}
                  </p>
                  <p className="mt-2 font-score text-4xl text-white">{highlighted.points}</p>
                </div>
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                    {copy.common.goalDifference}
                  </p>
                  <p className="mt-2 font-score text-4xl text-white">{highlighted.goalDifference}</p>
                </div>
              </div>
            </div>
          ) : null}
          <div className="mt-5 grid gap-4">
            {copy.pages.standings.summaryPoints.map((point) => (
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
            className="mt-6 inline-flex items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            {copy.common.recentScorelines} <Trophy size={18} />
          </Link>
          <Link
            href="/fixtures"
            className="mt-3 inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
          >
            {copy.common.upcomingMatches} <ArrowRight size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
