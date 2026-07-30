"use client";

import { PencilLine, Search, Trash2 } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import { formatCurrency, formatDate } from "@/lib/utils";
import type { AdminMatchItem } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";

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
  const matchCollection = useAdminCollection({
    records: filteredMatches,
    getId: (match) => match.id,
    getSearchValues: (match) => [
      match.homeTeam,
      match.awayTeam,
      match.competition,
      match.venue,
      match.matchStatus,
      match.isOnSale ? "on sale" : "closed",
    ],
    getSortValue: (
      match,
      key: "fixture" | "status" | "kickoff" | "sales" | "capacity",
    ) => {
      switch (key) {
        case "fixture": return `${match.homeTeam} ${match.awayTeam}`;
        case "status": return match.matchStatus;
        case "kickoff": return new Date(match.matchDate);
        case "sales": return match.isOnSale;
        case "capacity": return match.capacity === 0 ? 0 : match.soldCount / match.capacity;
      }
    },
    initialSortKey: "kickoff" as const,
    initialSortDirection: "descending",
    pageSize: 25,
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
                  "min-h-12 min-w-12 px-3 py-2 text-[10px] font-bold uppercase tracking-wider rounded-md transition-colors",
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
        <label className="admin-search-field">
          <Search size={14} aria-hidden="true" />
          <span className="sr-only">Search fixtures</span>
          <input type="search" value={matchCollection.query} onChange={(event) => matchCollection.setQuery(event.target.value)} placeholder="Search team, competition, venue, or state" />
        </label>
      </AdminFilterBar>

      <AdminDataGrid
        caption="Match operations"
        busy={loading}
        onRowActivate={(rowId) => {
          const match = matches.find((item) => item.id === rowId);
          if (match) onEdit(match);
        }}
        columns={[
          { key: "fixture", label: "Fixture", priority: "primary", sortable: true, sortDirection: matchCollection.sortDirectionFor("fixture"), onSort: () => matchCollection.toggleSort("fixture") },
          { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: matchCollection.sortDirectionFor("status"), onSort: () => matchCollection.toggleSort("status") },
          { key: "kickoff", label: "Kickoff", priority: "primary", sortable: true, sortDirection: matchCollection.sortDirectionFor("kickoff"), onSort: () => matchCollection.toggleSort("kickoff") },
          { key: "sales", label: "Sales", priority: "secondary", sortable: true, sortDirection: matchCollection.sortDirectionFor("sales"), onSort: () => matchCollection.toggleSort("sales") },
          { key: "score", label: "Score", priority: "secondary" },
          { key: "capacity", label: "Capacity", priority: "tertiary", sortable: true, sortDirection: matchCollection.sortDirectionFor("capacity"), onSort: () => matchCollection.toggleSort("capacity") },
          { key: "actions", label: "Actions", priority: "primary", className: "w-24" },
        ]}
      >
        {loading ? (
          Array.from({ length: 5 }).map((_, i) => (
            <tr key={i}>
              <td colSpan={7} className="p-4"><Skeleton className="skeleton-text h-4 w-full" /></td>
            </tr>
          ))
        ) : matchCollection.pageResult.items.length === 0 ? (
          <tr>
            <td colSpan={7}>
              <AdminEmptyState
                title="No fixtures found"
                description={matchCollection.query ? "No fixtures match the current search and status filters." : "Change filters or create a new fixture."}
                className="!min-h-[200px]"
              />
            </td>
          </tr>
        ) : (
          matchCollection.pageResult.items.map((match) => {
            const isLive = match.matchStatus === "live" || match.matchStatus === "halftime";
            return (
              <tr key={match.id} data-row-id={match.id} className={cn(isLive && "bg-emerald-500/[0.02]")}>
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
                      className="inline-flex min-h-12 min-w-12 items-center justify-center rounded hover:bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-100)] transition-colors"
                      aria-label={`Edit ${match.homeTeam} versus ${match.awayTeam}`}
                    >
                      <PencilLine size={16} />
                    </button>
                    <button
                      onClick={() => onDelete(match)}
                      className="inline-flex min-h-12 min-w-12 items-center justify-center rounded hover:bg-[var(--admin-zinc-800)] text-[var(--admin-zinc-500)] hover:text-rose-500 transition-colors"
                      aria-label={`Delete ${match.homeTeam} versus ${match.awayTeam}`}
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
      <AdminPagination page={matchCollection.pageResult} onPageChange={matchCollection.setPage} label="Match operations" />
    </div>
  );
}
