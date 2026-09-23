"use client";

import { useCallback, useMemo, useState } from "react";
import { Eye, Search, Terminal } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import {
  filterAdminRecords,
  paginateAdminRecords,
  stableSortAdminRecords,
  type AdminSortDirection,
} from "@/lib/admin-collection";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  getAdminAuditLogs,
  normalizeAdminAuditLogs,
  projectAdminAuditDetail,
  type AdminAuditRecord,
} from "@/lib/data/admin/audit";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

type AuditSortKey = "administrator" | "action" | "target" | "timestamp";

const pageSize = 25;
const emptyLogs: AdminAuditRecord[] = [];
const logsAreEmpty = (logs: AdminAuditRecord[]) => logs.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading audit history",
    detail: "Waiting for the first authenticated, club-scoped snapshot.",
  },
  ready: {
    label: "Audit history confirmed",
    detail: "The latest bounded operator records are ready for review.",
  },
  empty: {
    label: "No audit records in this scope",
    detail: "No governed actions are available for the active club.",
  },
  error: {
    label: "Audit history unavailable",
    detail: "Confirmed records remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Audit history is offline",
    detail: "Confirmed records remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "Audit access denied",
    detail:
      "Records, filters, pagination, and open details were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing audit history",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Audit history changed",
    detail: "Review the retained snapshot, then refresh the latest records.",
  },
  security_timeout: {
    label: "Audit request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained history.",
  },
};

