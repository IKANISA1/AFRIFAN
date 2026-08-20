"use client";

import { useCallback, useMemo, useState } from "react";
import { CalendarClock, Search, ShieldCheck, UserCheck } from "lucide-react";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  findAdminTicketVerifierCandidate,
  getAdminTicketVerifierWorkspace,
  grantAdminTicketVerifierAssignment,
  normalizeAdminTicketVerifierWorkspace,
  revokeAdminTicketVerifierAssignment,
  type AdminTicketVerifierAssignment,
  type AdminTicketVerifierCandidate,
  type AdminTicketVerifierWorkspace,
} from "@/lib/data/admin";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

const emptyWorkspace: AdminTicketVerifierWorkspace = {
  organizations: [],
  events: [],
  assignments: [],
};

function verifierWorkspaceIsEmpty(value: AdminTicketVerifierWorkspace) {
  return value.events.length === 0;
}

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading verifier authority",
    detail: "Waiting for the first authenticated, club-scoped snapshot.",
  },
  ready: {
    label: "Verifier authority confirmed",
    detail: "Organization, event, venue, gate, and shift scopes are current.",
  },
  empty: {
    label: "No ticket events configured",
    detail: "Create a governed ticket event before assigning matchday verifiers.",
  },
  error: {
    label: "Verifier workspace unavailable",
    detail: "Confirmed assignments remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Verifier workspace is offline",
    detail: "Confirmed assignments remain visible until connectivity returns.",
  },
  permission_denied: {
    label: "Verifier management denied",
    detail: "Previously loaded verifier identities and assignments were cleared.",
  },
  syncing: {
    label: "Refreshing verifier authority",
    detail: "Confirmed assignments remain visible during refresh.",
  },
  conflict: {
    label: "Verifier assignment changed",
    detail: "Refresh the latest assignment before acting again.",
  },
  security_timeout: {
    label: "Verifier request timed out",
    detail: "No assignment change was assumed or confirmed.",
  },
};

