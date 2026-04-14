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
    <div className={cn("admin-empty-state rounded-[28px] border border-rose-400/20 bg-rose-500/10", className)}>
      <div className="flex h-11 w-11 items-center justify-center rounded-full border border-rose-400/30 bg-rose-500/10 text-rose-200">
        <AlertTriangle size={18} />
      </div>
      <p className="admin-empty-title mt-4 text-rose-100">{title}</p>
      {description ? (
        <p className="admin-empty-copy text-rose-100/80">{description}</p>
      ) : null}
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="mt-4 rounded-full border border-rose-400/30 px-4 py-2 text-sm font-semibold text-rose-100 transition hover:bg-rose-500/10"
        >
          {retryLabel}
        </button>
      ) : null}
    </div>
  );
}
