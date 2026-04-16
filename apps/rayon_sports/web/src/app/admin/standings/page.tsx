"use client";

import { useCallback, useEffect, useState } from "react";
import { Trophy, Plus, Search } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminStandingRow,
  getAdminStandings,
} from "@/lib/data/admin/standings";
import type { AdminStandingRow } from "@/lib/types";
import { emptyForm, type StandingForm } from "./_components/standing-state";
import { StandingEditorForm } from "./_components/standing-editor-form";
import { cn } from "@/lib/utils";

const formBadge: Record<string, string> = {
  W: "bg-emerald-500/18 text-emerald-300",
  D: "bg-white/8 text-slate-200",
  L: "bg-rose-500/18 text-rose-300",
};

export default function AdminStandingsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [rows, setRows] = useState<AdminStandingRow[]>([]);
  const [form, setForm] = useState<StandingForm>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setRows(await getAdminStandings(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load standings.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

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
    setDrawerOpen(true);
  }

  function beginCreate() {
    setForm(emptyForm);
    setDrawerOpen(true);
  }

  async function removeRow(row: AdminStandingRow) {
    if (client == null) return;
    if (!confirmAdminDestructiveAction({
      subject: row.club,
      detail: "The selected league table row will be permanently removed.",
    })) return;

    try {
      await deleteAdminStandingRow(client, access, row.id);
      await load();
      showAdminToast(`${row.club} removed.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not remove row.", "error");
    }
  }

  const focusRow = rows.find(
    (row) =>
      (row.clubId != null && access.clubId != null && String(row.clubId) === access.clubId) ||
      (activeClub != null && row.clubSlug === activeClub.clubSlug),
  );

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Competition"
        title="Standings"
        meta={
          <button
            onClick={beginCreate}
            className="admin-action-button !bg-club-accent !text-white"
          >
            <Plus size={14} /> Add Club
          </button>
        }
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="League Size"
          value={loading ? "..." : `${rows.length} clubs`}
          icon={Trophy}
        />
        <AdminStateCard
          label="Active Club Pos"
          value={loading ? "..." : focusRow ? `#${focusRow.position}` : "-"}
          tone="info"
        />
        <AdminStateCard
          label="Tally"
          value={loading ? "..." : focusRow ? `${focusRow.points} pts` : "-"}
        />
      </div>

      {loadError && !loading ? (
        <AdminErrorState
          title="Standings could not be loaded"
          description={loadError}
          onRetry={() => { load().catch(() => {}); }}
        />
      ) : (
        <div className="admin-surface">
           <AdminDataGrid
            columns={[
              { key: "pos", label: "Pos", className: "text-center" },
              { key: "club", label: "Club" },
              { key: "played", label: "P", className: "text-center" },
              { key: "gd", label: "GD", className: "text-center" },
              { key: "pts", label: "Pts", className: "text-center" },
              { key: "form", label: "Recent Form" },
              { key: "actions", label: "", className: "text-right" },
            ]}
          >
            {rows.map((row) => {
              const isHighlighted = (row.clubId != null && access.clubId != null && String(row.clubId) === access.clubId) || (activeClub != null && row.clubSlug === activeClub.clubSlug);
              return (
                <tr key={row.id} className={cn(isHighlighted && "bg-club-accent/5")}>
                  <td className="text-center font-mono text-xs text-[var(--admin-zinc-500)]">{row.position}</td>
                  <td>
                    <p className="admin-row-title">{row.club}</p>
                    {isHighlighted && <span className="text-[9px] font-bold text-club-accent uppercase">Current Focus</span>}
                  </td>
                  <td className="text-center font-medium">{row.played}</td>
                  <td className="text-center text-[var(--admin-zinc-400)]">{row.goalDifference}</td>
                  <td className="text-center font-bold text-white">{row.points}</td>
                  <td>
                    <div className="flex gap-1">
                      {row.form.map((item, index) => (
                        <span key={index} className={cn("flex h-5 w-5 items-center justify-center rounded-full text-[8px] font-bold", formBadge[item] || formBadge.D)}>
                          {item}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-2">
                       <button onClick={() => beginEdit(row)} className="admin-action-button">Edit</button>
                       <button onClick={() => removeRow(row)} className="admin-action-button admin-action-button-danger">Remove</button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </AdminDataGrid>
        </div>
      )}

      <AdminActionDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={form.id ? "Edit standing row" : "Add club to table"}
      >
        <div className="p-1">
          <StandingEditorForm
            form={form}
            setForm={setForm}
            client={client}
            access={access}
            onSaved={async () => { setDrawerOpen(false); await load(); }}
          />
        </div>
      </AdminActionDrawer>
    </div>
  );
}
