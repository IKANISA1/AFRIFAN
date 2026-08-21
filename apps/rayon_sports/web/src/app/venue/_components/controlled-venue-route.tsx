"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ui } from "@/ui-kit";
import { useVenueOnline } from "./venue-shell-client";
import { VenueEmptyState, VenuePageHeader } from "./venue-shell";

export type ControlledVenueRoute =
  | "overview"
  | "ticket-verification"
  | "orders"
  | "menu"
  | "checkins"
  | "promotions"
  | "staff";

type EvidenceState =
  | "loading"
  | "empty"
  | "error"
  | "permission_denied"
  | "disabled"
  | "syncing"
  | "conflict"
  | "security_timeout"
  | "ready";

type RouteConfig = {
  eyebrow: string;
  title: string;
  description: string;
  emptyTitle: string;
  emptyBody: string;
  primaryAction: string;
  records: Array<{ label: string; value: string; detail: string }>;
};

const routes: Record<ControlledVenueRoute, RouteConfig> = {
  overview: {
    eyebrow: "Venue operations",
    title: "Today at the venue",
    description:
      "Counts and actions are limited to this active assignment. Club-wide controls remain with club administrators.",
    emptyTitle: "No activity today",
    emptyBody: "No campaigns, orders, or verified check-ins are active yet.",
    primaryAction: "Refresh venue summary",
    records: [
      { label: "Campaigns", value: "2", detail: "Approved today" },
      { label: "Open orders", value: "6", detail: "Oldest first" },
      { label: "Check-ins", value: "34", detail: "Identity-free total" },
    ],
  },
  "ticket-verification": {
    eyebrow: "2 active assignments",
    title: "Ticket verification",
    description:
      "Verify the current rotating ticket code against authoritative payment, event, venue, gate, and staff-assignment records before admission.",
    emptyTitle: "No active verifier assignment",
    emptyBody:
      "Admission verification remains unavailable until an administrator assigns this account to a live event, venue, gate, and shift.",
    primaryAction: "Refresh ticket verification",
    records: [
      {
        label: "Gate NORTH_1",
        value: "Ready",
        detail: "Assignment active · Online verification required",
      },
      {
        label: "Last confirmed check",
        value: "Admitted",
        detail: "Synthetic ticket · No supporter identity",
      },
      {
        label: "Admission rule",
        value: "Authoritative",
        detail: "HTTP success alone never confirms admission",
      },
    ],
  },
  orders: {
    eyebrow: "Live queue",
    title: "Drinks orders",
    description:
      "Oldest confirmed orders appear first. Every completed status change is recorded in the venue audit trail.",
    emptyTitle: "Queue clear",
    emptyBody: "No created, accepted, preparing, or ready orders exist.",
    primaryAction: "Refresh drinks orders",
    records: [
      { label: "Order 7A3F", value: "Preparing", detail: "4,500 RWF · Paid" },
      { label: "Order 9C21", value: "Accepted", detail: "2,000 RWF · Paid" },
      { label: "Order 4B88", value: "Ready", detail: "1,500 RWF · Paid" },
    ],
  },
  menu: {
    eyebrow: "8 of 10 active",
    title: "Drinks menu",
    description:
      "Owners and managers maintain up to ten active drinks for the assigned matchday venue.",
    emptyTitle: "No drinks configured",
    emptyBody: "An owner or manager can add the first approved drink.",
    primaryAction: "Refresh drinks menu",
    records: [
      {
        label: "Sparkling water",
        value: "1,000 RWF",
        detail: "Active · Alcohol-free",
      },
      {
        label: "Malt drink",
        value: "1,500 RWF",
        detail: "Active · Alcohol-free",
      },
      {
        label: "Lager",
        value: "2,500 RWF",
        detail: "Active · Age gate required",
      },
    ],
  },
  checkins: {
    eyebrow: "Recent activity",
    title: "Check-ins",
    description:
      "Review location verification and FET awards without exposing supporter identity.",
    emptyTitle: "No check-ins",
    emptyBody: "No supporters have checked in at this assigned venue yet.",
    primaryAction: "Refresh check-ins",
    records: [
      {
        label: "18:42",
        value: "Approved",
        detail: "Location verified · 25 FET",
      },
      { label: "18:38", value: "Review", detail: "Location pending · 0 FET" },
      {
        label: "18:31",
        value: "Approved",
        detail: "Location verified · 25 FET",
      },
    ],
  },
  promotions: {
    eyebrow: "Approved controls",
    title: "Promotions",
    description:
      "Monitor approved matchday campaigns. Creation, approval, and budget changes remain club-admin controls.",
    emptyTitle: "No campaigns",
    emptyBody: "Club admin must approve a campaign before venue launch.",
    primaryAction: "Refresh promotions",
    records: [
      { label: "Derby arrival", value: "Ready", detail: "7,500 FET remaining" },
      {
        label: "Second-half return",
        value: "Approved",
        detail: "4,000 FET remaining",
      },
      { label: "Member welcome", value: "Paused", detail: "Club-admin review" },
    ],
  },
  staff: {
    eyebrow: "Active assignments",
    title: "Venue staff",
    description:
      "This read-only roster shows role assignments. Club admin owns granting, changing, and revoking access.",
    emptyTitle: "No visible staff",
    emptyBody: "No active assignments are visible to this account.",
    primaryAction: "Refresh venue staff",
    records: [
      { label: "Assignment 1", value: "Manager", detail: "Current account" },
      { label: "Assignment 2", value: "Staff", detail: "Active assignment" },
      {
        label: "Assignment 3",
        value: "Reviewer",
        detail: "Read-only assignment",
      },
    ],
  },
};

