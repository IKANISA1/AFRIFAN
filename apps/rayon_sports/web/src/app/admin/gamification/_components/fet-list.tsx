"use client";

import { Power, Search, Trash2 } from "lucide-react";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminFanEngagementToken } from "@/lib/types";
import { scopeColors } from "./fet-state";
import { useAdminCollection } from "@/lib/use-admin-collection";

interface FetListProps {
  tokens: AdminFanEngagementToken[];
  loading: boolean;
  onEdit: (token: AdminFanEngagementToken) => void;
  onDelete: (token: AdminFanEngagementToken) => Promise<void>;
  onToggleActive: (token: AdminFanEngagementToken) => Promise<void>;
}

export function FetList({
  tokens,
  loading,
  onEdit,
  onDelete,
  onToggleActive,
}: FetListProps) {
  const tokenCollection = useAdminCollection({
    records: tokens,
    getId: (token) => token.id,
    getSearchValues: (token) => [token.code, token.itemName, token.description, token.templateScope, token.category, token.triggerCondition, token.activationTiming, token.isActive ? "active" : "inactive"],
    getSortValue: (token, key: "name" | "code" | "scope" | "category" | "value" | "status") => {
      switch (key) {
        case "name": return token.itemName;
        case "code": return token.code;
        case "scope": return token.templateScope;
        case "category": return token.category;
        case "value": return token.fetValue;
        case "status": return token.isActive;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 20,
  });

  return (
    <section className="glass-panel rounded-[32px] p-6">
      <p className="font-display text-3xl font-bold uppercase leading-none">
        FET catalog
      </p>
      <AdminFilterBar className="mt-5" actions={<div className="flex flex-wrap gap-2">{(["name", "code", "scope", "category", "value", "status"] as const).map((key) => <button key={key} type="button" data-active={tokenCollection.sortKey === key} onClick={() => tokenCollection.toggleSort(key)} className="dashboard-chip">Sort {key}</button>)}</div>}>
        <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search FET catalogue</span><input type="search" value={tokenCollection.query} onChange={(event) => tokenCollection.setQuery(event.target.value)} placeholder="Search item, code, scope, category, or trigger" /></label>
      </AdminFilterBar>
      <div className="mt-5 space-y-3">
        {loading
          ? Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[26px] border border-border-soft bg-white/5 p-5"
              >
                <Skeleton className="skeleton-text h-6 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                <Skeleton className="skeleton-text mt-2 h-3 w-4/5" />
              </div>
            ))
          : null}
        {!loading && tokenCollection.pageResult.items.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            {tokenCollection.query ? "No FET items match the current search." : "No FET items configured yet."}
          </p>
        ) : null}
        {!loading &&
          tokenCollection.pageResult.items.map((token) => (
            <article
              key={token.id}
              className={cn(
                "card-interactive rounded-[26px] border border-border-soft p-5 transition",
                token.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-65",
              )}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="rounded-full border border-border-soft bg-black/20 px-2.5 py-1 font-mono text-[11px] uppercase tracking-[0.18em] text-slate-300">
                      {token.code}
                    </span>
                    <span
                      className={cn(
                        "rounded-full border px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.14em]",
                        scopeColors[token.templateScope],
                      )}
                    >
                      {token.templateScope === "generic"
                        ? "Generic"
                        : "Club specific"}
                    </span>
                    <span className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-300">
                      {token.category}
                    </span>
                  </div>
                  <p className="font-display text-2xl font-bold uppercase leading-none">
                    {token.itemName}
                  </p>
                  <p className="text-sm text-slate-300">
                    {token.description}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-display text-3xl font-bold text-club-accent">
                    {token.fetValue}
                  </p>
                  <p className="text-xs uppercase tracking-[0.16em] text-slate-400">
                    FET
                  </p>
                  {token.badgeName ? (
                    <p className="mt-2 text-2xl" aria-label="Badge">
                      {token.badgeName}
                    </p>
                  ) : null}
                </div>
              </div>

              <div className="mt-4 grid gap-3 lg:grid-cols-2">
                <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                  <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-400">
                    Trigger
                  </p>
                  <p className="mt-1 text-sm text-slate-200">
                    {token.triggerCondition}
                  </p>
                </div>
                <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                  <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-400">
                    Activation timing
                  </p>
                  <p className="mt-1 text-sm text-slate-200">
                    {token.activationTiming}
                  </p>
                </div>
              </div>

              {token.implementationNotes ? (
                <div className="mt-3 rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                  <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-slate-400">
                    Implementation notes
                  </p>
                  <p className="mt-1 text-sm text-slate-200">
                    {token.implementationNotes}
                  </p>
                </div>
              ) : null}

              <div className="mt-4 flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => onEdit(token)}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => {
                    onToggleActive(token).catch(() => {});
                  }}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-amber-200 transition hover:border-amber-400/30 hover:bg-amber-500/15"
                >
                  <span className="inline-flex items-center gap-1.5">
                    <Power size={12} />
                    {token.isActive ? "Deactivate" : "Activate"}
                  </span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    onDelete(token).catch(() => {});
                  }}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                >
                  <span className="inline-flex items-center gap-1.5">
                    <Trash2 size={12} />
                    Delete
                  </span>
                </button>
              </div>
            </article>
          ))}
      </div>
      <AdminPagination page={tokenCollection.pageResult} onPageChange={tokenCollection.setPage} label="FET catalogue" />
    </section>
  );
}
