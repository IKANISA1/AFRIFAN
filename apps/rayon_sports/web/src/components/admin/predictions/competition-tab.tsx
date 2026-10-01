"use client";

import { Search } from "lucide-react";
import { AdminFilterBar } from "../admin-filter-bar";
import { AdminStatusBadge } from "../admin-status-badge";
import { AdminPagination } from "../admin-pagination";
import { cn } from "@/lib/utils";
import type { AdminCompetition } from "@/lib/data/admin/predictions";
import type { useCompetitionTab } from "./use-prediction-tabs";

export function CompetitionTab({ competitionCollection, competitions, globalMutationLocked, toggleCompetitionActive }: {
  competitionCollection: ReturnType<typeof useCompetitionTab>;
  competitions: AdminCompetition[];
  globalMutationLocked: boolean;
  toggleCompetitionActive: (competition: AdminCompetition) => Promise<void>;
}) {
  return (
    <div className="space-y-3">
      <p className="font-display text-2xl font-medium normal-case">
        Competitions ({competitions.length})
      </p>
      <AdminFilterBar
        actions={
          <div className="flex flex-wrap gap-2">
            {(["name", "kind", "region", "status"] as const).map(
              (key) => (
                <button
                  key={key}
                  type="button"
                  data-active={
                    competitionCollection.sortKey === key
                  }
                  onClick={() =>
                    competitionCollection.toggleSort(key)
                  }
                  className="dashboard-chip"
                >
                  Sort {key}
                </button>
              ),
            )}
          </div>
        }
      >
        <label className="admin-search-field">
          <Search size={16} aria-hidden="true" />
          <span className="sr-only">Search competitions</span>
          <input
            type="search"
            value={competitionCollection.query}
            onChange={(event) =>
              competitionCollection.setQuery(event.target.value)
            }
            placeholder="Search competition, kind, region, or state"
          />
        </label>
      </AdminFilterBar>
      {competitionCollection.pageResult.items.length === 0 ? (
        <p className="text-sm text-[var(--admin-text-muted)]">
          {competitionCollection.query
            ? "No competitions match the current search."
            : "No competitions found."}
        </p>
      ) : null}
      <div className="grid gap-3 sm:grid-cols-2">
        {competitionCollection.pageResult.items.map((comp) => (
          <div
            key={comp.id}
            data-inactive={!comp.isActive}
            className={cn(
              "admin-predictions-catalog-card rounded-[22px] border border-border-soft p-4 transition",
              comp.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
            )}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="font-semibold text-[var(--admin-text-strong)] truncate">
                  {comp.name}
                </p>
                <p className="text-xs text-[var(--admin-text-muted)] mt-0.5">
                  {comp.shortName} · {comp.competitionKind} ·{" "}
                  {comp.countryName || comp.region}
                </p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <AdminStatusBadge
                  label={comp.isActive ? "Active" : "Disabled"}
                  tone={comp.isActive ? "success" : "neutral"}
                />
                <button
                  type="button"
                  onClick={() => {
                    toggleCompetitionActive(comp).catch(() => {});
                  }}
                  disabled={globalMutationLocked}
                  className="admin-predictions-catalog-action rounded-full border border-border-soft px-3 py-2 text-xs font-semibold text-[var(--admin-text-muted)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed"
                >
                  {comp.isActive ? "Disable" : "Enable"}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
      <AdminPagination
        page={competitionCollection.pageResult}
        onPageChange={competitionCollection.setPage}
        label="Competitions"
      />
    </div>
  );
}
