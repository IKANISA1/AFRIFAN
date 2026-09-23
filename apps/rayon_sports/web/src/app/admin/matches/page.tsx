"use client";

import { fixtureInitials } from "@/lib/team-identity";

import { useCallback, useState } from "react";
import { Plus } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { KPISummaryRibbon, KPITile } from "@/components/admin/kpi-summary-ribbon";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminMatch,
  getAdminMatches,
  normalizeAdminMatches,
} from "@/lib/data/admin/matches";
import type { AdminMatchItem } from "@/lib/types";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { emptyMatchForm, matchToFormState } from "./_components/match-form-state";
import { MatchForm } from "./_components/match-form";
import { MatchList } from "./_components/match-list";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

const emptyMatches: AdminMatchItem[] = [];
const matchesAreEmpty = (items: AdminMatchItem[]) => items.length === 0;

const matchStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading match operations",
    detail: "Waiting for the first authenticated fixture snapshot.",
  },
  ready: {
    label: "Match operations confirmed",
    detail: "Fixtures, sale status, and match controls are current.",
  },
  empty: {
    label: "No fixtures in this scope",
    detail: "Create a fixture or change the active club scope.",
  },
  error: {
    label: "Match operations unavailable",
    detail: "Confirmed fixtures remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Match workspace is offline",
    detail: "Confirmed fixtures remain visible until connection returns.",
  },
  permission_denied: {
    label: "Match access denied",
    detail: "Previously loaded fixture data has been cleared.",
  },
  syncing: {
    label: "Refreshing match operations",
    detail: "Confirmed fixtures remain visible during refresh.",
  },
  conflict: {
    label: "Fixture records changed",
    detail: "Refresh before editing or deleting the current fixture records.",
  },
  security_timeout: {
    label: "Match request timed out",
    detail: "No fixture operation or change was confirmed.",
  },
};

export default function AdminMatchesPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [form, setForm] = useState(emptyMatchForm);
  const [filter, setFilter] = useState("ALL");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadMatches = useCallback((signal: AbortSignal) => {
    if (client == null) {
      return Promise.resolve([]);
    }
    return getAdminMatches(client, access, { signal });
  }, [access, client]);
  const handlePermissionDenied = useCallback(() => {
    setDrawerOpen(false);
    setForm(emptyMatchForm);
    setInteraction("idle");
  }, []);

  const {
    data: matches,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptyMatches,
    isEmpty: matchesAreEmpty,
    load: loadMatches,
    normalize: normalizeAdminMatches,
    onPermissionDenied: handlePermissionDenied,
    resourceLabel: "Match operations",
  });

  function beginEdit(match: AdminMatchItem) {
    setForm(matchToFormState(match));
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function beginCreate() {
    setForm(emptyMatchForm);
    setDrawerOpen(true);
    setInteraction("selected");
  }

  async function removeMatch(match: AdminMatchItem) {
    if (client == null) return;
    if (!confirmAdminDestructiveAction({
      action: "Delete",
      subject: fixtureInitials(match.homeTeam, match.awayTeam),
      scope: access.clubId == null
        ? "Platform fixture catalogue"
        : `Active club ${access.clubId}`,
      impact: "The selected fixture and its admin configuration will be removed.",
      undo: "not_available",
    })) return;

    try {
      await deleteAdminMatch(
        client,
        access,
        match.id,
        match.updatedAt,
      );
      await refresh();
      showAdminToast(`${fixtureInitials(match.homeTeam, match.awayTeam)} removed.`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? matchStatusCopy.conflict.label
          : "Could not confirm fixture removal.",
        "error",
      );
    }
  }

  return (
    <section
      className="admin-matches-state-surface section-grid !gap-6"
      data-admin-matches-status={status}
      data-admin-matches-interaction={interaction}
      data-admin-matches-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Matchday"
        title="Matches"
        actions={
          <button
            onClick={beginCreate}
            disabled={busy || status === "permission_denied"}
            className="admin-action-button min-h-12 !bg-[var(--admin-accent)] !text-[var(--admin-zinc-950)] disabled:cursor-not-allowed disabled:!bg-[var(--admin-zinc-800)] disabled:!text-[var(--admin-text-strong)]"
          >
            <Plus size={16} />
            <span>Create fixture</span>
          </button>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={matchStatusCopy[status].label}
        detail={matchStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh fixtures"
        selected={drawerOpen}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-matches-status"
      />

      <KPISummaryRibbon>
        <KPITile label="Total fixtures" value={initialLoading ? "..." : matches.length.toString()} />
        <KPITile label="On sale" value={initialLoading ? "..." : matches.filter(m => m.isOnSale).length.toString()} />
        <KPITile label="Live matches" value={initialLoading ? "..." : matches.filter(m => m.matchStatus === "live").length.toString()} />
        <KPITile label="Club" value={activeClub?.shortName ?? "Scope"} />
      </KPISummaryRibbon>

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={matchStatusCopy[status].label}
          description={matchStatusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <MatchList
          matches={matches}
          currencyCode={activeClub?.currencyCode ?? "USD"}
          filter={filter}
          setFilter={setFilter}
          loading={initialLoading}
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
            setInteraction("idle");
            await refresh();
          }}
          onConflict={async () => {
            await refresh();
            showAdminToast(
              "Latest fixtures loaded. Your draft is retained; review it before restarting the edit.",
              "info",
            );
          }}
          onFailure={(caught) => {
            applyFailure(caught);
          }}
          onCancel={() => {
            setDrawerOpen(false);
            setInteraction("idle");
          }}
        />
      </AdminActionDrawer>
    </section>
  );
}
