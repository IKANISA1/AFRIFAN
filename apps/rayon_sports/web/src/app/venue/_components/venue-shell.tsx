import Link from "next/link";
import type { ReactNode } from "react";
import type { VenueAccessResult } from "@/lib/data/venue-access";
import { ui } from "@/ui-kit";
import { VenueShellClient } from "./venue-shell-client";

export function VenueAccessBoundary({
  result,
  children,
}: {
  result: VenueAccessResult;
  children: ReactNode;
}) {
  if (result.status === "ready") {
    return <VenueShellClient access={result.access}>{children}</VenueShellClient>;
  }

  const state = {
    not_configured: {
      title: "Venue operations unavailable",
      body: "The secure venue service is not ready. Operations remain closed until a club administrator restores access.",
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
    <main className="venue-access-state grid min-h-screen place-items-center px-5">
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

export function VenuePageHeader({ eyebrow, title, description }: { eyebrow: string; title: string; description: string }) {
  return (
    <header className={`${ui.panelElevated} rounded-lg p-5`}>
      <p className={ui.kicker}>{eyebrow}</p>
      <h1 className="mt-3 font-display text-4xl font-bold uppercase leading-none md:text-6xl">{title}</h1>
      <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300">{description}</p>
    </header>
  );
}

export function formatVenueLabel(value: string) {
  return value
    .split(/[_-]+/)
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
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
      <p className="mt-2 text-sm text-slate-300">The venue service could not load this workflow. No change was made. Retry and share reference {correlationId} with support if the problem continues.</p>
      <Link className={`${ui.buttonSecondary} mt-5`} href="?retry=1">
        Retry current workflow
      </Link>
    </section>
  );
}
