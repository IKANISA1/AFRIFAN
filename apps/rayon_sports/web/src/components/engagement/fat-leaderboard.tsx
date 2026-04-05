"use client";

import { cn } from "@/lib/utils";

interface LeaderboardEntry {
  rank: number;
  name: string;
  fat: number;
  level: string;
  isCurrentUser?: boolean;
}

interface FatLeaderboardProps {
  entries: LeaderboardEntry[];
  currentUserRank?: number;
  currentUserName?: string;
  currentUserFat?: number;
  currentUserLevel?: string;
}

/**
 * FAT Leaderboard — top 10 fans ranked by Fan Achievement Tokens.
 * Shows a podium-style top 3, then a list for 4–10, plus the current
 * user's position if they're outside the top 10.
 */
export function FatLeaderboard({
  entries,
  currentUserRank,
  currentUserName,
  currentUserFat,
  currentUserLevel,
}: FatLeaderboardProps) {
  const top3 = entries.slice(0, 3);
  const rest = entries.slice(3);
  const showCurrentUser =
    currentUserRank && currentUserRank > 10 && currentUserName;

  return (
    <div className="grid gap-5">
      {/* Podium — top 3 */}
      <div className="glass-panel-elevated rounded-[34px] p-5 sm:p-6">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
          Fan leaderboard
        </p>
        <h3 className="mt-2 font-display text-2xl font-bold text-white sm:text-3xl">
          Top supporters
        </h3>

        <div className="mt-5 flex items-end justify-center gap-3">
          {/* 2nd place */}
          {top3[1] && (
            <PodiumCard entry={top3[1]} medal="🥈" height="h-24" />
          )}
          {/* 1st place */}
          {top3[0] && (
            <PodiumCard entry={top3[0]} medal="🥇" height="h-32" highlight />
          )}
          {/* 3rd place */}
          {top3[2] && (
            <PodiumCard entry={top3[2]} medal="🥉" height="h-20" />
          )}
        </div>
      </div>

      {/* Rest of top 10 */}
      {rest.length > 0 && (
        <div className="glass-panel rounded-[34px] p-5 sm:p-6">
          <div className="grid gap-2">
            {rest.map((entry) => (
              <div
                key={entry.rank}
                className={cn(
                  "flex items-center justify-between gap-3 rounded-2xl border px-4 py-3",
                  entry.isCurrentUser
                    ? "border-club-accent/30 bg-club-accent/8"
                    : "border-white/6 bg-white/4",
                )}
              >
                <div className="flex items-center gap-3">
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/8 font-mono text-xs font-bold text-slate-300">
                    {entry.rank}
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-white">
                      {entry.name}
                    </p>
                    <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400">
                      {entry.level}
                    </p>
                  </div>
                </div>
                <span className="shrink-0 rounded-full bg-club-accent/15 px-3 py-1 text-[11px] font-bold tabular-nums text-club-accent">
                  {entry.fat.toLocaleString()} FAT
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Current user position (if outside top 10) */}
      {showCurrentUser && (
        <div className="glass-panel rounded-[34px] p-5 sm:p-6">
          <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400">
            Your position
          </p>
          <div className="mt-3 flex items-center justify-between gap-3 rounded-2xl border border-club-accent/30 bg-club-accent/8 px-4 py-3">
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-club-accent/20 font-mono text-xs font-bold text-club-accent">
                {currentUserRank}
              </span>
              <div>
                <p className="text-sm font-semibold text-white">
                  {currentUserName}
                </p>
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-400">
                  {currentUserLevel}
                </p>
              </div>
            </div>
            <span className="shrink-0 rounded-full bg-club-accent/15 px-3 py-1 text-[11px] font-bold tabular-nums text-club-accent">
              {currentUserFat?.toLocaleString()} FAT
            </span>
          </div>
        </div>
      )}
    </div>
  );
}

function PodiumCard({
  entry,
  medal,
  height,
  highlight = false,
}: {
  entry: LeaderboardEntry;
  medal: string;
  height: string;
  highlight?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex w-28 flex-col items-center justify-end rounded-2xl border p-3 text-center sm:w-32",
        highlight
          ? "border-club-accent/30 bg-club-accent/8"
          : "border-white/8 bg-white/4",
        height,
      )}
    >
      <span className="text-2xl">{medal}</span>
      <p className="mt-1 truncate text-xs font-semibold text-white w-full">
        {entry.name}
      </p>
      <p className="mt-0.5 text-[9px] font-bold tabular-nums text-club-accent">
        {entry.fat.toLocaleString()} FAT
      </p>
    </div>
  );
}
