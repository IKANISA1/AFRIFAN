import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminSurfaceProps {
  title?: string;
  description?: string;
  actions?: ReactNode;
  toolbar?: ReactNode;
  children: ReactNode;
  className?: string;
  contentClassName?: string;
  flush?: boolean;
}

export function AdminSurface({
  title,
  description,
  actions,
  toolbar,
  children,
  className,
  contentClassName,
  flush = false,
}: AdminSurfaceProps) {
  const hasHeader = title != null || description != null || actions != null;

  return (
    <section className={cn("admin-surface relative overflow-hidden rounded-[30px]", className)}>
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(108,99,255,0.08),transparent_32%)]" />
      {hasHeader ? (
        <div className="admin-surface-header relative">
          <div className="space-y-1">
            {title ? <h2 className="admin-surface-title">{title}</h2> : null}
            {description ? (
              <p className="admin-surface-copy">{description}</p>
            ) : null}
          </div>
          {actions ? (
            <div className="flex flex-wrap items-center gap-2">{actions}</div>
          ) : null}
        </div>
      ) : null}
      {toolbar ? <div className="admin-toolbar relative">{toolbar}</div> : null}
      <div className={cn("relative", flush ? "" : "p-5 sm:p-6", contentClassName)}>
        {children}
      </div>
    </section>
  );
}
