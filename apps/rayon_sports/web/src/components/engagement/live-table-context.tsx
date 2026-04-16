"use client";

import type { StandingRow } from "@/lib/types";
import { cn } from "@/lib/utils";

interface LiveTableContextProps {
  standings: StandingRow[];
  currentClub: string;
  className?: string;
}

export function LiveTableContext({ standings, currentClub, className }: LiveTableContextProps) {
  // Find current club's index and slice 2 above and 2 below
  const clubIndex = standings.findIndex(s => s.club === currentClub);
  const start = Math.max(0, clubIndex - 2);
  const end = Math.min(standings.length, clubIndex + 3);
  const relevantRows = standings.slice(start, end);

  return (
    <div className={cn("glass-panel rounded-[32px] p-6", className)}>
      <p className="font-mono text-xs uppercase tracking-[0.24em] text-[var(--club-accent)] mb-4">
        Live Standings
      </p>
      <div className="overflow-hidden rounded-2xl border border-white/5 bg-black/20">
        <table className="w-full text-left text-xs">
          <thead>
            <tr className="border-b border-white/5 bg-white/5 text-[9px] font-black uppercase tracking-widest text-white/40">
              <th className="px-4 py-3">Pos</th>
              <th className="px-4 py-3">Club</th>
              <th className="px-4 py-3 text-center">PL</th>
              <th className="px-4 py-3 text-right">PTS</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {relevantRows.map((row) => (
              <tr 
                key={row.club}
                className={cn(
                  "transition-colors",
                  row.club === currentClub ? "bg-[var(--club-primary)]/20 text-white" : "text-white/60"
                )}
              >
                <td className="px-4 py-3 font-mono font-bold">{row.position}</td>
                <td className="px-4 py-3 font-bold uppercase tracking-tight">
                  {row.club}
                  {row.club === currentClub && <span className="ml-2 text-[8px] text-[var(--club-accent)]">●</span>}
                </td>
                <td className="px-4 py-3 text-center">{row.played}</td>
                <td className="px-4 py-3 text-right font-mono font-black">{row.points}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-[10px] font-medium leading-relaxed text-white/40">
        Live table updates automatically based on the current match score.
      </p>
    </div>
  );
}
