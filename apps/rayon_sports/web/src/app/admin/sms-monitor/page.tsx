"use client";

import { useCallback, useEffect, useState } from "react";
import { Search } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
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
  rejectAdminSmsManualReview,
} from "@/lib/data/admin/sms";
import { cn } from "@/lib/utils";
import type {
  AdminPendingPaymentIntent,
  AdminSmsManualReview,
  AdminSmsSnapshot,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";

const emptySnapshot: AdminSmsSnapshot = {
  metrics: {},
  syncRuns: [],
};

const pipelineSteps = [
  { step: "1", title: "Capture", body: "SMS listener receives an approved sender event.", color: "border-emerald-500/30 bg-emerald-500/5" },
  { step: "2", title: "Ingest", body: "Edge Function deduplicates and writes to raw table.", color: "border-club-accent/30 bg-club-accent/5" },
  { step: "3", title: "Parse", body: "Structured values land in parsed table.", color: "border-amber-500/30 bg-amber-500/5" },
  { step: "4", title: "Ledger", body: "Wallet and contribution records reconcile.", color: "border-violet-500/30 bg-violet-500/5" },
];

export default function AdminSmsMonitorPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [manualReviews, setManualReviews] = useState<AdminSmsManualReview[]>([]);
  const [pendingIntents, setPendingIntents] = useState<AdminPendingPaymentIntent[]>([]);
  const [intentSelections, setIntentSelections] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [busyReviewId, setBusyReviewId] = useState<string | null>(null);
  const [detailReview, setDetailReview] =
    useState<AdminSmsManualReview | null>(null);

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
    getSortValue: (
      review,
      key: "kind" | "amount" | "reason" | "updatedAt",
    ) => {
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

  const loadSnapshot = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      const [nextSnapshot, manualWorkspace] = await Promise.all([
        getAdminSmsSnapshot(client, access),
        access.isSuperAdmin
          ? getAdminSmsManualReviewWorkspace(client, access)
          : Promise.resolve({ reviews: [], pendingIntents: [] }),
      ]);
      setSnapshot(nextSnapshot);
      setManualReviews(manualWorkspace.reviews);
      setPendingIntents(manualWorkspace.pendingIntents);
      setIntentSelections((current) => {
        const next = { ...current };
        for (const review of manualWorkspace.reviews) {
          const currentSelection = current[review.reviewId];
          if (currentSelection) {
            next[review.reviewId] = currentSelection;
            continue;
          }
          const firstMatch = manualWorkspace.pendingIntents.find(
            (intent) =>
              intent.expectedAmount === review.amount &&
              intent.currency === review.currency &&
              (review.userId == null || intent.userId === review.userId),
          );
          if (firstMatch) {
            next[review.reviewId] = firstMatch.id;
          }
        }
        return next;
      });
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load SMS pipeline health.";
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
    loadSnapshot().catch(() => {});
  }, [access.hasAccess, client, loadSnapshot]);

  const metricEntries = Object.entries(snapshot.metrics);

  async function handleAllocate(review: AdminSmsManualReview) {
    if (client == null) {
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
      await loadSnapshot();
      setDetailReview(null);
      showAdminToast("Manual review allocated.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not allocate the manual review.",
        "error",
      );
    } finally {
      setBusyReviewId(null);
    }
  }

  async function handleReject(review: AdminSmsManualReview) {
    if (client == null) {
      return;
    }
    if (
      !confirmAdminDestructiveAction({
        action: "Reject",
        subject: review.momoTxId ?? review.reviewId,
        scope: `Active club ${access.clubId ?? "not selected"}; one manual review`,
        impact: "This marks the SMS review as not app-linked and leaves the ledger draft in place.",
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
      await loadSnapshot();
      setDetailReview(null);
      showAdminToast("Manual review rejected.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not reject the manual review.",
        "error",
      );
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
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="SMS pipeline"
        title="MoMo SMS ingestion health"
      />

      {loadError && !loading ? (
        <AdminErrorState
          title="SMS monitoring data could not be loaded"
          description={loadError}
          onRetry={() => {
            loadSnapshot().catch(() => {});
          }}
        />
      ) : null}

      <div className="grid gap-5 md:grid-cols-3">
        {metricEntries.length === 0 && loading ? (
          <>
            {Array.from({ length: 3 }).map((_, i) => (
              <AdminStateCard
                key={i}
                label="Pipeline"
                value="..."
                helper="Loading metrics."
              />
            ))}
          </>
        ) : null}
        {metricEntries.map(([label, value]) => (
          <AdminStateCard
            key={label}
            label={label}
            value={value.toString()}
            helper="Pipeline metric."
          />
        ))}
      </div>

      {!loadError ? (
      <section className="grid gap-5 lg:grid-cols-[0.85fr_1.15fr]">
        <article className="glass-panel rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">
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
                    <div className="flex h-8 w-8 items-center justify-center rounded-full border border-border-soft bg-white/10 font-display text-sm font-bold">
                      {item.step}
                    </div>
                    <div>
                      <p className="font-display text-2xl font-bold uppercase leading-none">
                        {item.title}
                      </p>
                    </div>
                  </div>
                  <p className="mt-2 pl-11 text-sm leading-6 text-slate-300">{item.body}</p>
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

        <article className="glass-panel rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Recent sync runs
            </p>
            <button
              type="button"
              onClick={() => loadSnapshot().catch(() => {})}
              className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
            >
              Refresh
            </button>
          </div>
          <div className="mt-5 space-y-3">
            <AdminFilterBar>
              <label className="admin-search-field">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">Search SMS synchronization runs</span>
                <input
                  type="search"
                  value={runCollection.query}
                  onChange={(event) => runCollection.setQuery(event.target.value)}
                  placeholder="Search status, trigger, or counts"
                />
              </label>
            </AdminFilterBar>
            <AdminDataGrid
              caption="SMS synchronization runs"
              busy={loading}
              columns={[
                { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: runCollection.sortDirectionFor("status"), onSort: () => runCollection.toggleSort("status") },
                { key: "trigger", label: "Trigger", priority: "primary", sortable: true, sortDirection: runCollection.sortDirectionFor("trigger"), onSort: () => runCollection.toggleSort("trigger") },
                { key: "scanned", label: "Scanned", priority: "secondary", sortable: true, sortDirection: runCollection.sortDirectionFor("scanned"), onSort: () => runCollection.toggleSort("scanned") },
                { key: "uploaded", label: "Uploaded", priority: "secondary", sortable: true, sortDirection: runCollection.sortDirectionFor("uploaded"), onSort: () => runCollection.toggleSort("uploaded") },
                { key: "started", label: "Started", priority: "primary", sortable: true, sortDirection: runCollection.sortDirectionFor("startedAt"), onSort: () => runCollection.toggleSort("startedAt") },
              ]}
            >
              {loading ? (
                Array.from({ length: 3 }).map((_, index) => (
                  <tr key={index}><td colSpan={5}><Skeleton className="skeleton-text h-6 w-full" /></td></tr>
                ))
              ) : runCollection.pageResult.items.length === 0 ? (
                <tr><td colSpan={5} className="py-8 text-center text-sm text-slate-400">{runCollection.query ? "No sync runs match the current search." : "No sync runs have been recorded yet."}</td></tr>
              ) : (
                runCollection.pageResult.items.map((run) => (
                  <tr key={run.id}>
                    <td><AdminStatusBadge label={run.status} tone={run.status === "failed" ? "danger" : run.status === "running" ? "warning" : "success"} /></td>
                    <td>{run.trigger}</td>
                    <td>{run.scannedMessages}</td>
                    <td>{run.uploadedMessages}</td>
                    <td>{run.startedAt ? new Date(run.startedAt).toLocaleString("en-RW") : "Awaiting timestamp"}</td>
                  </tr>
                ))
              )}
            </AdminDataGrid>
            <AdminPagination page={runCollection.pageResult} onPageChange={runCollection.setPage} label="SMS synchronization runs" />
          </div>
        </article>
      </section>
      ) : null}

      {access.isSuperAdmin ? (
        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="font-mono text-[11px] uppercase tracking-[0.3em] text-club-accent">
                Manual review
              </p>
              <h2 className="mt-2 font-display text-3xl font-bold uppercase leading-none text-white">
                Pending allocation queue
              </h2>
              <p className="mt-3 max-w-3xl text-sm leading-7 text-slate-300">
                Review unmatched MoMo SMS records, route them to the correct payment intent, or explicitly reject them as not app-linked.
              </p>
            </div>
            <div className="rounded-full border border-border-soft bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-300">
              {manualReviews.length} open review{manualReviews.length === 1 ? "" : "s"}
            </div>
          </div>

          <div className="mt-6 space-y-4">
            <AdminFilterBar>
              <label className="admin-search-field">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">Search manual SMS reviews</span>
                <input type="search" value={reviewCollection.query} onChange={(event) => reviewCollection.setQuery(event.target.value)} placeholder="Search payer, receiver, reason, or transaction" />
              </label>
            </AdminFilterBar>
            <AdminDataGrid
              caption="Pending manual SMS allocation reviews"
              busy={loading}
              onRowActivate={(rowId) => setDetailReview(manualReviews.find((review) => review.reviewId === rowId) ?? null)}
              columns={[
                { key: "kind", label: "Review", priority: "primary", sortable: true, sortDirection: reviewCollection.sortDirectionFor("kind"), onSort: () => reviewCollection.toggleSort("kind") },
                { key: "parties", label: "Payer to receiver", priority: "primary" },
                { key: "amount", label: "Amount", priority: "primary", sortable: true, sortDirection: reviewCollection.sortDirectionFor("amount"), onSort: () => reviewCollection.toggleSort("amount") },
                { key: "reason", label: "Reason", priority: "secondary", sortable: true, sortDirection: reviewCollection.sortDirectionFor("reason"), onSort: () => reviewCollection.toggleSort("reason") },
                { key: "updated", label: "Updated", priority: "secondary", sortable: true, sortDirection: reviewCollection.sortDirectionFor("updatedAt"), onSort: () => reviewCollection.toggleSort("updatedAt") },
              ]}
            >
              {loading ? (
                Array.from({ length: 3 }).map((_, index) => <tr key={index}><td colSpan={5}><Skeleton className="skeleton-text h-6 w-full" /></td></tr>)
              ) : reviewCollection.pageResult.items.length === 0 ? (
                <tr><td colSpan={5} className="py-8 text-center text-sm text-slate-400">{reviewCollection.query ? "No manual reviews match the current search." : "No manual SMS reviews are waiting for action."}</td></tr>
              ) : (
                reviewCollection.pageResult.items.map((review) => (
                  <tr key={review.reviewId} data-row-id={review.reviewId}>
                    <td>{review.reviewKind.replaceAll("_", " ")}<span className="block max-w-48 truncate text-xs text-slate-500">{review.momoTxId ?? review.reviewId}</span></td>
                    <td>{review.payerName ?? review.sender} → {review.payeeName ?? review.payeeNumberOrCode ?? "receiver"}</td>
                    <td>{review.amount.toLocaleString()} {review.currency}</td>
                    <td>{review.reason.replaceAll("_", " ")}</td>
                    <td>{review.updatedAt ? new Date(review.updatedAt).toLocaleString("en-RW") : "Awaiting timestamp"}</td>
                  </tr>
                ))
              )}
            </AdminDataGrid>
            <AdminPagination page={reviewCollection.pageResult} onPageChange={reviewCollection.setPage} label="Manual SMS reviews" />
          </div>
        </section>
      ) : null}
      <AdminActionDrawer open={detailReview != null} onClose={() => setDetailReview(null)} title="Manual SMS review">
        {detailReview ? (
          <div className="grid gap-5 text-sm">
            <dl className="grid gap-3">
              <div><dt className="text-slate-500">Review type</dt><dd className="mt-1 text-slate-100">{detailReview.reviewKind.replaceAll("_", " ")}</dd></div>
              <div><dt className="text-slate-500">Amount</dt><dd className="mt-1 text-slate-100">{detailReview.amount.toLocaleString()} {detailReview.currency}</dd></div>
              <div><dt className="text-slate-500">Message preview</dt><dd className="mt-1 break-words text-slate-100">{detailReview.smsPreview}</dd></div>
              <div><dt className="text-slate-500">Reason</dt><dd className="mt-1 text-slate-100">{detailReview.reason.replaceAll("_", " ")}</dd></div>
            </dl>
            <label className="grid gap-2 text-slate-300">
              Matching pending intent
              <select value={intentSelections[detailReview.reviewId] ?? ""} onChange={(event) => setIntentSelections((current) => ({ ...current, [detailReview.reviewId]: event.target.value }))} className="admin-input" disabled={busyReviewId === detailReview.reviewId}>
                <option value="">Choose a payment intent</option>
                {matchingIntents(detailReview).map((intent) => <option key={intent.id} value={intent.id}>{intent.userName} • {intent.expectedAmount.toLocaleString()} {intent.currency} • {intent.summaryLabel}</option>)}
              </select>
            </label>
            <div className="flex flex-wrap gap-3">
              <button type="button" onClick={() => handleAllocate(detailReview).catch(() => {})} disabled={busyReviewId === detailReview.reviewId || matchingIntents(detailReview).length === 0 || !intentSelections[detailReview.reviewId]} className="admin-button admin-button-primary disabled:opacity-60">{busyReviewId === detailReview.reviewId ? "Working…" : "Allocate"}</button>
              <button type="button" onClick={() => handleReject(detailReview).catch(() => {})} disabled={busyReviewId === detailReview.reviewId} className="admin-button admin-button-secondary !text-rose-200 disabled:opacity-60">Reject</button>
            </div>
          </div>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}
