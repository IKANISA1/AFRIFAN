interface MatchProgressBarProps {
  /** Current match minute (0–90+) */
  minute: number;
  /** Total expected minutes, defaults to 90 */
  total?: number;
  className?: string;
}

/**
 * Thin horizontal progress bar showing live match minute.
 * Uses club gradient with a glowing dot marker.
 */
export function MatchProgressBar({
  minute,
  total = 90,
  className,
}: MatchProgressBarProps) {
  const pct = Math.min((minute / total) * 100, 100);

  return (
    <div
      className={className ?? "mt-3"}
      role="progressbar"
      aria-valuenow={minute}
      aria-valuemin={0}
      aria-valuemax={total}
      aria-label={`Match minute ${minute}`}
    >
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-[9px] uppercase tracking-[0.22em] text-slate-500">
          0&rsquo;
        </span>
        <span className="font-score text-xs font-bold text-red-300">
          {minute}&rsquo;
        </span>
        <span className="text-[9px] uppercase tracking-[0.22em] text-slate-500">
          90&rsquo;
        </span>
      </div>
      <div className="relative h-1.5 overflow-hidden rounded-full bg-white/8">
        <div
          className="absolute inset-y-0 left-0 rounded-full bg-gradient-to-r from-club-accent via-club-primary-light to-club-primary transition-[width] duration-1000 ease-out"
          style={{ width: `${pct}%` }}
        />
        {/* Glowing dot at current position */}
        <div
          className="absolute top-1/2 -translate-y-1/2 h-3 w-3 rounded-full bg-red-400 shadow-[0_0_8px_rgba(239,68,68,0.6)] transition-[left] duration-1000 ease-out"
          style={{ left: `calc(${pct}% - 6px)` }}
        />
      </div>
    </div>
  );
}
