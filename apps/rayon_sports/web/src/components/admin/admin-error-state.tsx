import { AlertTriangle } from "lucide-react";
import { cn } from "@/lib/utils";

interface AdminErrorStateProps {
  title: string;
  description?: string;
  onRetry?: () => void;
  retryLabel?: string;
  className?: string;
}

export function AdminErrorState({
  title,
  description,
  onRetry,
  retryLabel = "Retry",
  className,
}: AdminErrorStateProps) {
  return (
    <div
      className={cn(
        "admin-empty-state rounded-[28px] border border-error/30 bg-error/10",
        className,
      )}
    >
      <div className="flex h-11 w-11 items-center justify-center rounded-full border border-error/40 bg-error/10 text-[var(--admin-danger-text)]">
        <AlertTriangle size={18} />
      </div>
      <p className="admin-empty-title mt-4 text-[var(--admin-danger-text)]">
        {title}
      </p>
      {description ? (
        <p className="admin-empty-copy text-[var(--admin-text)]">
          {description}
        </p>
      ) : null}
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="mt-4 min-h-12 rounded-full border border-error/50 px-5 py-3 text-sm font-semibold text-[var(--admin-danger-text)] transition hover:bg-error/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--admin-danger)] motion-reduce:transition-none"
        >
          {retryLabel}
        </button>
      ) : null}
    </div>
  );
}
