import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function PortalStateCard({
  label,
  value,
  helper,
  badge,
  className,
  valueClassName,
  helperClassName,
}: {
  label: string;
  value: string;
  helper: ReactNode;
  badge?: ReactNode;
  className?: string;
  valueClassName?: string;
  helperClassName?: string;
}) {
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
