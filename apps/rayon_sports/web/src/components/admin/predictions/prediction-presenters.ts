import type { AdminResourceStatus } from "@/lib/admin-resource-state";

export type PredictionTab = "markets" | "partnerPools" | "fixtures" | "competitions" | "seasons";

export const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading prediction operations",
    detail: "Waiting for the first authenticated, bounded workspace snapshot.",
  },
  ready: {
    label: "Prediction workspace confirmed",
    detail:
      "Templates, football sources, partners, and club pools are current.",
  },
  empty: {
    label: "No prediction records in this scope",
    detail:
      "No catalog or historical pool records are available.",
  },
  error: {
    label: "Prediction workspace unavailable",
    detail:
      "Confirmed records remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Prediction workspace is offline",
    detail: "Confirmed records remain visible; all changes are locked.",
  },
  permission_denied: {
    label: "Prediction access denied",
    detail:
      "Records, filters, selection, fixture details, and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing prediction operations",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Prediction data changed",
    detail: "Review the refreshed source before restarting the change.",
  },
  security_timeout: {
    label: "Prediction request timed out",
    detail:
      "No operation was confirmed. Retry from the latest retained snapshot.",
  },
};

export function formatKickoff(iso: string) {
  try {
    return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }).format(new Date(iso));
  } catch { return iso; }
}

export function statusTone(status: string) {
  switch (status) {
    case "completed":
    case "finished":
      return "success" as const;
    case "live":
    case "in_progress":
      return "accent" as const;
    case "postponed":
    case "cancelled":
      return "warning" as const;
    default:
      return "neutral" as const;
  }
}

