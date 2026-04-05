"use client";

import { useCallback, useEffect, useState } from "react";
import { Trophy } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminStandingRow,
  getAdminStandings,
} from "@/lib/data/admin/standings";
import type { AdminStandingRow } from "@/lib/types";
import { emptyForm, type StandingForm } from "./_components/standing-state";
import { StandingEditorForm } from "./_components/standing-editor-form";
import { StandingList } from "./_components/standing-list";

export default function AdminStandingsPage() {
  const { access, client } = useAdminPortal();
  const [rows, setRows] = useState<AdminStandingRow[]>([]);
  const [form, setForm] = useState<StandingForm>(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setRows(await getAdminStandings(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load standings.",
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
        <StandingEditorForm
          form={form}
          setForm={setForm}
          client={client}
          access={access}
          onSaved={load}
        />
        <StandingList
          rows={rows}
          loading={loading}
          onEdit={beginEdit}
          onDelete={removeRow}
        />
      </div>
    </div>
  );
}