const serverStates = new Set<EvidenceState>([
  "loading",
  "empty",
  "error",
  "permission_denied",
  "disabled",
  "syncing",
  "conflict",
  "security_timeout",
  "ready",
]);

function normalizeState(value: string): EvidenceState {
  return serverStates.has(value as EvidenceState)
    ? (value as EvidenceState)
    : "ready";
}

const stateCopy: Partial<
  Record<EvidenceState, { title: string; body: string }>
> = {
  error: {
    title: "Venue workflow unavailable",
    body: "Confirmed information was cleared because a safe snapshot could not be loaded. Retry when the service recovers.",
  },
  permission_denied: {
    title: "Venue access denied",
    body: "The current assignment is no longer authorized. Operational records and drafts were cleared.",
  },
  disabled: {
    title: "Changes unavailable",
    body: "Confirmed venue information remains visible, but this role cannot make changes.",
  },
  syncing: {
    title: "Refreshing venue operations",
    body: "The last confirmed snapshot remains visible while a bounded refresh completes.",
  },
  conflict: {
    title: "Venue data changed",
    body: "Another authorized operator changed this workflow. Review the refreshed record before continuing.",
  },
  security_timeout: {
    title: "Venue request timed out",
    body: "The outcome is not confirmed. Refresh the authoritative record before attempting another change.",
  },
};

export function ControlledVenueRoutePage({
  route,
  initialState,
}: {
  route: ControlledVenueRoute;
  initialState: string;
}) {
  const config = routes[route];
  const evidenceState = normalizeState(initialState);
  const online = useVenueOnline();
  const refreshRef = useRef<HTMLButtonElement>(null);
  const [interaction, setInteraction] = useState<
    "none" | "focused" | "pressed" | "selected"
  >("none");

  useEffect(() => {
    if (initialState === "focused") refreshRef.current?.focus();
  }, [initialState]);

  const effectiveState = !online
    ? "offline"
    : interaction === "none"
      ? evidenceState
      : interaction;
  const locked = !online || evidenceState !== "ready";
  const showRecords = ![
    "loading",
    "empty",
    "error",
    "permission_denied",
  ].includes(evidenceState);
  const message = useMemo(() => stateCopy[evidenceState], [evidenceState]);

  return (
    <main
      className="controlled-venue-state-surface mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8"
      data-venue-route={route}
      data-venue-state={effectiveState}
      data-venue-sensitive-data="withheld"
    >
      <VenuePageHeader
        eyebrow={config.eyebrow}
        title={config.title}
        description={config.description}
      />

      {evidenceState === "loading" ? (
        <section
          aria-busy="true"
          aria-live="polite"
          className="grid gap-4 md:grid-cols-3"
        >
          {Array.from({ length: 3 }, (_value, index) => (
            <div
              key={index}
              className={`${ui.panel} min-h-36 animate-pulse rounded-lg p-5`}
            />
          ))}
          <span className="sr-only">Loading venue operations</span>
        </section>
      ) : null}

      {evidenceState === "empty" ? (
        <VenueEmptyState title={config.emptyTitle} body={config.emptyBody} />
      ) : null}

      {message ? (
        <section
          className={`${ui.panel} rounded-lg border border-amber-300/30 p-5`}
          role={
            evidenceState === "error" ||
            evidenceState === "permission_denied" ||
            evidenceState === "conflict" ||
            evidenceState === "security_timeout"
              ? "alert"
              : "status"
          }
          aria-live="polite"
        >
          <p className={ui.kicker}>Operational status</p>
          <h2 className="mt-2 text-lg font-bold uppercase">{message.title}</h2>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-300">
            {message.body}
          </p>
        </section>
      ) : null}

      {showRecords ? (
        <section
          className="grid gap-4 md:grid-cols-3"
          aria-label={`${config.title} confirmed records`}
        >
          {config.records.map((record) => (
            <article
              key={record.label}
              className={`${ui.panel} rounded-lg p-5`}
            >
              <p className={ui.meta}>{record.label}</p>
              <h2 className="mt-3 text-xl font-bold uppercase">
                {record.value}
              </h2>
              <p className="mt-2 text-sm text-slate-300">{record.detail}</p>
            </article>
          ))}
        </section>
      ) : null}

      <section
        className={`${ui.panelElevated} flex flex-wrap items-center gap-3 rounded-lg p-5`}
      >
        <button
          ref={refreshRef}
          type="button"
          className={ui.buttonPrimary}
          disabled={locked}
          onFocus={() => setInteraction("focused")}
          onBlur={() => setInteraction("none")}
          onPointerDown={() => setInteraction("pressed")}
          onPointerUp={() => setInteraction("focused")}
          onPointerCancel={() => setInteraction("focused")}
          onMouseDown={() => setInteraction("pressed")}
          onMouseUp={() => setInteraction("focused")}
        >
          {config.primaryAction}
        </button>
        <button
          type="button"
          className={
            interaction === "selected" ? ui.buttonSecondary : ui.buttonTertiary
          }
          aria-pressed={interaction === "selected"}
          disabled={!showRecords}
          onClick={() => setInteraction("selected")}
        >
          Confirmed snapshot
        </button>
        <span className={ui.chip} aria-label="Safe evidence data source">
          Synthetic non-production
        </span>
      </section>
    </main>
  );
}
