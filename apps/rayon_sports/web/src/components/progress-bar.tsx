import { formatPercent, getProgressPercent } from "@/lib/utils";

interface ProgressBarProps {
  value: number;
  max: number;
  label?: string;
  compact?: boolean;
}

export function ProgressBar({
  value,
  max,
  label,
  compact = false,
}: ProgressBarProps) {
  const percent = getProgressPercent(value, max);

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        {label ? (
          <p className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-300">
            {label}
          </p>
        ) : (
          <span />
        )}
        <span className="text-xs font-semibold uppercase tracking-[0.22em] text-club-accent">
          {formatPercent(percent, compact ? 0 : 1)}
        </span>
      </div>
      <div className={`progress-track ${compact ? "h-2" : "h-3"}`}>
        <div className="progress-fill" style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}
