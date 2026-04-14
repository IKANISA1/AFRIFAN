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
    <article className={`${ui.panel} ${ui.cardInteractive} group rounded-[28px] border-[1.2px] p-5 sm:p-6`}>
      <div className="flex items-start justify-between gap-3">
        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
          {label}
        </p>
        {Icon ? (
          <div className={`${ui.iconButton} h-10 w-10 text-slate-400 group-hover:text-slate-100`}>
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
          <div className="mt-5 flex items-end gap-3">
            <p className="font-display text-[2.25rem] font-bold leading-none tracking-[-0.055em] text-white sm:text-[2.7rem]">
              {value}
            </p>
            {trend && trendLabel ? (
              <span
                className={cn(
                  "mb-1 flex items-center gap-1 rounded-full border px-2 py-1 text-[10px] font-semibold uppercase tracking-[0.16em]",
                  trend === "up" && "border-emerald-500/30 bg-emerald-500/10 text-emerald-300",
                  trend === "down" && "border-rose-500/30 bg-rose-500/10 text-rose-300",
                  trend === "neutral" && "border-border-soft bg-white/5 text-slate-400",
                )}
              >
                {trend === "up" ? "↑" : trend === "down" ? "↓" : "–"} {trendLabel}
              </span>
            ) : null}
          </div>
          {helper ? (
            <p className="mt-3 text-sm leading-6 text-slate-400">{helper}</p>
          ) : null}
        </>
      )}
    </article>
  );
}
