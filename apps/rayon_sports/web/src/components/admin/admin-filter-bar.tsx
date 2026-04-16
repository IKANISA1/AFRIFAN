import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminFilterBarProps {
  children: ReactNode;
  className?: string;
  actions?: ReactNode;
}

export function AdminFilterBar({
  children,
  className,
  actions,
}: AdminFilterBarProps) {
  return (
    <div className={cn("admin-toolbar", className)}>
      <div className="flex flex-1 flex-wrap items-center gap-3">
        {children}
      </div>
      {actions ? (
        <div className="flex shrink-0 items-center gap-2">
          {actions}
        </div>
      ) : null}
    </div>
  );
}
