import type { Metadata } from "next";
import Link from "next/link";
import {
  ClipboardList,
  GlassWater,
  Monitor,
  QrCode,
  ShieldCheck,
  Users,
} from "lucide-react";
import {
  emptyVenuePortalSnapshot,
  getVenuePortalSnapshot,
} from "@/lib/data/venue";
import { ui } from "@/ui-kit";

export const metadata: Metadata = {
  title: "Venue portal",
  description:
    "Venue-scoped operator portal for check-ins, drinks orders, TV codes, and approved matchday promotions.",
  robots: {
    index: false,
    follow: false,
  },
};

const queueCards = [
  {
    title: "Orders queue",
    href: "/venue/orders",
    icon: ClipboardList,
    body: "Accept, prepare, ready, serve, or cancel drinks-only MVP orders.",
  },
  {
    title: "Top-10 drinks",
    href: "/venue/menu",
    icon: GlassWater,
    body: "Manage approved drinks only. The backend enforces 10 active items.",
  },
  {
    title: "Check-ins",
    href: "/venue/checkins",
    icon: QrCode,
    body: "Review QR/code check-ins, duplicate states, and campaign limits.",
  },
  {
    title: "TV code",
    href: "/venue/tv-code",
    icon: Monitor,
    body: "Show a screen-safe code without user, wallet, or order data.",
  },
  {
    title: "Promotions",
    href: "/venue/promotions",
    icon: ShieldCheck,
    body: "Launch only approved templates and keep FET rewards auditable.",
  },
  {
    title: "Staff",
    href: "/venue/staff",
    icon: Users,
    body: "View assigned venue roles. Admin owns role assignment.",
  },
];

export default async function VenuePortalPage() {
  const snapshot = await getVenuePortalSnapshot().catch(
    () => emptyVenuePortalSnapshot,
  );

  return (
    <main className="min-h-screen bg-[#050510] text-white">
      <section className="mx-auto grid min-h-screen max-w-7xl content-start gap-8 px-5 py-8 lg:px-8">
        <header className={`${ui.panelElevated} rounded-lg p-5`}>
          <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <p className={ui.kicker}>Venue operations</p>
              <h1 className="mt-3 font-display text-4xl font-bold uppercase leading-none md:text-6xl">
                Today at the venue
              </h1>
              <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300">
                Staff-only operator workspace for assigned venues. Supporter check-in stays in the mobile app; club oversight stays in admin.
              </p>
            </div>
            <Link href="/admin/venues" className={ui.buttonSecondary}>
              Admin oversight
            </Link>
          </div>
        </header>

        <section className="grid gap-4 md:grid-cols-4">
          {[
            ["Venues", snapshot.venueCount],
            ["Campaigns", snapshot.activeCampaigns],
            ["Open orders", snapshot.openOrders],
            ["Check-ins today", snapshot.checkinsToday],
          ].map(([label, value]) => (
            <div key={label} className={`${ui.panel} rounded-lg p-4`}>
              <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-slate-400">
                {label}
              </p>
              <p className="mt-3 font-display text-3xl font-bold">{value}</p>
            </div>
          ))}
        </section>

        <section className="grid gap-4 lg:grid-cols-3">
          {queueCards.map(({ title, href, icon: Icon, body }) => (
            <Link
              key={title}
              href={href}
              className={`${ui.cardInteractive} rounded-lg p-5`}
            >
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-white/10 text-club-accent">
                <Icon size={20} aria-hidden="true" />
              </span>
              <h2 className="mt-5 text-lg font-bold uppercase">{title}</h2>
              <p className="mt-3 text-sm leading-6 text-slate-300">{body}</p>
            </Link>
          ))}
        </section>

        <section className={`${ui.panel} rounded-lg p-5`}>
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <p className={ui.kicker}>Screen-safe TV code</p>
              <p className="mt-2 font-display text-5xl font-bold tracking-[0.18em]">
                {snapshot.safeTvCode.code}
              </p>
              <p className="mt-2 text-sm text-slate-300">
                {snapshot.safeTvCode.rewardLabel}
              </p>
            </div>
            <p className="rounded-full border border-white/10 px-4 py-2 text-xs font-bold uppercase tracking-[0.18em] text-slate-300">
              {snapshot.safeTvCode.expiresAt}
            </p>
          </div>
        </section>
      </section>
    </main>
  );
}
