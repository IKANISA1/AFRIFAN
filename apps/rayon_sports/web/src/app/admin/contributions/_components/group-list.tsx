"use client";

import { Download, PencilLine, Search, Trash2 } from "lucide-react";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { formatCurrency } from "@/lib/utils";
import type { AdminContributionGroup, AdminContributionSnapshot } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";

interface GroupListProps {
  snapshot: AdminContributionSnapshot;
  currencyCode: string;
  filter: string;
  setFilter: (filter: string) => void;
  loading: boolean;
  onEdit: (group: AdminContributionGroup) => void;
  onDelete: (group: AdminContributionGroup) => void;
  onExportExcel: () => void;
}

export function ContributionGroupList({
  snapshot,
  currencyCode,
  filter,
  setFilter,
  loading,
  onEdit,
  onDelete,
  onExportExcel,
}: GroupListProps) {
  const filteredGroups = snapshot.groups.filter((group) => {
      switch (filter) {
        case "CLUB PROJECTS":
          return group.groupType === "project";
        case "COMMUNITY":
          return group.groupType === "community";
        case "CLOSED":
          return group.isClosed;
        default:
          return true;
      }
    });
  const groupCollection = useAdminCollection({
    records: filteredGroups,
    getId: (group) => group.id,
    getSearchValues: (group) => [
      group.name,
      group.description,
      group.groupType,
      group.isClosed ? "closed" : "active",
      group.creatorId,
      group.currency,
    ],
    getSortValue: (
      group,
      key: "initiative" | "type" | "status" | "members" | "total" | "progress" | "createdAt",
    ) => {
      switch (key) {
        case "initiative": return group.name;
        case "type": return group.groupType;
        case "status": return group.isClosed;
        case "members": return group.memberCount;
        case "total": return group.currentTotal;
        case "progress": return group.targetAmount === 0 ? 0 : group.currentTotal / group.targetAmount;
        case "createdAt": return new Date(group.createdAt);
      }
    },
    initialSortKey: "createdAt" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  return (
    <AdminSurface
      title="Public initiatives"
      actions={
        <button
          type="button"
          onClick={onExportExcel}
          className="admin-action-button"
        >
          <Download size={13} />
          Export
        </button>
      }
      toolbar={
        <div className="flex flex-wrap items-center gap-2">
          {["ALL", "CLUB PROJECTS", "COMMUNITY", "CLOSED"].map((item) => (
            <button
              key={item}
              type="button"
              data-active={filter === item}
              onClick={() => setFilter(item)}
              className="dashboard-chip"
            >
              {item}
            </button>
          ))}
          {(["RECENT", "TOTAL", "MEMBERS"] as const).map((item) => (
            <button
              key={item}
              type="button"
              data-active={
                (item === "RECENT" && groupCollection.sortKey === "createdAt") ||
                (item === "TOTAL" && groupCollection.sortKey === "total") ||
                (item === "MEMBERS" && groupCollection.sortKey === "members")
              }
              onClick={() => {
                const key = item === "RECENT" ? "createdAt" : item === "TOTAL" ? "total" : "members";
                groupCollection.toggleSort(key);
              }}
              className="dashboard-chip"
            >
              Sort {item}
            </button>
          ))}
          <label className="admin-search-field">
            <Search size={14} aria-hidden="true" />
            <span className="sr-only">Search public initiatives</span>
            <input type="search" value={groupCollection.query} onChange={(event) => groupCollection.setQuery(event.target.value)} placeholder="Search initiative, type, owner, or state" />
          </label>
        </div>
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
      ) : (
        <>
          <AdminDataGrid
            caption="Public contribution initiatives"
            onRowActivate={(rowId) => {
              const group = snapshot.groups.find((item) => item.id === rowId);
              if (group) onEdit(group);
            }}
            columns={[
              { key: "initiative", label: "Initiative", priority: "primary", sortable: true, sortDirection: groupCollection.sortDirectionFor("initiative"), onSort: () => groupCollection.toggleSort("initiative") },
              { key: "type", label: "Type", priority: "secondary", sortable: true, sortDirection: groupCollection.sortDirectionFor("type"), onSort: () => groupCollection.toggleSort("type") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: groupCollection.sortDirectionFor("status"), onSort: () => groupCollection.toggleSort("status") },
              { key: "members", label: "Members", priority: "secondary", sortable: true, sortDirection: groupCollection.sortDirectionFor("members"), onSort: () => groupCollection.toggleSort("members") },
              { key: "raised", label: "Raised", priority: "primary", sortable: true, sortDirection: groupCollection.sortDirectionFor("total"), onSort: () => groupCollection.toggleSort("total") },
              { key: "progress", label: "Progress", priority: "tertiary", sortable: true, sortDirection: groupCollection.sortDirectionFor("progress"), onSort: () => groupCollection.toggleSort("progress") },
              { key: "owner", label: "Owner", priority: "tertiary", sortable: true, sortDirection: groupCollection.sortDirectionFor("createdAt"), onSort: () => groupCollection.toggleSort("createdAt") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
            {groupCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={8}><AdminEmptyState title="No public initiatives in this view" description={groupCollection.query ? "No initiatives match the current search and filter." : "Adjust the current filter or create a new initiative from the editor."} /></td></tr>
            ) : groupCollection.pageResult.items.map((group) => {
                const creatorAlias = group.creatorId?.slice(0, 6) ?? "000000";

                return (
                  <tr key={group.id} data-row-id={group.id}>
                    <td>
                      <p className="admin-row-title">{group.name}</p>
                      <p className="admin-row-copy">{group.description}</p>
                    </td>
                    <td>
                      <AdminStatusBadge label={group.groupType} tone="neutral" />
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={group.isClosed ? "Closed" : "Active"}
                        tone={group.isClosed ? "danger" : "success"}
                      />
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">{group.memberCount}</p>
                      <p className="admin-row-meta">contributors</p>
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">
                        {formatCurrency(group.currentTotal, currencyCode)}
                      </p>
                      <p className="admin-row-meta">
                        Target {formatCurrency(group.targetAmount, currencyCode)}
                      </p>
                    </td>
                    <td className="min-w-[180px]">
                      <ProgressBar
                        value={group.currentTotal}
                        max={Math.max(group.targetAmount, group.currentTotal, 1)}
                        compact
                      />
                      <p className="admin-row-meta mt-2">
                        {Math.round((group.currentTotal / Math.max(group.targetAmount, 1)) * 100)}% funded
                      </p>
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">{creatorAlias}</p>
                      <p className="admin-row-meta">
                        {new Date(group.createdAt).toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })}
                      </p>
                    </td>
                    <td>
                      <div className="flex flex-wrap justify-start gap-2 sm:justify-end">
                        <button
                          type="button"
                          onClick={() => onEdit(group)}
                          className="admin-action-button"
                        >
                          <PencilLine size={13} />
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => onDelete(group)}
                          className="admin-action-button admin-action-button-danger"
                        >
                          <Trash2 size={13} />
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
          </AdminDataGrid>
          <AdminPagination page={groupCollection.pageResult} onPageChange={groupCollection.setPage} label="Public contribution initiatives" />
        </>
      )}
    </AdminSurface>
  );
}
