"use client";

import { Search } from "lucide-react";
import { AdminFilterBar } from "../admin-filter-bar";
import { AdminStatusBadge } from "../admin-status-badge";
import { AdminPagination } from "../admin-pagination";
import { AdminLegacyPartnerReconciliation } from "../admin-legacy-partner-reconciliation";
import type { AdminAccess } from "@/lib/types";
import type { AdminPartnerPredictionPool } from "@/lib/data/admin/partner-pools";
import type { AdminFixture } from "@/lib/data/admin/predictions";
import type { useHistoricalPoolsTab } from "./use-prediction-tabs";
import { statusTone } from "./prediction-presenters";

export function HistoricalPoolsTab({ poolCollection, partnerPools, fixtureById, access, mutationLocked, refresh }: {
  poolCollection: ReturnType<typeof useHistoricalPoolsTab>;
  partnerPools: AdminPartnerPredictionPool[];
  fixtureById: Map<string, AdminFixture>;
  access: AdminAccess;
  mutationLocked: boolean;
  refresh: () => Promise<void>;
}) {
  return (
    <div className="space-y-6">
      <div>
        <p className="font-display text-2xl font-medium normal-case">
          Historical partner pools ({partnerPools.length})
        </p>
        <p className="mt-1 text-sm text-[var(--admin-text-muted)]">
          Previous paid entries and liabilities remain visible. Creation and
          settlement require the approved service reconciliation process.
          Global operators can reconcile existing liabilities below.
        </p>
      </div>

      <AdminFilterBar
        actions={
          <div className="flex flex-wrap gap-2">
            {(
              [
                "title",
                "partner",
                "status",
                "stake",
                "entries",
              ] as const
            ).map((key) => (
              <button
                key={key}
                type="button"
                data-active={poolCollection.sortKey === key}
                onClick={() => poolCollection.toggleSort(key)}
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
            Search partner prediction pools
          </span>
          <input
            type="search"
            value={poolCollection.query}
            onChange={(event) =>
              poolCollection.setQuery(event.target.value)
            }
            placeholder="Search pool, partner, fixture, eligibility, or status"
          />
        </label>
      </AdminFilterBar>
      {poolCollection.pageResult.items.length === 0 ? (
        <p className="rounded-[24px] border border-dashed border-border-soft bg-[var(--admin-surface-muted)] p-5 text-sm text-[var(--admin-text-muted)]">
          {poolCollection.query
            ? "No partner WDW pools match the current search."
            : "No partner WDW pools yet."}
        </p>
      ) : null}

      <div className="space-y-3">
        {poolCollection.pageResult.items.map((pool) => {
          const fixture = fixtureById.get(pool.fixtureId);
          return (
            <article
              key={pool.id}
              className="admin-predictions-pool-card rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)] p-5"
            >
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-semibold text-[var(--admin-text-strong)]">
                      {pool.title}
                    </p>
                    <AdminStatusBadge
                      label={pool.status}
                      tone={statusTone(pool.status)}
                    />
                  </div>
                  <p className="mt-1 text-sm text-[var(--admin-text-muted)]">
                    {pool.partnerName} ·{" "}
                    {fixture
                      ? `${fixture.homeTeamName} versus ${fixture.awayTeamName}`
                      : "Linked fixture unavailable"}
                  </p>
                  <p className="mt-2 text-xs text-[var(--admin-text-muted)]">
                    Partner {pool.partnerStakeFet.toLocaleString()}{" "}
                    pts · Fan entry{" "}
                    {pool.fanEntryFet.toLocaleString()} pts ·{" "}
                    {pool.totalEntries} entries ·{" "}
                    {pool.eligibilityMode.replaceAll("_", " ")}
                  </p>
                  {pool.settlement ? (
                    <p className="mt-2 text-xs text-[var(--admin-text-muted)]">
                      Result review:{" "}
                      {pool.settlement.settlementMode.replaceAll(
                        "_",
                        " ",
                      )}{" "}
                      · credited{" "}
                      {pool.settlement.totalPaidFet.toLocaleString()}{" "}
                      pts · ineligible winners{" "}
                      {pool.settlement.ineligibleWinners}
                    </p>
                  ) : null}
                </div>
                <div className="space-y-3">
                  <p className="text-sm text-[var(--admin-text-muted)]">
                    {pool.settlement ? "Service reconciliation recorded" : "Awaiting service reconciliation"}
                  </p>
                  <AdminLegacyPartnerReconciliation key={`${access.userId}:${access.clubId}:${pool.id}`} pool={pool} disabled={mutationLocked} onConfirmed={refresh} />
                </div>
              </div>
            </article>
          );
        })}
      </div>
      <AdminPagination
        page={poolCollection.pageResult}
        onPageChange={poolCollection.setPage}
        label="Partner prediction pools"
      />
    </div>
  );
}
