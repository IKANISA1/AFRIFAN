import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { ui } from "@/ui-kit";

interface AdminStateCardProps {
  label: string;
  value: string;
  helper?: ReactNode;
  icon?: LucideIcon;
  tone?: "success" | "warning" | "danger" | "info" | "neutral" | "accent";
  trend?: "up" | "down" | "neutral";
  trendLabel?: string;
}

export function AdminStateCard({
  label,
  value,
  helper,
  icon: Icon,
  tone = "neutral",
  trend,
  trendLabel,
}: AdminStateCardProps) {
  const isLoading = value === "..." || value === "";
  const toneClass =
    tone === "success"
      ? "border-success/20"
      : tone === "warning"
        ? "border-warning/20"
        : tone === "danger"
          ? "border-error/20"
          : tone === "info"
            ? "border-accent/20"
            : tone === "accent"
              ? "border-[var(--action-neutral)]/25"
              : "";

  return (
    <article className={`${ui.panel} ${ui.cardInteractive} ${toneClass} group rounded-[28px] border-[1.2px] p-5 sm:p-6`}>
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs font-semibold normal-case tracking-normal text-[var(--admin-text-muted)]">
          {label}
        </p>
        {Icon ? (
          <div className={`${ui.iconButton} h-10 w-10 text-[var(--admin-text-muted)] group-hover:text-[var(--admin-text-strong)]`}>
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
            <p className="font-display text-[2.25rem] font-medium leading-none tracking-[-0.055em] text-[var(--admin-text-strong)] sm:text-[2.7rem]">
              {value}
            </p>
            {trend && trendLabel ? (
              <span
                className={cn(
                  "mb-1 flex items-center gap-1 rounded-full border px-2 py-1 text-xs font-semibold normal-case tracking-normal",
                  trend === "up" && "border-success/30 bg-success/10 text-success",
                  trend === "down" && "border-error/30 bg-error/10 text-error",
                  trend === "neutral" && "border-border-soft bg-[var(--admin-surface-muted)] text-[var(--admin-text-muted)]",
                )}
              >
                {trend === "up" ? "↑" : trend === "down" ? "↓" : "–"} {trendLabel}
              </span>
            ) : null}
          </div>
          {helper ? (
            <p className="mt-3 text-sm leading-6 text-[var(--admin-text-muted)]">{helper}</p>
          ) : null}
        </>
      )}
    </article>
  );
}
