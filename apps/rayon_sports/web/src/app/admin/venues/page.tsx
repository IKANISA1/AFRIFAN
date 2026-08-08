"use client";

import { useCallback, useMemo, useState } from "react";
import Link from "next/link";
import { ClipboardCheck, FileDown, MapPin, ShieldAlert } from "lucide-react";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  getAdminVenueOverview,
  normalizeAdminVenueOverview,
  type AdminVenueOverview,
} from "@/lib/data/admin/venues";
import { emptyVenueGovernanceSnapshot } from "@/lib/data/venue";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { ui } from "@/ui-kit";
import { VenueGovernancePanel } from "./venue-governance-panel";

const emptyOverview: AdminVenueOverview = {
  venueCount: 0,
  activeCampaigns: 0,
  openOrders: 0,
  checkinsToday: 0,
};

const overviewIsEmpty = (overview: AdminVenueOverview) =>
  overview.venueCount === 0 &&
  overview.activeCampaigns === 0 &&
  overview.openOrders === 0 &&
  overview.checkinsToday === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading venue oversight",
    detail: "Waiting for the first authenticated, club-scoped snapshot.",
  },
  ready: {
    label: "Venue oversight confirmed",
    detail: "The latest club-scoped venue metrics are ready for review.",
  },
  empty: {
    label: "No venue activity in this club",
    detail: "The venue oversight snapshot is confirmed and currently empty.",
  },
  error: {
    label: "Venue oversight unavailable",
    detail:
      "Confirmed metrics remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Venue oversight is offline",
    detail: "Confirmed metrics remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "Venue oversight access denied",
    detail:
      "Metrics, governance controls, and export data were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing venue oversight",
    detail: "Confirmed metrics remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Venue oversight changed",
    detail: "Review the retained snapshot, then refresh before continuing.",
  },
  security_timeout: {
    label: "Venue oversight request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained metrics.",
  },
};

export default function AdminVenuesPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const clearPrivateState = useCallback(() => {
    setInteraction("idle");
  }, []);
  const loadOverview = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyOverview;
      return getAdminVenueOverview(client, access, { signal });
    },
    [access, client],
  );
  const {
    data: overview,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
  } = useAdminResourceState<AdminVenueOverview>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyOverview,
    isEmpty: overviewIsEmpty,
    load: loadOverview,
    normalize: normalizeAdminVenueOverview,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "venue oversight",
  });
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");
  const governanceSnapshot = useMemo(
    () => ({
      ...emptyVenueGovernanceSnapshot,
      ...overview,
      exportCsv: [
        "metric,value",
        `venues,${overview.venueCount}`,
        `active_campaigns,${overview.activeCampaigns}`,
        `open_orders,${overview.openOrders}`,
        `checkins_today,${overview.checkinsToday}`,
      ].join("\n"),
    }),
    [overview],
  );

  return (
    <div
      className="section-grid !gap-6"
      data-admin-venues-status={status}
      data-admin-venues-interaction={interaction}
    >
      <AdminPageHeader
        eyebrow="Venue management"
        title="Venue oversight"
        meta={
          <>
            <AdminStatusBadge label="Feature flagged" tone="info" />
            <AdminStatusBadge
              label={
                hasConfirmed ? "Club scope confirmed" : "Scope unconfirmed"
              }
              tone={hasConfirmed ? "success" : "warning"}
            />
          </>
        }
        actions={
          <Link
            href="/venue"
            className={ui.buttonSecondary}
            style={{ minHeight: 48 }}
          >
            Open venue portal
          </Link>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh venue oversight"
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <section className="grid gap-4 md:grid-cols-4">
        {[
          ["Venues", overview.venueCount],
          ["Campaigns", overview.activeCampaigns],
          ["Open orders", overview.openOrders],
          ["Check-ins today", overview.checkinsToday],
        ].map(([label, value]) => (
          <AdminSurface key={label}>
            <p className="text-[11px] font-bold uppercase tracking-wider text-[var(--admin-text-muted)]">
              {label}
            </p>
            <p className="mt-3 text-3xl font-bold text-[var(--admin-text-strong)]">
              {hasConfirmed ? value : "—"}
            </p>
            <p className="mt-2 text-xs text-[var(--admin-text-muted)]">
              {hasConfirmed ? "Confirmed club scope" : "Awaiting confirmation"}
            </p>
          </AdminSurface>
        ))}
      </section>

      {initialLoading ? (
        <div
          className="grid gap-4 lg:grid-cols-2"
          aria-label="Loading venue oversight"
        >
          {Array.from({ length: 2 }).map((_, index) => (
            <div key={index} className="admin-surface p-6">
              <Skeleton className="skeleton-text h-7 w-2/5" />
              <Skeleton className="skeleton-text mt-5 h-48 w-full" />
            </div>
          ))}
        </div>
      ) : null}

      {!initialLoading && !unrecoveredFailure ? (
        <div className="grid gap-6" data-admin-venues-state-surface>
          <section className="grid gap-4 lg:grid-cols-3">
            {[
              {
                title: "Onboarding and approvals",
                icon: MapPin,
                body: "Confirm public profiles, venue status, radius policy, and assigned club scope before activation.",
              },
              {
                title: "FET review and export",
                icon: FileDown,
                body: "Export confirmed rewards, reservations, reversals, and campaign metrics without exposing private records.",
              },
              {
                title: "Compliance review",
                icon: ShieldAlert,
                body: "Review location, alcohol, duplicate check-in, and unusual order controls against approved procedures.",
              },
              {
                title: "Audit policy",
                icon: ClipboardCheck,
                body: "Venue order and campaign actions require attributable, club-scoped event records.",
              },
            ].map(({ title, icon: Icon, body }) => (
              <AdminSurface key={title}>
                <Icon className="h-5 w-5 text-club-accent" aria-hidden="true" />
                <h2 className="mt-4 text-sm font-bold uppercase tracking-wider text-[var(--admin-text-strong)]">
                  {title}
                </h2>
                <p className="mt-3 text-sm leading-6 text-[var(--admin-text-muted)]">
                  {body}
                </p>
              </AdminSurface>
            ))}
          </section>

          <VenueGovernancePanel
            snapshot={governanceSnapshot}
            onInteractionChange={setInteraction}
          />
        </div>
      ) : null}
    </div>
  );
}
