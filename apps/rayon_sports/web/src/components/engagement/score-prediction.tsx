"use client";

import { useState, useCallback } from "react";
import { cn } from "@/lib/utils";

interface ScorePredictionProps {
  homeTeam: string;
  awayTeam: string;
  matchId: string;
  /** Optional team logo URLs from the active football data source */
  homeTeamLogoUrl?: string | null;
  awayTeamLogoUrl?: string | null;
  /** Competition name */
  competitionName?: string;
  /** Kickoff time ISO string */
  kickoffAt?: string | null;
  /** 1X2 multipliers from the prediction engine */
  multipliers?: { home: number; draw: number; away: number } | null;
  /** Whether prediction is locked (match started) */
  locked?: boolean;
  /** Previously submitted prediction */
  existingPrediction?: { home: number; away: number } | null;
  /** Callback when prediction is submitted */
  onSubmit?: (matchId: string, home: number, away: number) => Promise<void>;
}

/**
 * "Guess the Score" prediction widget with live multipliers.
 * Touch-friendly +/- buttons for each team.
 * Glass-panel styled, locks after submission or kickoff.
 * Shows FET multipliers for 1X2 market when available.
 */
export function ScorePrediction({
  homeTeam,
  awayTeam,
  matchId,
  homeTeamLogoUrl,
  awayTeamLogoUrl,
  competitionName,
  kickoffAt,
  multipliers,
  locked = false,
  existingPrediction = null,
  onSubmit,
}: ScorePredictionProps) {
  const [homeScore, setHomeScore] = useState(existingPrediction?.home ?? 0);
  const [awayScore, setAwayScore] = useState(existingPrediction?.away ?? 0);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(!!existingPrediction);

  const isLocked = locked || submitted;

  const handleSubmit = useCallback(async () => {
    if (isLocked || !onSubmit) return;
    setIsSubmitting(true);
    try {
      await onSubmit(matchId, homeScore, awayScore);
      setSubmitted(true);
    } catch {
      // Error handled by parent
    } finally {
      setIsSubmitting(false);
    }
  }, [isLocked, onSubmit, matchId, homeScore, awayScore]);

  function formatKickoff(iso: string) {
    try {
      return new Intl.DateTimeFormat("en-US", {
        weekday: "short", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
      }).format(new Date(iso));
    } catch { return iso; }
  }

  return (
    <div className="rounded-[28px] border border-border-soft bg-black/20 p-4 sm:p-5">
      {/* Header */}
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
            Guess the score
          </p>
          {competitionName && (
            <p className="text-[10px] text-slate-500 mt-0.5">{competitionName}</p>
          )}
        </div>
        {submitted && (
          <span className="rounded-full bg-emerald-500/15 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-emerald-300">
            Locked in ✓
          </span>
        )}
        {locked && !submitted && (
          <span className="rounded-full bg-red-500/15 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-red-300">
            Closed
          </span>
        )}
      </div>

      {/* Kickoff time */}
      {kickoffAt && (
        <p className="mt-2 text-[11px] text-slate-400">{formatKickoff(kickoffAt)}</p>
      )}

      {/* Score selector */}
      <div className="mt-4 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
        {/* Home team */}
        <div className="text-center">
          {homeTeamLogoUrl && (
            <div className="mx-auto mb-2 h-10 w-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={homeTeamLogoUrl} alt={homeTeam} className="h-7 w-7 object-contain" loading="lazy" />
            </div>
          )}
          <p className="font-display text-lg font-bold uppercase leading-tight text-white sm:text-xl">
            {homeTeam}
          </p>
          <div className="mt-3 flex items-center justify-center gap-2">
            <button
              type="button"
              disabled={isLocked || homeScore === 0}
              onClick={() => setHomeScore((p) => Math.max(0, p - 1))}
              className="flex h-10 w-10 items-center justify-center rounded-full border border-white/12 bg-white/6 text-lg font-bold text-white transition hover:bg-white/12 disabled:opacity-30 disabled:cursor-not-allowed"
              aria-label={`Decrease ${homeTeam} score`}
            >
              −
            </button>
            <span className="font-score text-4xl font-bold text-white min-w-[3ch] text-center">
              {homeScore}
            </span>
            <button
              type="button"
              disabled={isLocked || homeScore >= 15}
              onClick={() => setHomeScore((p) => Math.min(15, p + 1))}
              className="flex h-10 w-10 items-center justify-center rounded-full border border-white/12 bg-white/6 text-lg font-bold text-white transition hover:bg-white/12 disabled:opacity-30 disabled:cursor-not-allowed"
              aria-label={`Increase ${homeTeam} score`}
            >
              +
            </button>
          </div>
        </div>

        {/* VS divider */}
        <div className="flex h-12 w-12 items-center justify-center rounded-full border border-white/8 bg-white/5">
          <span className="text-xs font-bold uppercase text-slate-400">VS</span>
        </div>

        {/* Away team */}
        <div className="text-center">
          {awayTeamLogoUrl && (
            <div className="mx-auto mb-2 h-10 w-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={awayTeamLogoUrl} alt={awayTeam} className="h-7 w-7 object-contain" loading="lazy" />
            </div>
          )}
          <p className="font-display text-lg font-bold uppercase leading-tight text-white/70 sm:text-xl">
            {awayTeam}
          </p>
          <div className="mt-3 flex items-center justify-center gap-2">
            <button
              type="button"
              disabled={isLocked || awayScore === 0}
              onClick={() => setAwayScore((p) => Math.max(0, p - 1))}
              className="flex h-10 w-10 items-center justify-center rounded-full border border-white/12 bg-white/6 text-lg font-bold text-white transition hover:bg-white/12 disabled:opacity-30 disabled:cursor-not-allowed"
              aria-label={`Decrease ${awayTeam} score`}
            >
              −
            </button>
            <span className="font-score text-4xl font-bold text-white min-w-[3ch] text-center">
              {awayScore}
            </span>
            <button
              type="button"
              disabled={isLocked || awayScore >= 15}
              onClick={() => setAwayScore((p) => Math.min(15, p + 1))}
              className="flex h-10 w-10 items-center justify-center rounded-full border border-white/12 bg-white/6 text-lg font-bold text-white transition hover:bg-white/12 disabled:opacity-30 disabled:cursor-not-allowed"
              aria-label={`Increase ${awayTeam} score`}
            >
              +
            </button>
          </div>
        </div>
      </div>

      {/* 1X2 Multiplier Chips */}
      {multipliers && (
        <div className="mt-4 grid grid-cols-3 gap-2">
          <MultiplierChip label="1" sublabel={homeTeam} value={multipliers.home} />
          <MultiplierChip label="X" sublabel="Draw" value={multipliers.draw} />
          <MultiplierChip label="2" sublabel={awayTeam} value={multipliers.away} />
        </div>
      )}

      {/* Submit button */}
      {!isLocked && (
        <button
          type="button"
          disabled={isSubmitting}
          onClick={handleSubmit}
          className={cn(
            "mt-5 w-full rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition",
            isSubmitting
              ? "opacity-60 cursor-not-allowed"
              : "hover:bg-club-primary-light cta-glow",
          )}
        >
          {isSubmitting ? "Submitting…" : "Lock in prediction"}
        </button>
      )}

      {/* FET reward hint */}
      <p className="mt-3 text-center text-[10px] uppercase tracking-[0.22em] text-slate-500">
        {submitted
          ? "Exact match = 50 pts · Correct result = 20 pts"
          : "Earn points for correct picks"}
      </p>
    </div>
  );
}

/**
 * A single 1X2 multiplier chip showing the outcome label and FET multiplier value.
 */
function MultiplierChip({
  label,
  sublabel,
  value,
}: {
  label: string;
  sublabel: string;
  value: number;
}) {
  return (
    <div className="group rounded-2xl border border-white/8 bg-white/5 px-3 py-3 text-center transition hover:bg-white/8 hover:border-white/15">
      <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-slate-400 group-hover:text-slate-300">
        {label}
      </p>
      <p className="mt-1 font-display text-lg font-bold text-white transition-colors group-hover:text-club-accent">
        {value.toFixed(2)}x
      </p>
      <p className="mt-0.5 text-[9px] uppercase tracking-wider text-slate-500 truncate">
        {sublabel}
      </p>
    </div>
  );
}
