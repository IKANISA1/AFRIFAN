"use client";

import { useCallback, useEffect, useState } from "react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
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

const runStatusColors: Record<string, string> = {
  success: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  completed: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  running: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  failed: "bg-rose-500/15 text-rose-300 border-rose-500/30",
  unknown: "bg-white/8 text-slate-300 border-border-soft",
};

export default function AdminSmsMonitorPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [manualReviews, setManualReviews] = useState<AdminSmsManualReview[]>([]);
  const [pendingIntents, setPendingIntents] = useState<AdminPendingPaymentIntent[]>([]);
  const [intentSelections, setIntentSelections] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [busyReviewId, setBusyReviewId] = useState<string | null>(null);

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
        detail: "This marks the SMS review as not app-linked and leaves the ledger draft in place.",
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
        description="Monitor pipeline health, recent sync runs, and operational gaps in one place."
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
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4">
                    <Skeleton className="skeleton-text h-6 w-24" />
                    <Skeleton className="skeleton-text mt-3 h-3 w-full" />
                    <Skeleton className="skeleton-text mt-3 h-2 w-20" />
                  </div>
                ))}
              </div>
            ) : null}
            {!loading && snapshot.syncRuns.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No sync runs have been recorded yet.
              </p>
            ) : null}
            {!loading && snapshot.syncRuns.map((run) => {
              const statusClass = runStatusColors[run.status] ?? runStatusColors.unknown;

              return (
                <article
                  key={run.id}
                  className="card-interactive rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <span className={cn("inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]", statusClass)}>
                        {run.status === "running" ? <span className="h-1.5 w-1.5 rounded-full bg-current animate-pulse" /> : null}
                        {run.status}
                      </span>
                    </div>
                    <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-slate-300">
                      {run.trigger}
                    </span>
                  </div>
                  <div className="mt-3 grid gap-3 sm:grid-cols-2">
                    <div className="rounded-[18px] border border-border-soft bg-black/10 px-3 py-2">
                      <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-club-accent">Scanned</p>
                      <p className="mt-1 font-display text-lg font-bold">{run.scannedMessages}</p>
                    </div>
                    <div className="rounded-[18px] border border-border-soft bg-black/10 px-3 py-2">
                      <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-club-accent">Uploaded</p>
                      <p className="mt-1 font-display text-lg font-bold">{run.uploadedMessages}</p>
                    </div>
                  </div>
                  <p className="mt-3 font-mono text-[11px] uppercase tracking-[0.24em] text-slate-400">
                    {run.startedAt
                      ? new Date(run.startedAt).toLocaleString("en-RW", {
                          month: "short",
                          day: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        })
                      : "Awaiting run timestamp"}
                  </p>
                </article>
              );
            })}
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
            {loading ? (
              Array.from({ length: 3 }).map((_, index) => (
                <div
                  key={index}
                  className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
                >
                  <Skeleton className="skeleton-text h-5 w-40" />
                  <Skeleton className="skeleton-text mt-3 h-3 w-full" />
                  <Skeleton className="skeleton-text mt-3 h-3 w-2/3" />
                </div>
              ))
            ) : null}
            {!loading && manualReviews.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No manual SMS reviews are waiting for action.
              </p>
            ) : null}
            {!loading &&
              manualReviews.map((review) => {
                const intents = matchingIntents(review);
                const busy = busyReviewId === review.reviewId;
                return (
                  <article
                    key={review.reviewId}
                    className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="rounded-full border border-amber-400/30 bg-amber-500/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-amber-200">
                            {review.reviewKind.replaceAll("_", " ")}
                          </span>
                          <span className="rounded-full border border-white/10 bg-black/10 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300">
                            {review.amount.toLocaleString()} {review.currency}
                          </span>
                          {review.momoTxId ? (
                            <span className="rounded-full border border-white/10 bg-black/10 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300">
                              {review.momoTxId}
                            </span>
                          ) : null}
                        </div>
                        <p className="mt-3 text-sm font-semibold text-white">
                          {review.payerName ?? review.sender} → {review.payeeName ?? review.payeeNumberOrCode ?? "receiver"}
                        </p>
                        <p className="mt-2 text-sm leading-6 text-slate-300">
                          {review.smsPreview}
                        </p>
                      </div>
                      <div className="rounded-[20px] border border-white/8 bg-black/10 px-3 py-2 text-right text-xs text-slate-400">
                        <p>{review.reason.replaceAll("_", " ")}</p>
                        <p className="mt-1">
                          {review.updatedAt
                            ? new Date(review.updatedAt).toLocaleString("en-RW", {
                                month: "short",
                                day: "numeric",
                                hour: "2-digit",
                                minute: "2-digit",
                              })
                            : "Awaiting timestamp"}
                        </p>
                      </div>
                    </div>

                    <div className="mt-4 grid gap-3 lg:grid-cols-[1fr_auto]">
                      <label className="grid gap-2 text-sm text-slate-300">
                        Matching pending intent
                        <select
                          value={intentSelections[review.reviewId] ?? ""}
                          onChange={(event) =>
                            setIntentSelections((current) => ({
                              ...current,
                              [review.reviewId]: event.target.value,
                            }))
                          }
                          className="admin-input"
                          disabled={busy}
                        >
                          <option value="">Choose a payment intent</option>
                          {intents.map((intent) => (
                            <option key={intent.id} value={intent.id}>
                              {intent.userName} • {intent.expectedAmount.toLocaleString()} {intent.currency} • {intent.summaryLabel}
                            </option>
                          ))}
                        </select>
                      </label>

                      <div className="flex flex-wrap items-end gap-3">
                        <button
                          type="button"
                          onClick={() => handleAllocate(review).catch(() => {})}
                          disabled={busy || intents.length === 0 || !intentSelections[review.reviewId]}
                          className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light disabled:opacity-60"
                        >
                          {busy ? "Working…" : "Allocate"}
                        </button>
                        <button
                          type="button"
                          onClick={() => handleReject(review).catch(() => {})}
                          disabled={busy}
                          className="rounded-full border border-rose-400/30 bg-rose-500/10 px-5 py-3 text-sm font-semibold text-rose-100 transition hover:bg-rose-500/15 disabled:opacity-60"
                        >
                          Reject
                        </button>
                      </div>
                    </div>

                    {review.notes ? (
                      <p className="mt-3 rounded-[18px] border border-white/8 bg-black/10 px-3 py-2 text-sm leading-6 text-slate-300">
                        {review.notes}
                      </p>
                    ) : null}
                  </article>
                );
              })}
          </div>
        </section>
      ) : null}
    </div>
  );
}
