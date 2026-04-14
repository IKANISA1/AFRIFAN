"use client";

import { PencilLine, Trash2 } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import { formatCurrency, formatDate } from "@/lib/utils";
import type { AdminMatchItem } from "@/lib/types";

function matchTone(status: string) {
  switch (status) {
    case "live":
    case "halftime":
      return "danger" as const;
    case "scheduled":
      return "info" as const;
    case "fulltime":
      return "neutral" as const;
    case "postponed":
      return "warning" as const;
    case "cancelled":
      return "danger" as const;
    default:
      return "neutral" as const;
  }
}

function statusLabel(status: string) {
  return status.replaceAll("_", " ");
}

interface MatchListProps {
  matches: AdminMatchItem[];
  currencyCode: string;
  filter: string;
  setFilter: (filter: string) => void;
  loading: boolean;
  onEdit: (match: AdminMatchItem) => void;
  onDelete: (match: AdminMatchItem) => void;
}

export function MatchList({
  matches,
  currencyCode,
  filter,
  setFilter,
  loading,
  onEdit,
  onDelete,
}: MatchListProps) {
  const filteredMatches = matches.filter((match) => {
    const date = new Date(match.matchDate);
    const today = new Date();
    const upcoming = date >= new Date(today.getFullYear(), today.getMonth(), today.getDate());

    switch (filter) {
      case "LIVE":
        return match.matchStatus === "live" || match.matchStatus === "halftime";
      case "UPCOMING":
        return upcoming;
      case "COMPLETED":
        return !upcoming;
      case "ON SALE":
        return match.isOnSale;
      default:
        return true;
    }
  });

  return (
    <AdminSurface
      title="Fixtures"
      description="Live state, sales, score, and capacity."
      toolbar={
        <div className="flex flex-wrap gap-2">
          {["ALL", "LIVE", "UPCOMING", "COMPLETED", "ON SALE"].map((item) => (
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
      ) : filteredMatches.length === 0 ? (
        <AdminEmptyState
          title="No fixtures in this view"
          description="Change the current filter or create a new fixture from the editor."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Fixture</th>
                <th>Status</th>
                <th>Kickoff</th>
                <th>Sales</th>
                <th>Score</th>
                <th>Capacity</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredMatches.map((match) => {
                const isLive =
                  match.matchStatus === "live" || match.matchStatus === "halftime";

                return (
                  <tr key={match.id} className={cn(isLive && "bg-white/[0.03]")}>
                    <td>
                      <p className="admin-row-title">
                        {match.homeTeam} vs {match.awayTeam}
                      </p>
                      <p className="admin-row-copy">
                        {match.competition} · {match.venue}
                      </p>
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={statusLabel(match.matchStatus)}
                        tone={matchTone(match.matchStatus)}
                        pulse={isLive}
                      />
                    </td>
                    <td>
                      <p className="text-sm font-medium text-white">
                        {formatDate(match.matchDate)}
                      </p>
                      <p className="admin-row-meta">{match.kickoffTime}</p>
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={match.isOnSale ? "On sale" : "Closed"}
                        tone={match.isOnSale ? "success" : "neutral"}
                      />
                      <p className="admin-row-meta">{formatCurrency(match.generalPrice, currencyCode)}</p>
                    </td>
                    <td>
                      <p className="text-sm font-semibold text-white">
                        {match.homeScore} - {match.awayScore}
                      </p>
                      <p className="admin-row-meta">
                        {isLive ? `${match.liveMinute ?? 0}' live` : "Match state"}
                      </p>
                    </td>
                    <td className="min-w-[180px]">
                      <ProgressBar value={match.soldCount} max={match.capacity} compact />
                      <p className="admin-row-meta mt-2">
                        {match.soldCount} sold · {match.capacity} capacity
                      </p>
                    </td>
                    <td>
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => onEdit(match)}
                          className="admin-action-button"
                        >
                          <PencilLine size={13} />
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => onDelete(match)}
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
