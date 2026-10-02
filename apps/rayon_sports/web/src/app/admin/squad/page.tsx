"use client";

import Image from "next/image";
import { useCallback, useState } from "react";
import { Plus, Search, Shield, Users } from "lucide-react";
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
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import {
  deleteAdminSquadPlayer,
  getAdminSquad,
  normalizeAdminSquad,
  type AdminSquadPlayer,
} from "@/lib/data/admin/squad";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { cn } from "@/lib/utils";
import { SquadEditorForm } from "./_components/squad-form";
import { emptySquadForm, positionColor } from "./_components/squad-form-state";

type PositionFilter =
  | "ALL"
  | "GOALKEEPER"
  | "DEFENDER"
  | "MIDFIELDER"
  | "FORWARD";

const emptySquad: AdminSquadPlayer[] = [];
const squadIsEmpty = (players: AdminSquadPlayer[]) => players.length === 0;

const squadStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading squad operations",
    detail: "Waiting for the first authenticated roster snapshot.",
  },
  ready: {
    label: "Squad operations confirmed",
    detail: "Roster profiles and availability are current.",
  },
  empty: {
    label: "No players in this scope",
    detail: "Add the first player or change the active club scope.",
  },
  error: {
    label: "Squad operations unavailable",
    detail: "Confirmed players remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Squad workspace is offline",
    detail: "Confirmed players remain visible until connection returns.",
  },
  permission_denied: {
    label: "Squad access denied",
    detail: "Previously loaded player data has been cleared.",
  },
  syncing: {
    label: "Refreshing squad operations",
    detail: "Confirmed players remain visible during refresh.",
  },
  conflict: {
    label: "Squad records changed",
    detail: "Refresh before editing or removing the current player records.",
  },
  security_timeout: {
    label: "Squad request timed out",
    detail: "No roster operation or change was confirmed.",
  },
};

