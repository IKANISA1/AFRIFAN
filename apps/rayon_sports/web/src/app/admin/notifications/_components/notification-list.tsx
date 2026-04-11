import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import type { AdminNotificationContext, AdminNotificationRecord } from "@/lib/types";

function notificationTone(status: string) {
  switch (status) {
    case "sent":
    case "delivered":
      return "success" as const;
    case "scheduled":
    case "pending":
      return "warning" as const;
    case "failed":
      return "danger" as const;
    default:
      return "neutral" as const;
  }
}

function audienceLabel(item: AdminNotificationRecord) {
  if (item.audienceType === "all_fans") return "All fans";
  if (item.audienceType === "by_tier") return `Tier · ${item.audienceTier}`;
  return item.audienceGroupName ?? "Group";
}

export function NotificationList({
  context,
  loading,
  onRefresh,
}: {
  context: AdminNotificationContext;
  loading: boolean;
  onRefresh: () => void;
}) {
  return (
    <AdminSurface
      title="Delivery queue"
      description="Recent sends, schedules, and failure visibility."
      actions={
        <button
          type="button"
          onClick={onRefresh}
          className="admin-action-button"
        >
          Refresh
        </button>
      }
      flush
    >
      {loading ? (
        <div className="space-y-3 p-5 sm:p-6">
          {Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="rounded-[20px] border border-border-soft bg-white/5 p-4">
              <Skeleton className="skeleton-text h-5 w-2/5" />
              <Skeleton className="skeleton-text mt-2 h-3 w-full" />
              <div className="mt-4 grid gap-3 sm:grid-cols-4">
                {Array.from({ length: 4 }).map((_, cellIndex) => (
                  <Skeleton key={cellIndex} className="h-10 rounded-xl" />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : context.history.length === 0 ? (
        <AdminEmptyState
          title="No notifications recorded"
          description="Campaign deliveries and schedules will appear here after the first send."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Message</th>
                <th>Audience</th>
                <th>Delivery</th>
                <th>Status</th>
                <th>Sent</th>
                <th>Failures</th>
              </tr>
            </thead>
            <tbody>
              {context.history.map((item) => {
                const total = Math.max(item.sentCount + item.failedCount, item.requestedRecipientCount);

                return (
                  <tr key={item.id}>
                    <td>
                      <p className="admin-row-title">{item.title}</p>
                      <p className="admin-row-copy">{item.body}</p>
                      {item.lastError ? (
                        <div className="mt-2">
                          <AdminStatusBadge label="Last error" tone="danger" />
                          <p className="admin-row-meta mt-2">{item.lastError}</p>
                        </div>
                      ) : null}
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">{audienceLabel(item)}</p>
                      <p className="admin-row-meta">{item.audienceType.replaceAll("_", " ")}</p>
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">
                        {item.deliveryMode === "schedule" ? "Scheduled" : "Immediate"}
                      </p>
                      <p className="admin-row-meta">
                        {new Date(item.scheduledAt ?? item.sentAt ?? item.createdAt).toLocaleString("en-US", {
                          month: "short",
                          day: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </p>
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={item.status}
                        tone={notificationTone(item.status)}
                      />
                    </td>
                    <td className="min-w-[180px]">
                      <p className="text-sm font-medium text-white">
                        {item.sentCount} / {total}
                      </p>
                      {total > 0 ? (
                        <div className="mt-2">
                          <ProgressBar value={item.sentCount} max={total} compact />
                        </div>
                      ) : null}
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">{item.failedCount}</p>
                      <p className="admin-row-meta">
                        {item.failedCount > 0 ? "needs review" : "clear"}
                      </p>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </AdminSurface>
  );
}
