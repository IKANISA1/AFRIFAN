"use client";

import { useCallback, useEffect, useState } from "react";
import { Trophy } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
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
import { StandingList } from "./_components/standing-list";

export default function AdminStandingsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [rows, setRows] = useState<AdminStandingRow[]>([]);
  const [form, setForm] = useState<StandingForm>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setRows(await getAdminStandings(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "Could not load standings.";
      setLoadError(message);
      showAdminToast(
        message,
        "error",
      );
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
    showAdminToast(`Editing ${row.club}.`, "info");
  }

  async function removeRow(row: AdminStandingRow) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        subject: row.club,
        detail: "The selected league table row will be permanently removed.",
      })
    ) {
      return;
    }

    try {
      await deleteAdminStandingRow(client, access, row.id);
      await load();
      showAdminToast(`${row.club} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove row.",
        "error",
      );
    }
  }

  const focusRow = rows.find(
    (row) =>
      (row.clubId != null && access.clubId != null && String(row.clubId) === access.clubId) ||
      (activeClub != null && row.clubSlug === activeClub.clubSlug),
  );

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Competition"
        title="Standings"
        description="Maintain the league table and keep the active club's position in view."
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Clubs"
          value={loading ? "..." : rows.length.toString()}
          helper="Table rows."
          icon={Trophy}
        />
        <AdminStateCard
          label="Club position"
          value={loading ? "..." : focusRow ? `#${focusRow.position}` : "-"}
          helper="League position."
        />
        <AdminStateCard
          label="Club points"
          value={loading ? "..." : focusRow ? focusRow.points.toString() : "-"}
          helper="Points tally."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.85fr_1.15fr]">
        <StandingEditorForm
          form={form}
          setForm={setForm}
          client={client}
          access={access}
          onSaved={load}
        />
        {loadError && !loading ? (
          <AdminErrorState
            title="Standings could not be loaded"
            description={loadError}
            onRetry={() => {
              load().catch(() => {});
            }}
          />
        ) : (
          <StandingList
            rows={rows}
            loading={loading}
            highlightedClubId={access.clubId}
            highlightedClubSlug={activeClub?.clubSlug ?? null}
            onEdit={beginEdit}
            onDelete={removeRow}
          />
        )}
      </div>
    </div>
  );
}
