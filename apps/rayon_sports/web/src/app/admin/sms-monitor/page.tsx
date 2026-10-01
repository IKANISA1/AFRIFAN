"use client";

import { useCallback, useEffect, useState } from "react";
import { Search } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { Skeleton } from "@/components/skeleton";
import {
  allocateAdminSmsManualReview,
  getAdminSmsManualReviewWorkspace,
  getAdminSmsSnapshot,
  normalizeAdminSmsManualReviewWorkspace,
  normalizeAdminSmsSnapshot,
  rejectAdminSmsManualReview,
} from "@/lib/data/admin/sms";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import { cn } from "@/lib/utils";
import type {
  AdminPendingPaymentIntent,
  AdminSmsManualReview,
  AdminSmsSnapshot,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

const emptySnapshot: AdminSmsSnapshot = {
  metrics: {},
  syncRuns: [],
};
const emptyManualWorkspace = {
  reviews: [] as AdminSmsManualReview[],
  pendingIntents: [] as AdminPendingPaymentIntent[],
};
const emptyMonitorWorkspace = {
  snapshot: emptySnapshot,
  manualWorkspace: emptyManualWorkspace,
};

type SmsMonitorWorkspace = typeof emptyMonitorWorkspace;

const monitorWorkspaceIsEmpty = (workspace: SmsMonitorWorkspace) =>
  workspace.snapshot.syncRuns.length === 0 &&
  Object.keys(workspace.snapshot.metrics).length === 0 &&
  workspace.manualWorkspace.reviews.length === 0 &&
  workspace.manualWorkspace.pendingIntents.length === 0;

function normalizeMonitorWorkspace(value: unknown): SmsMonitorWorkspace {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("SMS monitor workspace is invalid.");
  }
  const workspace = value as Record<string, unknown>;
  return {
    snapshot: normalizeAdminSmsSnapshot(workspace.snapshot),
    manualWorkspace: normalizeAdminSmsManualReviewWorkspace(
      workspace.manualWorkspace,
    ),
  };
}

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading SMS monitor",
    detail: "Waiting for the first authenticated, club-scoped snapshot.",
  },
  ready: {
    label: "SMS monitor confirmed",
    detail: "The latest bounded pipeline and review data are ready.",
  },
  empty: {
    label: "No SMS activity in this club",
    detail: "The pipeline snapshot is confirmed with no current activity.",
  },
  error: {
    label: "SMS monitoring unavailable",
    detail: "Confirmed data remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "SMS monitoring is offline",
    detail: "Confirmed data remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "SMS monitoring access denied",
    detail:
      "Metrics, runs, reviews, filters, selections, and drawer content were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing SMS monitor",
    detail: "Confirmed data remain visible during the bounded refresh.",
  },
  conflict: {
    label: "SMS monitoring data changed",
    detail: "Review the retained snapshot, then refresh before acting.",
  },
  security_timeout: {
    label: "SMS monitoring request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained data.",
  },
};

const pipelineSteps = [
  {
    step: "1",
    title: "Capture",
    body: "SMS listener receives an approved sender event.",
    color: "border-success/30 bg-success/5",
  },
  {
    step: "2",
    title: "Ingest",
    body: "Edge Function deduplicates and writes to raw table.",
    color: "border-[var(--admin-accent)]/30 bg-[var(--admin-accent)]/5",
  },
  {
    step: "3",
    title: "Parse",
    body: "Structured values land in parsed table.",
    color: "border-warning/30 bg-warning/5",
  },
  {
    step: "4",
    title: "Ledger",
    body: "Wallet and contribution records reconcile.",
    color: "border-accent/30 bg-accent/5",
  },
];

