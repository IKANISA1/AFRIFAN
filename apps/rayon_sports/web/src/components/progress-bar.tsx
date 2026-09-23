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
          <p className="text-xs font-semibold normal-case tracking-normal text-foreground">
            {label}
          </p>
        ) : (
          <span />
        )}
        <span className="text-xs font-semibold normal-case tracking-normal text-warning">
          {formatPercent(percent, compact ? 0 : 1)}
        </span>
      </div>
      <div
        className={`progress-track ${compact ? "h-2" : "h-3"}`}
        role="progressbar"
        aria-valuenow={Math.round(percent)}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label ? `${label}: ${formatPercent(percent, compact ? 0 : 1)}` : `${formatPercent(percent, compact ? 0 : 1)} complete`}
      >
        <div className="progress-fill" style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}
