import Link from "next/link";
import { ClipboardCheck, FileDown, MapPin, ShieldAlert } from "lucide-react";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import {
  emptyVenueGovernanceSnapshot,
  getVenueGovernanceSnapshot,
} from "@/lib/data/venue";
import { ui } from "@/ui-kit";
import { VenueGovernancePanel } from "./venue-governance-panel";

export default async function AdminVenuesPage() {
  const snapshot = await getVenueGovernanceSnapshot().catch(
    () => emptyVenueGovernanceSnapshot,
  );

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Venue management"
        title="Venue oversight"
        meta={
          <>
            <AdminStatusBadge label="Feature flagged" tone="info" />
            <AdminStatusBadge label="RLS scoped" tone="success" />
          </>
        }
        actions={
          <Link href="/venue" className={ui.buttonSecondary}>
            Open venue portal
          </Link>
        }
      />

      <section className="grid gap-4 md:grid-cols-4">
        {[
          ["Venues", snapshot.venueCount],
          ["Campaigns", snapshot.activeCampaigns],
          ["Open orders", snapshot.openOrders],
          ["Check-ins today", snapshot.checkinsToday],
        ].map(([label, value]) => (
          <AdminSurface key={label}>
            <p className="text-[11px] font-bold uppercase tracking-wider text-[var(--admin-text-muted)]">
              {label}
            </p>
            <p className="mt-3 text-3xl font-bold text-[var(--admin-text-strong)]">
              {value}
            </p>
          </AdminSurface>
        ))}
      </section>

      <section className="grid gap-4 lg:grid-cols-3">
        {[
          {
            title: "Onboarding and approvals",
            icon: MapPin,
            body: "Approve public profiles, venue status, radius policy, and assigned club scope.",
          },
          {
            title: "FET review and export",
            icon: FileDown,
            body: "Export closed-loop rewards, reservations, reversals, and campaign events without exposing private data.",
          },
          {
            title: "Compliance queue",
            icon: ShieldAlert,
            body: "Review location, alcohol, duplicate check-in, and unusual order activity.",
          },
          {
            title: "Audit events",
            icon: ClipboardCheck,
            body: "Every venue order status change and campaign action writes an event row.",
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

      <VenueGovernancePanel snapshot={snapshot} />
    </div>
  );
}
