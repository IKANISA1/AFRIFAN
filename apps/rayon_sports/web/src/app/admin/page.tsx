"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  Users,
  CircleDollarSign,
  ArrowRightLeft,
  Ticket,
  Newspaper,
  CalendarDays,
  HeartHandshake,
  Bell,
  Settings,
  ShoppingBag,
  Crown,
} from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { getAdminDashboardSnapshot } from "@/lib/data/admin";
import type { AdminDashboardSnapshot } from "@/lib/types";

const emptySnapshot: AdminDashboardSnapshot = {
  metrics: {
    totalUsers: 0,
    activeGroups: 0,
    transactionsToday: 0,
    ticketsSold: 0,
  },
  activity: [],
};

const quickActions = [
  {
    href: "/admin/settings",
    title: "Tune club settings",
    icon: Settings,
  },
  {
    href: "/admin/cms",
    title: "Publish club content",
    icon: Newspaper,
  },
  {
    href: "/admin/matches",
    title: "Update fixtures",
    icon: CalendarDays,
  },
  {
    href: "/admin/shop",
    title: "Manage merchandise",
    icon: ShoppingBag,
  },
  {
    href: "/admin/membership",
    title: "Control membership",
    icon: Crown,
  },
  {
    href: "/admin/contributions",
    title: "Monitor circles",
    icon: HeartHandshake,
  },
  {
    href: "/admin/notifications",
    title: "Broadcast updates",
    icon: Bell,
  },
];

export default function AdminDashboardPage() {
  const { client, access } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [loading, setLoading] = useState(true);

  const loadDashboard = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminDashboardSnapshot(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load admin dashboard.",
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

    loadDashboard().catch(() => {});
  }, [access.hasAccess, client, loadDashboard]);

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Admin dashboard"
        title="Operate matchdays, content, and supporter activity from one place."
      />

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <AdminStateCard
          label="Total users"
          value={loading ? "..." : snapshot.metrics.totalUsers.toString()}
          icon={Users}
        />
        <AdminStateCard
          label="Active circles"
          value={loading ? "..." : snapshot.metrics.activeGroups.toString()}
          icon={CircleDollarSign}
        />
        <AdminStateCard
          label="Transactions today"
          value={loading ? "..." : snapshot.metrics.transactionsToday.toString()}
          icon={ArrowRightLeft}
        />
        <AdminStateCard
          label="Tickets sold"
          value={loading ? "..." : snapshot.metrics.ticketsSold.toString()}
          icon={Ticket}
        />
      </div>

      <section className="grid gap-5 lg:grid-cols-[1.2fr_0.8fr]">
        <article className="glass-panel rounded-[32px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Quick actions
          </p>
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            {quickActions.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className="card-interactive rounded-[20px] border border-border-soft bg-white/5 px-4 py-3 transition group flex items-center gap-3"
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-border-soft bg-white/5 text-slate-400 transition group-hover:text-club-accent group-hover:border-club-accent/30">
                    <Icon size={18} />
                  </div>
                  <p className="font-display text-lg font-bold uppercase leading-none">
                    {item.title}
                  </p>
                </Link>
              );
            })}
          </div>
        </article>

        <article className="glass-panel rounded-[32px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Recent activity
          </p>
          <div className="mt-5 space-y-3">
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4">
                    <Skeleton className="skeleton-text h-5 w-3/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                    <Skeleton className="skeleton-text mt-3 h-2 w-20" />
                  </div>
                ))}
              </div>
            ) : snapshot.activity.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No activity yet.
              </p>
            ) : null}
            {snapshot.activity.map((item) => (
              <article
                key={item.id}
                className="py-4 border-b border-border-soft last:border-0"
              >
                <div className="flex justify-between items-start gap-4">
                  <div>
                    <p className="font-display text-lg font-bold uppercase leading-none">
                      {item.title}
                    </p>
                    <p className="mt-1 text-sm text-slate-300">
                      {item.detail}
                    </p>
                  </div>
                  <p className="shrink-0 font-mono text-[10px] uppercase tracking-[0.1em] text-slate-500">
                    {new Date(item.createdAt).toLocaleString("en-RW", {
                      month: "short",
                      day: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </p>
                </div>
              </article>
            ))}
          </div>
        </article>
      </section>
    </div>
  );
}
