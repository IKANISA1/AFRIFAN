import { cn } from "@/lib/utils";

type AdminStatusTone =
  | "neutral"
  | "accent"
  | "info"
  | "success"
  | "warning"
  | "danger";

const toneClassName: Record<AdminStatusTone, string> = {
  neutral: "admin-status-neutral",
  accent: "admin-status-accent",
  info: "admin-status-info",
  success: "admin-status-success",
  warning: "admin-status-warning",
  danger: "admin-status-danger",
};

interface AdminStatusBadgeProps {
  label: string;
  tone?: AdminStatusTone;
  pulse?: boolean;
  className?: string;
}

export function AdminStatusBadge({
  label,
  tone = "neutral",
  pulse = false,
  className,
}: AdminStatusBadgeProps) {
  return (
    <span className={cn("admin-status-badge", toneClassName[tone], className)}>
      {pulse ? <span className="admin-status-dot" aria-hidden="true" /> : null}
      {label}
    </span>
  );
}
