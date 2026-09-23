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
  mutationDisabled: boolean;
  onEdit: (token: AdminFanEngagementToken) => void;
  onDelete: (token: AdminFanEngagementToken) => Promise<void>;
  onToggleActive: (token: AdminFanEngagementToken) => Promise<void>;
}

export function FetList({
  tokens,
  loading,
  mutationDisabled,
  onEdit,
  onDelete,
  onToggleActive,
}: FetListProps) {
  const tokenCollection = useAdminCollection({
    records: tokens,
    getId: (token) => token.id,
    getSearchValues: (token) => [
      token.code,
      token.itemName,
      token.description,
      token.templateScope,
      token.category,
      token.triggerCondition,
      token.activationTiming,
      token.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      token,
      key: "name" | "code" | "scope" | "category" | "value" | "status",
    ) => {
      switch (key) {
        case "name":
          return token.itemName;
        case "code":
          return token.code;
        case "scope":
          return token.templateScope;
        case "category":
          return token.category;
        case "value":
          return token.fetValue;
        case "status":
          return token.isActive;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });

  return (
    <section className="glass-panel rounded-[32px] p-6">
      <p className="font-display text-3xl font-medium normal-case leading-none">
        FET catalog
      </p>
      <AdminFilterBar
        className="mt-5"
        actions={
          <div className="flex flex-wrap gap-2">
            {(
              ["name", "code", "scope", "category", "value", "status"] as const
            ).map((key) => (
              <button
                key={key}
                type="button"
                data-active={tokenCollection.sortKey === key}
                onClick={() => tokenCollection.toggleSort(key)}
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
          <span className="sr-only">Search FET catalogue</span>
          <input
            type="search"
            value={tokenCollection.query}
            onChange={(event) => tokenCollection.setQuery(event.target.value)}
            placeholder="Search item, code, scope, category, or trigger"
          />
        </label>
      </AdminFilterBar>
      <div className="mt-5 space-y-3">
        {loading
          ? Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[26px] border border-border-soft bg-[var(--admin-surface-muted)] p-5"
              >
                <Skeleton className="skeleton-text h-6 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                <Skeleton className="skeleton-text mt-2 h-3 w-4/5" />
              </div>
            ))
          : null}
        {!loading && tokenCollection.pageResult.items.length === 0 ? (
          <p className="rounded-[24px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-4 text-sm text-[var(--admin-text)]">
            {tokenCollection.query
              ? "No FET items match the current search."
              : "No FET items configured yet."}
          </p>
        ) : null}
        {!loading &&
          tokenCollection.pageResult.items.map((token) => (
            <article
              key={token.id}
              className={cn(
                "card-interactive rounded-[26px] border border-[var(--admin-border)] p-5 transition",
                token.isActive
                  ? "bg-[var(--admin-surface)]"
                  : "bg-[var(--admin-surface-muted)]",
              )}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="rounded-full border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-2.5 py-1 font-mono text-xs normal-case tracking-normal text-[var(--admin-text)]">
                      {token.code}
                    </span>
                    <span
                      className={cn(
                        "rounded-full border px-3 py-1.5 text-xs font-semibold normal-case tracking-normal",
                        scopeColors[token.templateScope],
                      )}
                    >
                      {token.templateScope === "generic"
                        ? "Generic"
                        : "Club specific"}
                    </span>
                    <span className="rounded-full border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-3 py-1.5 text-xs font-semibold normal-case tracking-normal text-[var(--admin-text)]">
                      {token.category}
                    </span>
                  </div>
                  <p className="font-display text-2xl font-medium normal-case leading-none">
                    {token.itemName}
                  </p>
                  <p className="text-sm text-[var(--admin-text)]">
                    {token.description}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-display text-3xl font-medium text-[var(--admin-accent)]">
                    {token.fetValue}
                  </p>
                  <p className="text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">
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
                <div className="rounded-[20px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-3">
                  <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">
                    Trigger
                  </p>
                  <p className="mt-1 text-sm text-[var(--admin-text)]">
                    {token.triggerCondition}
                  </p>
                </div>
                <div className="rounded-[20px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-3">
                  <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">
                    Activation timing
                  </p>
                  <p className="mt-1 text-sm text-[var(--admin-text)]">
                    {token.activationTiming}
                  </p>
                </div>
              </div>

              {token.implementationNotes ? (
                <div className="mt-3 rounded-[20px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-3">
                  <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">
                    Implementation notes
                  </p>
                  <p className="mt-1 text-sm text-[var(--admin-text)]">
                    {token.implementationNotes}
                  </p>
                </div>
              ) : null}

              <div className="mt-4 flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={mutationDisabled}
                  onClick={() => onEdit(token)}
                  className="admin-action-button"
                >
                  Edit
                </button>
                <button
                  type="button"
                  disabled={mutationDisabled}
                  onClick={() => {
                    onToggleActive(token).catch(() => {});
                  }}
                  className="admin-action-button"
                >
                  <span className="inline-flex items-center gap-1.5">
                    <Power size={12} />
                    {token.isActive ? "Deactivate" : "Activate"}
                  </span>
                </button>
                <button
                  type="button"
                  disabled={mutationDisabled}
                  onClick={() => {
                    onDelete(token).catch(() => {});
                  }}
                  className="admin-action-button admin-action-button-danger"
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
      <AdminPagination
        page={tokenCollection.pageResult}
        onPageChange={tokenCollection.setPage}
        label="FET catalogue"
      />
    </section>
  );
}