export default function AdminSmsMonitorPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [intentSelections, setIntentSelections] = useState<
    Record<string, string>
  >({});
  const [busyReviewId, setBusyReviewId] = useState<string | null>(null);
  const [detailReview, setDetailReview] = useState<AdminSmsManualReview | null>(
    null,
  );
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const clearPrivateState = useCallback(() => {
    setIntentSelections({});
    setBusyReviewId(null);
    setDetailReview(null);
    setInteraction("idle");
  }, []);
  const loadMonitorWorkspace = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyMonitorWorkspace;
      const [snapshot, manualWorkspace] = await Promise.all([
        getAdminSmsSnapshot(client, access, { signal }),
        access.isSuperAdmin
          ? getAdminSmsManualReviewWorkspace(client, access, { signal })
          : Promise.resolve(emptyManualWorkspace),
      ]);
      return { snapshot, manualWorkspace };
    },
    [access, client],
  );
  const {
    data: monitorWorkspace,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState<SmsMonitorWorkspace>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyMonitorWorkspace,
    isEmpty: monitorWorkspaceIsEmpty,
    load: loadMonitorWorkspace,
    normalize: normalizeMonitorWorkspace,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "SMS monitor",
  });
  const snapshot = monitorWorkspace.snapshot;
  const manualReviews = monitorWorkspace.manualWorkspace.reviews;
  const pendingIntents = monitorWorkspace.manualWorkspace.pendingIntents;

  const runCollection = useAdminCollection({
    records: snapshot.syncRuns,
    getId: (run) => run.id,
    getSearchValues: (run) => [
      run.status,
      run.trigger,
      run.scannedMessages,
      run.uploadedMessages,
    ],
    getSortValue: (
      run,
      key: "status" | "trigger" | "scanned" | "uploaded" | "startedAt",
    ) => {
      switch (key) {
        case "status":
          return run.status;
        case "trigger":
          return run.trigger;
        case "scanned":
          return run.scannedMessages;
        case "uploaded":
          return run.uploadedMessages;
        case "startedAt":
          return run.startedAt ? new Date(run.startedAt) : null;
      }
    },
    initialSortKey: "startedAt" as const,
    initialSortDirection: "descending",
    pageSize: 15,
  });

  const reviewCollection = useAdminCollection({
    records: manualReviews,
    getId: (review) => review.reviewId,
    getSearchValues: (review) => [
      review.reviewKind,
      review.reason,
      review.momoTxId,
      review.payerName,
      review.sender,
      review.payeeName,
      review.payeeNumberOrCode,
      review.smsPreview,
    ],
    getSortValue: (review, key: "kind" | "amount" | "reason" | "updatedAt") => {
      switch (key) {
        case "kind":
          return review.reviewKind;
        case "amount":
          return review.amount;
        case "reason":
          return review.reason;
        case "updatedAt":
          return review.updatedAt ? new Date(review.updatedAt) : null;
      }
    },
    initialSortKey: "updatedAt" as const,
    initialSortDirection: "descending",
    pageSize: 20,
  });

  useEffect(() => {
    if (!hasConfirmed) return;
    setIntentSelections((current) => {
      const next: Record<string, string> = {};
      for (const review of manualReviews) {
        const currentSelection = current[review.reviewId];
        if (currentSelection) {
          next[review.reviewId] = currentSelection;
          continue;
        }
        const firstMatch = pendingIntents.find(
          (intent) =>
            intent.expectedAmount === review.amount &&
            intent.currency === review.currency &&
            (review.userId == null || intent.userId === review.userId),
        );
        if (firstMatch) next[review.reviewId] = firstMatch.id;
      }
      return next;
    });
  }, [hasConfirmed, manualReviews, pendingIntents]);

  useEffect(() => {
    if (status === "permission_denied") {
      runCollection.setQuery("");
      reviewCollection.setQuery("");
    }
  }, [reviewCollection, runCollection, status]);

  const canManageReviews = access.isSuperAdmin;
  const mutationLocked =
    busy ||
    busyReviewId != null ||
    !canManageReviews ||
    (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  const metricEntries: Array<[string, number | null]> = hasConfirmed
    ? Object.entries(snapshot.metrics)
    : [
        ["SMS captured", null],
        ["SMS parsed", null],
        ["Ledger entries", null],
      ];

  async function handleAllocate(review: AdminSmsManualReview) {
    if (client == null || mutationLocked) {
      return;
    }
    const intentId = intentSelections[review.reviewId];
    if (!intentId) {
      showAdminToast("Choose a pending payment intent first.", "error");
      return;
    }
    setBusyReviewId(review.reviewId);
    showAdminToast("Allocating SMS review...", "info");
    try {
      await allocateAdminSmsManualReview(client, access, {
        reviewId: review.reviewId,
        intentId,
      });
      await refresh();
      setDetailReview(null);
      showAdminToast("Manual review allocated.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      showAdminToast(statusCopy[nextStatus].label, "error");
    } finally {
      setBusyReviewId(null);
    }
  }

  async function handleReject(review: AdminSmsManualReview) {
    if (client == null || mutationLocked) {
      return;
    }
    if (
      !confirmAdminDestructiveAction({
        action: "Reject",
        subject: review.momoTxId ?? review.reviewId,
        scope: `Active club ${access.clubId ?? "not selected"}; one manual review`,
        impact:
          "This marks the SMS review as not app-linked and leaves the ledger draft in place.",
        undo: "manual_recovery",
      })
    ) {
      return;
    }
    setBusyReviewId(review.reviewId);
    showAdminToast("Rejecting SMS review...", "info");
    try {
      await rejectAdminSmsManualReview(client, access, {
        reviewId: review.reviewId,
      });
      await refresh();
      setDetailReview(null);
      showAdminToast("Manual review rejected.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      showAdminToast(statusCopy[nextStatus].label, "error");
    } finally {
      setBusyReviewId(null);
    }
  }

  function matchingIntents(review: AdminSmsManualReview) {
    return pendingIntents.filter(
      (intent) =>
        intent.expectedAmount === review.amount &&
        intent.currency === review.currency &&
        (review.userId == null || intent.userId === review.userId),
    );
  }

  return (
    <div
      className="admin-sms-state-surface section-grid min-w-0 w-full max-w-full overflow-x-hidden"
      data-admin-sms-status={status}
      data-admin-sms-interaction={interaction}
    >
      <AdminPageHeader
        eyebrow="SMS pipeline"
        title="MoMo SMS ingestion health"
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh SMS monitor"
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="grid gap-5 md:grid-cols-3">
        {metricEntries.map(([label, value]) => (
          <AdminStateCard
            key={label}
            label={label}
            value={value == null ? "—" : value.toString()}
            helper={
              hasConfirmed
                ? "Confirmed pipeline metric."
                : "Awaiting confirmation."
            }
          />
        ))}
      </div>

      {initialLoading ? (
        <div
          className="grid gap-5 lg:grid-cols-2"
          role="group"
          aria-label="Loading SMS workspace"
        >
          {Array.from({ length: 2 }).map((_, index) => (
            <div key={index} className="ui-panel rounded-[32px] p-6">
              <Skeleton className="skeleton-text h-7 w-2/5" />
              <Skeleton className="skeleton-text mt-5 h-52 w-full" />
            </div>
          ))}
        </div>
      ) : null}

      {!initialLoading && !unrecoveredFailure ? (
        <section
          className="grid gap-5 lg:grid-cols-[0.85fr_1.15fr]"
          data-admin-sms-state-surface
        >
          <article className="ui-panel rounded-[32px] p-6">
            <p className="font-display text-3xl font-medium normal-case leading-none">
              Pipeline flow
            </p>
            <div className="mt-5 space-y-1">
              {pipelineSteps.map((item, index) => (
                <div key={item.step}>
                  <div
                    className={cn(
                      "rounded-[24px] border px-4 py-4 transition",
                      item.color,
                    )}
                  >
                    <div className="flex items-center gap-3">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full border border-border-soft bg-[var(--admin-surface-muted)] font-display text-sm font-medium">
                        {item.step}
                      </div>
                      <div>
                        <p className="font-display text-2xl font-medium normal-case leading-none">
                          {item.title}
                        </p>
                      </div>
                    </div>
                    <p className="mt-2 pl-11 text-sm leading-6 text-[var(--admin-text-muted)]">
                      {item.body}
                    </p>
                  </div>
                  {index < pipelineSteps.length - 1 ? (
                    <div className="flex justify-center py-1">
                      <div className="h-4 w-px bg-border-soft" />
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          </article>

          <article className="ui-panel rounded-[32px] p-6">
            <div className="flex items-center justify-between gap-3">
              <p className="font-display text-3xl font-medium normal-case leading-none">
                Recent sync runs
              </p>
              <button
                type="button"
                disabled={busy}
                onClick={() => void refresh()}
                className="inline-flex min-h-12 items-center justify-center rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed disabled:opacity-60"
              >
                Refresh
              </button>
            </div>
            <div className="mt-5 space-y-3">
              <AdminFilterBar>
                <label className="admin-search-field">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">
                    Search SMS synchronization runs
                  </span>
                  <input
                    type="search"
                    value={runCollection.query}
                    onChange={(event) =>
                      runCollection.setQuery(event.target.value)
                    }
                    placeholder="Search status, trigger, or counts"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="SMS synchronization runs"
                busy={busy}
                columns={[
                  {
                    key: "status",
                    label: "Status",
                    priority: "primary",
                    sortable: true,
                    sortDirection: runCollection.sortDirectionFor("status"),
                    onSort: () => runCollection.toggleSort("status"),
                  },
                  {
                    key: "trigger",
                    label: "Trigger",
                    priority: "primary",
                    sortable: true,
                    sortDirection: runCollection.sortDirectionFor("trigger"),
                    onSort: () => runCollection.toggleSort("trigger"),
                  },
                  {
                    key: "scanned",
                    label: "Scanned",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: runCollection.sortDirectionFor("scanned"),
                    onSort: () => runCollection.toggleSort("scanned"),
                  },
                  {
                    key: "uploaded",
                    label: "Uploaded",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: runCollection.sortDirectionFor("uploaded"),
                    onSort: () => runCollection.toggleSort("uploaded"),
                  },
                  {
                    key: "started",
                    label: "Started",
                    priority: "primary",
                    sortable: true,
                    sortDirection: runCollection.sortDirectionFor("startedAt"),
                    onSort: () => runCollection.toggleSort("startedAt"),
                  },
                ]}
              >
                {runCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td
                      colSpan={5}
                      className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                    >
                      {runCollection.query
                        ? "No sync runs match the current search."
                        : "No sync runs have been recorded yet."}
                    </td>
                  </tr>
                ) : (
                  runCollection.pageResult.items.map((run) => (
                    <tr key={run.id}>
                      <td>
                        <AdminStatusBadge
                          label={run.status}
                          tone={
                            run.status === "failed"
                              ? "danger"
                              : run.status === "running"
                                ? "warning"
                                : "success"
                          }
                        />
                      </td>
                      <td>{run.trigger}</td>
                      <td>{run.scannedMessages}</td>
                      <td>{run.uploadedMessages}</td>
                      <td>
                        {run.startedAt
                          ? new Date(run.startedAt).toLocaleString("en-RW")
                          : "Awaiting timestamp"}
                      </td>
                    </tr>
                  ))
                )}
              </AdminDataGrid>
              <AdminPagination
                page={runCollection.pageResult}
                onPageChange={runCollection.setPage}
                label="SMS synchronization runs"
              />
            </div>
          </article>
        </section>
      ) : null}

      {access.isSuperAdmin && !initialLoading && !unrecoveredFailure ? (
        <section
          className="ui-panel rounded-[32px] p-6"
          data-admin-sms-review-surface
        >
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-accent)]">
                Manual review
              </p>
              <h2 className="mt-2 font-display text-3xl font-medium normal-case leading-none text-[var(--admin-text-strong)]">
                Pending allocation queue
              </h2>
              <p className="mt-3 max-w-3xl text-sm leading-7 text-[var(--admin-text-muted)]">
                Review unmatched MoMo SMS records, route them to the correct
                payment intent, or explicitly reject them as not app-linked.
              </p>
            </div>
            <div className="rounded-full border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-2 text-xs font-semibold normal-case tracking-normal text-[var(--admin-text-muted)]">
              {manualReviews.length} open review
              {manualReviews.length === 1 ? "" : "s"}
            </div>
          </div>

          <div className="mt-6 space-y-4">
            <AdminFilterBar>
              <label className="admin-search-field">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">Search manual SMS reviews</span>
                <input
                  type="search"
                  value={reviewCollection.query}
                  onChange={(event) =>
                    reviewCollection.setQuery(event.target.value)
                  }
                  placeholder="Search payer, receiver, reason, or transaction"
                />
              </label>
            </AdminFilterBar>
            <AdminDataGrid
              caption="Pending manual SMS allocation reviews"
              busy={busy}
              onRowActivate={(rowId) =>
                setDetailReview(
                  manualReviews.find((review) => review.reviewId === rowId) ??
                    null,
                )
              }
              columns={[
                {
                  key: "kind",
                  label: "Review",
                  priority: "primary",
                  sortable: true,
                  sortDirection: reviewCollection.sortDirectionFor("kind"),
                  onSort: () => reviewCollection.toggleSort("kind"),
                },
                {
                  key: "parties",
                  label: "Payer to receiver",
                  priority: "primary",
                },
                {
                  key: "amount",
                  label: "Amount",
                  priority: "primary",
                  sortable: true,
                  sortDirection: reviewCollection.sortDirectionFor("amount"),
                  onSort: () => reviewCollection.toggleSort("amount"),
                },
                {
                  key: "reason",
                  label: "Reason",
                  priority: "secondary",
                  sortable: true,
                  sortDirection: reviewCollection.sortDirectionFor("reason"),
                  onSort: () => reviewCollection.toggleSort("reason"),
                },
                {
                  key: "updated",
                  label: "Updated",
                  priority: "secondary",
                  sortable: true,
                  sortDirection: reviewCollection.sortDirectionFor("updatedAt"),
                  onSort: () => reviewCollection.toggleSort("updatedAt"),
                },
              ]}
            >
              {reviewCollection.pageResult.items.length === 0 ? (
                <tr>
                  <td
                    colSpan={5}
                    className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                  >
                    {reviewCollection.query
                      ? "No manual reviews match the current search."
                      : "No manual SMS reviews are waiting for action."}
                  </td>
                </tr>
              ) : (
                reviewCollection.pageResult.items.map((review) => (
                  <tr key={review.reviewId} data-row-id={review.reviewId}>
                    <td>
                      {review.reviewKind.replaceAll("_", " ")}
                      <span className="block max-w-48 truncate text-xs text-[var(--admin-text-muted)]">
                        {review.momoTxId ?? review.reviewId}
                      </span>
                    </td>
                    <td>
                      {review.payerName ?? review.sender} →{" "}
                      {review.payeeName ??
                        review.payeeNumberOrCode ??
                        "receiver"}
                    </td>
                    <td>
                      {review.amount.toLocaleString()} {review.currency}
                    </td>
                    <td>{review.reason.replaceAll("_", " ")}</td>
                    <td>
                      {review.updatedAt
                        ? new Date(review.updatedAt).toLocaleString("en-RW")
                        : "Awaiting timestamp"}
                    </td>
                  </tr>
                ))
              )}
            </AdminDataGrid>
            <AdminPagination
              page={reviewCollection.pageResult}
              onPageChange={reviewCollection.setPage}
              label="Manual SMS reviews"
            />
          </div>
        </section>
      ) : null}
      <AdminActionDrawer
        open={detailReview != null}
        onClose={() => setDetailReview(null)}
        title="Manual SMS review"
      >
        {detailReview ? (
          <div className="grid gap-5 text-sm">
            <dl className="grid gap-3">
              <div>
                <dt className="text-[var(--admin-text-muted)]">Review type</dt>
                <dd className="mt-1 text-[var(--admin-text-strong)]">
                  {detailReview.reviewKind.replaceAll("_", " ")}
                </dd>
              </div>
              <div>
                <dt className="text-[var(--admin-text-muted)]">Amount</dt>
                <dd className="mt-1 text-[var(--admin-text-strong)]">
                  {detailReview.amount.toLocaleString()} {detailReview.currency}
                </dd>
              </div>
              <div>
                <dt className="text-[var(--admin-text-muted)]">Message preview</dt>
                <dd className="mt-1 break-words text-[var(--admin-text-strong)]">
                  {detailReview.smsPreview}
                </dd>
              </div>
              <div>
                <dt className="text-[var(--admin-text-muted)]">Reason</dt>
                <dd className="mt-1 text-[var(--admin-text-strong)]">
                  {detailReview.reason.replaceAll("_", " ")}
                </dd>
              </div>
            </dl>
            <label className="grid gap-2 text-[var(--admin-text-muted)]">
              Matching pending intent
              <select
                value={intentSelections[detailReview.reviewId] ?? ""}
                onChange={(event) =>
                  setIntentSelections((current) => ({
                    ...current,
                    [detailReview.reviewId]: event.target.value,
                  }))
                }
                className="admin-input"
                disabled={mutationLocked}
              >
                <option value="">Choose a payment intent</option>
                {matchingIntents(detailReview).map((intent) => (
                  <option key={intent.id} value={intent.id}>
                    {intent.userName} • {intent.expectedAmount.toLocaleString()}{" "}
                    {intent.currency} • {intent.summaryLabel}
                  </option>
                ))}
              </select>
            </label>
            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => handleAllocate(detailReview).catch(() => {})}
                disabled={
                  mutationLocked ||
                  matchingIntents(detailReview).length === 0 ||
                  !intentSelections[detailReview.reviewId]
                }
                className="admin-button admin-button-primary disabled:opacity-60"
              >
                {busyReviewId === detailReview.reviewId
                  ? "Working…"
                  : "Allocate"}
              </button>
              <button
                type="button"
                onClick={() => handleReject(detailReview).catch(() => {})}
                disabled={mutationLocked}
                className="admin-button admin-button-secondary !text-[var(--admin-danger-text)] disabled:opacity-60"
              >
                Reject
              </button>
            </div>
          </div>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}
