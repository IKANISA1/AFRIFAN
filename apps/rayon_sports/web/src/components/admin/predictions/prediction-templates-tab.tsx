"use client";

import { Search } from "lucide-react";
import { AdminFilterBar } from "../admin-filter-bar";
import { AdminStatusBadge } from "../admin-status-badge";
import { AdminPagination } from "../admin-pagination";
import { cn } from "@/lib/utils";
import type { AdminPredictionMarket } from "@/lib/data/admin/predictions";
import type { usePredictionTemplatesTab } from "./use-prediction-tabs";

export function PredictionTemplatesTab({ marketCollection, markets, globalMutationLocked, toggleMarketActive }: {
  marketCollection: ReturnType<typeof usePredictionTemplatesTab>;
  markets: AdminPredictionMarket[];
  globalMutationLocked: boolean;
  toggleMarketActive: (market: AdminPredictionMarket) => Promise<void>;
}) {
  return (
    <div className="space-y-3">
      <p className="font-display text-2xl font-medium normal-case">
        Prediction Templates ({markets.length})
      </p>
      <AdminFilterBar
        actions={
          <div className="flex flex-wrap gap-2">
            {(
              [
                "name",
                "category",
                "difficulty",
                "value",
                "status",
              ] as const
            ).map((key) => (
              <button
                key={key}
                type="button"
                data-active={marketCollection.sortKey === key}
                onClick={() => marketCollection.toggleSort(key)}
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
          <span className="sr-only">
            Search prediction templates
          </span>
          <input
            type="search"
            value={marketCollection.query}
            onChange={(event) =>
              marketCollection.setQuery(event.target.value)
            }
            placeholder="Search template, league, category, difficulty, or state"
          />
        </label>
      </AdminFilterBar>
      {marketCollection.pageResult.items.length === 0 ? (
        <p className="text-sm text-[var(--admin-text-muted)]">
          {marketCollection.query
            ? "No prediction templates match the current search."
            : "No prediction templates found."}
        </p>
      ) : null}
      <div className="space-y-2">
        {marketCollection.pageResult.items.map((market) => (
          <div
            key={market.id}
            data-inactive={!market.isActive}
            className={cn(
              "admin-predictions-catalog-card flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition",
              market.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
            )}
          >
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[var(--admin-text-strong)] truncate">
                {market.name}
              </p>
              <p className="text-xs text-[var(--admin-text-muted)] mt-0.5">
                {market.marketCategory} · {market.difficultyTier} ·{" "}
                {market.defaultFetValue} pts
              </p>
              {market.leagueAvailability.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-1">
                  {market.leagueAvailability.map((league) => (
                    <span
                      key={league}
                      className="rounded-full border border-border-soft px-2 py-0.5 text-xs text-[var(--admin-text-muted)]"
                    >
                      {league}
                    </span>
                  ))}
                </div>
              )}
            </div>
            <AdminStatusBadge
              label={market.isActive ? "Active" : "Disabled"}
              tone={market.isActive ? "success" : "neutral"}
            />
            <button
              type="button"
              onClick={() => {
                toggleMarketActive(market).catch(() => {});
              }}
              disabled={globalMutationLocked}
              className="admin-predictions-catalog-action rounded-full border border-border-soft px-3 py-2 text-xs font-semibold text-[var(--admin-text-muted)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed"
            >
              {market.isActive ? "Disable" : "Enable"}
            </button>
          </div>
        ))}
      </div>
      <AdminPagination
        page={marketCollection.pageResult}
        onPageChange={marketCollection.setPage}
        label="Prediction templates"
      />
    </div>
  );
}
