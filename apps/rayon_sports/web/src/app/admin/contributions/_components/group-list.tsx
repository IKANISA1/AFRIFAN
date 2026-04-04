"use client";

import { Trash2 } from "lucide-react";
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
    <section className="glass-panel rounded-[32px] p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-2">
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
        <button
          type="button"
          onClick={onExportExcel}
          className="rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-club-secondary"
        >
          Export Excel
        </button>
      </div>

      <div className="mt-5 space-y-3">
        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                <Skeleton className="skeleton-text h-6 w-2/5" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                <Skeleton className="mt-4 h-3 w-full rounded-full" />
              </div>
            ))}
          </div>
        ) : null}
        {!loading && filteredGroups.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            No contribution groups match the current view.
          </p>
        ) : null}
        {!loading &&
          filteredGroups.map((group) => {
            const creatorAlias = group.creatorId
              ? snapshot.aliases[group.creatorId] ?? "000000"
              : "000000";

            return (
              <article
                key={group.id}
                className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-display text-2xl font-bold uppercase leading-none">
                        {group.name}
                      </p>
                      <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">
                        {group.groupType}
                      </span>
                      <span
                        className={`rounded-full border px-3 py-1.5 text-xs uppercase tracking-[0.18em] ${
                          group.isClosed
                            ? "border-rose-400/30 text-rose-300"
                            : "border-emerald-500/30 text-emerald-400"
                        }`}
                      >
                        {group.isClosed ? "Closed" : "Active"}
                      </span>
                    </div>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      {group.description}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => onEdit(group)}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => onDelete(group)}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                    >
                      <span className="inline-flex items-center gap-1.5">
                        <Trash2 size={12} />
                        Delete
                      </span>
                    </button>
                  </div>
                </div>
                <div className="mt-4">
                  <ProgressBar
                    value={group.currentTotal}
                    max={group.targetAmount}
                    label="Funding progress"
                    compact
                  />
                </div>
                <div className="mt-4 grid gap-3 sm:grid-cols-4">
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">Total</p>
                    <p className="mt-2 text-sm text-slate-200">{formatCurrency(group.currentTotal)}</p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">Target</p>
                    <p className="mt-2 text-sm text-slate-200">{formatCurrency(group.targetAmount)}</p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">Members</p>
                    <p className="mt-2 text-sm text-slate-200">{group.memberCount}</p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">Creator</p>
                    <p className="mt-2 text-sm text-slate-200">{creatorAlias}</p>
                  </div>
                </div>
              </article>
            );
          })}
      </div>
    </section>
  );
}
