"use client";

import Link from "next/link";
import { type ComponentProps, useCallback, useEffect, useState } from "react";
import {
  DollarSign,
  Newspaper,
  CalendarDays,
  Bell,
  ShoppingBag,
  Crown,
  Settings,
  Users,
} from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { KPISummaryRibbon, KPITile } from "@/components/admin/kpi-summary-ribbon";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { withAdminClubScope } from "@/lib/admin-club-scope";
import { getAdminDashboardSnapshot } from "@/lib/data/admin/dashboard";
import type { AdminDashboardSnapshot } from "@/lib/types";

const emptySnapshot: AdminDashboardSnapshot = {
  metrics: {
    activeUsers: 0,
    pendingVerifications: 0,
    activeSupportCircles: 0,
    recentTicketSales: 0,
    totalFans: 0,
    ticketRevenue: 0,
  },
  activity: [],
};

const quickActions = [
  { href: "/admin/cms", title: "Manage Website", icon: Newspaper },
  { href: "/admin/notifications", title: "App Push & Alerts", icon: Bell },
  { href: "/admin/matches", title: "Matchday Centre", icon: CalendarDays },
  { href: "/admin/membership", title: "Memberships", icon: Crown },
  { href: "/admin/shop", title: "Shop Operations", icon: ShoppingBag },
  { href: "/admin/access", title: "Role Management", icon: Users },
  { href: "/admin/settings", title: "Platform Config", icon: Settings },
];

