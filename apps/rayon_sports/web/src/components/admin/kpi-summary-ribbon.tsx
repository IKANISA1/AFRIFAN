import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
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
  icon?: LucideIcon;
  tone?: "success" | "warning" | "danger" | "info" | "neutral" | "accent";
  trend?: "up" | "down" | "neutral";
  trendLabel?: string;
}

export function KPITile({
  label,
  value,
  className,
  icon: Icon,
  tone = "neutral",
  trend,
  trendLabel,
}: KPITileProps) {
  const toneClass =
    tone === "success"
      ? "border-t border-success/30"
      : tone === "warning"
        ? "border-t border-warning/30"
        : tone === "danger"
          ? "border-t border-error/30"
          : tone === "info"
            ? "border-t border-accent/30"
            : tone === "accent"
              ? "border-t border-[var(--action-neutral)]/40"
              : "";

  return (
    <div className={cn("flex-1 min-w-[160px] bg-[var(--admin-zinc-900)] p-4 sm:p-5", toneClass, className)}>
      <div className="mb-2 flex items-center justify-between gap-2">
        <p className="text-xs font-medium normal-case tracking-normal text-[var(--admin-zinc-500)]">
          {label}
        </p>
        {Icon ? <Icon size={14} className="text-[var(--admin-zinc-500)]" /> : null}
      </div>
      <div className="flex items-baseline gap-2">
        <p className="text-xl font-medium text-[var(--admin-text-strong)]">
          {value}
        </p>
        {trend && trendLabel ? (
          <span className={cn(
            "text-xs font-medium",
            trend === "up" && "text-success",
            trend === "down" && "text-error",
            trend === "neutral" && "text-[var(--admin-zinc-500)]"
          )}>
            {trend === "up" ? "↑" : trend === "down" ? "↓" : ""} {trendLabel}
          </span>
        ) : null}
      </div>
    </div>
  );
}
