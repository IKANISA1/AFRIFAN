"use client";

import { useCallback, useState } from "react";
import { Coins, DollarSign, Users } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminContributionGroup,
  downloadContributionExcel,
  getAdminContributionSnapshot,
  normalizeAdminContributionSnapshot,
} from "@/lib/data/admin/contributions";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type {
  AdminContributionGroup,
  AdminContributionSnapshot,
} from "@/lib/types";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { formatCurrency } from "@/lib/utils";
import {
  emptyGroupForm,
  groupToFormState,
} from "./_components/group-form-state";
import { ContributionGroupForm } from "./_components/group-form";
import { ContributionGroupList } from "./_components/group-list";

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  monthlyTotal: 0,
};

const contributionSnapshotIsEmpty = (snapshot: AdminContributionSnapshot) =>
  snapshot.groups.length === 0 && snapshot.contributions.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading contribution operations",
    detail: "Waiting for the first authenticated contribution snapshot.",
  },
  ready: {
    label: "Contribution snapshot confirmed",
    detail:
      "Public initiatives and the latest bounded ledger window are current.",
  },
  empty: {
    label: "No contribution records in this scope",
    detail: "Create the first authorized public initiative.",
  },
  error: {
    label: "Contribution operations unavailable",
    detail: "Confirmed records remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Contribution workspace is offline",
    detail:
      "Confirmed records remain visible; mutations are locked until reconnect.",
  },
  permission_denied: {
    label: "Contribution access denied",
    detail:
      "Previously loaded records, filters, selections, and drafts were cleared.",
  },
  syncing: {
    label: "Refreshing contribution operations",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Contribution records changed",
    detail: "Review the current record before restarting the change.",
  },
  security_timeout: {
    label: "Contribution request timed out",
    detail: "No contribution operation or change was confirmed.",
  },
};

export default function AdminContributionsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [form, setForm] = useState(emptyGroupForm);
  const [filter, setFilter] = useState("ALL");
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadSnapshot = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptySnapshot;
      return getAdminContributionSnapshot(client, access, { signal });
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setForm(emptyGroupForm);
    setFilter("ALL");
    setInteraction("idle");
  }, []);

  const {
    data,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptySnapshot,
    isEmpty: contributionSnapshotIsEmpty,
    load: loadSnapshot,
    normalize: normalizeAdminContributionSnapshot,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "contribution operations",
  });

  const currencyCode = activeClub?.currencyCode ?? "RWF";
  const mutationLocked =
    !hydrated || client == null || (status !== "ready" && status !== "empty");
  const exportLocked =
    !hydrated ||
    data.groups.length === 0 ||
    status === "loading" ||
    status === "syncing" ||
    status === "permission_denied";
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  function beginEdit(group: AdminContributionGroup) {
    setForm(groupToFormState(group));
    setInteraction("selected");
    showAdminToast(`Editing ${group.name}.`, "info");
  }

  function mutationFailureMessage(caught: unknown, fallback: string) {
    const nextStatus = applyFailure(caught);
    return nextStatus === "conflict" ? statusCopy.conflict.label : fallback;
  }

  async function removeGroup(group: AdminContributionGroup) {
    if (
      client == null ||
      mutationLocked ||
      !confirmAdminDestructiveAction({
        action: "Remove",
        subject: group.name,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact:
          "The public initiative and its operational definition will be removed.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminContributionGroup(
        client,
        access,
        group.id,
        group.updatedAt,
      );
      if (form.id === group.id) setForm(emptyGroupForm);
      setInteraction("idle");
      await refresh();
      showAdminToast(`${group.name} removed.`, "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        mutationFailureMessage(
          caught,
          "Could not confirm public-initiative removal.",
        ),
        "error",
      );
    }
  }

  async function exportExcel() {
    if (exportLocked) return;
    try {
      await downloadContributionExcel(data);
      showAdminToast("Initiative summary prepared as Excel.", "success");
    } catch (caught) {
      applyFailure(caught);
      showAdminToast("Could not prepare the initiative summary.", "error");
    }
  }

  const totalParticipants = data.groups.reduce(
    (sum, group) => sum + group.memberCount,
    0,
  );

  return (
    <section
      className="admin-contributions-state-surface section-grid min-w-0 max-w-full"
      data-admin-contributions-status={status}
      data-admin-contributions-interaction={interaction}
      data-admin-contributions-refresh-disabled={busy}
      data-admin-contributions-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Funding"
        title="Contributions"
        meta={
          <span className="admin-meta-chip">
            Public initiatives and bounded ledger monitoring
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh contribution operations"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-contributions-status"
      />

      <div className="admin-contributions-metrics-grid">
        <AdminStateCard
          label="Confirmed this month"
          value={
            initialLoading
              ? "..."
              : formatCurrency(data.monthlyTotal, currencyCode)
          }
          helper="Confirmed in the latest 500 ledger entries (UTC)."
          icon={Coins}
        />
        <AdminStateCard
          label="Active initiatives"
          value={
            initialLoading
              ? "..."
              : data.groups.filter((group) => !group.isClosed).length.toString()
          }
          helper="Currently public and open."
          icon={DollarSign}
        />
        <AdminStateCard
          label="Participants"
          value={initialLoading ? "..." : totalParticipants.toString()}
          helper="Aggregate initiative participation."
          icon={Users}
        />
        <AdminStateCard
          label="Recent ledger rows"
          value={initialLoading ? "..." : data.contributions.length.toString()}
          helper="Maximum retained monitoring window: 500."
        />
      </div>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry contribution operations"
        />
      ) : (
        <div className="admin-contributions-content-grid">
          <AdminSurface
            title={form.id ? "Edit public initiative" : "New public initiative"}
            className="min-w-0"
          >
            <ContributionGroupForm
              form={form}
              setForm={(next) => {
                setForm(next);
                setInteraction("selected");
              }}
              emptyForm={emptyGroupForm}
              defaultCurrencyCode={currencyCode}
              client={client}
              access={access}
              disabled={mutationLocked}
              onSaved={async () => {
                setInteraction("idle");
                await refresh();
              }}
              onConflict={async () => {
                await refresh();
                showAdminToast(
                  "The latest initiative list is loaded. Your draft is retained for review.",
                  "info",
                );
              }}
              onFailure={(caught) =>
                mutationFailureMessage(
                  caught,
                  "Could not confirm the initiative change.",
                )
              }
            />
          </AdminSurface>

          <ContributionGroupList
            key={status === "permission_denied" ? "denied" : "available"}
            snapshot={data}
            currencyCode={currencyCode}
            filter={filter}
            setFilter={setFilter}
            loading={initialLoading}
            busy={busy}
            permissionLocked={status === "permission_denied"}
            mutationDisabled={mutationLocked}
            exportDisabled={exportLocked}
            onEdit={beginEdit}
            onDelete={(group) => void removeGroup(group)}
            onExportExcel={() => void exportExcel()}
          />
        </div>
      )}
    </section>
  );
}
