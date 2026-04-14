"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  Award,
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
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { withAdminClubScope } from "@/lib/admin-club-scope";
import { getAdminDashboardSnapshot } from "@/lib/data/admin/dashboard";
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
    href: "/admin/gamification",
    title: "Manage FET catalog",
    icon: Award,
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
  const { client, access, activeClub } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const loadDashboard = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminDashboardSnapshot(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load admin dashboard.";
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

    loadDashboard().catch(() => {});
  }, [access.hasAccess, client, loadDashboard]);

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Control center"
        title="Operations dashboard"
        description="Signal first. Actions stay one click away."
        meta={
          <>
            <span className="admin-meta-chip">
              {access.canSelectClub ? "Multi-club workspace" : "Club workspace"}
            </span>
            <span className="admin-meta-chip">
              {snapshot.activity.length} recent events
            </span>
            <AdminStatusBadge
              label={access.hasAccess ? "Secure session" : "Read only"}
              tone={access.hasAccess ? "success" : "warning"}
            />
          </>
        }
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

      {loadError && !loading ? (
        <AdminErrorState
          title="Dashboard metrics could not be loaded"
          description={loadError}
          onRetry={() => {
            loadDashboard().catch(() => {});
          }}
        />
      ) : null}

      {!loadError ? (
      <section className="grid gap-5 lg:grid-cols-[1.15fr_0.85fr]">
        <AdminSurface
          title="Operational lanes"
          description="Most-used admin actions."
          contentClassName="p-5 sm:p-6"
        >
          <div className="grid gap-3 sm:grid-cols-2">
            {quickActions.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={withAdminClubScope(item.href, activeClub?.id ?? access.clubId)}
                  className="admin-quick-link group"
                >
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl border border-border-soft bg-white/5 text-slate-400 transition group-hover:text-white group-hover:border-border-hover">
                    <Icon size={18} />
                  </div>
                  <div className="space-y-1">
                    <p className="text-sm font-semibold text-white">{item.title}</p>
                    <p className="text-xs text-slate-400">Open module</p>
                  </div>
                </Link>
              );
            })}
          </div>
        </AdminSurface>

        <AdminSurface
          title="Recent activity"
          description="Latest admin and content events."
          contentClassName="p-5 sm:p-6"
        >
          <div className="space-y-3">
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-4">
                    <Skeleton className="skeleton-text h-5 w-3/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                    <Skeleton className="skeleton-text mt-3 h-2 w-20" />
                  </div>
                ))}
              </div>
            ) : snapshot.activity.length === 0 ? (
              <div className="admin-empty-state !min-h-[12rem]">
                <p className="admin-empty-title">No activity yet</p>
                <p className="admin-empty-copy">Recent admin events will appear here.</p>
              </div>
            ) : null}
            {snapshot.activity.map((item) => (
              <article
                key={item.id}
                className="admin-timeline-item"
              >
                <div className="flex justify-between items-start gap-4">
                  <div>
                    <p className="text-sm font-semibold text-white">{item.title}</p>
                    <p className="mt-1 text-sm text-slate-300">{item.detail}</p>
                  </div>
                  <p className="shrink-0 text-[11px] font-medium text-slate-500">
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
        </AdminSurface>
      </section>
      ) : null}
    </div>
  );
}
