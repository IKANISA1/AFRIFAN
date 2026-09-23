
import { FixtureTeams, TeamCard } from "@/components/team-card";
import Link from "next/link";
import { Calendar } from "lucide-react";
import { ui } from "@/ui-kit";
import type { MatchItem } from "@/lib/types";
import type { SiteChromeCopy } from "@/lib/site-copy";
import { formatDateTime, isLiveMatch } from "@/lib/utils";

interface MatchRibbonProps {
  match: MatchItem | null;
  copy: SiteChromeCopy;
}

export function MatchRibbon({ match, copy }: MatchRibbonProps) {
  if (!match) return null;

  const live = isLiveMatch(match.matchStatus);

  if (live) {
    return (
      <div
        className={`relative z-[65] overflow-hidden text-white ${ui.ribbonLive}`}
        style={{ minHeight: "var(--ribbon-height)" }}
      >
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(90deg,transparent_0%,rgba(255,255,255,0.18)_50%,transparent_100%)] opacity-40 [background-size:200%_100%] animate-[shimmer_3s_linear_infinite]" />
        <div className="page-shell relative flex min-h-[var(--ribbon-height)] flex-wrap items-center justify-center gap-x-3 gap-y-2 py-2 text-center sm:justify-between">
          <div className="flex flex-wrap items-center justify-center gap-2 sm:justify-start">
            <span className="badge-live border-none bg-black/20 px-2.5 py-1 text-[10px] text-white">
              Live
            </span>
            <span className="text-xs font-semibold normal-case tracking-normal sm:text-sm">
              <TeamCard name={match.homeTeam} />
            </span>
            <span className="font-score text-2xl font-medium normal-case sm:text-3xl">
              {match.homeScore} - {match.awayScore}
            </span>
            <span className="text-xs font-semibold normal-case tracking-normal sm:text-sm">
              <TeamCard name={match.awayTeam} />
            </span>
            {match.liveMinute != null ? (
              <span className={`${ui.ribbonPill} rounded-full px-2.5 py-1 text-[10px] normal-case tracking-normal text-white/85`}>
                {match.liveMinute}&rsquo;
              </span>
            ) : null}
          </div>
          <Link
            href={`/fixtures/${match.id}`}
            prefetch={false}
            className={ui.ribbonAction}
          >
            {copy.followLive}
          </Link>
        </div>
      </div>
    );
  }

  // Non-live: show next fixture ribbon (subtle, minimal)
  return (
    <div
      className={`relative z-[65] ${ui.ribbonSubtle}`}
      style={{ minHeight: "var(--ribbon-height)" }}
    >
      <div className="page-shell flex min-h-[var(--ribbon-height)] flex-wrap items-center justify-center gap-x-3 gap-y-1 py-1.5 text-center sm:justify-between">
        <div className="flex flex-wrap items-center justify-center gap-2 sm:justify-start">
          <Calendar size={14} className="text-muted" />
          <span className="text-[11px] font-semibold normal-case tracking-normal text-muted">
            {copy.next}
          </span>
          <span className="text-[11px] font-semibold normal-case tracking-normal text-white">
            <FixtureTeams homeTeam={match.homeTeam} awayTeam={match.awayTeam} />
          </span>
          <span className="text-[11px] normal-case tracking-normal text-muted">
            {formatDateTime(match.matchDate)}
          </span>
        </div>
        <Link
          href={`/fixtures/${match.id}`}
          prefetch={false}
          className={`${ui.ribbonAction} px-3 py-1 text-[10px] text-foreground`}
        >
          {copy.details}
        </Link>
      </div>
    </div>
  );
}
