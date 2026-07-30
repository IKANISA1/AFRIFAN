"use client";

import { useCallback, useState } from "react";
import { ClipboardCheck, FileCheck2, History, ShieldCheck } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminSurface } from "@/components/admin/admin-surface";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  getAdminGameSnapshot,
  normalizeAdminGameSnapshot,
  type AdminGameSnapshot,
} from "@/lib/data/admin/games";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { rayonClub } from "@/lib/config";
import { GamesControlClient } from "./games-control-client";

const emptySnapshot: AdminGameSnapshot = normalizeAdminGameSnapshot(null);
const snapshotIsEmpty = (snapshot: AdminGameSnapshot) =>
  snapshot.drafts.length === 0 && snapshot.audit.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading game operations",
    detail: "Waiting for the first authenticated draft and audit snapshot.",
  },
  ready: {
    label: "Game operations snapshot confirmed",
    detail: "The bounded moderation queue and operational audit are current.",
  },
  empty: {
    label: "No game operations in this scope",
    detail: "The workspace is ready for an approved session or question draft.",
  },
  error: {
    label: "Game operations unavailable",
    detail: "Confirmed records remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Game operations workspace is offline",
    detail:
      "Confirmed records remain visible; actions are locked until reconnect.",
  },
  permission_denied: {
    label: "Game operations access denied",
    detail:
      "Previously loaded drafts, audit details, selections, and active inputs were cleared.",
  },
  syncing: {
    label: "Refreshing game operations",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Game operations changed",
    detail: "Review the current snapshot before restarting the action.",
  },
  security_timeout: {
    label: "Game operations request timed out",
    detail: "No session, moderation, pairing, or audit change was confirmed.",
  },
};

export default function AdminGamesPage() {
  const { access } = useAdminPortal();
  const hydrated = useHydrated();
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const clubId = Number.parseInt(
    access.clubId ?? String(rayonClub.numericId),
    10,
  );
  const safeClubId =
    Number.isFinite(clubId) && clubId > 0 ? clubId : rayonClub.numericId;

  const loadSnapshot = useCallback(
    (signal: AbortSignal) =>
      getAdminGameSnapshot(safeClubId, {
        signal,
      }),
    [safeClubId],
  );

  const clearDeniedState = useCallback(() => {
    setInteraction("idle");
  }, []);

  const { data, status, hasConfirmed, busy, initialLoading, refresh } =
    useAdminResourceState({
      enabled: hydrated && access.hasAccess,
      emptyValue: emptySnapshot,
      isEmpty: snapshotIsEmpty,
      load: loadSnapshot,
      normalize: normalizeAdminGameSnapshot,
      onPermissionDenied: clearDeniedState,
      resourceLabel: "game operations",
    });

  const pendingDrafts = data.drafts.filter(
    (draft) => draft.validationStatus === "pending_review",
  ).length;
  const approvedDrafts = data.drafts.filter(
    (draft) => draft.validationStatus === "approved",
  ).length;
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  return (
    <section
      className="admin-games-state-surface section-grid min-w-0 max-w-full"
      data-admin-games-status={status}
      data-admin-games-interaction={interaction}
      data-admin-games-refresh-disabled={busy}
      data-admin-games-mutation-disabled={
        status !== "ready" && status !== "empty"
      }
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Matchday games"
        title="Game Control Room"
        meta={
          <span className="admin-meta-chip">
            Bounded session, moderation, TV, and audit operations
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh game operations"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-games-status"
      />

      <div className="admin-games-metrics-grid">
        <AdminStateCard
          label="Draft window"
          value={initialLoading ? "..." : data.drafts.length.toString()}
          helper="Latest strict queue, capped at 100."
          icon={ClipboardCheck}
        />
        <AdminStateCard
          label="Pending review"
          value={initialLoading ? "..." : pendingDrafts.toString()}
          helper="Human decision required."
          icon={ShieldCheck}
        />
        <AdminStateCard
          label="Approved drafts"
          value={initialLoading ? "..." : approvedDrafts.toString()}
          helper="Approved within the current window."
          icon={FileCheck2}
        />
        <AdminStateCard
          label="Audit window"
          value={initialLoading ? "..." : data.audit.length.toString()}
          helper="Latest privacy-filtered actions, capped at 100."
          icon={History}
        />
      </div>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry game operations"
        />
      ) : initialLoading ? (
        <AdminSurface title="Game operations workspace">
          <div className="space-y-4 p-5 sm:p-6">
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
        <GamesControlClient
          defaultClubId={safeClubId}
          initialDraftRows={data.drafts}
          initialAuditRows={data.audit}
          onSelectionChange={(selected) =>
            setInteraction(selected ? "selected" : "idle")
          }
        />
      )}
    </section>
  );
}
