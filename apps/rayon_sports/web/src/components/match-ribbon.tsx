import Link from "next/link";
import { Calendar } from "lucide-react";
import type { MatchItem } from "@/lib/types";
import { formatDateTime, isLiveMatch } from "@/lib/utils";

interface MatchRibbonProps {
  match: MatchItem | null;
}

export function MatchRibbon({ match }: MatchRibbonProps) {
  if (!match) return null;

  const live = isLiveMatch(match.matchStatus);

  if (live) {
    return (
      <div
        className="relative z-[65] overflow-hidden border-b border-white/10 bg-gradient-to-r from-club-primary via-club-primary-light to-club-secondary text-white"
        style={{ minHeight: "var(--ribbon-height)" }}
      >
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(90deg,transparent_0%,rgba(255,255,255,0.18)_50%,transparent_100%)] opacity-40 [background-size:200%_100%] animate-[shimmer_3s_linear_infinite]" />
        <div className="page-shell relative flex min-h-[var(--ribbon-height)] flex-wrap items-center justify-center gap-x-3 gap-y-2 py-2 text-center sm:justify-between">
          <div className="flex flex-wrap items-center justify-center gap-2 sm:justify-start">
            <span className="badge-live border-none bg-black/20 px-2.5 py-1 text-[10px] text-white">
              Live
            </span>
            <span className="text-xs font-semibold uppercase tracking-[0.22em] sm:text-sm">
              {match.homeTeam}
            </span>
            <span className="font-score text-2xl font-bold uppercase sm:text-3xl">
              {match.homeScore} - {match.awayScore}
            </span>
            <span className="text-xs font-semibold uppercase tracking-[0.22em] sm:text-sm">
              {match.awayTeam}
            </span>
            {match.liveMinute != null ? (
              <span className="rounded-full border border-white/10 bg-black/15 px-2.5 py-1 text-[10px] uppercase tracking-[0.22em] text-white/85">
                {match.liveMinute}&rsquo;
              </span>
            ) : null}
          </div>
          <Link
            href={`/fixtures/${match.id}`}
            prefetch={false}
            className="rounded-full border border-white/14 bg-black/15 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] transition hover:bg-black/25"
          >
            Follow live
          </Link>
        </div>
      </div>
    );
  }

  // Non-live: show next fixture ribbon (subtle, minimal)
  return (
    <div
      className="relative z-[65] border-b border-border-soft bg-surface-strong/90 backdrop-blur-sm"
      style={{ minHeight: "var(--ribbon-height)" }}
    >
      <div className="page-shell flex min-h-[var(--ribbon-height)] flex-wrap items-center justify-center gap-x-3 gap-y-1 py-1.5 text-center sm:justify-between">
        <div className="flex flex-wrap items-center justify-center gap-2 sm:justify-start">
          <Calendar size={14} className="text-club-secondary" />
          <span className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-300">
            Next
          </span>
          <span className="text-[11px] font-semibold uppercase tracking-[0.18em] text-white">
            {match.homeTeam} vs {match.awayTeam}
          </span>
          <span className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
            {formatDateTime(match.matchDate)}
          </span>
        </div>
        <Link
          href={`/fixtures/${match.id}`}
          prefetch={false}
          className="rounded-full border border-border-soft bg-white/5 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-slate-200 transition hover:bg-white/10"
        >
          Details
        </Link>
      </div>
    </div>
  );
}
