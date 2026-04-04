"use client";

import { useCallback, useEffect, useState } from "react";
import { Users, Shield } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import { getAdminSquad, deleteAdminSquadPlayer } from "@/lib/data/admin";
import type { AdminSquadPlayer } from "@/lib/data/admin";
import { emptySquadForm } from "./_components/squad-form-state";
import { SquadEditorForm } from "./_components/squad-form";
import { SquadList } from "./_components/squad-list";

export default function AdminSquadPage() {
  const { access, client } = useAdminPortal();
  const [players, setPlayers] = useState<AdminSquadPlayer[]>([]);
  const [form, setForm] = useState(emptySquadForm);
  const [filter, setFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);

  const loadSquad = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setPlayers(await getAdminSquad(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load squad.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    loadSquad().catch(() => {});
  }, [access.hasAccess, client, loadSquad]);

  function beginEdit(player: AdminSquadPlayer) {
    setForm({
      id: player.id,
      name: player.name,
      role: player.role,
      number: String(player.number),
      nationality: player.nationality,
      bio: player.bio,
      imageUrl: player.imageUrl ?? "",
      isActive: player.isActive,
    });
    showAdminToast(`Editing ${player.name}.`, "info");
  }

  async function removePlayer(player: AdminSquadPlayer) {
    if (client == null) return;
    showAdminToast(`Removing ${player.name}...`, "info");
    try {
      await deleteAdminSquadPlayer(client, player.id);
      await loadSquad();
      showAdminToast(`${player.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove player.",
        "error",
      );
    }
  }

  const positionCounts = {
    goalkeepers: players.filter((p) => p.role.toLowerCase().includes("goalkeeper")).length,
    defenders: players.filter((p) => p.role.toLowerCase().includes("defender")).length,
    midfielders: players.filter((p) => p.role.toLowerCase().includes("midfielder")).length,
    forwards: players.filter((p) => p.role.toLowerCase().includes("forward")).length,
  };

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Squad manager"
        title="Manage first-team player profiles published on the public site."
        description="Player profiles flow directly to the squad section. Update positions, shirt numbers, and bios here."
      />

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <AdminStateCard label="Total players" value={loading ? "..." : players.length.toString()} helper="All registered first-team players." icon={Users} />
        <AdminStateCard label="Defenders" value={loading ? "..." : positionCounts.defenders.toString()} helper="Players registered in defensive positions." icon={Shield} />
        <AdminStateCard label="Midfielders" value={loading ? "..." : positionCounts.midfielders.toString()} helper="Players registered in midfield positions." />
        <AdminStateCard label="Forwards" value={loading ? "..." : positionCounts.forwards.toString()} helper="Players registered in attacking positions." />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <SquadEditorForm form={form} setForm={setForm} client={client} access={access} onSaved={loadSquad} />
        <SquadList players={players} filter={filter} setFilter={setFilter} loading={loading} onEdit={beginEdit} onDelete={(p) => { removePlayer(p).catch(() => {}); }} />
      </div>
    </div>
  );
}
