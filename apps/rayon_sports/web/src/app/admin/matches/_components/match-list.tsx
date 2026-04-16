"use client";

import { PencilLine, Search, Trash2 } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import { formatCurrency, formatDate } from "@/lib/utils";
import type { AdminMatchItem } from "@/lib/types";

function matchTone(status: string) {
  switch (status) {
    case "live":
    case "halftime": return "danger" as const;
    case "scheduled": return "info" as const;
    case "fulltime": return "neutral" as const;
    case "postponed": return "warning" as const;
    case "cancelled": return "danger" as const;
    default: return "neutral" as const;
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
      case "LIVE": return match.matchStatus === "live" || match.matchStatus === "halftime";
      case "UPCOMING": return upcoming;
      case "COMPLETED": return !upcoming;
      case "ON SALE": return match.isOnSale;
      default: return true;
    }
  });

  return (
    <div className="admin-surface">
      <AdminFilterBar
        actions={
          <div className="flex gap-1 bg-[var(--admin-zinc-950)] p-1 rounded-lg border border-[var(--admin-border)]">
            {["ALL", "LIVE", "UPCOMING", "COMPLETED", "ON SALE"].map((item) => (
              <button
                key={item}
                type="button"
                onClick={() => setFilter(item)}
                className={cn(
                  "px-3 py-1 text-[10px] font-bold uppercase tracking-wider rounded-md transition-colors",
                  filter === item
                    ? "bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-100)] shadow-sm"
                    : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]"
                )}
              >
                {item}
              </button>
            ))}
          </div>
        }
      >
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] text-[var(--admin-zinc-400)]">
          <Search size={14} />
          <span className="text-[11px] uppercase tracking-wider">Fixtures list</span>
        </div>
      </AdminFilterBar>

      <AdminDataGrid
        columns={[
          { key: "fixture", label: "Fixture" },
          { key: "status", label: "Status" },
          { key: "kickoff", label: "Kickoff" },
          { key: "sales", label: "Sales" },
          { key: "score", label: "Score" },
          { key: "capacity", label: "Capacity" },
          { key: "actions", label: "", className: "w-24" },
        ]}
      >
        {loading ? (
          Array.from({ length: 5 }).map((_, i) => (
            <tr key={i}>
              <td colSpan={7} className="p-4"><Skeleton className="skeleton-text h-4 w-full" /></td>
            </tr>
          ))
        ) : filteredMatches.length === 0 ? (
          <tr>
            <td colSpan={7}>
              <AdminEmptyState
                title="No fixtures found"
                description="Change filters or create a new fixture."
                className="!min-h-[200px]"
              />
            </td>
          </tr>
        ) : (
          filteredMatches.map((match) => {
            const isLive = match.matchStatus === "live" || match.matchStatus === "halftime";
            return (
              <tr key={match.id} className={cn(isLive && "bg-emerald-500/[0.02]")}>
                <td>
                  <div className="space-y-0.5">
                    <p className="admin-row-title">{match.homeTeam} vs {match.awayTeam}</p>
                    <p className="admin-row-copy">{match.competition} · {match.venue}</p>
                  </div>
                </td>
                <td>
                  <AdminStatusBadge
                    label={statusLabel(match.matchStatus)}
                    tone={matchTone(match.matchStatus)}
                    pulse={isLive}
                  />
                </td>
                <td>
                  <div className="space-y-0.5 text-sm">
                    <p className="font-medium text-[var(--admin-zinc-100)]">{formatDate(match.matchDate)}</p>
                    <p className="text-[10px] text-[var(--admin-zinc-500)] uppercase font-bold">{match.kickoffTime}</p>
                  </div>
                </td>
                <td>
                  <div className="space-y-1">
                    <AdminStatusBadge
                      label={match.isOnSale ? "On sale" : "Closed"}
                      tone={match.isOnSale ? "success" : "neutral"}
                    />
                    <p className="text-[10px] text-[var(--admin-zinc-500)] font-bold">{formatCurrency(match.generalPrice, currencyCode)}</p>
                  </div>
                </td>
                <td>
                  <div className="space-y-0.5">
                    <p className="text-sm font-bold text-[var(--admin-zinc-100)]">{match.homeScore} - {match.awayScore}</p>
                    <p className="text-[10px] text-[var(--admin-zinc-500)] uppercase font-bold">
                      {isLive ? `${match.liveMinute ?? 0}' LIVE` : "Final"}
                    </p>
                  </div>
                </td>
                <td className="min-w-[140px]">
                  <ProgressBar value={match.soldCount} max={match.capacity} compact />
                  <p className="mt-1.5 text-[10px] text-[var(--admin-zinc-500)] font-bold">
                    {match.soldCount} / {match.capacity} SOLD
                  </p>
                </td>
                <td className="text-right">
                  <div className="flex justify-end gap-1">
                    <button
                      onClick={() => onEdit(match)}
                      className="p-2 rounded hover:bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-100)] transition-colors"
                      title="Edit"
                    >
                      <PencilLine size={16} />
                    </button>
                    <button
                      onClick={() => onDelete(match)}
                      className="p-2 rounded hover:bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-500)] hover:text-rose-500 transition-colors"
                      title="Delete"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </td>
              </tr>
            );
          })
        )}
      </AdminDataGrid>
    </div>
  );
}
