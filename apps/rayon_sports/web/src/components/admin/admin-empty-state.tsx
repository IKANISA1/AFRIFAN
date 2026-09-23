import { cn } from "@/lib/utils";

interface AdminEmptyStateProps {
  title: string;
  description?: string;
  className?: string;
}

export function AdminEmptyState({
  title,
  description,
  className,
}: AdminEmptyStateProps) {
  return (
    <div
      className={cn(
        "admin-empty-state rounded-[26px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)]",
        className,
      )}
    >
      <p className="admin-empty-title">{title}</p>
      {description ? (
        <p className="admin-empty-copy">{description}</p>
      ) : null}
    </div>
  );
}
