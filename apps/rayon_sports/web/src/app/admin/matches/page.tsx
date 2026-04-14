"use client";

import { useCallback, useEffect, useState } from "react";
import { CalendarDays, Radio, Ticket } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
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

  const loadMatches = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setMatches(await getAdminMatches(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "Could not load matches.";
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
    if (client == null || !access.hasAccess) {
      return;
    }
    loadMatches().catch(() => {});
  }, [access.hasAccess, client, loadMatches]);

  function beginEdit(match: AdminMatchItem) {
    setForm(matchToFormState(match));
    showAdminToast(`Editing ${match.homeTeam} vs ${match.awayTeam}.`, "info");
  }

  async function removeMatch(match: AdminMatchItem) {
    if (client == null) {
      return;
    }
    if (
      !confirmAdminDestructiveAction({
        subject: `${match.homeTeam} vs ${match.awayTeam}`,
        detail: "The selected fixture and its admin configuration will be removed.",
      })
    ) {
      return;
    }

    try {
      await deleteAdminMatch(client, access, match.id);
      await loadMatches();
      showAdminToast(
        `${match.homeTeam} vs ${match.awayTeam} removed.`,
        "success",
      );
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove fixture.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Matchday"
        title="Matches"
        description="Fixtures, ticket state, live status, and capacity in one operational view."
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Matches"
          value={loading ? "..." : matches.length.toString()}
          helper="Club-scoped fixtures."
          icon={CalendarDays}
        />
        <AdminStateCard
          label="On sale"
          value={loading ? "..." : matches.filter((match) => match.isOnSale).length.toString()}
          helper="Active ticket sales."
          icon={Ticket}
        />
        <AdminStateCard
          label="Live now"
          value={loading ? "..." : matches.filter((match) => match.matchStatus === "live").length.toString()}
          helper="Pushing live updates."
          icon={Radio}
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <MatchForm
          form={form}
          setForm={setForm}
          emptyForm={emptyMatchForm}
          client={client}
          access={access}
          onSaved={loadMatches}
        />
        {loadError && !loading ? (
          <AdminErrorState
            title="Fixtures could not be loaded"
            description={loadError}
            onRetry={() => {
              loadMatches().catch(() => {});
            }}
          />
        ) : (
          <MatchList
            matches={matches}
            currencyCode={activeClub?.currencyCode ?? "USD"}
            filter={filter}
            setFilter={setFilter}
            loading={loading}
            onEdit={beginEdit}
            onDelete={(match) => {
              removeMatch(match).catch(() => {});
            }}
          />
        )}
      </div>
    </div>
  );
}
