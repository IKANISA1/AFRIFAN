"use client";

import { useCallback, useEffect, useState } from "react";
import { History, Search, Terminal } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { getAdminAuditLogs, type AdminAuditRecord } from "@/lib/data/admin/audit";
import { Skeleton } from "@/components/skeleton";

export default function AdminAuditLogPage() {
  const { access, client } = useAdminPortal();
  const [logs, setLogs] = useState<AdminAuditRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filter, setFilter] = useState("");

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

  const filteredLogs = logs.filter(l => 
    l.userName?.toLowerCase().includes(filter.toLowerCase()) ||
    l.action?.toLowerCase().includes(filter.toLowerCase()) ||
    JSON.stringify(l.metadata).toLowerCase().includes(filter.toLowerCase())
  );

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Governance"
        title="Audit logs"
        meta={
          <span className="admin-meta-chip">
            <Terminal size={12} className="inline mr-1" />
            Last 100 actions
          </span>
        }
      />

      <div className="flex flex-col gap-4">
        <div className="relative max-w-md">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--admin-zinc-500)]" />
          <input
            type="text"
            placeholder="Filter by admin or action..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
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
              columns={[
                { key: "admin", label: "Administrator" },
                { key: "action", label: "Action" },
                { key: "details", label: "Details" },
                { key: "timestamp", label: "Timestamp" },
              ]}
            >
              {loading ? (
                Array.from({ length: 10 }).map((_, i) => (
                  <tr key={i}>
                    <td colSpan={4} className="p-4"><Skeleton className="skeleton-text h-4 w-full" /></td>
                  </tr>
                ))
              ) : filteredLogs.length === 0 ? (
                <tr>
                  <td colSpan={4} className="p-12 text-center text-sm text-[var(--admin-zinc-500)]">
                    No matching audit records found.
                  </td>
                </tr>
              ) : (
                filteredLogs.map((log) => (
                  <tr key={log.id}>
                    <td>
                      <p className="admin-row-title">{log.userName}</p>
                      <p className="admin-row-meta font-mono">{log.userId.slice(0, 8)}</p>
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
                  </tr>
                ))
              )}
            </AdminDataGrid>
          </div>
        )}
      </div>
    </div>
  );
}
