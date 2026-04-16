import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface KPISummaryRibbonProps {
  children: ReactNode;
  className?: string;
}

export function KPISummaryRibbon({ children, className }: KPISummaryRibbonProps) {
  return (
    <div className={cn("flex flex-wrap items-center gap-px border border-[var(--admin-border)] bg-[var(--admin-border)] overflow-hidden rounded-lg", className)}>
      {children}
    </div>
  );
}

interface KPITileProps {
  label: string;
  value: string;
  className?: string;
  trend?: "up" | "down" | "neutral";
  trendLabel?: string;
}

export function KPITile({ label, value, className, trend, trendLabel }: KPITileProps) {
  return (
    <div className={cn("flex-1 min-w-[160px] bg-[var(--admin-zinc-900)] p-4 sm:p-5", className)}>
      <p className="text-[10px] font-bold uppercase tracking-[0.1em] text-[var(--admin-zinc-500)] mb-2">
        {label}
      </p>
      <div className="flex items-baseline gap-2">
        <p className="text-xl font-bold text-[var(--admin-text-strong)]">
          {value}
        </p>
        {trend && trendLabel ? (
          <span className={cn(
            "text-[10px] font-bold",
            trend === "up" && "text-emerald-500",
            trend === "down" && "text-rose-500",
            trend === "neutral" && "text-[var(--admin-zinc-500)]"
          )}>
            {trend === "up" ? "↑" : trend === "down" ? "↓" : ""} {trendLabel}
          </span>
        ) : null}
      </div>
    </div>
  );
}
