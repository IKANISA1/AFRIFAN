"use client";

import { useCallback, useState } from "react";
import { Plus, Search, Trophy } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import {
  deleteAdminStandingRow,
  getAdminStandings,
  normalizeAdminStandings,
} from "@/lib/data/admin/standings";
import type { AdminStandingRow } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { cn } from "@/lib/utils";
import { StandingEditorForm } from "./_components/standing-editor-form";
import { emptyForm, type StandingForm } from "./_components/standing-state";

const formBadge: Record<string, string> = {
  W: "bg-success/18 text-success",
  D: "bg-[var(--admin-zinc-800)] text-[var(--admin-text-strong)]",
  L: "bg-error/18 text-error",
};

const emptyStandings: AdminStandingRow[] = [];
const standingsAreEmpty = (rows: AdminStandingRow[]) => rows.length === 0;

const standingsStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading standings operations",
    detail: "Waiting for the first authenticated competition snapshot.",
  },
  ready: {
    label: "Standings operations confirmed",
    detail: "League positions, form, and points are current.",
  },
  empty: {
    label: "No standings in this scope",
    detail: "Add the first club or change the active club scope.",
  },
  error: {
    label: "Standings operations unavailable",
    detail: "Confirmed standings remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Standings workspace is offline",
    detail: "Confirmed standings remain visible until connection returns.",
  },
  permission_denied: {
    label: "Standings access denied",
    detail: "Previously loaded competition data has been cleared.",
  },
  syncing: {
    label: "Refreshing standings operations",
    detail: "Confirmed standings remain visible during refresh.",
  },
  conflict: {
    label: "Standings records changed",
    detail: "Refresh before editing or removing the current standings rows.",
  },
  security_timeout: {
    label: "Standings request timed out",
    detail: "No standings operation or change was confirmed.",
  },
};

