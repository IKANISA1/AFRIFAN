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
    <header className={cn("admin-page-header", className)}>
      <div className="space-y-2">
        {eyebrow ? <p className="admin-page-eyebrow">{eyebrow}</p> : null}
        <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <div className="space-y-2">
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
