import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { MatchCard } from "@/components/match-card";
import { SectionHeading } from "@/components/section-heading";
import { getClubProfile, getMatches } from "@/lib/data/public";

export async function FixturesBlock() {
  const [club, matches] = await Promise.all([getClubProfile(), getMatches()]);
  const featuredMatch =
    matches.find((m) => m.matchStatus === "live") ??
    matches.find((m) => m.isFeatured) ??
    null;
  const upcomingMatches = matches.filter((m) => m.id !== featuredMatch?.id);

  return (
    <section className="page-shell section-grid">
      <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <SectionHeading
          eyebrow="Fixtures"
          title="Matchday schedule."
        />
        <Link
          href="/fixtures"
          prefetch={false}
          className="inline-flex items-center gap-2 rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8"
        >
          Full fixtures <ArrowRight size={18} />
        </Link>
      </div>
      <div className="flex gap-5 scroll-snap-x lg:grid lg:grid-cols-3 lg:overflow-visible">
        {upcomingMatches.slice(0, 3).map((match) => (
          <div key={match.id} className="min-w-[85vw] sm:min-w-[340px] lg:min-w-0">
            <MatchCard
              match={match}
              clubName={club.shortName}
              clubLogoUrl={club.officialLogoUrl}
            />
          </div>
        ))}
      </div>
    </section>
  );
}
