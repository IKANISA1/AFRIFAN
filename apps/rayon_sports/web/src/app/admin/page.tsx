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
    href: "/admin/cms",
    title: "Publish club content",
    body: "Create and push news articles, headlines, and homepage stories.",
    icon: Newspaper,
  },
  {
    href: "/admin/matches",
    title: "Update fixtures",
    body: "Manage ticketing, live scores, featured matches, and sale status.",
    icon: CalendarDays,
  },
  {
    href: "/admin/contributions",
    title: "Monitor circles",
    body: "Track supporter funds, momentum, and creator performance.",
    icon: HeartHandshake,
  },
  {
    href: "/admin/notifications",
    title: "Broadcast updates",
    body: "Send or schedule supporter notifications by audience segment.",
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
      setSnapshot(await getAdminDashboardSnapshot(client));
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
  }, [client]);

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
        description="This workspace uses the same club-scoped backend contracts as the mobile admin tools, but tuned for touch-first web use on phone and tablet."
      />

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <AdminStateCard
          label="Total users"
          value={loading ? "..." : snapshot.metrics.totalUsers.toString()}
          helper="Profiles connected to Rayon Sports club scope."
          icon={Users}
        />
        <AdminStateCard
          label="Active circles"
          value={loading ? "..." : snapshot.metrics.activeGroups.toString()}
          helper="Open contribution groups visible to the club admin layer."
          icon={CircleDollarSign}
        />
        <AdminStateCard
          label="Transactions today"
          value={loading ? "..." : snapshot.metrics.transactionsToday.toString()}
          helper="Contribution movements recorded since midnight UTC."
          icon={ArrowRightLeft}
        />
        <AdminStateCard
          label="Tickets sold"
          value={loading ? "..." : snapshot.metrics.ticketsSold.toString()}
          helper="Club-scoped ticket records available to the admin workspace."
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
                  className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5 transition group"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full border border-border-soft bg-white/5 text-slate-400 transition group-hover:text-club-accent group-hover:border-club-accent/30">
                      <Icon size={18} />
                    </div>
                    <p className="font-display text-2xl font-bold uppercase leading-none">
                      {item.title}
                    </p>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-slate-300">
                    {item.body}
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
                No admin feed is available yet. As soon as content, match, and
                notification actions flow through Supabase, they appear here.
              </p>
            ) : null}
            {snapshot.activity.map((item) => (
              <article
                key={item.id}
                className="card-interactive rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
              >
                <p className="font-display text-2xl font-bold uppercase leading-none">
                  {item.title}
                </p>
                <p className="mt-2 text-sm leading-6 text-slate-300">
                  {item.detail}
                </p>
                <p className="mt-3 font-mono text-[11px] uppercase tracking-[0.24em] text-slate-400">
                  {new Date(item.createdAt).toLocaleString("en-RW", {
                    month: "short",
                    day: "numeric",
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </p>
              </article>
            ))}
          </div>
        </article>
      </section>
    </div>
  );
}