export default function AdminStandingsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [form, setForm] = useState<StandingForm>(emptyForm);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadStandings = useCallback(
    (signal: AbortSignal) => {
      if (client == null) {
        return Promise.resolve([]);
      }
      return getAdminStandings(client, access, { signal });
    },
    [access, client],
  );
  const handlePermissionDenied = useCallback(() => {
    setDrawerOpen(false);
    setForm(emptyForm);
    setInteraction("idle");
  }, []);

  const {
    data: rows,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptyStandings,
    isEmpty: standingsAreEmpty,
    load: loadStandings,
    normalize: normalizeAdminStandings,
    onPermissionDenied: handlePermissionDenied,
    resourceLabel: "Standings operations",
  });

  function beginEdit(row: AdminStandingRow) {
    setForm({
      id: row.id,
      expectedUpdatedAt: row.updatedAt,
      position: String(row.position),
      club: row.club,
      clubSlug: row.clubSlug ?? "",
      played: String(row.played),
      goalDifference: String(row.goalDifference),
      points: String(row.points),
      form: row.form.join(", "),
    });
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function beginCreate() {
    setForm(emptyForm);
    setDrawerOpen(true);
    setInteraction("selected");
  }

  async function removeRow(row: AdminStandingRow) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Remove",
        subject: row.club,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The selected league table row will be permanently removed.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminStandingRow(client, access, row.id, row.updatedAt);
      await refresh();
      showAdminToast(`${row.club} removed.`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? standingsStatusCopy.conflict.label
          : "Could not confirm standings row removal.",
        "error",
      );
    }
  }

  const focusRow = rows.find(
    (row) =>
      (row.clubId != null &&
        access.clubId != null &&
        String(row.clubId) === access.clubId) ||
      (activeClub != null && row.clubSlug === activeClub.clubSlug),
  );
  const rowCollection = useAdminCollection({
    records: rows,
    getId: (row) => row.id,
    getSearchValues: (row) => [
      row.club,
      row.clubSlug,
      row.position,
      row.points,
      row.form.join(" "),
    ],
    getSortValue: (
      row,
      key: "position" | "club" | "played" | "goalDifference" | "points",
    ) => {
      switch (key) {
        case "position":
          return row.position;
        case "club":
          return row.club;
        case "played":
          return row.played;
        case "goalDifference":
          return row.goalDifference;
        case "points":
          return row.points;
      }
    },
    initialSortKey: "position" as const,
    pageSize: 25,
  });
  const mutationLocked = busy || status === "permission_denied";

  return (
    <section
      className="admin-standings-state-surface section-grid !gap-6"
      data-admin-standings-status={status}
      data-admin-standings-interaction={interaction}
      data-admin-standings-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Competition"
        title="Standings"
        actions={
          <button
            type="button"
            onClick={beginCreate}
            disabled={mutationLocked}
            className="admin-action-button min-h-12 !bg-[var(--admin-accent)] !text-[var(--admin-zinc-950)] disabled:cursor-not-allowed disabled:!bg-[var(--admin-zinc-800)] disabled:!text-[var(--admin-text-strong)]"
          >
            <Plus size={16} aria-hidden="true" />
            <span>Add club</span>
          </button>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={standingsStatusCopy[status].label}
        detail={standingsStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh standings"
        selected={drawerOpen}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-standings-status"
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="League size"
          value={initialLoading ? "..." : `${rows.length} clubs`}
          icon={Trophy}
        />
        <AdminStateCard
          label="Active club position"
          value={initialLoading ? "..." : focusRow ? `#${focusRow.position}` : "-"}
          tone="info"
        />
        <AdminStateCard
          label="Active club tally"
          value={initialLoading ? "..." : focusRow ? `${focusRow.points} pts` : "-"}
        />
      </div>

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={standingsStatusCopy[status].label}
          description={standingsStatusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <div className="admin-surface">
          <AdminFilterBar>
            <label className="admin-search-field">
              <Search size={16} aria-hidden="true" />
              <span className="sr-only">Search standings</span>
              <input
                type="search"
                value={rowCollection.query}
                onChange={(event) =>
                  rowCollection.setQuery(event.target.value)
                }
                placeholder="Search club, position, or form"
              />
            </label>
          </AdminFilterBar>
          <AdminDataGrid
            caption="Competition standings"
            busy={initialLoading}
            onRowActivate={(rowId) => {
              const row = rows.find((item) => item.id === rowId);
              if (row && !mutationLocked) beginEdit(row);
            }}
            columns={[
              {
                key: "pos",
                label: "Pos",
                priority: "primary",
                className: "text-center",
                sortable: true,
                sortDirection: rowCollection.sortDirectionFor("position"),
                onSort: () => rowCollection.toggleSort("position"),
              },
              {
                key: "club",
                label: "Club",
                priority: "primary",
                sortable: true,
                sortDirection: rowCollection.sortDirectionFor("club"),
                onSort: () => rowCollection.toggleSort("club"),
              },
              {
                key: "played",
                label: "P",
                priority: "secondary",
                className: "text-center",
                sortable: true,
                sortDirection: rowCollection.sortDirectionFor("played"),
                onSort: () => rowCollection.toggleSort("played"),
              },
              {
                key: "gd",
                label: "GD",
                priority: "secondary",
                className: "text-center",
                sortable: true,
                sortDirection:
                  rowCollection.sortDirectionFor("goalDifference"),
                onSort: () => rowCollection.toggleSort("goalDifference"),
              },
              {
                key: "pts",
                label: "Pts",
                priority: "primary",
                className: "text-center",
                sortable: true,
                sortDirection: rowCollection.sortDirectionFor("points"),
                onSort: () => rowCollection.toggleSort("points"),
              },
              {
                key: "form",
                label: "Recent form",
                priority: "tertiary",
              },
              {
                key: "actions",
                label: "Actions",
                priority: "primary",
                className: "text-right",
              },
            ]}
          >
            {initialLoading ? (
              <tr>
                <td
                  colSpan={7}
                  className="py-8 text-center text-sm text-[var(--admin-zinc-400)]"
                >
                  Loading standings…
                </td>
              </tr>
            ) : rowCollection.pageResult.items.length === 0 ? (
              <tr>
                <td
                  colSpan={7}
                  className="py-8 text-center text-sm text-[var(--admin-zinc-400)]"
                >
                  {rowCollection.query
                    ? "No standings match the current search."
                    : "No standings rows found."}
                </td>
              </tr>
            ) : (
              rowCollection.pageResult.items.map((row) => {
                const isHighlighted =
                  (row.clubId != null &&
                    access.clubId != null &&
                    String(row.clubId) === access.clubId) ||
                  (activeClub != null &&
                    row.clubSlug === activeClub.clubSlug);
                return (
                  <tr
                    key={row.id}
                    data-row-id={row.id}
                    className={cn(isHighlighted && "bg-[var(--admin-accent)]/5")}
                  >
                    <td className="text-center font-mono text-xs text-[var(--admin-zinc-500)]">
                      {row.position}
                    </td>
                    <td>
                      <p className="admin-row-title">{row.club}</p>
                      {isHighlighted ? (
                        <span className="text-xs font-medium normal-case text-[var(--admin-accent)]">
                          Current focus
                        </span>
                      ) : null}
                    </td>
                    <td className="text-center font-medium">{row.played}</td>
                    <td className="text-center text-[var(--admin-zinc-400)]">
                      {row.goalDifference}
                    </td>
                    <td className="text-center font-medium text-[var(--admin-text-strong)]">
                      {row.points}
                    </td>
                    <td>
                      <div className="flex gap-1" aria-label={`${row.club} recent form`}>
                        {row.form.map((item, index) => (
                          <span
                            key={`${item}-${index}`}
                            className={cn(
                              "flex h-5 w-5 items-center justify-center rounded-full text-xs font-medium",
                              formBadge[item] || formBadge.D,
                            )}
                          >
                            {item}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="text-right">
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          disabled={mutationLocked}
                          onClick={() => beginEdit(row)}
                          aria-label={`Edit ${row.club}`}
                          className="admin-action-button min-h-12 min-w-12"
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          disabled={mutationLocked}
                          onClick={() => void removeRow(row)}
                          aria-label={`Remove ${row.club}`}
                          className="admin-action-button admin-action-button-danger min-h-12 min-w-12"
                        >
                          Remove
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </AdminDataGrid>
          <AdminPagination
            page={rowCollection.pageResult}
            onPageChange={rowCollection.setPage}
            label="Competition standings"
          />
        </div>
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={() => {
          setDrawerOpen(false);
          setInteraction("idle");
        }}
        title={form.id ? "Edit standing row" : "Add club to table"}
      >
        <StandingEditorForm
          form={form}
          setForm={setForm}
          client={client}
          access={access}
          onSaved={async () => {
            setDrawerOpen(false);
            setInteraction("idle");
            await refresh();
          }}
          onConflict={async () => {
            await refresh();
            showAdminToast(
              "Latest standings loaded. Your draft is retained; review it before restarting the edit.",
              "info",
            );
          }}
          onFailure={(caught) => {
            applyFailure(caught);
          }}
          onCancel={() => {
            setDrawerOpen(false);
            setInteraction("idle");
          }}
        />
      </AdminActionDrawer>
    </section>
  );
}
