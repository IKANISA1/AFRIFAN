import { PencilLine, Trash2 } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { Skeleton } from "@/components/skeleton";
import type { AdminFanClub } from "@/lib/types";

interface CommunityContentListProps {
  clubs: AdminFanClub[];
  loading: boolean;
  onBeginEdit: (club: AdminFanClub) => void;
  onRemove: (club: AdminFanClub) => void;
}

export function CommunityContentList({
  clubs,
  loading,
  onBeginEdit,
  onRemove,
}: CommunityContentListProps) {
  return (
    <AdminSurface
      title="Chapter directory"
      flush
    >
      {loading ? (
        <div className="space-y-3 p-5 sm:p-6">
          {Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="rounded-[20px] border border-border-soft bg-white/5 p-4">
              <Skeleton className="skeleton-text h-5 w-2/5" />
              <Skeleton className="skeleton-text mt-2 h-3 w-full" />
            </div>
          ))}
        </div>
      ) : clubs.length === 0 ? (
        <AdminEmptyState
          title="No supporter chapters yet"
          description="Create the first chapter from the editor to start regional operations."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Chapter</th>
                <th>Region</th>
                <th>Status</th>
                <th>Members</th>
                <th>Events</th>
                <th>Rating</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {clubs.map((club) => (
                <tr key={club.id} className="admin-table-row">
                  <td className="admin-table-cell" data-column-label="Chapter">
                    <p className="admin-row-title">{club.name}</p>
                    <p className="admin-row-copy">{club.description}</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Region">
                    <p className="text-sm font-medium text-white">{club.region}</p>
                    <p className="admin-row-meta">territory</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Status">
                    <AdminStatusBadge
                      label={club.isActive ? "Visible" : "Hidden"}
                      tone={club.isActive ? "success" : "neutral"}
                    />
                  </td>
                  <td className="admin-table-cell" data-column-label="Members">
                    <p className="text-sm font-medium text-white">{club.memberCount}</p>
                    <p className="admin-row-meta">supporters</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Events">
                    <p className="text-sm font-medium text-white">{club.eventCount}</p>
                    <p className="admin-row-meta">chapter events</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Rating">
                    <p className="text-sm font-medium text-white">{club.rating.toFixed(1)}</p>
                    <p className="admin-row-meta">engagement score</p>
                  </td>
                  <td className="admin-table-cell" data-column-label="Actions">
                    <div className="flex flex-wrap justify-start gap-2 sm:justify-end">
                      <button
                        type="button"
                        onClick={() => onBeginEdit(club)}
                        className="admin-action-button"
                      >
                        <PencilLine size={13} />
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => onRemove(club)}
                        className="admin-action-button admin-action-button-danger"
                      >
                        <Trash2 size={13} />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </AdminSurface>
  );
}
