"use client";

import { Search } from "lucide-react";
import { AdminFilterBar } from "../admin-filter-bar";
import { AdminStatusBadge } from "../admin-status-badge";
import { AdminPagination } from "../admin-pagination";
import { cn } from "@/lib/utils";
import type { AdminSeason } from "@/lib/data/admin/predictions";
import type { useSeasonTab } from "./use-prediction-tabs";

export function SeasonTab({ seasonCollection, seasons }: {
  seasonCollection: ReturnType<typeof useSeasonTab>;
  seasons: AdminSeason[];
}) {
  return (
    <div className="space-y-3">
      <p className="font-display text-2xl font-medium normal-case">
        Seasons ({seasons.length})
      </p>
      <AdminFilterBar
        actions={
          <div className="flex flex-wrap gap-2">
            {(
              [
                "competition",
                "label",
                "start",
                "end",
                "status",
              ] as const
            ).map((key) => (
              <button
                key={key}
                type="button"
                data-active={seasonCollection.sortKey === key}
                onClick={() => seasonCollection.toggleSort(key)}
                className="dashboard-chip"
              >
                Sort {key}
              </button>
            ))}
          </div>
        }
      >
        <label className="admin-search-field">
          <Search size={16} aria-hidden="true" />
          <span className="sr-only">Search seasons</span>
          <input
            type="search"
            value={seasonCollection.query}
            onChange={(event) =>
              seasonCollection.setQuery(event.target.value)
            }
            placeholder="Search competition, season, date, or status"
          />
        </label>
      </AdminFilterBar>
      {seasonCollection.pageResult.items.length === 0 ? (
        <p className="text-sm text-[var(--admin-text-muted)]">
          {seasonCollection.query
            ? "No seasons match the current search."
            : "No seasons found."}
        </p>
      ) : null}
      <div className="space-y-2">
        {seasonCollection.pageResult.items.map((season) => (
          <div
            key={season.id}
            data-inactive={!season.isActive}
            className={cn(
              "admin-predictions-catalog-card flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition",
              season.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
            )}
          >
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[var(--admin-text-strong)]">
                {season.competitionName} — {season.label}
              </p>
              <p className="text-xs text-[var(--admin-text-muted)] mt-0.5">
                {season.startsOn ?? "Start not recorded"} →{" "}
                {season.endsOn ?? "End not recorded"} ·{" "}
                {season.status}
              </p>
            </div>
            <AdminStatusBadge
              label={season.status}
              tone={
                season.status === "active" ? "success" : "neutral"
              }
            />
          </div>
        ))}
      </div>
      <AdminPagination
        page={seasonCollection.pageResult}
        onPageChange={seasonCollection.setPage}
        label="Competition seasons"
      />
    </div>
  );
}
