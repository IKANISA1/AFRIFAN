"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, CalendarDays, Radio, Ticket } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { KPISummaryRibbon, KPITile } from "@/components/admin/kpi-summary-ribbon";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminMatch,
  getAdminMatches,
} from "@/lib/data/admin/matches";
import type { AdminMatchItem } from "@/lib/types";
import { emptyMatchForm, matchToFormState } from "./_components/match-form-state";
import { MatchForm } from "./_components/match-form";
import { MatchList } from "./_components/match-list";

export default function AdminMatchesPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [matches, setMatches] = useState<AdminMatchItem[]>([]);
  const [form, setForm] = useState(emptyMatchForm);
  const [filter, setFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const loadMatches = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setMatches(await getAdminMatches(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load matches.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    loadMatches().catch(() => {});
  }, [access.hasAccess, client, loadMatches]);

  function beginEdit(match: AdminMatchItem) {
    setForm(matchToFormState(match));
    setDrawerOpen(true);
  }

  function beginCreate() {
    setForm(emptyMatchForm);
    setDrawerOpen(true);
  }

  async function removeMatch(match: AdminMatchItem) {
    if (client == null) return;
    if (!confirmAdminDestructiveAction({
      subject: `${match.homeTeam} vs ${match.awayTeam}`,
      detail: "The selected fixture and its admin configuration will be removed.",
    })) return;

    try {
      await deleteAdminMatch(client, access, match.id);
      await loadMatches();
      showAdminToast(`${match.homeTeam} vs ${match.awayTeam} removed.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not remove fixture.", "error");
    }
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Matchday"
        title="Matches"
        actions={
          <button
            onClick={beginCreate}
            className="admin-action-button !bg-[var(--admin-zinc-100)] !text-[var(--admin-zinc-950)] hover:!bg-white"
          >
            <Plus size={16} />
            <span>Create fixture</span>
          </button>
        }
      />

      <KPISummaryRibbon>
        <KPITile label="Total fixtures" value={loading ? "..." : matches.length.toString()} />
        <KPITile label="On sale" value={loading ? "..." : matches.filter(m => m.isOnSale).length.toString()} />
        <KPITile label="Live matches" value={loading ? "..." : matches.filter(m => m.matchStatus === "live").length.toString()} />
        <KPITile label="Club" value={activeClub?.shortName ?? "Scope"} />
      </KPISummaryRibbon>

      {loadError && !loading ? (
        <AdminErrorState
          title="Fixtures could not be loaded"
          description={loadError}
          onRetry={() => { loadMatches().catch(() => {}); }}
        />
      ) : (
        <MatchList
          matches={matches}
          currencyCode={activeClub?.currencyCode ?? "USD"}
          filter={filter}
          setFilter={setFilter}
          loading={loading}
          onEdit={beginEdit}
          onDelete={(match) => { removeMatch(match).catch(() => {}); }}
        />
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={form.id ? "Edit fixture" : "Create fixture"}
      >
        <MatchForm
          form={form}
          setForm={setForm}
          emptyForm={emptyMatchForm}
          client={client}
          access={access}
          onSaved={async () => {
            setDrawerOpen(false);
            await loadMatches();
          }}
          onCancel={() => setDrawerOpen(false)}
        />
      </AdminActionDrawer>
    </div>
  );
}
