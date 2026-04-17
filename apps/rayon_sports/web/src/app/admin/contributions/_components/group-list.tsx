"use client";

import { Download, PencilLine, Trash2 } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { formatCurrency } from "@/lib/utils";
import type { AdminContributionGroup, AdminContributionSnapshot } from "@/lib/types";

interface GroupListProps {
  snapshot: AdminContributionSnapshot;
  currencyCode: string;
  filter: string;
  setFilter: (filter: string) => void;
  sortMode: string;
  setSortMode: (mode: string) => void;
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
  sortMode,
  setSortMode,
  loading,
  onEdit,
  onDelete,
  onExportExcel,
}: GroupListProps) {
  const filteredGroups = snapshot.groups
    .filter((group) => {
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
    })
    .sort((left, right) => {
      if (sortMode === "TOTAL") {
        return right.currentTotal - left.currentTotal;
      }
      if (sortMode === "MEMBERS") {
        return right.memberCount - left.memberCount;
      }
      return right.createdAt.localeCompare(left.createdAt);
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
          {["RECENT", "TOTAL", "MEMBERS"].map((item) => (
            <button
              key={item}
              type="button"
              data-active={sortMode === item}
              onClick={() => setSortMode(item)}
              className="dashboard-chip"
            >
              Sort {item}
            </button>
          ))}
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
      ) : filteredGroups.length === 0 ? (
          <AdminEmptyState
          title="No public initiatives in this view"
          description="Adjust the current filter or create a new initiative from the editor."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Initiative</th>
                <th>Type</th>
                <th>Status</th>
                <th>Members</th>
                <th>Raised</th>
                <th>Progress</th>
                <th>Owner</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredGroups.map((group) => {
                const creatorAlias = group.creatorId?.slice(0, 6) ?? "000000";

                return (
                  <tr key={group.id} className="admin-table-row">
                    <td className="admin-table-cell" data-column-label="Initiative">
                      <p className="admin-row-title">{group.name}</p>
                      <p className="admin-row-copy">{group.description}</p>
                    </td>
                    <td className="admin-table-cell" data-column-label="Type">
                      <AdminStatusBadge label={group.groupType} tone="neutral" />
                    </td>
                    <td className="admin-table-cell" data-column-label="Status">
                      <AdminStatusBadge
                        label={group.isClosed ? "Closed" : "Active"}
                        tone={group.isClosed ? "danger" : "success"}
                      />
                    </td>
                    <td className="admin-table-cell" data-column-label="Members">
                      <p className="text-sm font-medium text-white">{group.memberCount}</p>
                      <p className="admin-row-meta">contributors</p>
                    </td>
                    <td className="admin-table-cell" data-column-label="Raised">
                      <p className="text-sm font-medium text-white">
                        {formatCurrency(group.currentTotal, currencyCode)}
                      </p>
                      <p className="admin-row-meta">
                        Target {formatCurrency(group.targetAmount, currencyCode)}
                      </p>
                    </td>
                    <td className="admin-table-cell min-w-[180px]" data-column-label="Progress">
                      <ProgressBar
                        value={group.currentTotal}
                        max={Math.max(group.targetAmount, group.currentTotal, 1)}
                        compact
                      />
                      <p className="admin-row-meta mt-2">
                        {Math.round((group.currentTotal / Math.max(group.targetAmount, 1)) * 100)}% funded
                      </p>
                    </td>
                    <td className="admin-table-cell" data-column-label="Owner">
                      <p className="text-sm font-medium text-white">{creatorAlias}</p>
                      <p className="admin-row-meta">
                        {new Date(group.createdAt).toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })}
                      </p>
                    </td>
                    <td className="admin-table-cell" data-column-label="Actions">
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
            </tbody>
          </table>
        </div>
      )}
    </AdminSurface>
  );
}
