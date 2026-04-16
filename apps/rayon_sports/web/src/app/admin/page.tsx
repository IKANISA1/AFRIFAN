"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  Award,
  Users,
  GroupDollarSign,
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
  { href: "/admin/community", title: "Support Circles", icon: HeartHandshake },
  { href: "/admin/shop", title: "Shop Operations", icon: ShoppingBag },
  { href: "/admin/settings", title: "Platform Config", icon: Settings },
  { href: "/admin/access", title: "Role Management", icon: Users },
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
          <AdminSurface title="Operational lanes">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="ui-panel-inset rounded-2xl p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-xs font-bold uppercase tracking-wider text-[var(--admin-text-strong)]">Website Status</h3>
                  <AdminStatusBadge label="Live" tone="success" />
                </div>
                <p className="text-[10px] text-[var(--admin-zinc-500)]">Last cache invalidation: 12 mins ago</p>
                <Link href={withAdminClubScope("/admin/cms", activeClub?.id ?? access.clubId)} className="text-[11px] font-bold text-club-accent hover:underline">Manage stories →</Link>
              </div>

              <div className="ui-panel-inset rounded-2xl p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-xs font-bold uppercase tracking-wider text-[var(--admin-text-strong)]">App Services</h3>
                  <AdminStatusBadge label="Operational" tone="success" />
                </div>
                <p className="text-[10px] text-[var(--admin-zinc-500)]">Push server: Connected</p>
                <Link href={withAdminClubScope("/admin/notifications", activeClub?.id ?? access.clubId)} className="text-[11px] font-bold text-club-accent hover:underline">Send notification →</Link>
              </div>
            </div>
          </AdminSurface>

          <AdminSurface title="Quick actions">
            <div className="grid gap-2 sm:grid-cols-2">
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

        <div className="space-y-6">
          <AdminSurface title="Recent activity">
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
                  <div key={item.id} className="p-4 hover:bg-[var(--admin-zinc-800)] transition-colors">
                    <div className="flex justify-between items-start gap-3">
                      <div className="min-w-0">
                        <p className="text-sm font-semibold text-[var(--admin-text-strong)] truncate">
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

          <AdminSurface title="Support">
            <div className="ui-panel-inset rounded-2xl p-4 text-center">
              <p className="text-xs text-[var(--admin-zinc-400)] mb-3">Need assistance with operations?</p>
              <a href="https://wa.me/250788767816" target="_blank" className="ui-button-primary w-full py-2 text-xs">WhatsApp Admin</a>
            </div>
          </AdminSurface>
        </div>
      </section>
    </div>
  );
}
