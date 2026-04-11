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
          return group.groupType === "general";
        case "SAVINGS":
          return group.groupType === "savings";
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
      title="Contribution groups"
      description="Funding progress, ownership, and group health."
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
          {["ALL", "CLUB PROJECTS", "COMMUNITY", "SAVINGS", "CLOSED"].map((item) => (
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
          title="No contribution groups in this view"
          description="Adjust the current filter or create a new group from the editor."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Group</th>
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
                const creatorAlias = group.creatorId
                  ? snapshot.aliases[group.creatorId] ?? "000000"
                  : "000000";

                return (
                  <tr key={group.id}>
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
                        {formatCurrency(group.currentTotal)}
                      </p>
                      <p className="admin-row-meta">
                        Target {formatCurrency(group.targetAmount)}
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
                      <div className="flex justify-end gap-2">
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
