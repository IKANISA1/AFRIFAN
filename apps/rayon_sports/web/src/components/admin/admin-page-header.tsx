import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminPageHeaderProps {
  eyebrow?: string;
  title: string;
  description?: string;
  meta?: ReactNode;
  actions?: ReactNode;
  className?: string;
}

export function AdminPageHeader({
  eyebrow,
  title,
  description,
  meta,
  actions,
  className,
}: AdminPageHeaderProps) {
  return (
    <header className={cn("relative overflow-hidden rounded-[32px] border border-[var(--admin-border)] bg-[linear-gradient(180deg,rgba(40,34,86,0.7),rgba(18,13,48,0.88))] px-5 py-5 shadow-[0_20px_60px_-34px_rgba(5,4,16,0.96)] sm:px-6 sm:py-6", className)}>
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(108,99,255,0.18),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(196,192,255,0.12),transparent_36%)]" />
      <div className="relative space-y-3">
        {eyebrow ? <p className="admin-page-eyebrow">{eyebrow}</p> : null}
        <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <div className="space-y-3">
            <h1 className="admin-page-title">{title}</h1>
            {description ? <p className="admin-page-copy">{description}</p> : null}
            {meta ? <div className="flex flex-wrap gap-2">{meta}</div> : null}
          </div>
          {actions ? (
            <div className="flex flex-wrap items-center gap-2">{actions}</div>
          ) : null}
        </div>
      </div>
    </header>
  );
}
