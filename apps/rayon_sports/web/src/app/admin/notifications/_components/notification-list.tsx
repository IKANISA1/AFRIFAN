import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminNotificationContext } from "@/lib/types";
import { notifStatusColors } from "./notification-state";

export function NotificationList({
  context,
  loading,
  onRefresh,
}: {
  context: AdminNotificationContext;
  loading: boolean;
  onRefresh: () => void;
}) {
  return (
    <section className="glass-panel rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          Delivery history
        </p>
        <button
          type="button"
          onClick={onRefresh}
          className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
        >
          Refresh
        </button>
      </div>

      <div className="mt-5 space-y-3">
        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                <Skeleton className="skeleton-text h-6 w-2/5" />
                <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                <div className="mt-4 grid gap-3 sm:grid-cols-3">
                  {Array.from({ length: 3 }).map((_, j) => (
                    <Skeleton key={j} className="h-16 rounded-[22px]" />
                  ))}
                </div>
              </div>
            ))}
          </div>
        ) : null}
        {!loading && context.history.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            No notifications have been recorded yet.
          </p>
        ) : null}
        {!loading && context.history.map((item) => {
          const total = item.sentCount + item.failedCount;
          const statusClass = notifStatusColors[item.status] ?? notifStatusColors.pending;

          return (
            <article
              key={item.id}
              className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="font-display text-2xl font-bold uppercase leading-none">
                    {item.title}
                  </p>
                  <p className="mt-2 text-sm leading-6 text-slate-300">
                    {item.body}
                  </p>
                </div>
                <span className={cn("rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]", statusClass)}>
                  {item.status}
                </span>
              </div>
              {total > 0 ? (
                <div className="mt-4">
                  <ProgressBar
                    value={item.sentCount}
                    max={total}
                    label="Delivery success"
                    compact
                  />
                </div>
              ) : null}
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                    Audience
                  </p>
                  <p className="mt-2 text-sm text-slate-200">
                    {item.audienceType === "all_fans"
                      ? "All fans"
                      : item.audienceType === "by_tier"
                        ? `Tier • ${item.audienceTier}`
                        : item.audienceGroupName ?? "Group"}
                  </p>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                    Delivery
                  </p>
                  <p className="mt-2 text-sm text-slate-200">
                    {item.deliveryMode === "schedule" ? "Scheduled" : "Immediate"}
                  </p>
                </div>
                <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                    Metrics
                  </p>
                  <p className="mt-2 text-sm text-slate-200">
                    <span className="text-emerald-400">{item.sentCount}</span> sent •{" "}
                    <span className={item.failedCount > 0 ? "text-rose-400" : "text-slate-400"}>{item.failedCount}</span> failed
                  </p>
                </div>
              </div>
              {item.lastError ? (
                <p className="mt-4 rounded-[22px] border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
                  {item.lastError}
                </p>
              ) : null}
            </article>
          );
        })}
      </div>
    </section>
  );
}
