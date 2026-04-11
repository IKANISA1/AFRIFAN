import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { ui } from "@/design-system";

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
  helper,
  icon: Icon,
  trend,
  trendLabel,
}: AdminStateCardProps) {
  const isLoading = value === "..." || value === "";

  return (
    <article className={`${ui.panel} ${ui.cardInteractive} group rounded-[28px] p-5`}>
      <div className="flex items-start justify-between gap-3">
        <p className={ui.kicker}>
          {label}
        </p>
        {Icon ? (
          <div className={`${ui.iconButton} h-9 w-9 text-slate-400 group-hover:text-club-accent`}>
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
            <p className="font-display text-4xl font-bold uppercase leading-none tracking-[-0.05em]">
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
          {helper ? (
            <p className="mt-2 text-sm leading-5 text-slate-400">{helper}</p>
          ) : null}
        </>
      )}
    </article>
  );
}
