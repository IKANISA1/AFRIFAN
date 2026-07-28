"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Eye, Search, Terminal } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { getAdminAuditLogs, type AdminAuditRecord } from "@/lib/data/admin/audit";
import {
  filterAdminRecords,
  paginateAdminRecords,
  stableSortAdminRecords,
  type AdminSortDirection,
} from "@/lib/admin-collection";
import { Skeleton } from "@/components/skeleton";

type AuditSortKey = "administrator" | "action" | "target" | "timestamp";

const pageSize = 25;

export default function AdminAuditLogPage() {
  const { access, client } = useAdminPortal();
  const [logs, setLogs] = useState<AdminAuditRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filter, setFilter] = useState("");
  const [sortKey, setSortKey] = useState<AuditSortKey>("timestamp");
  const [sortDirection, setSortDirection] =
    useState<AdminSortDirection>("descending");
  const [page, setPage] = useState(1);
  const [detailLog, setDetailLog] = useState<AdminAuditRecord | null>(null);

  const loadLogs = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setLogs(await getAdminAuditLogs(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load audit logs.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    loadLogs().catch(() => {});
  }, [access.hasAccess, client, loadLogs]);

  const sortedLogs = useMemo(() => {
    const filtered = filterAdminRecords(logs, filter, (log) => [
      log.userName,
      log.action,
      log.targetTable,
      log.targetId,
      log.notes,
      JSON.stringify(log.metadata),
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
            return `${log.targetTable ?? ""}:${log.targetId ?? ""}`;
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

  function sortDirectionFor(column: AuditSortKey) {
    return sortKey === column ? sortDirection : "none";
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Governance"
        title="Audit logs"
        meta={
          <span className="admin-meta-chip">
            <Terminal size={12} className="inline mr-1" />
            Latest 500 actions
          </span>
        }
      />

      <div className="flex flex-col gap-4">
        <div className="relative max-w-md">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--admin-zinc-500)]" />
          <input
            type="search"
            placeholder="Filter by admin or action..."
            aria-label="Filter audit logs"
            value={filter}
            onChange={(event) => {
              setFilter(event.target.value);
              setPage(1);
            }}
            className="admin-input !pl-10 w-full"
          />
        </div>

        {loadError && !loading ? (
          <AdminErrorState
            title="Audit logs could not be loaded"
            description={loadError}
            onRetry={() => { loadLogs().catch(() => {}); }}
          />
        ) : (
          <div className="admin-surface">
            <AdminDataGrid
              caption="Administrator audit log"
              busy={loading}
              onRowActivate={(rowId) => {
                const log = logs.find((candidate) => candidate.id === rowId);
                if (log) setDetailLog(log);
              }}
              columns={[
                {
                  key: "admin",
                  label: "Administrator",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortDirectionFor("administrator"),
                  onSort: () => changeSort("administrator"),
                },
                {
                  key: "action",
                  label: "Action",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortDirectionFor("action"),
                  onSort: () => changeSort("action"),
                },
                {
                  key: "target",
                  label: "Target",
                  priority: "secondary",
                  sortable: true,
                  sortDirection: sortDirectionFor("target"),
                  onSort: () => changeSort("target"),
                },
                { key: "details", label: "Details", priority: "tertiary" },
                {
                  key: "timestamp",
                  label: "Timestamp",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortDirectionFor("timestamp"),
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
              {loading ? (
                Array.from({ length: 10 }).map((_, i) => (
                  <tr key={i}>
                    <td colSpan={6} className="p-4"><Skeleton className="skeleton-text h-4 w-full" /></td>
                  </tr>
                ))
              ) : logPage.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-12 text-center text-sm text-[var(--admin-zinc-500)]">
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
                        {log.userId ? "Authenticated administrator" : "System action"}
                      </p>
                    </td>
                    <td>
                      <AdminStatusBadge 
                        label={log.action} 
                        tone={
                          log.action.includes("delete") || log.action.includes("revoke") ? "danger" : 
                          log.action.includes("update") || log.action.includes("save") ? "info" : 
                          "neutral"
                        } 
                      />
                    </td>
                    <td>
                      <p className="admin-row-title">{log.targetTable || "Not recorded"}</p>
                      <p className="admin-row-meta font-mono">
                        {log.targetId ? "Record available in details" : "No target ID"}
                      </p>
                    </td>
                    <td>
                      <div className="max-w-xs truncate text-[10px] font-mono text-[var(--admin-zinc-400)] bg-[var(--admin-zinc-950)] p-1.5 rounded border border-[var(--admin-border)]">
                        {JSON.stringify(log.metadata)}
                      </div>
                    </td>
                    <td className="text-xs text-[var(--admin-zinc-500)]">
                       {new Date(log.createdAt).toLocaleString("en-RW", {
                         month: "short",
                         day: "numeric",
                         hour: "2-digit",
                         minute: "2-digit"
                       })}
                    </td>
                    <td className="text-right">
                      <button
                        type="button"
                        className="admin-action-button"
                        onClick={() => setDetailLog(log)}
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
            <AdminPagination page={logPage} onPageChange={setPage} label="Audit logs" />
          </div>
        )}
      </div>

      <AdminActionDrawer
        open={detailLog != null}
        onClose={() => setDetailLog(null)}
        title="Audit record details"
      >
        {detailLog ? (
          <dl className="grid gap-5 text-sm">
            <AuditDetail label="Administrator" value={detailLog.userName ?? "System / Unknown"} />
            <AuditDetail label="Action" value={detailLog.action} />
            <AuditDetail label="Target table" value={detailLog.targetTable || "Not recorded"} />
            <AuditDetail label="Target record" value={detailLog.targetId || "Not recorded"} />
            <AuditDetail
              label="Timestamp"
              value={new Date(detailLog.createdAt).toLocaleString("en-RW")}
            />
            <AuditJsonDetail label="Previous values" value={detailLog.oldData} />
            <AuditJsonDetail label="New values" value={detailLog.newData} />
            <AuditJsonDetail label="Metadata" value={detailLog.metadata} />
            {detailLog.notes ? <AuditDetail label="Notes" value={detailLog.notes} /> : null}
          </dl>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}

function AuditDetail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-text-muted)]">
        {label}
      </dt>
      <dd className="mt-1 break-words text-[var(--admin-text-strong)]">{value}</dd>
    </div>
  );
}

function AuditJsonDetail({
  label,
  value,
}: {
  label: string;
  value: Record<string, unknown>;
}) {
  return (
    <div>
      <dt className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-text-muted)]">
        {label}
      </dt>
      <dd className="mt-2 overflow-x-auto rounded-xl border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] p-3 font-mono text-xs text-[var(--admin-text)]">
        <pre className="whitespace-pre-wrap break-words">
          {JSON.stringify(value, null, 2)}
        </pre>
      </dd>
    </div>
  );
}
