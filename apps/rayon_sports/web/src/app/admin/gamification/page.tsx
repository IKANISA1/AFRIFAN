"use client";

import { useCallback, useState } from "react";
import { Award } from "lucide-react";
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
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminFanEngagementToken,
  getAdminFanEngagementTokens,
  normalizeAdminFanEngagementTokens,
  saveAdminFanEngagementToken,
} from "@/lib/data/admin/gamification";
import type { AdminFanEngagementToken } from "@/lib/types";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import {
  emptyFetForm,
  type FetForm,
  tokenToForm,
} from "./_components/fet-state";
import { FetEditorForm } from "./_components/fet-editor-form";
import { FetList } from "./_components/fet-list";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

const emptyTokens: AdminFanEngagementToken[] = [];
const tokensAreEmpty = (items: AdminFanEngagementToken[]) => items.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading FET catalogue",
    detail: "Waiting for the first authenticated reward-definition snapshot.",
  },
  ready: {
    label: "FET catalogue confirmed",
    detail: "The bounded reward-definition catalogue is current.",
  },
  empty: {
    label: "No FET items in this scope",
    detail: "Create an approved reward definition for this club.",
  },
  error: {
    label: "FET catalogue unavailable",
    detail: "Confirmed items remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Gamification workspace is offline",
    detail:
      "Confirmed items remain visible; mutations are locked until reconnect.",
  },
  permission_denied: {
    label: "Gamification access denied",
    detail:
      "Previously loaded items, filters, selection, and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing FET catalogue",
    detail: "Confirmed items remain visible during the bounded refresh.",
  },
  conflict: {
    label: "FET catalogue changed",
    detail: "Review the current item before restarting the change.",
  },
  security_timeout: {
    label: "FET catalogue request timed out",
    detail: "No catalogue change was confirmed.",
  },
};

export default function AdminGamificationPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [form, setForm] = useState<FetForm>(emptyFetForm);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadTokens = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyTokens;
      return getAdminFanEngagementTokens(client, access, { signal });
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setForm(emptyFetForm);
    setInteraction("idle");
  }, []);

  const {
    data: tokens,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyTokens,
    isEmpty: tokensAreEmpty,
    load: loadTokens,
    normalize: normalizeAdminFanEngagementTokens,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "FET catalogue",
  });

  const mutationLocked = status !== "ready" && status !== "empty";
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  function beginEdit(token: AdminFanEngagementToken) {
    setForm(tokenToForm(token));
    setInteraction("selected");
    showAdminToast("Reward definition selected for review.", "info");
  }

  async function removeToken(token: AdminFanEngagementToken) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: token.code,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The FET catalog entry will be removed from this club scope.",
        undo: "not_available",
      })
    ) {
      return;
    }

    showAdminToast(`Removing ${token.code}...`, "info");
    try {
      await deleteAdminFanEngagementToken(
        client,
        access,
        token.id,
        token.updatedAt,
      );
      await refresh();
      if (form.id === token.id) {
        setForm(emptyFetForm);
        setInteraction("idle");
      }
      showAdminToast("Reward definition removed.", "success");
    } catch (caught) {
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast("Could not remove the reward definition.", "error");
    }
  }

  async function toggleActive(token: AdminFanEngagementToken) {
    if (client == null) return;

    showAdminToast(
      `${token.isActive ? "Deactivating" : "Activating"} ${token.code}...`,
      "info",
    );
    try {
      await saveAdminFanEngagementToken(client, access, {
        id: token.id,
        expectedUpdatedAt: token.updatedAt,
        code: token.code,
        templateScope: token.templateScope,
        category: token.category,
        itemName: token.itemName,
        fetValue: token.fetValue,
        triggerCondition: token.triggerCondition,
        activationTiming: token.activationTiming,
        description: token.description,
        badgeName: token.badgeName,
        implementationNotes: token.implementationNotes,
        sortOrder: token.sortOrder,
        isActive: !token.isActive,
      });
      await refresh();
      showAdminToast("Reward activation state updated.", "success");
    } catch (caught) {
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast("Could not update the reward activation state.", "error");
    }
  }

  return (
    <section
      className="admin-gamification-state-surface section-grid min-w-0 max-w-full"
      data-admin-gamification-status={status}
      data-admin-gamification-interaction={interaction}
      data-admin-gamification-refresh-disabled={busy}
      data-admin-gamification-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Gamification"
        title="Fan Engagement Tokens"
        meta={
          <span className="admin-meta-chip">
            Bounded club-scoped reward definitions
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh FET catalogue"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="admin-gamification-metrics-grid">
        <AdminStateCard
          label="Catalog items"
          value={initialLoading ? "..." : tokens.length.toString()}
          helper="Strict catalogue window, capped at 500."
          icon={Award}
        />
        <AdminStateCard
          label="Active"
          value={
            initialLoading
              ? "..."
              : tokens.filter((token) => token.isActive).length.toString()
          }
          helper="Available to this club."
        />
        <AdminStateCard
          label="Generic"
          value={
            initialLoading
              ? "..."
              : tokens
                  .filter((token) => token.templateScope === "generic")
                  .length.toString()
          }
          helper="Reusable across clubs."
        />
        <AdminStateCard
          label="Club-specific"
          value={
            initialLoading
              ? "..."
              : tokens
                  .filter((token) => token.templateScope === "club_specific")
                  .length.toString()
          }
          helper="Tailored to local context."
        />
      </div>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry FET catalogue"
        />
      ) : initialLoading ? (
        <AdminSurface title="FET catalogue workspace">
          <div className="space-y-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-zinc-900)] p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        </AdminSurface>
      ) : (
        <div className="admin-gamification-content-grid">
          <FetEditorForm
            form={form}
            setForm={setForm}
            client={client}
            access={access}
            disabled={mutationLocked}
            onSaved={refresh}
            onFailure={applyFailure}
            onConflict={async () => {
              await refresh();
              showAdminToast(
                "Latest FET catalogue loaded. Your draft is retained; review it before restarting the edit.",
                "info",
              );
            }}
          />
          <FetList
            tokens={tokens}
            loading={false}
            mutationDisabled={mutationLocked}
            onEdit={beginEdit}
            onDelete={removeToken}
            onToggleActive={toggleActive}
          />
        </div>
      )}
    </section>
  );
}
