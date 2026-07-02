"use client";

import { useState, useCallback } from "react";
import { cn } from "@/lib/utils";

interface PollOption {
  id: string;
  label: string;
  votes?: number;
}

interface MatchPollProps {
  pollId: string;
  question: string;
  options: PollOption[];
  /** Whether poll is open for voting */
  open?: boolean;
  /** Previously selected option ID */
  existingVote?: string | null;
  onVote?: (pollId: string, optionId: string) => Promise<void>;
}

/**
 * Quick poll widget for matchday engagement.
 * Shows a question with radio-style options.
 * After voting, reveals vote distribution with animated bars.
 */
export function MatchPoll({
  pollId,
  question,
  options,
  open = true,
  existingVote = null,
  onVote,
}: MatchPollProps) {
  const [selectedId, setSelectedId] = useState<string | null>(existingVote);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [voted, setVoted] = useState(!!existingVote);
  const [showResults, setShowResults] = useState(!!existingVote);

  const totalVotes = options.reduce((sum, opt) => sum + (opt.votes ?? 0), 0);

  const isLocked = !open || voted;

  const handleVote = useCallback(async () => {
    if (isLocked || !selectedId || !onVote) return;
    setIsSubmitting(true);
    try {
      await onVote(pollId, selectedId);
      setVoted(true);
      setShowResults(true);
    } catch {
      // Error handled by parent
    } finally {
      setIsSubmitting(false);
    }
  }, [isLocked, selectedId, onVote, pollId]);

  return (
    <div className="rounded-[28px] border border-border-soft bg-black/20 p-4 sm:p-5">
      <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
        Quick poll
      </p>
      <p className="mt-2 font-display text-xl font-bold uppercase leading-tight text-white sm:text-2xl">
        {question}
      </p>

      <div className="mt-4 grid gap-2">
        {options.map((option) => {
          const pct = totalVotes > 0 ? Math.round(((option.votes ?? 0) / totalVotes) * 100) : 0;
          const isSelected = selectedId === option.id;

          return (
            <button
              key={option.id}
              type="button"
              disabled={isLocked && !isSelected}
              onClick={() => !isLocked && setSelectedId(option.id)}
              className={cn(
                "relative overflow-hidden rounded-2xl border p-3 text-left transition",
                isSelected
                  ? "border-club-accent/40 bg-club-accent/8"
                  : "border-white/8 bg-white/4 hover:bg-white/8",
                isLocked && !isSelected && "opacity-50",
              )}
            >
              {/* Result bar (shown after voting) */}
              {showResults && (
                <div
                  className="absolute inset-y-0 left-0 bg-club-primary/15 transition-all duration-700 ease-out"
                  style={{ width: `${pct}%` }}
                />
              )}
              <div className="relative flex items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  {/* Radio indicator */}
                  <div
                    className={cn(
                      "flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 transition",
                      isSelected
                        ? "border-club-accent bg-club-accent"
                        : "border-white/25 bg-transparent",
                    )}
                  >
                    {isSelected && (
                      <div className="h-2 w-2 rounded-full bg-slate-950" />
                    )}
                  </div>
                  <span className="text-sm font-medium text-white">
                    {option.label}
                  </span>
                </div>
                {showResults && (
                  <span className="text-sm font-bold tabular-nums text-white">
                    {pct}%
                  </span>
                )}
              </div>
            </button>
          );
        })}
      </div>

      {/* Submit */}
      {!isLocked && selectedId && (
        <button
          type="button"
          disabled={isSubmitting}
          onClick={handleVote}
          className={cn(
            "mt-4 w-full rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition",
            isSubmitting
              ? "opacity-60 cursor-not-allowed"
              : "hover:bg-club-primary-light cta-glow",
          )}
        >
          {isSubmitting ? "Voting…" : "Submit vote"}
        </button>
      )}

      <p className="mt-3 text-center text-[10px] uppercase tracking-[0.22em] text-slate-500">
        {voted
          ? `${totalVotes.toLocaleString()} total votes · 5 points earned`
          : `${totalVotes.toLocaleString()} votes · Vote to earn 5 points`}
      </p>
    </div>
  );
}
