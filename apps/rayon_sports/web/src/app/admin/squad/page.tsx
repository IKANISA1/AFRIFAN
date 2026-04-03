"use client";

import { useCallback, useEffect, useState } from "react";
import { Users, Shield, Trash2 } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { cn } from "@/lib/utils";
import {
  getAdminSquad,
  saveAdminSquadPlayer,
  deleteAdminSquadPlayer,
} from "@/lib/data/admin";
import type { AdminSquadPlayer } from "@/lib/data/admin";

const emptyForm = {
  id: "",
  name: "",
  role: "Midfielder",
  number: "",
  nationality: "Rwanda",
  bio: "",
  imageUrl: "",
  isActive: true,
};

const positionColors: Record<string, string> = {
  Goalkeeper: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  Defender: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  Midfielder: "bg-club-accent/15 text-club-accent border-club-accent/30",
  Forward: "bg-rose-500/15 text-rose-300 border-rose-500/30",
};

function positionColor(role: string) {
  const key = Object.keys(positionColors).find((item) =>
    role.toLowerCase().includes(item.toLowerCase()),
  );
  return positionColors[key ?? "Midfielder"] ?? positionColors.Midfielder;
}

export default function AdminSquadPage() {
  const { access, client } = useAdminPortal();
  const [players, setPlayers] = useState<AdminSquadPlayer[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [filter, setFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);

  const loadSquad = useCallback(async () => {
    if (client == null) {
      return;
    }

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
    if (client == null || !access.hasAccess) {
      return;
    }
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

  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    showAdminToast(form.id ? "Saving player..." : "Adding player...", "info");

    try {
      await saveAdminSquadPlayer(client, access, {
        id: form.id || null,
        name: String(formData.get("name") ?? ""),
        role: String(formData.get("role") ?? "Midfielder"),
        number: Number(formData.get("number") ?? 0),
        nationality: String(formData.get("nationality") ?? "Rwanda"),
        bio: String(formData.get("bio") ?? ""),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptyForm);
      await loadSquad();
      showAdminToast("Player saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save player.",
        "error",
      );
    }
  }

  async function removePlayer(player: AdminSquadPlayer) {
    if (client == null) {
      return;
    }

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

  const filteredPlayers = players.filter((player) => {
    if (filter === "ALL") return true;
    return player.role.toLowerCase().includes(filter.toLowerCase());
  });

  const positionCounts = {
    goalkeepers: players.filter((player) =>
      player.role.toLowerCase().includes("goalkeeper"),
    ).length,
    defenders: players.filter((player) =>
      player.role.toLowerCase().includes("defender"),
    ).length,
    midfielders: players.filter((player) =>
      player.role.toLowerCase().includes("midfielder"),
    ).length,
    forwards: players.filter((player) =>
      player.role.toLowerCase().includes("forward"),
    ).length,
  };

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Squad manager"
        title="Manage first-team player profiles published on the public site."
        description="Player profiles flow directly to the squad section. Update positions, shirt numbers, and bios here."
      />

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <AdminStateCard
          label="Total players"
          value={loading ? "..." : players.length.toString()}
          helper="All registered first-team players."
          icon={Users}
        />
        <AdminStateCard
          label="Defenders"
          value={loading ? "..." : positionCounts.defenders.toString()}
          helper="Players registered in defensive positions."
          icon={Shield}
        />
        <AdminStateCard
          label="Midfielders"
          value={loading ? "..." : positionCounts.midfielders.toString()}
          helper="Players registered in midfield positions."
        />
        <AdminStateCard
          label="Forwards"
          value={loading ? "..." : positionCounts.forwards.toString()}
          helper="Players registered in attacking positions."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              {form.id ? "Edit player" : "New player"}
            </p>
            {form.id ? (
              <button
                type="button"
                onClick={() => {
                  setForm(emptyForm);
                  showAdminToast("Form cleared.", "info");
                }}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
              >
                Clear
              </button>
            ) : null}
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Player name
              <input
                name="name"
                required
                value={form.name}
                onChange={(event) =>
                  setForm((current) => ({ ...current, name: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Shirt number
              <input
                type="number"
                name="number"
                required
                min={1}
                max={99}
                value={form.number}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    number: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Position
              <select
                name="role"
                value={form.role}
                onChange={(event) =>
                  setForm((current) => ({ ...current, role: event.target.value }))
                }
                className="dashboard-input"
              >
                <option value="Goalkeeper">Goalkeeper</option>
                <option value="Defender">Defender</option>
                <option value="Midfielder">Midfielder</option>
                <option value="Forward">Forward</option>
              </select>
            </label>
            <label className="grid gap-2 text-sm">
              Nationality
              <input
                name="nationality"
                value={form.nationality}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    nationality: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="grid gap-2 text-sm">
            Photo URL
            <input
              name="imageUrl"
              value={form.imageUrl}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  imageUrl: event.target.value,
                }))
              }
              className="dashboard-input"
            />
          </label>
          {form.imageUrl.trim() ? (
            <div className="flex justify-center">
              <div className="h-24 w-24 overflow-hidden rounded-full border-2 border-club-accent/30">
                <img
                  src={form.imageUrl}
                  alt="Player preview"
                  className="h-full w-full object-cover"
                />
              </div>
            </div>
          ) : null}

          <label className="grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span>Bio</span>
              <span className="font-mono text-[10px] text-slate-400">
                {form.bio.length} chars
              </span>
            </div>
            <textarea
              name="bio"
              rows={4}
              value={form.bio}
              onChange={(event) =>
                setForm((current) => ({ ...current, bio: event.target.value }))
              }
              className="dashboard-input min-h-28 resize-y"
            />
          </label>

          <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
            <input
              type="checkbox"
              name="isActive"
              checked={form.isActive}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  isActive: event.target.checked,
                }))
              }
            />
            Active in squad
          </label>

          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {form.id ? "Save player" : "Add player"}
          </button>
        </form>

        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Squad roster
            </p>
            <div className="flex flex-wrap gap-2">
              {["ALL", "GOALKEEPER", "DEFENDER", "MIDFIELDER", "FORWARD"].map(
                (item) => (
                  <button
                    key={item}
                    type="button"
                    data-active={filter === item}
                    onClick={() => setFilter(item)}
                    className="dashboard-chip"
                  >
                    {item}
                  </button>
                ),
              )}
            </div>
          </div>

          <div className="mt-5 space-y-3">
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-4 rounded-[26px] border border-border-soft bg-white/5 p-5"
                  >
                    <Skeleton className="h-14 w-14 flex-shrink-0 rounded-full" />
                    <div className="flex-1 space-y-2">
                      <Skeleton className="skeleton-text h-5 w-2/5" />
                      <Skeleton className="skeleton-text h-3 w-full" />
                    </div>
                  </div>
                ))}
              </div>
            ) : null}
            {!loading && filteredPlayers.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                {filter === "ALL"
                  ? "No players in the squad yet. Use the form to add the first player."
                  : `No ${filter.toLowerCase()}s found.`}
              </p>
            ) : null}
            {!loading &&
              filteredPlayers.map((player) => (
                <article
                  key={player.id}
                  className={cn(
                    "card-interactive flex items-start gap-4 rounded-[26px] border border-border-soft p-5 transition",
                    player.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60",
                  )}
                >
                  {player.imageUrl ? (
                    <div className="hidden sm:block h-14 w-14 flex-shrink-0 overflow-hidden rounded-full border-2 border-border-soft">
                      <img
                        src={player.imageUrl}
                        alt={player.name}
                        className="h-full w-full object-cover"
                      />
                    </div>
                  ) : (
                    <div className="hidden sm:flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-full border-2 border-border-soft bg-white/5 font-display text-xl font-bold text-club-accent">
                      {player.number}
                    </div>
                  )}
                  <div className="flex-1 min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-display text-2xl font-bold uppercase leading-none">
                        {player.name}
                      </p>
                      <span className="font-display text-lg font-bold text-club-accent">
                        #{player.number}
                      </span>
                    </div>
                    <p className="mt-1 truncate text-sm text-slate-300">
                      {player.nationality} • {player.bio}
                    </p>
                    <div className="mt-3 flex flex-wrap items-center gap-2">
                      <span
                        className={cn(
                          "rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]",
                          positionColor(player.role),
                        )}
                      >
                        {player.role}
                      </span>
                      {!player.isActive ? (
                        <span className="rounded-full border border-rose-400/30 bg-rose-500/10 px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-rose-300">
                          Inactive
                        </span>
                      ) : null}
                    </div>
                  </div>
                  <div className="flex flex-shrink-0 gap-2">
                    <button
                      type="button"
                      onClick={() => beginEdit(player)}
                      className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-white/8"
                      title="Edit"
                    >
                      <span className="text-xs">✏️</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        removePlayer(player).catch(() => {});
                      }}
                      className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-rose-500/15 hover:border-rose-400/30 hover:text-rose-300"
                      title="Remove"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </article>
              ))}
          </div>
        </section>
      </div>
    </div>
  );
}