function formatAuditDate(value: string) {
  return new Intl.DateTimeFormat("en-RW", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export default function AdminAuditLogPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [filter, setFilter] = useState("");
  const [sortKey, setSortKey] = useState<AuditSortKey>("timestamp");
  const [sortDirection, setSortDirection] =
    useState<AdminSortDirection>("descending");
  const [page, setPage] = useState(1);
  const [detailLog, setDetailLog] = useState<AdminAuditRecord | null>(null);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const clearPrivateState = useCallback(() => {
    setFilter("");
    setPage(1);
    setDetailLog(null);
  }, []);
  const loadLogs = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyLogs;
      return getAdminAuditLogs(client, access, { limit: 500, signal });
    },
    [access, client],
  );
  const {
    data: logs,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
  } = useAdminResourceState<AdminAuditRecord[]>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyLogs,
    isEmpty: logsAreEmpty,
    load: loadLogs,
    normalize: normalizeAdminAuditLogs,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "audit history",
  });

  const sortedLogs = useMemo(() => {
    const filtered = filterAdminRecords(logs, filter, (log) => [
      log.userName,
      log.action,
      log.targetTable,
      log.targetId,
      log.notes,
    ]);
    return stableSortAdminRecords(
      filtered,
      (log) => {
        switch (sortKey) {
          case "administrator":
            return log.userName;
          case "action":
            return log.action;
          case "target":
            return `${log.targetTable}:${log.targetId ?? ""}`;
          case "timestamp":
            return new Date(log.createdAt);
        }
      },
      sortDirection,
    );
  }, [filter, logs, sortDirection, sortKey]);
  const logPage = useMemo(
    () => paginateAdminRecords(sortedLogs, page, pageSize),
    [page, sortedLogs],
  );
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  function changeSort(nextSortKey: AuditSortKey) {
    setPage(1);
    if (sortKey === nextSortKey) {
      setSortDirection((current) =>
        current === "ascending" ? "descending" : "ascending",
      );
      return;
    }
    setSortKey(nextSortKey);
    setSortDirection(nextSortKey === "timestamp" ? "descending" : "ascending");
  }

  return (
    <div
      className="admin-audit-state-surface section-grid min-w-0 max-w-full !gap-6"
      data-admin-audit-status={status}
      data-admin-audit-interaction={interaction}
      data-admin-audit-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Governance"
        title="Audit logs"
        meta={
          <span className="admin-meta-chip">
            <Terminal size={12} className="mr-1 inline" aria-hidden="true" />
            Latest 500 bounded records
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh audit history"
        selected={interaction === "selected"}
        onRefresh={() => {
          void refresh();
        }}
        onInteractionChange={setInteraction}
      />

      {!unrecoveredFailure ? (
        <section className="admin-audit-workspace grid gap-4" aria-label="Audit records">
          <div className="relative max-w-md">
            <Search
              size={16}
              aria-hidden="true"
              className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[var(--admin-zinc-500)]"
            />
            <input
              type="search"
              placeholder="Filter administrator, action, or target"
              aria-label="Filter audit logs"
              value={filter}
              disabled={busy && !hasConfirmed}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction(filter ? "selected" : "idle")}
              onChange={(event) => {
                setFilter(event.target.value);
                setPage(1);
                setInteraction(event.target.value ? "selected" : "focused");
              }}
              className="admin-input min-h-12 w-full !pl-11"
            />
          </div>

          <div className="admin-surface min-w-0">
            <AdminDataGrid
              caption="Administrator audit log"
              busy={busy}
              onRowActivate={(rowId) => {
                const log = logs.find((candidate) => candidate.id === rowId);
                if (log) {
                  setDetailLog(log);
                  setInteraction("selected");
                }
              }}
              columns={[
                {
                  key: "admin",
                  label: "Administrator",
                  priority: "primary",
                  sortable: true,
                  sortDirection:
                    sortKey === "administrator" ? sortDirection : "none",
                  onSort: () => changeSort("administrator"),
                },
                {
                  key: "action",
                  label: "Action",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortKey === "action" ? sortDirection : "none",
                  onSort: () => changeSort("action"),
                },
                {
                  key: "target",
                  label: "Target",
                  priority: "secondary",
                  sortable: true,
                  sortDirection: sortKey === "target" ? sortDirection : "none",
                  onSort: () => changeSort("target"),
                },
                {
                  key: "timestamp",
                  label: "Timestamp",
                  priority: "primary",
                  sortable: true,
                  sortDirection:
                    sortKey === "timestamp" ? sortDirection : "none",
                  onSort: () => changeSort("timestamp"),
                },
                {
                  key: "actions",
                  label: "Actions",
                  priority: "primary",
                  className: "text-right",
                },
              ]}
            >
              {initialLoading ? (
                Array.from({ length: 8 }).map((_, index) => (
                  <tr key={index}>
                    <td colSpan={5} className="p-4">
                      <Skeleton className="skeleton-text h-4 w-full" />
                    </td>
                  </tr>
                ))
              ) : logPage.items.length === 0 ? (
                <tr>
                  <td
                    colSpan={5}
                    className="p-12 text-center text-sm text-[var(--admin-zinc-500)]"
                  >
                    {filter
                      ? "No audit records match the current filter."
                      : "No audit records are available for this club."}
                  </td>
                </tr>
              ) : (
                logPage.items.map((log) => (
                  <tr key={log.id} data-row-id={log.id}>
                    <td>
                      <p className="admin-row-title">{log.userName}</p>
                      <p className="admin-row-meta">
                        {log.actorKind === "administrator"
                          ? "Authenticated administrator"
                          : "System action"}
                      </p>
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={log.action}
                        tone={
                          log.action.includes("delete") ||
                          log.action.includes("revoke")
                            ? "danger"
                            : log.action.includes("update") ||
                                log.action.includes("save")
                              ? "info"
                              : "neutral"
                        }
                      />
                    </td>
                    <td>
                      <p className="admin-row-title">{log.targetTable}</p>
                      <p className="admin-row-meta">
                        {log.targetId
                          ? "Record identifier available in details"
                          : "No target identifier"}
                      </p>
                    </td>
                    <td className="text-xs text-[var(--admin-zinc-500)]">
                      {formatAuditDate(log.createdAt)}
                    </td>
                    <td className="text-right">
                      <button
                        type="button"
                        className="admin-action-button min-h-12"
                        onClick={() => {
                          setDetailLog(log);
                          setInteraction("selected");
                        }}
                        aria-label={`View audit details for ${log.action}`}
                      >
                        <Eye size={15} aria-hidden="true" />
                        Details
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </AdminDataGrid>
            <AdminPagination
              page={logPage}
              onPageChange={setPage}
              label="Audit logs"
            />
          </div>
        </section>
      ) : null}

      <AdminActionDrawer
        open={detailLog != null}
        onClose={() => setDetailLog(null)}
        title="Audit record details"
      >
        {detailLog ? <AuditRecordDetails record={detailLog} /> : null}
      </AdminActionDrawer>
    </div>
  );
}

function AuditRecordDetails({ record }: { record: AdminAuditRecord }) {
  const detail = useMemo(() => projectAdminAuditDetail(record), [record]);
  return (
    <dl className="grid gap-5 text-sm">
      <AuditDetail label="Administrator" value={record.userName} />
      <AuditDetail label="Action" value={record.action} />
      <AuditDetail label="Target table" value={record.targetTable} />
      <AuditDetail
        label="Target record"
        value={record.targetId ?? "Not recorded"}
      />
      <AuditDetail
        label="Timestamp"
        value={formatAuditDate(record.createdAt)}
      />
      <AuditJsonDetail
        label="Previous values"
        value={detail.previousValues}
      />
      <AuditJsonDetail label="New values" value={detail.newValues} />
      <AuditJsonDetail label="Metadata" value={detail.metadata} />
      {record.notes ? <AuditDetail label="Notes" value={record.notes} /> : null}
    </dl>
  );
}

function AuditDetail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-semibold normal-case tracking-normal text-[var(--admin-text-muted)]">
        {label}
      </dt>
      <dd className="mt-1 break-words text-[var(--admin-text-strong)]">
        {value}
      </dd>
    </div>
  );
}

function AuditJsonDetail({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div>
      <dt className="text-xs font-semibold normal-case tracking-normal text-[var(--admin-text-muted)]">
        {label}
      </dt>
      <dd className="mt-2 overflow-x-auto rounded-xl border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] p-3 font-mono text-xs text-[var(--admin-text)]">
        <pre className="whitespace-pre-wrap break-words">{value}</pre>
      </dd>
    </div>
  );
}