type AdminStatusTone = NonNullable<ComponentProps<typeof AdminStatusBadge>["tone"]>;

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
      const message = caught instanceof Error ? caught.message : "Could not load admin dashboard.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }

    loadDashboard().catch(() => { });
  }, [access.hasAccess, client, loadDashboard]);

  const operationalQueue: {
    key: string;
    title: string;
    href: string;
    value: string;
    detail: string;
    tone: AdminStatusTone;
    badge: string;
  }[] = [
    {
      key: "verifications",
      title: "Pending verifications",
      href: "/admin/membership",
      value: loading ? "..." : snapshot.metrics.pendingVerifications.toLocaleString(),
      detail:
        snapshot.metrics.pendingVerifications > 0
          ? "Review supporter approvals before they queue up."
          : "No approvals are waiting.",
      tone: snapshot.metrics.pendingVerifications > 0
        ? ("warning" as const)
        : ("success" as const),
      badge: snapshot.metrics.pendingVerifications > 0 ? "Needs review" : "Clear",
    },
    {
      key: "tickets",
      title: "Recent ticket sales",
      href: "/admin/tickets",
      value: loading ? "..." : snapshot.metrics.recentTicketSales.toLocaleString(),
      detail: "Latest activity from live matchday commerce.",
      tone: "info" as const,
      badge: "Live",
    },
    {
      key: "circles",
      title: "Support circles",
      href: "/admin/community",
      value: loading ? "..." : snapshot.metrics.activeSupportCircles.toLocaleString(),
      detail:
        snapshot.metrics.activeSupportCircles > 0
          ? "Community chapters with active operations."
          : "No circles are active yet.",
      tone: snapshot.metrics.activeSupportCircles > 0
        ? ("success" as const)
        : ("neutral" as const),
      badge: snapshot.metrics.activeSupportCircles > 0 ? "Active" : "Idle",
    },
    {
      key: "activity",
      title: "Recent events",
      href: "/admin/settings/audit",
      value: loading ? "..." : snapshot.activity.length.toLocaleString(),
      detail:
        snapshot.activity.length > 0
          ? "Audit what changed across content and operations."
          : "No recent admin actions recorded.",
      tone: snapshot.activity.length > 0
        ? ("accent" as const)
        : ("neutral" as const),
      badge: snapshot.activity.length > 0 ? "Tracked" : "Quiet",
    },
  ];

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Control center"
        title="Operations dashboard"
        meta={
          <>
            <AdminStatusBadge
              label={access.hasAccess ? "Operational" : "Read only"}
              tone={access.hasAccess ? "success" : "warning"}
            />
            <span className="admin-meta-chip">
              {snapshot.activity.length} Recent events
            </span>
          </>
        }
      />

      <KPISummaryRibbon>
        <KPITile
          label="Active Users"
          value={loading ? "..." : snapshot.metrics.activeUsers.toLocaleString()}
        />
        <KPITile
          label="Pending Verifications"
          value={loading ? "..." : snapshot.metrics.pendingVerifications.toLocaleString()}
          tone={snapshot.metrics.pendingVerifications > 0 ? "warning" : "neutral"}
        />
        <KPITile
          label="Support Circles"
          value={loading ? "..." : snapshot.metrics.activeSupportCircles.toLocaleString()}
          icon={DollarSign}
        />
        <KPITile
          label="Ticket Sales"
          value={loading ? "..." : snapshot.metrics.recentTicketSales.toLocaleString()}
        />
      </KPISummaryRibbon>

      {loadError && !loading ? (
        <AdminErrorState
          title="Metrics could not be loaded"
          description={loadError}
          onRetry={() => { loadDashboard().catch(() => { }); }}
        />
      ) : null}

      <section className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-6">
          <AdminSurface title="Priority queue">
            <div className="grid gap-4 sm:grid-cols-2">
              {operationalQueue.map((item) => (
                <div key={item.key} className="ui-panel-inset rounded-2xl p-4 space-y-3">
                  <div className="flex items-center justify-between gap-3">
                    <h3 className="text-xs font-bold uppercase tracking-wider text-[var(--admin-text-strong)]">
                      {item.title}
                    </h3>
                    <AdminStatusBadge label={item.badge} tone={item.tone} />
                  </div>
                  <div className="space-y-1">
                    <p className="text-2xl font-bold tracking-tight text-[var(--admin-text-strong)]">
                      {item.value}
                    </p>
                    <p className="text-xs leading-5 text-[var(--admin-zinc-400)]">
                      {item.detail}
                    </p>
                  </div>
                  <Link
                    href={withAdminClubScope(item.href, activeClub?.id ?? access.clubId)}
                    className="text-[11px] font-bold text-club-accent hover:underline"
                  >
                    Open queue →
                  </Link>
                </div>
              ))}
            </div>
          </AdminSurface>

          <AdminSurface title="Quick actions">
            <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
              {quickActions.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.href}
                    href={withAdminClubScope(item.href, activeClub?.id ?? access.clubId)}
                    className="admin-nav-link !rounded-lg border border-[var(--admin-border)] !py-3 px-4 hover:bg-[var(--admin-zinc-800)]"
                  >
                    <Icon size={16} className="text-[var(--admin-zinc-500)]" />
                    <span className="text-sm font-medium">{item.title}</span>
                  </Link>
                );
              })}
            </div>
          </AdminSurface>
        </div>

        <AdminSurface title="Recent activity" className="lg:sticky lg:top-24 lg:h-fit">
          <div className="divide-y divide-[var(--admin-border)]">
            {loading ? (
              <div className="p-4 space-y-4">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="space-y-2">
                    <Skeleton className="skeleton-text h-4 w-1/2" />
                    <Skeleton className="skeleton-text h-3 w-full" />
                  </div>
                ))}
              </div>
            ) : snapshot.activity.length === 0 ? (
              <div className="p-8 text-center text-sm text-[var(--admin-zinc-500)]">
                No recent activity detected.
              </div>
            ) : (
              snapshot.activity.map((item) => (
                <div key={item.id} className="p-4 transition-colors hover:bg-[var(--admin-zinc-800)]">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-[var(--admin-text-strong)]">
                        {item.title}
                      </p>
                      <p className="mt-0.5 text-xs text-[var(--admin-zinc-400)]">
                        {item.detail}
                      </p>
                    </div>
                    <time className="shrink-0 text-[10px] font-medium text-[var(--admin-zinc-500)]">
                      {new Date(item.createdAt).toLocaleString("en-RW", {
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </time>
                  </div>
                </div>
              ))
            )}
          </div>
        </AdminSurface>
      </section>
    </div>
  );
}
