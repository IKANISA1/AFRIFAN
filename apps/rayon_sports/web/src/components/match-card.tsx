import Link from "next/link";
import { ArrowRight, Radio, Ticket, Trophy } from "lucide-react";
import type { MatchItem } from "@/lib/types";
import {
  formatCurrency,
  formatDateTime,
  formatMatchStatusLabel,
  isLiveMatch,
  isResultMatch,
} from "@/lib/utils";

interface MatchCardProps {
  match: MatchItem;
  href?: string;
}

export function MatchCard({
  match,
  href = `/fixtures/${match.id}`,
}: MatchCardProps) {
  const live = isLiveMatch(match.matchStatus);
  const result = isResultMatch(match.matchStatus);
  const ctaLabel = live ? "Follow live" : result ? "Match report" : "View tickets";

  return (
    <Link
      href={href}
      prefetch={false}
      className="glass-panel card-interactive flex h-full flex-col gap-5 rounded-[30px] border border-border-soft p-5"
    >
      <div className="flex items-center justify-between gap-3">
        {live ? (
          <span className="badge-live">Live</span>
        ) : (
          <span className="rounded-full bg-club-accent/15 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-club-accent">
            {formatMatchStatusLabel(match.matchStatus)}
          </span>
        )}
        <span className="text-[11px] uppercase tracking-[0.24em] text-slate-300">
          {match.competition}
        </span>
      </div>

      <div className="grid gap-4 rounded-[26px] border border-white/8 bg-black/20 p-4">
        <div className="flex items-center justify-between gap-4">
          <div className="min-w-0">
            <p className="font-display text-3xl font-bold uppercase leading-none text-white">
              {match.homeTeam}
            </p>
            <p className="mt-3 font-display text-3xl font-bold uppercase leading-none text-white">
              {match.awayTeam}
            </p>
          </div>
          <div className="rounded-[22px] border border-white/8 bg-white/6 px-4 py-3 text-center">
            {(live || result) ? (
              <>
                <p className="font-score text-5xl font-bold uppercase text-white">
                  {match.homeScore}
                </p>
                <p className="my-1 text-[11px] uppercase tracking-[0.24em] text-slate-500">
                  -
                </p>
                <p className="font-score text-5xl font-bold uppercase text-white">
                  {match.awayScore}
                </p>
              </>
            ) : (
              <>
                <p className="text-[10px] uppercase tracking-[0.22em] text-slate-300">
                  From
                </p>
                <p className="mt-2 font-score text-4xl font-bold uppercase text-white">
                  {formatCurrency(match.generalPrice)}
                </p>
              </>
            )}
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <span className="rounded-full border border-white/8 bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-300">
            {formatDateTime(match.matchDate)}
          </span>
          <span className="rounded-full border border-white/8 bg-white/5 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-slate-300">
            {match.venue}
          </span>
          {live && match.liveMinute != null ? (
            <span className="rounded-full border border-red-400/30 bg-red-500/10 px-3 py-1.5 text-[11px] uppercase tracking-[0.22em] text-red-200">
              {match.liveMinute}&rsquo;
            </span>
          ) : null}
        </div>
      </div>

      <p className="text-sm leading-7 text-slate-300">
        {match.matchSummary ?? "Match details will appear here closer to kickoff."}
      </p>

      {(live || result) && match.liveEvents.length > 0 ? (
        <div className="grid gap-2">
          {match.liveEvents.slice(0, 2).map((event) => (
            <div
              key={`${event.minute}-${event.event}`}
              className="rounded-[20px] border border-white/8 bg-white/4 px-3 py-3 text-sm text-slate-200"
            >
              <span className="mr-2 font-semibold text-club-accent">{event.minute}</span>
              {event.event}
            </div>
          ))}
        </div>
      ) : (
        <div className="flex flex-wrap gap-2 text-[11px] uppercase tracking-[0.22em] text-slate-300">
          <span className="rounded-full border border-border-soft px-3 py-1.5">
            General {formatCurrency(match.generalPrice)}
          </span>
          <span className="rounded-full border border-border-soft px-3 py-1.5">
            VIP {formatCurrency(match.vipPrice)}
          </span>
        </div>
      )}

      <div className="mt-auto flex items-center justify-between gap-3 border-t border-white/8 pt-4">
        <div className="flex items-center gap-2 text-sm font-semibold text-white">
          {live ? <Radio size={16} className="text-red-300" /> : result ? <Trophy size={16} className="text-club-accent" /> : <Ticket size={16} className="text-club-accent" />}
          {ctaLabel}
        </div>
        <ArrowRight size={18} className="text-slate-300" />
      </div>
    </Link>
  );
}
