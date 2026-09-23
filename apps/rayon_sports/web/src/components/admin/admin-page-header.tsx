import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminPageHeaderProps {
  eyebrow?: string;
  title: string;
  meta?: ReactNode;
  actions?: ReactNode;
  className?: string;
}

export function AdminPageHeader({
  eyebrow,
  title,
  meta,
  actions,
  className,
}: AdminPageHeaderProps) {
  return (
    <header className={cn("admin-page-header", className)}>
      <div className="relative space-y-3">
        {eyebrow ? <p className="admin-page-eyebrow">{eyebrow}</p> : null}
        <div className="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div className="space-y-3">
            <h1 className="admin-page-title">{title}</h1>
            {meta ? <div className="flex flex-wrap items-center gap-2">{meta}</div> : null}
          </div>
          {actions ? (
            <div className="flex flex-wrap items-center gap-2">{actions}</div>
          ) : null}
        </div>
      </div>
    </header>
  );
}

