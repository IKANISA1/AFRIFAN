"use client";

import { useCallback, useEffect, useState } from "react";
import { Coins, CircleDollarSign, Users } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import {
  downloadContributionExcel,
  getAdminContributionSnapshot,
} from "@/lib/data/admin";
import { formatCurrency } from "@/lib/utils";
import type { AdminContributionSnapshot } from "@/lib/types";

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  aliases: {},
  monthlyTotal: 0,
};

export default function AdminContributionsPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [filter, setFilter] = useState("ALL");
  const [sortMode, setSortMode] = useState("RECENT");
  const [loading, setLoading] = useState(true);

  const loadMonitor = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminContributionSnapshot(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load contributions monitor.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadMonitor().catch(() => {});
  }, [access.hasAccess, client, loadMonitor]);

  async function exportExcel() {
    try {
      await downloadContributionExcel(snapshot);
      showAdminToast("Contribution report downloaded as Excel.", "success");
    } catch {
      showAdminToast("Could not generate Excel report.", "error");
    }
  }

  const filteredGroups = snapshot.groups
    .filter((group) => {
      switch (filter) {
        case "CLUB PROJECTS":
          return group.groupType === "project";
        case "COMMUNITY":
          return group.groupType === "general";
        case "SAVINGS":
          return group.groupType === "savings";
        default:
          return true;
      }
    })
    .sort((left, right) => {
      if (sortMode === "TOTAL") {
        return right.currentTotal - left.currentTotal;
      }
      return right.createdAt.localeCompare(left.createdAt);
    });

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Contributions monitor"
        title="Track supporter funding, momentum, and chapter health."
        description="The contributions surface is optimized for field operations on tablets and phones, with card-based reporting instead of desktop-only tables."
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Raised this month"
          value={loading ? "..." : formatCurrency(snapshot.monthlyTotal)}
          helper="Successful contribution volume in the current UTC month."
          icon={Coins}
        />
        <AdminStateCard
          label="Active circles"
          value={loading ? "..." : snapshot.groups.filter((group) => !group.isClosed).length.toString()}
          helper="Open groups with club-scoped visibility."
          icon={CircleDollarSign}
        />
        <AdminStateCard
          label="Recent contributions"
          value={loading ? "..." : snapshot.contributions.length.toString()}
          helper="Latest contribution rows available to the admin monitor."
          icon={Users}
        />
      </div>

      <div className="glass-panel rounded-[32px] p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2">
            {["ALL", "CLUB PROJECTS", "COMMUNITY", "SAVINGS"].map((item) => (
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
            {["RECENT", "TOTAL"].map((item) => (
              <button
                key={item}
                type="button"
                data-active={sortMode === item}
                onClick={() => setSortMode(item)}
                className="dashboard-chip"
              >
                Sort {item}
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={() => {
              exportExcel().catch(() => {});
            }}
            className="rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-club-secondary"
          >
            Export Excel
          </button>
        </div>

        <div className="mt-5 space-y-3">
          {loading ? (
            <div className="space-y-3">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                  <Skeleton className="skeleton-text h-6 w-2/5" />
                  <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                  <Skeleton className="mt-4 h-3 w-full rounded-full" />
                  <div className="mt-4 grid gap-3 sm:grid-cols-4">
                    {Array.from({ length: 4 }).map((_, j) => (
                      <Skeleton key={j} className="h-16 rounded-[22px]" />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          ) : null}
          {!loading && filteredGroups.length === 0 ? (
            <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
              No contribution groups match the current view.
            </p>
          ) : null}
          {!loading && filteredGroups.map((group) => {
            const creatorAlias = group.creatorId
              ? snapshot.aliases[group.creatorId] ?? "000000"
              : "000000";

            return (
              <article
                key={group.id}
                className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="font-display text-2xl font-bold uppercase leading-none">
                      {group.name}
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      {group.description}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">
                      {group.groupType}
                    </span>
                    <span className={`rounded-full border px-3 py-1.5 text-xs uppercase tracking-[0.18em] ${group.isClosed ? "border-rose-400/30 text-rose-300" : "border-emerald-500/30 text-emerald-400"}`}>
                      {group.isClosed ? "Closed" : "Active"}
                    </span>
                  </div>
                </div>
                <div className="mt-4">
                  <ProgressBar
                    value={group.currentTotal}
                    max={group.targetAmount}
                    label="Funding progress"
                    compact
                  />
                </div>
                <div className="mt-4 grid gap-3 sm:grid-cols-4">
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Total
                    </p>
                    <p className="mt-2 text-sm text-slate-200">
                      {formatCurrency(group.currentTotal)}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Target
                    </p>
                    <p className="mt-2 text-sm text-slate-200">
                      {formatCurrency(group.targetAmount)}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Members
                    </p>
                    <p className="mt-2 text-sm text-slate-200">
                      {group.memberCount}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Creator
                    </p>
                    <p className="mt-2 text-sm text-slate-200">{creatorAlias}</p>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </div>
  );
}
