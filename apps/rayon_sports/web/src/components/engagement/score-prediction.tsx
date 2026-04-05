"use client";

import { useState, useCallback } from "react";
import { cn } from "@/lib/utils";

interface ScorePredictionProps {
  homeTeam: string;
  awayTeam: string;
  matchId: string;
  /** Whether prediction is locked (match started) */
  locked?: boolean;
  /** Previously submitted prediction */
  existingPrediction?: { home: number; away: number } | null;
  /** Callback when prediction is submitted */
  onSubmit?: (matchId: string, home: number, away: number) => Promise<void>;
}

/**
 * "Guess the Score" prediction widget.
 * Touch-friendly +/- buttons for each team.
 * Glass-panel styled, locks after submission or kickoff.
 */
export function ScorePrediction({
  homeTeam,
  awayTeam,
  matchId,
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

  return (
    <div className="rounded-[28px] border border-border-soft bg-black/20 p-4 sm:p-5">
      <div className="flex items-center justify-between gap-3">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
          Guess the score
        </p>
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

      <div className="mt-4 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
        {/* Home team */}
        <div className="text-center">
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

      {/* FAT reward hint */}
      <p className="mt-3 text-center text-[10px] uppercase tracking-[0.22em] text-slate-500">
        {submitted
          ? "Exact match = 50 FAT · Correct result = 20 FAT"
          : "Earn FAT for correct predictions"}
      </p>
    </div>
  );
}
