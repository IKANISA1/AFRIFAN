import Link from "next/link";
import type { ReactNode } from "react";
import type { VenueAccess, VenueAccessResult } from "@/lib/data/venue-access";
import { ui } from "@/ui-kit";

const navigation = [
  ["Today", "/venue"],
  ["Orders", "/venue/orders"],
  ["Menu", "/venue/menu"],
  ["Check-ins", "/venue/checkins"],
  ["Promotions", "/venue/promotions"],
  ["TV code", "/venue/tv-code"],
  ["Staff", "/venue/staff"],
] as const;

export function VenueAccessBoundary({
  result,
  children,
}: {
  result: VenueAccessResult;
  children: ReactNode;
}) {
  if (result.status === "ready") {
    return <VenueShell access={result.access}>{children}</VenueShell>;
  }

  const state = {
    not_configured: {
      title: "Venue service is not configured",
      body: "Production Supabase settings are missing. Venue operations remain closed until an administrator restores the service.",
      action: "Open admin status",
    },
    signed_out: {
      title: "Secure sign-in required",
      body: "Sign in with the staff account assigned to this venue. Access is checked again for every operation.",
      action: "Secure sign in",
    },
    forbidden: {
      title: "No active venue assignment",
      body: "This account has no active venue staff membership. Ask a club administrator to assign or restore access.",
      action: "Contact club admin",
    },
    service_error: {
      title: "Venue service unavailable",
      body: `The authorization check could not complete. Retry shortly and give support correlation ID ${result.status === "service_error" ? result.correlationId : "unavailable"}.`,
      action: "Retry",
    },
  }[result.status];

  return (
    <main className="grid min-h-screen place-items-center bg-[#050510] px-5 text-white">
      <section className={`${ui.panelElevated} max-w-xl rounded-lg p-7`} role="alert">
        <p className={ui.kicker}>Venue access</p>
        <h1 className="mt-3 font-display text-4xl font-bold uppercase">{state.title}</h1>
        <p className="mt-4 leading-7 text-slate-300">{state.body}</p>
        <Link className={`${ui.buttonPrimary} mt-6 inline-flex`} href={result.status === "service_error" ? "/venue" : "/admin"}>
          {state.action}
        </Link>
      </section>
    </main>
  );
}

function VenueShell({ access, children }: { access: VenueAccess; children: ReactNode }) {
  return (
    <div className="min-h-screen bg-[#050510] text-white">
      <header className="border-b border-white/10 bg-[#080817] px-5 py-4">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className={ui.kicker}>Assigned venue</p>
            <p className="mt-1 text-lg font-bold">{access.venueName}</p>
            <p className="text-xs uppercase tracking-[0.14em] text-slate-400">
              {access.venueCity || "Venue operations"} · {access.role}
            </p>
          </div>
          <nav aria-label="Venue operations" className="flex max-w-full gap-2 overflow-x-auto pb-1">
            {navigation.map(([label, href]) => (
              <Link key={href} href={href} className={`${ui.buttonTertiary} shrink-0 whitespace-nowrap`}>{label}</Link>
            ))}
          </nav>
        </div>
      </header>
      {children}
    </div>
  );
}

export function VenuePageHeader({ eyebrow, title, description }: { eyebrow: string; title: string; description: string }) {
  return (
    <header className={`${ui.panelElevated} rounded-lg p-5`}>
      <p className={ui.kicker}>{eyebrow}</p>
      <h1 className="mt-3 font-display text-4xl font-bold uppercase leading-none md:text-6xl">{title}</h1>
      <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300">{description}</p>
    </header>
  );
}

export function VenueEmptyState({ title, body }: { title: string; body: string }) {
  return (
    <section className={`${ui.panel} rounded-lg p-6`}>
      <h2 className="text-lg font-bold uppercase">{title}</h2>
      <p className="mt-2 text-sm leading-6 text-slate-300">{body}</p>
    </section>
  );
}

export function VenueDataError({ correlationId }: { correlationId: string }) {
  return (
    <section className={`${ui.panel} rounded-lg border border-red-400/40 p-6`} role="alert">
      <h2 className="text-lg font-bold uppercase">Data unavailable</h2>
      <p className="mt-2 text-sm text-slate-300">The venue service could not load this workflow. Retry and share correlation ID {correlationId} with support.</p>
    </section>
  );
}
