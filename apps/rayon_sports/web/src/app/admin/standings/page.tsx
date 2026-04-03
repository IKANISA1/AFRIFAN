"use client";

import { useCallback, useEffect, useState } from "react";
import { Trash2, Trophy } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { cn } from "@/lib/utils";
import {
  deleteAdminStandingRow,
  getAdminStandings,
  saveAdminStandingRow,
} from "@/lib/data/admin";
import type { AdminStandingRow } from "@/lib/types";

type StandingForm = {
  id: string;
  position: string;
  club: string;
  clubSlug: string;
  played: string;
  goalDifference: string;
  points: string;
  form: string;
};

const emptyForm: StandingForm = {
  id: "",
  position: "",
  club: "",
  clubSlug: "",
  played: "0",
  goalDifference: "0",
  points: "0",
  form: "",
};

const formBadge: Record<string, string> = {
  W: "bg-emerald-500/18 text-emerald-300",
  D: "bg-white/8 text-slate-200",
  L: "bg-rose-500/18 text-rose-300",
};

export default function AdminStandingsPage() {
  const { access, client } = useAdminPortal();
  const [rows, setRows] = useState<AdminStandingRow[]>([]);
  const [form, setForm] = useState<StandingForm>(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setRows(await getAdminStandings(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load standings.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

  function beginEdit(row: AdminStandingRow) {
    setForm({
      id: row.id,
      position: String(row.position),
      club: row.club,
      clubSlug: row.clubSlug ?? "",
      played: String(row.played),
      goalDifference: String(row.goalDifference),
      points: String(row.points),
      form: row.form.join(", "),
    });
    showAdminToast(`Editing ${row.club}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) return;

    showAdminToast(form.id ? "Saving row..." : "Adding row...", "info");
    try {
      await saveAdminStandingRow(client, access, {
        id: form.id || null,
        position: Number(formData.get("position") ?? 0),
        club: String(formData.get("club") ?? ""),
        clubSlug: String(formData.get("clubSlug") ?? "").trim() || null,
        played: Number(formData.get("played") ?? 0),
        goalDifference: Number(formData.get("goalDifference") ?? 0),
        points: Number(formData.get("points") ?? 0),
        form: String(formData.get("form") ?? "")
          .split(",")
          .map((item) => item.trim().toUpperCase())
          .filter(Boolean)
          .slice(0, 5),
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Standing row saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save standing.",
        "error",
      );
    }
  }

  async function removeRow(row: AdminStandingRow) {
    if (client == null) return;

    try {
      await deleteAdminStandingRow(client, row.id);
      await load();
      showAdminToast(`${row.club} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove row.",
        "error",
      );
    }
  }

  const rayon = rows.find(
    (row) =>
      row.club.toLowerCase().includes("rayon") ||
      row.clubSlug === "rayon_sports_rw",
  );

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Standings manager"
        title="Maintain the league table displayed on the public site."
        description="Add or update club positioning, points, and form indicators. Data feeds the standings page and the homepage table preview."
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Clubs"
          value={loading ? "..." : rows.length.toString()}
          helper="Total rows in the current standings table."
          icon={Trophy}
        />
        <AdminStateCard
          label="Rayon position"
          value={loading ? "..." : rayon ? `#${rayon.position}` : "-"}
          helper="Current league position for Rayon Sports."
        />
        <AdminStateCard
          label="Rayon points"
          value={loading ? "..." : rayon ? rayon.points.toString() : "-"}
          helper="Current points tally for the club."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.85fr_1.15fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              {form.id ? "Edit row" : "New row"}
            </p>
            {form.id ? (
              <button
                type="button"
                onClick={() => setForm(emptyForm)}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
              >
                Clear
              </button>
            ) : null}
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Position
              <input
                type="number"
                name="position"
                required
                min={1}
                value={form.position}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    position: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Club name
              <input
                name="club"
                required
                value={form.club}
                onChange={(event) =>
                  setForm((current) => ({ ...current, club: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Played
              <input
                type="number"
                name="played"
                value={form.played}
                onChange={(event) =>
                  setForm((current) => ({ ...current, played: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Goal diff
              <input
                type="number"
                name="goalDifference"
                value={form.goalDifference}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    goalDifference: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Points
              <input
                type="number"
                name="points"
                value={form.points}
                onChange={(event) =>
                  setForm((current) => ({ ...current, points: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="grid gap-2 text-sm">
            Club slug (optional)
            <input
              name="clubSlug"
              value={form.clubSlug}
              onChange={(event) =>
                setForm((current) => ({ ...current, clubSlug: event.target.value }))
              }
              placeholder="rayon_sports_rw"
              className="dashboard-input"
            />
          </label>

          <label className="grid gap-2 text-sm">
            Form (W, D, L comma separated)
            <input
              name="form"
              value={form.form}
              onChange={(event) =>
                setForm((current) => ({ ...current, form: event.target.value }))
              }
              placeholder="W, W, D, L, W"
              className="dashboard-input"
            />
          </label>

          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {form.id ? "Save row" : "Add row"}
          </button>
        </form>

        <section className="glass-panel overflow-hidden rounded-[32px] border border-border-soft">
          <div className="p-6">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              League table
            </p>
          </div>
          {loading ? (
            <div className="space-y-3 px-6 pb-6">
              {Array.from({ length: 5 }).map((_, index) => (
                <div key={index} className="flex gap-4">
                  <Skeleton className="h-8 w-10" />
                  <Skeleton className="skeleton-text h-8 flex-1" />
                </div>
              ))}
            </div>
          ) : rows.length === 0 ? (
            <p className="px-6 pb-6 text-sm text-slate-300">
              No standings data yet.
            </p>
          ) : (
            <table className="w-full text-left text-sm">
              <thead className="bg-white/8 text-xs uppercase tracking-[0.24em] text-slate-400">
                <tr>
                  <th className="px-4 py-3 text-center">Pos</th>
                  <th className="px-4 py-3">Club</th>
                  <th className="px-4 py-3 text-center">P</th>
                  <th className="px-4 py-3 text-center">GD</th>
                  <th className="px-4 py-3 text-center">Pts</th>
                  <th className="px-4 py-3">Form</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => {
                  const isRayon =
                    row.club.toLowerCase().includes("rayon") ||
                    row.clubSlug === "rayon_sports_rw";

                  return (
                    <tr
                      key={row.id}
                      className={cn(
                        "border-t border-white/6",
                        isRayon && "bg-club-primary/15",
                      )}
                    >
                      <td className="px-4 py-3 text-center font-mono text-xs text-slate-400">
                        {row.position}
                      </td>
                      <td className="px-4 py-3 font-semibold text-white">
                        {row.club}
                      </td>
                      <td className="px-4 py-3 text-center">{row.played}</td>
                      <td className="px-4 py-3 text-center">
                        {row.goalDifference}
                      </td>
                      <td className="px-4 py-3 text-center font-semibold text-white">
                        {row.points}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex gap-1">
                          {row.form.map((item, index) => (
                            <span
                              key={`${row.id}-${index}`}
                              className={cn(
                                "flex h-6 w-6 items-center justify-center rounded-full text-[9px] font-bold",
                                formBadge[item] ?? formBadge.D,
                              )}
                            >
                              {item}
                            </span>
                          ))}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex gap-1.5">
                          <button
                            type="button"
                            onClick={() => beginEdit(row)}
                            className="rounded-full border border-border-soft p-1.5 text-slate-300 transition hover:bg-white/8"
                            title="Edit"
                          >
                            <span className="text-[10px]">✏️</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              removeRow(row).catch(() => {});
                            }}
                            className="rounded-full border border-border-soft p-1.5 text-slate-300 transition hover:bg-rose-500/15 hover:text-rose-300"
                            title="Remove"
                          >
                            <Trash2 size={12} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </section>
      </div>
    </div>
  );
}