export default function AdminSquadPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState(emptySquadForm);
  const draft = useAdminMediaDraftScope(access, "squad_player");
  const [filter, setFilter] = useState<PositionFilter>("ALL");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadSquad = useCallback(
    (signal: AbortSignal) => {
      if (client == null) {
        return Promise.resolve([]);
      }
      return getAdminSquad(client, access, { signal });
    },
    [access, client],
  );
  const handlePermissionDenied = useCallback(() => {
    setDrawerOpen(false);
    setForm(emptySquadForm);
    setInteraction("idle");
  }, []);

  const {
    data: players,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptySquad,
    isEmpty: squadIsEmpty,
    load: loadSquad,
    normalize: normalizeAdminSquad,
    onPermissionDenied: handlePermissionDenied,
    resourceLabel: "Squad operations",
  });

  async function beginEdit(player: AdminSquadPlayer) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    setForm({
      id: player.id,
      expectedUpdatedAt: player.updatedAt,
      name: player.name,
      role: player.role,
      number: String(player.number),
      nationality: player.nationality,
      bio: player.bio,
      imageUrl: player.imageUrl ?? "",
      isActive: player.isActive,
    });
    setDrawerOpen(true);
    setInteraction("selected");
  }

  async function beginCreate() {
    // Reopen the retained unsaved composer for original-command recovery.
    if (form.id && !await draft.resetDraft(form.id)) return;
    if (!draft.scopeKey) return;
    if (form.id) setForm(emptySquadForm);
    setDrawerOpen(true);
    setInteraction("selected");
  }

  async function removePlayer(player: AdminSquadPlayer) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Remove",
        subject: player.name,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The player profile will be removed from the squad list.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminSquadPlayer(
        client,
        access,
        player.id,
        player.updatedAt,
      );
      await refresh();
      showAdminToast(`${player.name} removed.`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? squadStatusCopy.conflict.label
          : "Could not confirm player removal.",
        "error",
      );
    }
  }

  const filteredPlayers = players.filter((player) => {
    if (filter === "ALL") return true;
    return player.role.toLowerCase() === filter.toLowerCase();
  });
  const playerCollection = useAdminCollection({
    records: filteredPlayers,
    getId: (player) => player.id,
    getSearchValues: (player) => [
      player.name,
      player.role,
      player.number,
      player.nationality,
      player.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      player,
      key: "name" | "number" | "role" | "nationality" | "status",
    ) => {
      switch (key) {
        case "name":
          return player.name;
        case "number":
          return player.number;
        case "role":
          return player.role;
        case "nationality":
          return player.nationality;
        case "status":
          return player.isActive;
      }
    },
    initialSortKey: "number" as const,
    pageSize: 25,
  });

  const positionCounts = {
    defenders: players.filter((player) => player.role === "Defender").length,
    midfielders: players.filter((player) => player.role === "Midfielder")
      .length,
    forwards: players.filter((player) => player.role === "Forward").length,
  };
  const mutationLocked = busy || status === "permission_denied";

  return (
    <section
      className="admin-squad-state-surface section-grid !gap-6"
      data-admin-squad-status={status}
      data-admin-squad-interaction={interaction}
      data-admin-squad-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Roster"
        title="Squad management"
        actions={
          <button
            onClick={beginCreate}
            disabled={mutationLocked}
            className="admin-action-button min-h-12 !bg-[var(--admin-accent)] !text-[var(--admin-canvas)] disabled:cursor-not-allowed disabled:!bg-[var(--admin-raised)] disabled:!text-[var(--admin-text-strong)]"
          >
            <Plus size={16} aria-hidden="true" />
            <span>Add player</span>
          </button>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={squadStatusCopy[status].label}
        detail={squadStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh squad"
        selected={drawerOpen}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-squad-status"
      />

      <div className="grid gap-4 md:grid-cols-4">
        <AdminStateCard
          label="Total squad"
          value={initialLoading ? "..." : players.length.toString()}
          icon={Users}
        />
        <AdminStateCard
          label="Defenders"
          value={initialLoading ? "..." : positionCounts.defenders.toString()}
          icon={Shield}
        />
        <AdminStateCard
          label="Midfielders"
          value={initialLoading ? "..." : positionCounts.midfielders.toString()}
        />
        <AdminStateCard
          label="Forwards"
          value={initialLoading ? "..." : positionCounts.forwards.toString()}
        />
      </div>

      <div
        className="flex items-center gap-1 overflow-x-auto border-b border-[var(--admin-border)] no-scrollbar"
        role="group"
        aria-label="Filter squad by position"
      >
        {(
          [
            "ALL",
            "GOALKEEPER",
            "DEFENDER",
            "MIDFIELDER",
            "FORWARD",
          ] as PositionFilter[]
        ).map((tab) => (
          <button
            key={tab}
            type="button"
            aria-pressed={filter === tab}
            disabled={mutationLocked}
            onClick={() => setFilter(tab)}
            className={cn(
              "relative min-h-12 px-6 py-3 text-xs font-medium normal-case tracking-normal transition-colors motion-reduce:transition-none disabled:cursor-not-allowed disabled:opacity-70",
              filter === tab
                ? "text-[var(--admin-text-strong)]"
                : "text-[var(--admin-secondary)] hover:text-[var(--admin-foreground)]",
            )}
          >
            {tab}
            {filter === tab ? (
              <span
                aria-hidden="true"
                className="absolute inset-x-0 bottom-0 h-0.5 bg-[var(--admin-accent)]"
              />
            ) : null}
          </button>
        ))}
      </div>

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={squadStatusCopy[status].label}
          description={squadStatusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <div className="admin-surface">
          <AdminFilterBar>
            <label className="admin-search-field">
              <Search size={16} aria-hidden="true" />
              <span className="sr-only">Search squad</span>
              <input
                type="search"
                value={playerCollection.query}
                onChange={(event) =>
                  playerCollection.setQuery(event.target.value)
                }
                placeholder="Search player, role, or nationality"
              />
            </label>
          </AdminFilterBar>
          <AdminDataGrid
            caption="Squad players"
            busy={initialLoading}
            onRowActivate={(rowId) => {
              const player = players.find((item) => item.id === rowId);
              if (player && !mutationLocked) beginEdit(player);
            }}
            columns={[
              {
                key: "player",
                label: "Player",
                priority: "primary",
                sortable: true,
                sortDirection: playerCollection.sortDirectionFor("name"),
                onSort: () => playerCollection.toggleSort("name"),
              },
              {
                key: "number",
                label: "No.",
                priority: "primary",
                className: "text-center",
                sortable: true,
                sortDirection: playerCollection.sortDirectionFor("number"),
                onSort: () => playerCollection.toggleSort("number"),
              },
              {
                key: "role",
                label: "Role",
                priority: "primary",
                sortable: true,
                sortDirection: playerCollection.sortDirectionFor("role"),
                onSort: () => playerCollection.toggleSort("role"),
              },
              {
                key: "nationality",
                label: "Nationality",
                priority: "secondary",
                sortable: true,
                sortDirection:
                  playerCollection.sortDirectionFor("nationality"),
                onSort: () => playerCollection.toggleSort("nationality"),
              },
              {
                key: "status",
                label: "Status",
                priority: "secondary",
                sortable: true,
                sortDirection: playerCollection.sortDirectionFor("status"),
                onSort: () => playerCollection.toggleSort("status"),
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
                  colSpan={6}
                  className="py-8 text-center text-sm text-[var(--admin-secondary)]"
                >
                  Loading squad roster…
                </td>
              </tr>
            ) : playerCollection.pageResult.items.length === 0 ? (
              <tr>
                <td
                  colSpan={6}
                  className="py-8 text-center text-sm text-[var(--admin-secondary)]"
                >
                  {playerCollection.query
                    ? "No players match the current search."
                    : "No players found for this position."}
                </td>
              </tr>
            ) : (
              playerCollection.pageResult.items.map((player) => (
                <tr key={player.id} data-row-id={player.id}>
                  <td>
                    <div className="flex items-center gap-3">
                      <div className="h-8 w-8 overflow-hidden rounded-full border border-[var(--admin-border)] bg-[var(--admin-raised)]">
                        {player.imageUrl ? (
                          <Image
                            src={player.imageUrl}
                            alt=""
                            width={32}
                            height={32}
                            unoptimized
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-xs font-medium text-[var(--admin-secondary)]">
                            {player.number}
                          </div>
                        )}
                      </div>
                      <p className="admin-row-title">{player.name}</p>
                    </div>
                  </td>
                  <td className="text-center font-medium text-[var(--admin-accent)]">
                    {player.number}
                  </td>
                  <td>
                    <span
                      className={cn(
                        "inline-flex rounded-full px-2 py-0.5 text-xs font-medium normal-case tracking-normal",
                        positionColor(player.role),
                      )}
                    >
                      {player.role}
                    </span>
                  </td>
                  <td className="text-[var(--admin-secondary)]">
                    {player.nationality}
                  </td>
                  <td>
                    <AdminStatusBadge
                      label={player.isActive ? "Active" : "Inactive"}
                      tone={player.isActive ? "success" : "neutral"}
                    />
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-2">
                      <button
                        type="button"
                        disabled={mutationLocked}
                        onClick={() => beginEdit(player)}
                        aria-label={`Edit ${player.name}`}
                        className="admin-action-button min-h-12 min-w-12"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        disabled={mutationLocked}
                        onClick={() => void removePlayer(player)}
                        aria-label={`Remove ${player.name}`}
                        className="admin-action-button admin-action-button-danger min-h-12 min-w-12"
                      >
                        Remove
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </AdminDataGrid>
          <AdminPagination
            page={playerCollection.pageResult}
            onPageChange={playerCollection.setPage}
            label="Squad players"
          />
        </div>
      )}

      {draft.error && !drawerOpen ? <p role="alert">{draft.error}</p> : null}
      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={async () => { if (await draft.resetDraft(form.id || undefined)) { setForm(emptySquadForm); setDrawerOpen(false); setInteraction("idle"); } }}
        title={form.id ? "Edit player profile" : "Add new player"}
      >
        <SquadEditorForm
          form={form}
          setForm={setForm}
          draft={draft}
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
              "Latest squad loaded. Your draft is retained; review it before restarting the edit.",
              "info",
            );
          }}
          onFailure={(caught) => {
            applyFailure(caught);
          }}
          onCancel={async () => { if (await draft.resetDraft(form.id || undefined)) { setForm(emptySquadForm); setDrawerOpen(false); setInteraction("idle"); } }}
        />
      </AdminActionDrawer>
    </section>
  );
}
