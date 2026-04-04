"use client";

import { Trash2 } from "lucide-react";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import { formatCurrency, formatDate } from "@/lib/utils";
import { statusColors } from "./match-form-state";
import type { AdminMatchItem } from "@/lib/types";

function MatchStatusBadge({ status }: { status: string }) {
  const colorClass = statusColors[status] ?? statusColors.scheduled;
  const isLive = status === "live" || status === "halftime";

  return (
    <span className={cn("inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]", colorClass)}>
      {isLive ? <span className="h-1.5 w-1.5 rounded-full bg-current animate-pulse" /> : null}
      {status}
    </span>
  );
}

interface MatchListProps {
  matches: AdminMatchItem[];
  filter: string;
  setFilter: (filter: string) => void;
  loading: boolean;
  onEdit: (match: AdminMatchItem) => void;
  onDelete: (match: AdminMatchItem) => void;
}

export function MatchList({
  matches,
  filter,
  setFilter,
  loading,
  onEdit,
  onDelete,
}: MatchListProps) {
  const filteredMatches = matches.filter((match) => {
    const date = new Date(match.matchDate);
    const today = new Date();
    const upcoming = date >= new Date(today.getFullYear(), today.getMonth(), today.getDate());

    switch (filter) {
      case "LIVE":
        return match.matchStatus === "live" || match.matchStatus === "halftime";
      case "UPCOMING":
        return upcoming;
      case "COMPLETED":
        return !upcoming;
      case "ON SALE":
        return match.isOnSale;
      default:
        return true;
    }
  });

  return (
    <section className="glass-panel rounded-[32px] p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          Fixture list
        </p>
        <div className="flex flex-wrap gap-2">
          {["ALL", "LIVE", "UPCOMING", "COMPLETED", "ON SALE"].map((item) => (
            <button
              key={item}
              type="button"
              data-active={filter === item}
              onClick={() => setFilter(item)}
              className="dashboard-chip"
            >
              {item}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-5 space-y-3">
        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                <Skeleton className="skeleton-text h-6 w-3/5" />
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
        {!loading && filteredMatches.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            No fixtures match the current filter.
          </p>
        ) : null}
        {!loading && filteredMatches.map((match) => (
          <article
            key={match.id}
            className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="flex flex-wrap items-center gap-3">
                  <p className="font-display text-2xl font-bold uppercase leading-none">
                    {match.homeTeam} vs {match.awayTeam}
                  </p>
                  <MatchStatusBadge status={match.matchStatus} />
                </div>
                <p className="mt-2 text-sm leading-6 text-slate-300">
                  {match.competition} • {match.venue} • {formatDate(match.matchDate)}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => onEdit(match)}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => onDelete(match)}
                  className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                >
                  <span className="inline-flex items-center gap-1.5">
                    <Trash2 size={12} />
                    Delete
                  </span>
                </button>
              </div>
            </div>
            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                  Sales
                </p>
                <p className="mt-2 text-sm text-slate-200">
                  <span className={match.isOnSale ? "text-emerald-400" : "text-slate-400"}>
                    {match.isOnSale ? "On sale" : "Closed"}
                  </span>
                  {" • "}
                  {formatCurrency(match.generalPrice)}
                </p>
              </div>
              <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                  Score
                </p>
                <p className="mt-2 font-display text-xl font-bold text-slate-200">
                  {match.homeScore} – {match.awayScore}
                </p>
              </div>
              <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                  Capacity
                </p>
                <div className="mt-2">
                  <ProgressBar value={match.soldCount} max={match.capacity} compact />
                </div>
              </div>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
