"use client";

import { useState, useCallback } from "react";
import { cn } from "@/lib/utils";

interface MotmCandidate {
  id: string;
  name: string;
  position: string;
  number?: number;
}

interface MotmVotingProps {
  matchId: string;
  candidates: MotmCandidate[];
  /** Whether voting is open */
  open?: boolean;
  /** Previously voted player ID */
  existingVote?: string | null;
  /** Callback when vote is submitted */
  onVote?: (matchId: string, playerId: string) => Promise<void>;
}

/**
 * Man of the Match voting widget.
 * Displays player cards in a compact grid.
 * Single-selection, locks after vote.
 */
export function MotmVoting({
  matchId,
  candidates,
  open = true,
  existingVote = null,
  onVote,
}: MotmVotingProps) {
  const [selectedId, setSelectedId] = useState<string | null>(existingVote);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [voted, setVoted] = useState(!!existingVote);

  const isLocked = !open || voted;

  const handleVote = useCallback(async () => {
    if (isLocked || !selectedId || !onVote) return;
    setIsSubmitting(true);
    try {
      await onVote(matchId, selectedId);
      setVoted(true);
    } catch {
      // Error handled by parent
    } finally {
      setIsSubmitting(false);
    }
  }, [isLocked, selectedId, onVote, matchId]);

  return (
    <div className="rounded-[28px] border border-border-soft bg-black/20 p-4 sm:p-5">
      <div className="flex items-center justify-between gap-3">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
          Man of the Match
        </p>
        {voted && (
          <span className="rounded-full bg-club-accent/15 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
            Voted ✓
          </span>
        )}
        {!open && !voted && (
          <span className="rounded-full bg-white/8 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-slate-400">
            Closed
          </span>
        )}
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4">
        {candidates.map((player) => (
          <button
            key={player.id}
            type="button"
            disabled={isLocked && selectedId !== player.id}
            onClick={() => !isLocked && setSelectedId(player.id)}
            className={cn(
              "flex flex-col items-center gap-1.5 rounded-2xl border p-3 text-center transition",
              selectedId === player.id
                ? "border-club-accent/50 bg-club-accent/10 shadow-[0_0_16px_rgba(212,160,23,0.12)]"
                : "border-white/8 bg-white/4 hover:bg-white/8",
              isLocked && selectedId !== player.id && "opacity-40",
            )}
          >
            {/* Player number circle */}
            <div
              className={cn(
                "flex h-10 w-10 items-center justify-center rounded-full text-sm font-bold",
                selectedId === player.id
                  ? "bg-club-accent/25 text-club-accent"
                  : "bg-white/10 text-white",
              )}
            >
              {player.number ?? player.name.charAt(0)}
            </div>
            <p className="text-xs font-semibold text-white leading-tight">
              {player.name}
            </p>
            <p className="text-[9px] uppercase tracking-[0.18em] text-slate-400">
              {player.position}
            </p>
          </button>
        ))}
      </div>

      {/* Submit button */}
      {!isLocked && selectedId && (
        <button
          type="button"
          disabled={isSubmitting}
          onClick={handleVote}
          className={cn(
            "mt-4 w-full rounded-full bg-club-accent px-5 py-3 text-sm font-semibold text-slate-950 transition",
            isSubmitting
              ? "opacity-60 cursor-not-allowed"
              : "hover:brightness-110",
          )}
        >
          {isSubmitting ? "Voting…" : "Cast your vote"}
        </button>
      )}

      {/* FET reward */}
      <p className="mt-3 text-center text-[10px] uppercase tracking-[0.22em] text-slate-500">
        {voted ? "10 FET earned for voting" : "Vote to earn 10 FET"}
      </p>
    </div>
  );
}
