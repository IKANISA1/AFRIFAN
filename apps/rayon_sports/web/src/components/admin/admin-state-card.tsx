import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminStateCardProps {
  label: string;
  value: string;
  helper?: ReactNode;
  icon?: LucideIcon;
  trend?: "up" | "down" | "neutral";
  trendLabel?: string;
}

export function AdminStateCard({
  label,
  value,
  icon: Icon,
  trend,
  trendLabel,
}: AdminStateCardProps) {
  const isLoading = value === "..." || value === "";

  return (
    <article className="glass-panel card-interactive rounded-[28px] p-5 group">
      <div className="flex items-start justify-between gap-3">
        <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
          {label}
        </p>
        {Icon ? (
          <div className="flex h-9 w-9 items-center justify-center rounded-full border border-border-soft bg-white/5 text-slate-400 transition group-hover:text-club-accent group-hover:border-club-accent/30">
            <Icon size={16} />
          </div>
        ) : null}
      </div>

      {isLoading ? (
        <div className="mt-4 space-y-2">
          <div className="skeleton h-9 w-24 rounded-xl" />
          <div className="skeleton-text h-3 w-32" />
        </div>
      ) : (
        <>
          <div className="mt-4 flex items-end gap-3">
            <p className="font-display text-4xl font-bold uppercase leading-none">
              {value}
            </p>
            {trend && trendLabel ? (
              <span
                className={cn(
                  "mb-1 flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em]",
                  trend === "up" && "bg-emerald-500/15 text-emerald-400",
                  trend === "down" && "bg-rose-500/15 text-rose-400",
                  trend === "neutral" && "bg-white/8 text-slate-400",
                )}
              >
                {trend === "up" ? "↑" : trend === "down" ? "↓" : "–"} {trendLabel}
              </span>
            ) : null}
          </div>
        </>
      )}
    </article>
  );
}
