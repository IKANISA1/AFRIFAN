"use client";

import { useCallback, useEffect, useState } from "react";
import { CalendarDays, Radio, Ticket } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminMatch,
  getAdminMatches,
} from "@/lib/data/admin/matches";
import type { AdminMatchItem } from "@/lib/types";
import { emptyMatchForm, matchToFormState } from "./_components/match-form-state";
import { MatchForm } from "./_components/match-form";
import { MatchList } from "./_components/match-list";

export default function AdminMatchesPage() {
  const { access, client } = useAdminPortal();
  const [matches, setMatches] = useState<AdminMatchItem[]>([]);
  const [form, setForm] = useState(emptyMatchForm);
  const [filter, setFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);

  const loadMatches = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setMatches(await getAdminMatches(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load matches.",
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
      <SectionHeading
        eyebrow="Match manager"
        title="Control fixtures, ticket sales, and live-state from one mobile-first surface."
        description="This editor keeps the club website, fan portal, and live center aligned on the same match contract."
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Matches"
          value={loading ? "..." : matches.length.toString()}
          helper="All club-scoped fixtures currently visible to admin."
          icon={CalendarDays}
        />
        <AdminStateCard
          label="On sale"
          value={loading ? "..." : matches.filter((match) => match.isOnSale).length.toString()}
          helper="Fixtures with active ticket sales in the supporter surfaces."
          icon={Ticket}
        />
        <AdminStateCard
          label="Live now"
          value={loading ? "..." : matches.filter((match) => match.matchStatus === "live").length.toString()}
          helper="Live-score driven fixtures currently pushing updates."
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
        <MatchList
          matches={matches}
          filter={filter}
          setFilter={setFilter}
          loading={loading}
          onEdit={beginEdit}
          onDelete={(match) => {
            removeMatch(match).catch(() => {});
          }}
        />
      </div>
    </div>
  );
}
