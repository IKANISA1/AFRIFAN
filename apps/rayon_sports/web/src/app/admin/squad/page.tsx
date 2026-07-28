"use client";

import Image from "next/image";
import { useCallback, useEffect, useState } from "react";
import { Users, Shield, Plus, Search } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { getAdminSquad, deleteAdminSquadPlayer } from "@/lib/data/admin/squad";
import type { AdminSquadPlayer } from "@/lib/data/admin/squad";
import { emptySquadForm, positionColor } from "./_components/squad-form-state";
import { SquadEditorForm } from "./_components/squad-form";
import { cn } from "@/lib/utils";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

type PositionFilter = "ALL" | "GOALKEEPER" | "DEFENDER" | "MIDFIELDER" | "FORWARD";

export default function AdminSquadPage() {
  const { access, client } = useAdminPortal();
  const [players, setPlayers] = useState<AdminSquadPlayer[]>([]);
  const [form, setForm] = useState(emptySquadForm);
  const [filter, setFilter] = useState<PositionFilter>("ALL");
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const loadSquad = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setPlayers(await getAdminSquad(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load squad.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    loadSquad().catch(() => {});
  }, [access.hasAccess, client, loadSquad]);

  function beginEdit(player: AdminSquadPlayer) {
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
  }

  function beginCreate() {
    setForm(emptySquadForm);
    setDrawerOpen(true);
  }

  async function removePlayer(player: AdminSquadPlayer) {
    if (client == null) return;
    if (!confirmAdminDestructiveAction({
      action: "Remove",
      subject: player.name,
      scope: `Active club ${access.clubId ?? "not selected"}`,
      impact: "The player profile will be removed from the squad list.",
      undo: "not_available",
    })) return;

    try {
      await deleteAdminSquadPlayer(
        client,
        access,
        player.id,
        player.updatedAt,
      );
      await loadSquad();
      showAdminToast(`${player.name} removed.`, "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await loadSquad();
      }
      showAdminToast(caught instanceof Error ? caught.message : "Could not remove player.", "error");
    }
  }

  const filteredPlayers = players.filter((player) => {
    if (filter === "ALL") return true;
    return player.role.toLowerCase().includes(filter.toLowerCase());
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
        case "name": return player.name;
        case "number": return player.number;
        case "role": return player.role;
        case "nationality": return player.nationality;
        case "status": return player.isActive;
      }
    },
    initialSortKey: "number" as const,
    pageSize: 25,
  });

  const positionCounts = {
    goalkeepers: players.filter((p) => p.role.toLowerCase().includes("goalkeeper")).length,
    defenders: players.filter((p) => p.role.toLowerCase().includes("defender")).length,
    midfielders: players.filter((p) => p.role.toLowerCase().includes("midfielder")).length,
    forwards: players.filter((p) => p.role.toLowerCase().includes("forward")).length,
  };

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Roster"
        title="Squad management"
        meta={
          <button
            onClick={beginCreate}
            className="admin-action-button !bg-club-accent !text-white"
          >
            <Plus size={14} /> Add Player
          </button>
        }
      />

      <div className="grid gap-4 md:grid-cols-4">
        <AdminStateCard label="Total Squad" value={loading ? "..." : players.length.toString()} icon={Users} />
        <AdminStateCard label="Defenders" value={loading ? "..." : positionCounts.defenders.toString()} icon={Shield} />
        <AdminStateCard label="Midfielders" value={loading ? "..." : positionCounts.midfielders.toString()} />
        <AdminStateCard label="Forwards" value={loading ? "..." : positionCounts.forwards.toString()} />
      </div>

      <div className="flex items-center gap-1 border-b border-[var(--admin-border)] overflow-x-auto no-scrollbar">
        {(["ALL", "GOALKEEPER", "DEFENDER", "MIDFIELDER", "FORWARD"] as PositionFilter[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setFilter(tab)}
            className={cn(
              "px-6 py-3 text-xs font-bold uppercase tracking-widest transition-colors relative",
              filter === tab ? "text-white" : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]"
            )}
          >
            {tab}
            {filter === tab && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-club-accent" />
            )}
          </button>
        ))}
      </div>

      {loadError && !loading ? (
        <AdminErrorState
          title="Squad could not be loaded"
          description={loadError}
          onRetry={() => { loadSquad().catch(() => {}); }}
        />
      ) : (
        <div className="admin-surface">
          <AdminFilterBar>
            <label className="admin-search-field">
              <Search size={16} aria-hidden="true" />
              <span className="sr-only">Search squad</span>
              <input type="search" value={playerCollection.query} onChange={(event) => playerCollection.setQuery(event.target.value)} placeholder="Search player, role, or nationality" />
            </label>
          </AdminFilterBar>
          <AdminDataGrid
            caption="Squad players"
            busy={loading}
            onRowActivate={(rowId) => {
              const player = players.find((item) => item.id === rowId);
              if (player) beginEdit(player);
            }}
            columns={[
              { key: "player", label: "Player", priority: "primary", sortable: true, sortDirection: playerCollection.sortDirectionFor("name"), onSort: () => playerCollection.toggleSort("name") },
              { key: "number", label: "No.", priority: "primary", className: "text-center", sortable: true, sortDirection: playerCollection.sortDirectionFor("number"), onSort: () => playerCollection.toggleSort("number") },
              { key: "role", label: "Role", priority: "primary", sortable: true, sortDirection: playerCollection.sortDirectionFor("role"), onSort: () => playerCollection.toggleSort("role") },
              { key: "nationality", label: "Nationality", priority: "secondary", sortable: true, sortDirection: playerCollection.sortDirectionFor("nationality"), onSort: () => playerCollection.toggleSort("nationality") },
              { key: "status", label: "Status", priority: "secondary", sortable: true, sortDirection: playerCollection.sortDirectionFor("status"), onSort: () => playerCollection.toggleSort("status") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
            {playerCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={6} className="py-8 text-center text-sm text-slate-400">{playerCollection.query ? "No players match the current search." : "No players found for this position."}</td></tr>
            ) : playerCollection.pageResult.items.map((player) => (
              <tr key={player.id} data-row-id={player.id}>
                <td>
                  <div className="flex items-center gap-3">
                    <div className="h-8 w-8 overflow-hidden rounded-full bg-[var(--admin-zinc-800)] border border-[var(--admin-border)]">
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
                        <div className="flex h-full w-full items-center justify-center text-[10px] font-bold text-[var(--admin-zinc-500)]">
                          {player.number}
                        </div>
                      )}
                    </div>
                    <p className="admin-row-title">{player.name}</p>
                  </div>
                </td>
                <td className="text-center font-bold text-club-accent">{player.number}</td>
                <td>
                   <span className={cn("inline-flex rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider", positionColor(player.role))}>
                     {player.role}
                   </span>
                </td>
                <td className="text-[var(--admin-zinc-400)]">{player.nationality}</td>
                <td>
                  <AdminStatusBadge
                    label={player.isActive ? "Active" : "Inactive"}
                    tone={player.isActive ? "success" : "neutral"}
                  />
                </td>
                <td className="text-right">
                   <div className="flex justify-end gap-2">
                      <button onClick={() => beginEdit(player)} className="admin-action-button">Edit</button>
                      <button onClick={() => removePlayer(player)} className="admin-action-button admin-action-button-danger">Remove</button>
                   </div>
                </td>
              </tr>
            ))}
          </AdminDataGrid>
          <AdminPagination page={playerCollection.pageResult} onPageChange={playerCollection.setPage} label="Squad players" />
        </div>
      )}

      <AdminActionDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={form.id ? "Edit player profile" : "Add new player"}
      >
        <SquadEditorForm
          form={form}
          setForm={setForm}
          client={client}
          access={access}
          onSaved={async () => { setDrawerOpen(false); await loadSquad(); }}
          onConflict={async () => {
            await loadSquad();
            showAdminToast(
              "Latest squad loaded. Your draft is retained; review it before restarting the edit.",
              "info",
            );
          }}
        />
      </AdminActionDrawer>
    </div>
  );
}
