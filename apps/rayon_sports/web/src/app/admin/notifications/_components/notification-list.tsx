"use client";

import { Search } from "lucide-react";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import type { AdminNotificationContext, AdminNotificationRecord } from "@/lib/types";
import type { AdminResourceInteraction } from "@/components/admin/admin-resource-status-banner";
import { useAdminCollection } from "@/lib/use-admin-collection";

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
  disabled = false,
  onInteractionChange,
}: {
  context: AdminNotificationContext;
  loading: boolean;
  onRefresh: () => void;
  disabled?: boolean;
  onInteractionChange?: (interaction: AdminResourceInteraction) => void;
}) {
  const notificationCollection = useAdminCollection({
    records: context.history,
    getId: (item) => item.id,
    getSearchValues: (item) => [
      item.title,
      item.body,
      item.audienceType,
      audienceLabel(item),
      item.deliveryMode,
      item.status,
      item.lastError,
    ],
    getSortValue: (
      item,
      key: "message" | "audience" | "delivery" | "status" | "sent" | "failures",
    ) => {
      switch (key) {
        case "message": return item.title;
        case "audience": return audienceLabel(item);
        case "delivery": return new Date(item.scheduledAt ?? item.sentAt ?? item.createdAt);
        case "status": return item.status;
        case "sent": return item.sentCount;
        case "failures": return item.failedCount;
      }
    },
    initialSortKey: "delivery" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  return (
    <AdminSurface
      title="Delivery queue"
      actions={
        <button
          type="button"
          onClick={onRefresh}
          disabled={disabled}
          onFocus={() => onInteractionChange?.("focused")}
          onBlur={() => onInteractionChange?.("idle")}
          className="admin-action-button"
        >
          Refresh
        </button>
      }
      toolbar={
        <AdminFilterBar><label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search notification delivery queue</span><input type="search" value={notificationCollection.query} onChange={(event) => notificationCollection.setQuery(event.target.value)} placeholder="Search message, audience, delivery, or status" disabled={disabled} /></label></AdminFilterBar>
      }
      flush
    >
      {loading ? (
        <div className="space-y-3 p-5 sm:p-6">
          {Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="rounded-[20px] border border-border-soft bg-[var(--admin-surface-muted)] p-4">
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
      ) : (
        <>
          <AdminDataGrid
            caption="Notification delivery queue"
            columns={[
              { key: "message", label: "Message", priority: "primary", sortable: true, sortDirection: notificationCollection.sortDirectionFor("message"), onSort: () => notificationCollection.toggleSort("message") },
              { key: "audience", label: "Audience", priority: "primary", sortable: true, sortDirection: notificationCollection.sortDirectionFor("audience"), onSort: () => notificationCollection.toggleSort("audience") },
              { key: "delivery", label: "Delivery", priority: "secondary", sortable: true, sortDirection: notificationCollection.sortDirectionFor("delivery"), onSort: () => notificationCollection.toggleSort("delivery") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: notificationCollection.sortDirectionFor("status"), onSort: () => notificationCollection.toggleSort("status") },
              { key: "sent", label: "Sent", priority: "secondary", sortable: true, sortDirection: notificationCollection.sortDirectionFor("sent"), onSort: () => notificationCollection.toggleSort("sent") },
              { key: "failures", label: "Failures", priority: "secondary", sortable: true, sortDirection: notificationCollection.sortDirectionFor("failures"), onSort: () => notificationCollection.toggleSort("failures") },
            ]}
          >
            {notificationCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={6}><AdminEmptyState title="No notifications recorded" description={notificationCollection.query ? "No notifications match the current search." : "Campaign deliveries and schedules will appear here after the first send."} /></td></tr>
            ) : notificationCollection.pageResult.items.map((item) => {
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
                      <p className="text-sm font-medium text-[var(--admin-text-strong)]">{audienceLabel(item)}</p>
                      <p className="admin-row-meta">{item.audienceType.replaceAll("_", " ")}</p>
                    </td>
                    <td>
                      <p className="text-sm font-medium text-[var(--admin-text-strong)]">
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
                      <p className="text-sm font-medium text-[var(--admin-text-strong)]">
                        {item.sentCount} / {total}
                      </p>
                      {total > 0 ? (
                        <div className="mt-2">
                          <ProgressBar value={item.sentCount} max={total} compact />
                        </div>
                      ) : null}
                    </td>
                    <td>
                      <p className="text-sm font-medium text-[var(--admin-text-strong)]">{item.failedCount}</p>
                      <p className="admin-row-meta">
                        {item.failedCount > 0 ? "needs review" : "clear"}
                      </p>
                    </td>
                  </tr>
                );
              })}
          </AdminDataGrid>
          <AdminPagination page={notificationCollection.pageResult} onPageChange={notificationCollection.setPage} label="Notification delivery queue" />
        </>
      )}
    </AdminSurface>
  );
}