function toDateTimeLocal(value: string) {
  const date = new Date(value);
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 16);
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("en-RW", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default function AdminTicketVerifiersPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const [publicUserId, setPublicUserId] = useState("");
  const [candidate, setCandidate] =
    useState<AdminTicketVerifierCandidate | null>(null);
  const [ticketEventId, setTicketEventId] = useState("");
  const [gateCode, setGateCode] = useState("");
  const [startsAt, setStartsAt] = useState("");
  const [endsAt, setEndsAt] = useState("");
  const [showInactive, setShowInactive] = useState(false);
  const [busyAction, setBusyAction] =
    useState<"lookup" | "grant" | "revoke" | null>(null);

  const canManage = access.hasAccess && access.clubId != null && (
    access.isSuperAdmin ||
    access.role === "super_admin" ||
    access.role === "admin" ||
    access.role === "club_admin"
  );

  const clearPrivateState = useCallback(() => {
    setCandidate(null);
    setPublicUserId("");
    setTicketEventId("");
    setGateCode("");
    setStartsAt("");
    setEndsAt("");
  }, []);

  const loadWorkspace = useCallback(
    async (signal: AbortSignal) => {
      if (!client) return emptyWorkspace;
      return getAdminTicketVerifierWorkspace(client, access, { signal });
    },
    [access, client],
  );

  const {
    data: workspace,
    status,
    busy,
    hasConfirmed,
    refresh,
  } = useAdminResourceState<AdminTicketVerifierWorkspace>({
    enabled: hydrated && client != null && canManage,
    emptyValue: emptyWorkspace,
    isEmpty: verifierWorkspaceIsEmpty,
    load: loadWorkspace,
    normalize: normalizeAdminTicketVerifierWorkspace,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "ticket verifier authority",
  });

  const selectableEvents = useMemo(
    () => workspace.events.filter((event) =>
      event.status !== "completed" && event.status !== "cancelled"
    ),
    [workspace.events],
  );
  const selectedEvent = selectableEvents.find((event) =>
    event.id === ticketEventId
  ) ?? selectableEvents[0] ?? null;
  const selectedTicketEventId = selectedEvent?.id ?? "";
  const hasSelectedEventDraft = selectedEvent?.id === ticketEventId;
  const selectedStartsAt = hasSelectedEventDraft && startsAt
    ? startsAt
    : selectedEvent
    ? toDateTimeLocal(selectedEvent.entryOpensAt)
    : "";
  const selectedEndsAt = hasSelectedEventDraft && endsAt
    ? endsAt
    : selectedEvent
    ? toDateTimeLocal(selectedEvent.entryClosesAt)
    : "";
  const visibleAssignments = useMemo(
    () => workspace.assignments.filter((assignment) =>
      showInactive || assignment.isActive
    ),
    [showInactive, workspace.assignments],
  );

  async function lookupCandidate() {
    if (!client || busyAction) return;
    setBusyAction("lookup");
    setCandidate(null);
    try {
      const resolved = await findAdminTicketVerifierCandidate(
        client,
        access,
        publicUserId,
      );
      setCandidate(resolved);
      showAdminToast("Verifier identity confirmed.", "success");
    } catch (error) {
      showAdminToast(
        error instanceof Error ? error.message : "Verifier lookup failed.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function grantAssignment() {
    if (!client || !candidate || !selectedEvent || busyAction) return;
    setBusyAction("grant");
    try {
      await grantAdminTicketVerifierAssignment(client, access, {
        ticketEventId: selectedEvent.id,
        userId: candidate.userId,
        gateCode,
        startsAt: new Date(selectedStartsAt).toISOString(),
        endsAt: new Date(selectedEndsAt).toISOString(),
      });
      showAdminToast("Verifier assignment granted and audited.", "success");
      clearPrivateState();
      await refresh();
    } catch (error) {
      showAdminToast(
        error instanceof Error ? error.message : "Verifier assignment failed.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function revokeAssignment(assignment: AdminTicketVerifierAssignment) {
    if (!client || busyAction) return;
    const confirmed = confirmAdminDestructiveAction({
      action: "Revoke",
      subject: `${assignment.userName}'s verifier authority`,
      scope: `${assignment.organizationName}, ${assignment.matchLabel}, ${assignment.gateCode ?? "all gates"}`,
      impact: "The user can no longer verify tickets under this assignment.",
      undo: "manual_recovery",
      confirmationLabel: "Regranting requires a new audited assignment.",
    });
    if (!confirmed) return;

    setBusyAction("revoke");
    try {
      await revokeAdminTicketVerifierAssignment(client, access, assignment);
      showAdminToast("Verifier assignment revoked and audited.", "success");
      await refresh();
    } catch (error) {
      if (isAdminMutationConflict(error)) await refresh();
      showAdminToast(
        error instanceof Error ? error.message : "Verifier revocation failed.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  if (hydrated && !canManage) {
    return (
      <div className="section-grid">
        <AdminPageHeader eyebrow="Ticket operations" title="Verifier authority" />
        <AdminErrorState
          title="Club-admin authority required"
          description="Ticket verification access can only be granted or revoked by a platform or club administrator in the active club scope."
        />
      </div>
    );
  }

  return (
    <div
      className="admin-ticket-verifiers-state-surface section-grid min-w-0 w-full max-w-full overflow-x-hidden !gap-6"
      data-admin-ticket-verifiers-status={status}
      data-admin-ticket-verifiers-interaction={interaction}
    >
      <AdminPageHeader
        eyebrow="Ticket operations"
        title="Verifier authority"
        meta={
          <AdminStatusBadge
            label="Organization-scoped access"
            tone="info"
          />
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy || busyAction != null}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh verifier authority"
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="Active verifiers"
          value={hasConfirmed
            ? workspace.assignments.filter((assignment) => assignment.isActive)
              .length.toString()
            : "—"}
          icon={UserCheck}
          tone="success"
        />
        <AdminStateCard
          label="Ticket events"
          value={hasConfirmed ? workspace.events.length.toString() : "—"}
          icon={CalendarClock}
        />
        <AdminStateCard
          label="Organizations"
          value={hasConfirmed ? workspace.organizations.length.toString() : "—"}
          icon={ShieldCheck}
          tone="info"
        />
      </div>

      <div className="grid items-start gap-6 2xl:grid-cols-[minmax(0,0.9fr)_minmax(0,1.5fr)]">
        <AdminSurface title="Grant verifier access">
          <div className="grid gap-5">
            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
              Public user id
              <span className="flex gap-2">
                <input
                  value={publicUserId}
                  onChange={(event) => {
                    setPublicUserId(event.target.value.replace(/\D/g, "").slice(0, 6));
                    setCandidate(null);
                  }}
                  inputMode="numeric"
                  autoComplete="off"
                  placeholder="6-digit supporter id"
                  className="admin-input min-w-0 flex-1"
                  aria-label="Verifier public user id"
                />
                <button
                  type="button"
                  onClick={() => void lookupCandidate()}
                  disabled={busyAction != null || publicUserId.length !== 6}
                  className="admin-button admin-button-secondary min-h-12 disabled:opacity-50"
                >
                  <Search size={16} aria-hidden="true" />
                  Find
                </button>
              </span>
            </label>

            {candidate ? (
              <div className="rounded-2xl border border-emerald-500/25 bg-emerald-500/10 p-4">
                <p className="font-bold text-[var(--admin-text-strong)]">
                  {candidate.displayName}
                </p>
                <p className="mt-1 font-mono text-xs text-emerald-300">
                  Public ID {candidate.publicUserId}
                </p>
              </div>
            ) : (
              <p className="rounded-2xl border border-dashed border-[var(--admin-border)] p-4 text-sm leading-6 text-[var(--admin-zinc-400)]">
                Find an active supporter profile in this club. Phone numbers,
                email addresses, and internal identifiers are not displayed.
              </p>
            )}

            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
              Ticket event
              <select
                value={selectedTicketEventId}
                onChange={(event) => {
                  const nextEvent = selectableEvents.find((item) =>
                    item.id === event.target.value
                  );
                  setTicketEventId(event.target.value);
                  setStartsAt(nextEvent
                    ? toDateTimeLocal(nextEvent.entryOpensAt)
                    : "");
                  setEndsAt(nextEvent
                    ? toDateTimeLocal(nextEvent.entryClosesAt)
                    : "");
                }}
                className="admin-input min-h-12"
              >
                {selectableEvents.length === 0 ? (
                  <option value="">No assignable ticket events</option>
                ) : null}
                {selectableEvents.map((event) => (
                  <option key={event.id} value={event.id}>
                    {event.matchLabel} · {event.organizationName}
                  </option>
                ))}
              </select>
            </label>

            {selectedEvent ? (
              <div className="grid gap-1 rounded-2xl border border-[var(--admin-border)] bg-[var(--admin-zinc-900)] p-4 text-sm text-[var(--admin-zinc-300)]">
                <span>{selectedEvent.venueName}</span>
                <span>
                  Entry {formatDateTime(selectedEvent.entryOpensAt)} – {formatDateTime(selectedEvent.entryClosesAt)}
                </span>
                {!selectedEvent.verificationEnabled ? (
                  <span className="text-amber-300">
                    Verification is currently disabled for this event.
                  </span>
                ) : null}
              </div>
            ) : null}

            <div className="grid gap-4 sm:grid-cols-2">
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Shift starts
                <input
                  type="datetime-local"
                  value={selectedStartsAt}
                  min={selectedEvent ? toDateTimeLocal(selectedEvent.entryOpensAt) : undefined}
                  max={selectedEvent ? toDateTimeLocal(selectedEvent.entryClosesAt) : undefined}
                  onChange={(event) => setStartsAt(event.target.value)}
                  className="admin-input min-h-12"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Shift ends
                <input
                  type="datetime-local"
                  value={selectedEndsAt}
                  min={selectedEvent ? toDateTimeLocal(selectedEvent.entryOpensAt) : undefined}
                  max={selectedEvent ? toDateTimeLocal(selectedEvent.entryClosesAt) : undefined}
                  onChange={(event) => setEndsAt(event.target.value)}
                  className="admin-input min-h-12"
                />
              </label>
            </div>

            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
              Gate code (optional)
              <input
                value={gateCode}
                onChange={(event) =>
                  setGateCode(
                    event.target.value.toUpperCase().replace(/[^A-Z0-9_-]/g, "")
                      .slice(0, 32),
                  )}
                placeholder="All gates"
                className="admin-input min-h-12"
              />
            </label>

            <button
              type="button"
              onClick={() => void grantAssignment()}
              disabled={
                busyAction != null ||
                !candidate ||
                !selectedEvent ||
                !selectedStartsAt ||
                !selectedEndsAt
              }
              className="admin-button admin-button-primary min-h-12 justify-center disabled:opacity-50"
            >
              <ShieldCheck size={17} aria-hidden="true" />
              {busyAction === "grant" ? "Granting authority…" : "Grant verifier authority"}
            </button>
          </div>
        </AdminSurface>

        <AdminSurface
          title="Verifier assignments"
          actions={
            <label className="flex items-center gap-2 text-sm text-[var(--admin-zinc-300)]">
              <input
                type="checkbox"
                checked={showInactive}
                onChange={(event) => setShowInactive(event.target.checked)}
              />
              Show revoked
            </label>
          }
          flush
        >
          <AdminDataGrid
            className="admin-ticket-verifiers-assignments"
            caption="Organization-scoped ticket verifier assignments"
            busy={busy || busyAction === "revoke"}
            columns={[
              { key: "verifier", label: "Verifier", priority: "primary" },
              { key: "scope", label: "Event scope", priority: "primary" },
              { key: "shift", label: "Shift", priority: "secondary" },
              { key: "status", label: "Status", priority: "secondary" },
              { key: "action", label: "Action", priority: "primary" },
            ]}
          >
            {visibleAssignments.length === 0 ? (
              <tr>
                <td colSpan={5} className="p-8 text-center text-sm text-[var(--admin-zinc-400)]">
                  No verifier assignments match this view.
                </td>
              </tr>
            ) : visibleAssignments.map((assignment) => (
              <tr key={assignment.id} data-row-id={assignment.id}>
                <td>
                  <p className="font-bold text-[var(--admin-text-strong)]">
                    {assignment.userName}
                  </p>
                  <p className="mt-1 font-mono text-xs text-[var(--admin-zinc-400)]">
                    Public ID {assignment.publicUserId}
                  </p>
                </td>
                <td>
                  <p className="font-semibold text-[var(--admin-text-strong)]">
                    {assignment.matchLabel}
                  </p>
                  <p className="mt-1 text-xs text-[var(--admin-zinc-400)]">
                    {assignment.organizationName} · {assignment.venueName} · {assignment.gateCode ?? "All gates"}
                  </p>
                </td>
                <td className="text-sm text-[var(--admin-zinc-300)]">
                  {formatDateTime(assignment.startsAt)}
                  <br />
                  to {formatDateTime(assignment.endsAt)}
                </td>
                <td>
                  <AdminStatusBadge
                    label={assignment.isActive ? "Active" : "Revoked"}
                    tone={assignment.isActive ? "success" : "neutral"}
                  />
                </td>
                <td>
                  {assignment.isActive ? (
                    <button
                      type="button"
                      onClick={() => void revokeAssignment(assignment)}
                      disabled={busyAction != null}
                      className="admin-button admin-button-secondary min-h-10 disabled:opacity-50"
                    >
                      Revoke
                    </button>
                  ) : (
                    <span className="text-xs text-[var(--admin-zinc-500)]">
                      {assignment.revokedAt
                        ? formatDateTime(assignment.revokedAt)
                        : "Inactive"}
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </AdminDataGrid>
        </AdminSurface>
      </div>
    </div>
  );
}
