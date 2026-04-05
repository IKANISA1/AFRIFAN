"use client";

import { useCallback, useEffect, useState } from "react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { getAdminSmsSnapshot } from "@/lib/data/admin/sms";
import { cn } from "@/lib/utils";
import type { AdminSmsSnapshot } from "@/lib/types";

const emptySnapshot: AdminSmsSnapshot = {
  metrics: {},
  syncRuns: [],
};

const pipelineSteps = [
  { step: "1", title: "Capture", body: "Android SMS listener receives an approved sender event.", color: "border-emerald-500/30 bg-emerald-500/5" },
  { step: "2", title: "Ingest", body: "The Edge Function deduplicates and writes to `momo_sms_raw`.", color: "border-club-accent/30 bg-club-accent/5" },
  { step: "3", title: "Parse", body: "Structured values land in `momo_sms_parsed` for finance logic.", color: "border-amber-500/30 bg-amber-500/5" },
  { step: "4", title: "Ledger", body: "Wallet and contribution records reconcile against supporter activity.", color: "border-violet-500/30 bg-violet-500/5" },
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
  const [loading, setLoading] = useState(true);

  const loadSnapshot = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminSmsSnapshot(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load SMS pipeline health.",
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

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="SMS pipeline"
        title="Watch the MoMo SMS ingestion chain from capture to ledger."
        description="This view mirrors the mobile admin monitor but is optimized for web operations on phones and tablets during support and finance reconciliation."
      />

      <div className="grid gap-5 md:grid-cols-3">
        {metricEntries.length === 0 && loading ? (
          <>
            {Array.from({ length: 3 }).map((_, i) => (
              <AdminStateCard
                key={i}
                label="Pipeline"
                value="..."
                helper="Loading SMS ingestion metrics."
              />
            ))}
          </>
        ) : null}
        {metricEntries.map(([label, value]) => (
          <AdminStateCard
            key={label}
            label={label}
            value={value.toString()}
            helper="Club-scoped operational metric from the SMS ingestion pipeline."
          />
        ))}
      </div>

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
    </div>
  );
}
