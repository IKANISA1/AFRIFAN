import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Radio, Ticket, Trophy } from "lucide-react";
import { MatchCountdown } from "@/components/match-countdown";
import { MatchProgressBar } from "@/components/match-progress-bar";
import type { MatchItem } from "@/lib/types";
import {
  cn,
  formatCurrency,
  formatDateTime,
  formatMatchStatusLabel,
  isLiveMatch,
  isResultMatch,
  isUpcomingMatch,
} from "@/lib/utils";

interface MatchCardProps {
  match: MatchItem;
  href?: string;
  clubName?: string;
  clubLogoUrl?: string | null;
}

function TeamBadge({
  name,
  clubName,
  clubLogoUrl,
  variant = "neutral",
}: {
  name: string;
  clubName?: string;
  clubLogoUrl?: string | null;
  variant?: "home" | "neutral";
}) {
  const normalizedName = name.trim().toLowerCase();
  const normalizedClubName = clubName?.trim().toLowerCase() ?? "";
  const isClubTeam =
    normalizedClubName.length > 0 &&
    (normalizedName === normalizedClubName ||
      normalizedName.includes(normalizedClubName) ||
      normalizedClubName.includes(normalizedName));

  if (isClubTeam && clubLogoUrl) {
    return (
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-club-primary/20 p-1" aria-hidden="true">
        <Image
          src={clubLogoUrl}
          alt={`${clubName ?? name} crest`}
          width={28}
          height={28}
          className="object-contain"
        />
      </div>
    );
  }

  return (
    <div
      className={cn(
        "flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-bold",
        variant === "home"
          ? "bg-club-primary/30 text-white"
          : "bg-white/10 text-slate-300",
      )}
      aria-hidden="true"
    >
      {name.charAt(0)}
    </div>
  );
}

export function MatchCard({
  match,
  href = `/fixtures/${match.id}`,
  clubName,
  clubLogoUrl,
}: MatchCardProps) {
  const live = isLiveMatch(match.matchStatus);
  const result = isResultMatch(match.matchStatus);
  const upcoming = isUpcomingMatch(match.matchStatus);
  const ctaLabel = live ? "Follow live" : result ? "Match report" : "View tickets";

  // Status-specific card treatment
  const borderClass = live
    ? "border-red-500/30 shadow-[0_0_32px_rgba(239,68,68,0.12)] ring-1 ring-red-500/10"
    : upcoming
      ? "border-club-accent/25 shadow-[0_0_24px_rgba(212,160,23,0.08)]"
      : result
        ? "border-white/6 opacity-85"
        : "border-border-soft";

  return (
    <Link
      href={href}
      prefetch={false}
      className={cn(
        "glass-panel card-interactive flex h-full flex-col gap-4 rounded-[30px] border p-5",
        borderClass,
        upcoming && "kit-stripe",
      )}
    >
      {/* Status + competition */}
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

      {/* Teams + score panel */}
      <div className="grid gap-3 rounded-[26px] border border-white/8 bg-black/20 p-4">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <TeamBadge
              name={match.homeTeam}
              clubName={clubName}
              clubLogoUrl={clubLogoUrl}
              variant="home"
            />
            <div className="min-w-0">
              <p className="font-display text-2xl font-bold uppercase leading-none text-white sm:text-3xl">
                {match.homeTeam}
              </p>
            </div>
          </div>
          {/* Score or price */}
          <div className="rounded-[18px] border border-white/8 bg-white/6 px-3 py-2 text-center shrink-0">
            {(live || result) ? (
              <p className="font-score text-3xl font-bold uppercase text-white sm:text-4xl">
                {match.homeScore}
              </p>
            ) : (
              <>
                <p className="text-[9px] uppercase tracking-[0.22em] text-slate-400">From</p>
                <p className="font-score text-2xl font-bold uppercase text-white sm:text-3xl">
                  {formatCurrency(match.generalPrice)}
                </p>
              </>
            )}
          </div>
        </div>

        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <TeamBadge
              name={match.awayTeam}
              clubName={clubName}
              clubLogoUrl={clubLogoUrl}
              variant="neutral"
            />
            <div className="min-w-0">
              <p className="font-display text-2xl font-bold uppercase leading-none text-white/70 sm:text-3xl">
                {match.awayTeam}
              </p>
            </div>
          </div>
          {(live || result) ? (
            <div className="rounded-[18px] border border-white/8 bg-white/6 px-3 py-2 text-center shrink-0">
              <p className="font-score text-3xl font-bold uppercase text-white sm:text-4xl">
                {match.awayScore}
              </p>
            </div>
          ) : null}
        </div>

        {/* Countdown for upcoming / Progress for live */}
        {live && match.liveMinute != null ? (
          <MatchProgressBar minute={match.liveMinute} />
        ) : upcoming ? (
          <div className="flex items-center gap-2 pt-1">
            <span className="text-[10px] uppercase tracking-[0.22em] text-slate-400">Kickoff in</span>
            <MatchCountdown matchDate={match.matchDate} />
          </div>
        ) : null}

        {/* Meta pills */}
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

      {/* Summary */}
      <p className="text-sm leading-7 text-slate-300">
        {match.matchSummary ?? "Match details will appear here closer to kickoff."}
      </p>

      {/* Live events */}
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
      ) : !live && !result ? (
        <div className="flex flex-wrap gap-2 text-[11px] uppercase tracking-[0.22em] text-slate-300">
          <span className="rounded-full border border-border-soft px-3 py-1.5">
            General {formatCurrency(match.generalPrice)}
          </span>
          <span className="rounded-full border border-border-soft px-3 py-1.5">
            VIP {formatCurrency(match.vipPrice)}
          </span>
        </div>
      ) : null}

      {/* CTA footer */}
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
