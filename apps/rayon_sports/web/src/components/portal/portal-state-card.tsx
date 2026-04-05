import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function PortalStateCard({
  label,
  value,
  helper,
  badge,
  compact = false,
  className,
  valueClassName,
  helperClassName,
}: {
  label: string;
  value: string;
  helper: ReactNode;
  badge?: ReactNode;
  /** Compact chip mode for mobile density */
  compact?: boolean;
  className?: string;
  valueClassName?: string;
  helperClassName?: string;
}) {
  if (compact) {
    return (
      <article
        className={cn(
          "glass-panel flex items-center justify-between gap-3 rounded-2xl px-4 py-3",
          className,
        )}
      >
        <div className="flex items-center gap-3 min-w-0">
          <p className="font-mono text-[10px] uppercase tracking-[0.22em] text-club-accent shrink-0">
            {label}
          </p>
          {badge ? <div className="shrink-0">{badge}</div> : null}
        </div>
        <p
          className={cn(
            "font-display text-xl font-bold uppercase leading-none text-white shrink-0",
            valueClassName,
          )}
        >
          {value}
        </p>
      </article>
    );
  }

  return (
    <article className={cn("glass-panel rounded-[28px] p-5", className)}>
      <div className="flex items-start justify-between gap-3">
        <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
          {label}
        </p>
        {badge ? <div>{badge}</div> : null}
      </div>
      <p
        className={cn(
          "mt-4 font-display text-4xl font-bold uppercase leading-none",
          valueClassName,
        )}
      >
        {value}
      </p>
      <div className={cn("mt-3 text-sm leading-6 text-slate-300", helperClassName)}>
        {helper}
      </div>
    </article>
  );
}
