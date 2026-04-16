import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminSurfaceProps {
  title?: string;
  actions?: ReactNode;
  toolbar?: ReactNode;
  children: ReactNode;
  className?: string;
  contentClassName?: string;
  flush?: boolean;
}

export function AdminSurface({
  title,
  actions,
  toolbar,
  children,
  className,
  contentClassName,
  flush = false,
}: AdminSurfaceProps) {
  const hasHeader = title != null || actions != null;

  return (
    <section className={cn("admin-surface", className)}>
      {hasHeader ? (
        <div className="admin-surface-header">
          {title ? <h2 className="admin-surface-title">{title}</h2> : <div />}
          {actions ? (
            <div className="flex flex-wrap items-center gap-2">{actions}</div>
          ) : null}
        </div>
      ) : null}
      {toolbar ? <div className="admin-toolbar">{toolbar}</div> : null}
      <div className={cn("relative", flush ? "" : "p-4 sm:p-5", contentClassName)}>
        {children}
      </div>
    </section>
  );
}

