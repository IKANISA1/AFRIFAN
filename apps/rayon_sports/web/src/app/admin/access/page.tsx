"use client";

import {
  type PointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  RefreshCw,
  Search,
  Trash2,
  ShieldCheck,
  UserPlus,
  Users,
} from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { KPISummaryRibbon, KPITile } from "@/components/admin/kpi-summary-ribbon";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { normalizeAdminRoleAssignments } from "@/lib/admin-role-assignments";
import {
  resolveAdminResourceFailure,
  type AdminResourceStatus,
  withAdminResourceTimeout,
} from "@/lib/admin-resource-state";
import {
  assignAdminRole,
  findAdminUserCandidate,
  formatAdminRoleLabel,
  getAdminRoleAssignments,
  revokeAdminRole,
} from "@/lib/data/admin";
import type {
  AdminAssignableRole,
  AdminRoleAssignment,
  AdminUserCandidate,
} from "@/lib/types";
import { cn } from "@/lib/utils";
import { useAdminCollection } from "@/lib/use-admin-collection";

type AdminAccessInteraction = "idle" | "focused" | "pressed" | "selected";

const accessStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading access assignments",
    detail: "Waiting for the first authenticated platform access snapshot.",
  },
  ready: {
    label: "Access assignments confirmed",
    detail: "Authorized roles and scopes are current.",
  },
  empty: {
    label: "No access assignments",
    detail: "No administrator assignments exist in the selected view.",
  },
  error: {
    label: "Access assignments unavailable",
    detail: "Confirmed assignments remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Access workspace is offline",
    detail: "Confirmed assignments remain visible until connection returns.",
  },
  permission_denied: {
    label: "Access management denied",
    detail: "Previously loaded administrator data has been cleared.",
  },
  syncing: {
    label: "Refreshing access assignments",
    detail: "Confirmed assignments remain visible during refresh.",
  },
  conflict: {
    label: "Access assignments changed",
    detail: "Refresh before acting on the current role assignments.",
  },
  security_timeout: {
    label: "Access request timed out",
    detail: "No access operation or change was confirmed.",
  },
};

const roleOptions: Array<{
  value: AdminAssignableRole;
  label: string;
  requiresClub: boolean;
}> = [
  { value: "super_admin", label: "Super admin", requiresClub: false },
  { value: "admin", label: "Platform admin", requiresClub: false },
  { value: "club_admin", label: "Club admin", requiresClub: true },
  { value: "club_moderator", label: "Club moderator", requiresClub: true },
];

function roleBadgeTone(role: AdminAssignableRole) {
  switch (role) {
    case "super_admin": return "accent" as const;
    case "admin": return "info" as const;
    case "club_admin": return "success" as const;
    case "club_moderator": return "neutral" as const;
  }
}

export default function AdminAccessPage() {
  const { access, client, clubOptions, activeClub } = useAdminPortal();
  const [assignments, setAssignments] = useState<AdminRoleAssignment[]>([]);
  const [candidate, setCandidate] = useState<AdminUserCandidate | null>(null);
  const [lookupInput, setLookupInput] = useState("");
  const [notes, setNotes] = useState("");
  const [role, setRole] = useState<AdminAssignableRole>("club_admin");
  const [clubId, setClubId] = useState(activeClub?.id ?? clubOptions[0]?.id ?? "");
  const [showInactive, setShowInactive] = useState(false);
  const [status, setStatus] = useState<AdminResourceStatus>("loading");
  const [hasConfirmed, setHasConfirmed] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminAccessInteraction>("idle");
  const [busyAction, setBusyAction] = useState<"lookup" | "assign" | "revoke" | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [detailAssignment, setDetailAssignment] =
    useState<AdminRoleAssignment | null>(null);
  const hasConfirmedRef = useRef(false);
  const activeController = useRef<AbortController | null>(null);
  const mounted = useRef(true);

  const assignmentCollection = useAdminCollection({
    records: assignments,
    getId: (assignment) => assignment.id,
    getSearchValues: (assignment) => [
      assignment.userName,
      assignment.userPhone,
      assignment.userEmail,
      assignment.role,
      assignment.clubName,
      assignment.publicUserId,
      assignment.grantedByName,
    ],
    getSortValue: (
      assignment,
      key: "user" | "role" | "scope" | "grantedAt",
    ) => {
      switch (key) {
        case "user":
          return assignment.userName;
        case "role":
          return assignment.role;
        case "scope":
          return assignment.clubName ?? "Platform scope";
        case "grantedAt":
          return new Date(assignment.grantedAt);
      }
    },
    initialSortKey: "grantedAt" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  const selectedRole = roleOptions.find((entry) => entry.value === role) ?? roleOptions[0];

  const loadAssignments = useCallback(async () => {
    if (client == null) return;

    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeController.current?.abort();
    const controller = new AbortController();
    activeController.current = controller;
    setStatus(hasConfirmedRef.current ? "syncing" : "loading");

    try {
      const response = await withAdminResourceTimeout({
        operation: getAdminRoleAssignments(client, access, {
          activeOnly: !showInactive,
          signal: controller.signal,
        }),
        controller,
        resourceLabel: "Access assignments",
      });
      if (!mounted.current) {
        return;
      }
      const nextAssignments = normalizeAdminRoleAssignments(response);
      setAssignments(nextAssignments);
      setHasConfirmed(true);
      hasConfirmedRef.current = true;
      setDetailAssignment((current) =>
        current != null &&
        nextAssignments.some((assignment) => assignment.id === current.id)
          ? current
          : null,
      );
      setStatus(nextAssignments.length === 0 ? "empty" : "ready");
    } catch (caught) {
      if (
        caught instanceof DOMException &&
        caught.name === "AbortError" &&
        activeController.current !== controller
      ) {
        return;
      }
      if (!mounted.current) {
        return;
      }
      const nextStatus = resolveAdminResourceFailure(
        caught,
        typeof navigator === "undefined" ? true : navigator.onLine,
      );
      if (nextStatus === "permission_denied") {
        setAssignments([]);
        setHasConfirmed(false);
        hasConfirmedRef.current = false;
        setDetailAssignment(null);
        setDrawerOpen(false);
      }
      setStatus(nextStatus);
      showAdminToast(accessStatusCopy[nextStatus].label, "error");
    } finally {
      if (activeController.current === controller) {
        activeController.current = null;
      }
    }
  }, [access, client, showInactive]);

  useEffect(() => {
    if (activeClub?.id && !clubId) setClubId(activeClub.id);
  }, [activeClub?.id, clubId]);

  useEffect(() => {
    if (client == null || !access.hasAccess || !access.isSuperAdmin) return;
    mounted.current = true;
    void loadAssignments();

    const markOffline = () => setStatus("offline");
    const recoverOnline = () => void loadAssignments();
    window.addEventListener("offline", markOffline);
    window.addEventListener("online", recoverOnline);
    return () => {
      mounted.current = false;
      activeController.current?.abort();
      window.removeEventListener("offline", markOffline);
      window.removeEventListener("online", recoverOnline);
    };
  }, [access.hasAccess, access.isSuperAdmin, client, loadAssignments]);

  const summary = useMemo(() => {
    const activeAssignments = assignments.filter((assignment) => assignment.isActive);
    const platformAssignments = activeAssignments.filter(a => a.role === "admin" || a.role === "super_admin");
    const clubScopedAssignments = activeAssignments.filter(a => a.clubId != null);
    const clubsTouched = new Set(clubScopedAssignments.map(a => a.clubId).filter(Boolean));

    return {
      total: activeAssignments.length,
      platform: platformAssignments.length,
      clubScoped: clubScopedAssignments.length,
      clubsTouched: clubsTouched.size,
    };
  }, [assignments]);

  const busy = status === "loading" || status === "syncing";
  const initialLoading = status === "loading" && !hasConfirmed;
  const statusCopy = accessStatusCopy[status];

  const pointerPressed = useRef(false);
  const setPointerPressed = (event: PointerEvent<HTMLButtonElement>) => {
    event.currentTarget.setPointerCapture?.(event.pointerId);
    pointerPressed.current = true;
    setInteraction("pressed");
  };
  const restInteraction = () => {
    if (!pointerPressed.current) {
      setInteraction(detailAssignment == null ? "idle" : "selected");
    }
  };
  const finishPointer = () => {
    pointerPressed.current = false;
    restInteraction();
  };
  const focusInteraction = () => {
    if (!pointerPressed.current) setInteraction("focused");
  };

  async function handleLookup() {
    if (client == null) return;
    setBusyAction("lookup");
    try {
      const nextCandidate = await findAdminUserCandidate(client, access, lookupInput);
      setCandidate(nextCandidate);
      showAdminToast(`Loaded ${nextCandidate.fullName}.`, "success");
    } catch (caught) {
      setCandidate(null);
      const nextStatus = resolveAdminResourceFailure(
        caught,
        typeof navigator === "undefined" ? true : navigator.onLine,
      );
      setStatus(nextStatus);
      showAdminToast(
        nextStatus === "permission_denied"
          ? accessStatusCopy.permission_denied.label
          : "Could not find a matching registered user.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function handleAssign() {
    if (client == null || candidate == null) return;
    setBusyAction("assign");
    try {
      await assignAdminRole(client, access, {
        userId: candidate.userId,
        role,
        clubId: selectedRole.requiresClub ? clubId : null,
        notes,
      });
      showAdminToast("Admin assignment saved.", "success");
      setNotes("");
      setCandidate(null);
      setLookupInput("");
      setDrawerOpen(false);
      await loadAssignments();
    } catch (caught) {
      const nextStatus = resolveAdminResourceFailure(
        caught,
        typeof navigator === "undefined" ? true : navigator.onLine,
      );
      setStatus(nextStatus);
      showAdminToast(
        nextStatus === "conflict"
          ? accessStatusCopy.conflict.label
          : "Could not confirm the admin assignment.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function handleRevoke(assignment: AdminRoleAssignment) {
    if (client == null) return;
    if (!confirmAdminDestructiveAction({
      action: "Revoke",
      subject: `${assignment.userName} (${formatAdminRoleLabel(assignment.role)})`,
      scope: assignment.clubName == null
        ? "Platform administration"
        : `Club ${assignment.clubName}`,
      impact: "This admin assignment will be disabled immediately.",
      undo: "manual_recovery",
    })) return;

    setBusyAction("revoke");
    try {
      await revokeAdminRole(client, access, assignment.id);
      showAdminToast("Admin assignment revoked.", "success");
      await loadAssignments();
    } catch (caught) {
      const nextStatus = resolveAdminResourceFailure(
        caught,
        typeof navigator === "undefined" ? true : navigator.onLine,
      );
      setStatus(nextStatus);
      showAdminToast(
        nextStatus === "conflict"
          ? accessStatusCopy.conflict.label
          : "Could not confirm the access revocation.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  if (!access.isSuperAdmin) {
    return (
      <div
        className="admin-access-state-surface section-grid"
        data-admin-access-status="permission_denied"
        role="alert"
      >
        <AdminPageHeader eyebrow="Access" title="Admin access management" />
        <AdminErrorState title="Platform admin access is required" description="Only platform administrators can add or revoke admin assignments." />
      </div>
    );
  }

  return (
    <section
      className="admin-access-state-surface section-grid !gap-6"
      data-admin-access-status={status}
      data-admin-access-interaction={interaction}
      data-admin-access-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Governance"
        title="Role management"
        meta={
          <>
            <AdminStatusBadge
              label="Secure access"
              tone="success"
            />
            <span className="admin-meta-chip">
              {summary.total} Active admins
            </span>
          </>
        }
        actions={
          <button
            onClick={() => setDrawerOpen(true)}
            disabled={busy || status === "permission_denied"}
            className="admin-action-button min-h-12 !bg-[var(--admin-accent)] !text-[var(--admin-canvas)] disabled:cursor-not-allowed disabled:!bg-[var(--admin-raised)] disabled:!text-[var(--admin-text-strong)]"
          >
            <UserPlus size={16} />
            <span>Grant access</span>
          </button>
        }
      />

      <div
        className={cn(
          "admin-access-status rounded-2xl border px-4 py-3",
          status === "permission_denied" ||
            status === "error" ||
            status === "security_timeout"
            ? "border-error/30 bg-error/10"
            : status === "offline" || status === "conflict"
              ? "border-warning/30 bg-warning/10"
              : "border-[var(--admin-border)] bg-[var(--admin-widget)]",
        )}
        role={
          status === "error" ||
          status === "permission_denied" ||
          status === "security_timeout"
            ? "alert"
            : "status"
        }
        aria-live={
          status === "error" ||
          status === "permission_denied" ||
          status === "security_timeout"
            ? "assertive"
            : "polite"
        }
      >
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="min-w-0">
            <p className="font-medium text-[var(--admin-text-strong)]">
              {statusCopy.label}
            </p>
            <p className="mt-1 text-sm leading-6 text-[var(--admin-secondary)]">
              {statusCopy.detail}
            </p>
          </div>
          <button
            type="button"
            disabled={busy || status === "permission_denied"}
            onClick={() => void loadAssignments()}
            onFocus={focusInteraction}
            onBlur={restInteraction}
            onPointerDown={setPointerPressed}
            onPointerUp={finishPointer}
            onPointerCancel={finishPointer}
            onLostPointerCapture={finishPointer}
            className="admin-access-control inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border border-[var(--admin-border)] px-4 py-3 text-sm font-medium text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-raised)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:cursor-not-allowed disabled:bg-[var(--admin-raised)] disabled:text-[var(--admin-text-strong)] motion-reduce:transition-none"
          >
            <RefreshCw
              size={17}
              aria-hidden="true"
              className={busy ? "animate-spin motion-reduce:animate-none" : ""}
            />
            {status === "error" ||
            status === "offline" ||
            status === "conflict" ||
            status === "security_timeout"
              ? "Try again"
              : "Refresh assignments"}
          </button>
        </div>
      </div>

      <KPISummaryRibbon>
        <KPITile label="Platform admins" value={initialLoading ? "..." : summary.platform.toString()} icon={ShieldCheck} />
        <KPITile label="Club-scoped" value={initialLoading ? "..." : summary.clubScoped.toString()} icon={Users} />
        <KPITile label="Clubs touched" value={initialLoading ? "..." : summary.clubsTouched.toString()} />
      </KPISummaryRibbon>

      {hasConfirmed || initialLoading ? (
      <div className="admin-surface">
        <AdminFilterBar
          actions={
            <label className="flex items-center gap-2 text-xs font-medium normal-case tracking-normal text-[var(--admin-secondary)] cursor-pointer hover:text-[var(--admin-foreground)] transition-colors">
              <input
                type="checkbox"
                checked={showInactive}
                onChange={(event) => setShowInactive(event.target.checked)}
                className="rounded border-[var(--admin-border)] bg-[var(--admin-canvas)] text-[var(--admin-accent)] focus:ring-action-neutral"
              />
              Show revoked
            </label>
          }
        >
          <label className="admin-search-field">
            <Search size={14} aria-hidden="true" />
            <span className="sr-only">Search administrator assignments</span>
            <input type="search" value={assignmentCollection.query} onChange={(event) => assignmentCollection.setQuery(event.target.value)} placeholder="Search administrator, role, or scope" />
          </label>
        </AdminFilterBar>

        <AdminDataGrid
          caption="Administrator role assignments"
          busy={busy}
          onRowActivate={(rowId) => {
            setDetailAssignment(assignments.find((assignment) => assignment.id === rowId) ?? null);
            setInteraction("selected");
          }}
          columns={[
            { key: "user", label: "User / Administrator", priority: "primary", sortable: true, sortDirection: assignmentCollection.sortDirectionFor("user"), onSort: () => assignmentCollection.toggleSort("user") },
            { key: "role", label: "Permission Role", priority: "primary", sortable: true, sortDirection: assignmentCollection.sortDirectionFor("role"), onSort: () => assignmentCollection.toggleSort("role") },
            { key: "scope", label: "Operational Scope", priority: "secondary", sortable: true, sortDirection: assignmentCollection.sortDirectionFor("scope"), onSort: () => assignmentCollection.toggleSort("scope") },
            { key: "granted", label: "Authorized On", priority: "secondary", sortable: true, sortDirection: assignmentCollection.sortDirectionFor("grantedAt"), onSort: () => assignmentCollection.toggleSort("grantedAt") },
            { key: "actions", label: "Actions", priority: "primary", className: "w-24" },
          ]}
        >
          {initialLoading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <tr key={i}>
                <td colSpan={5} className="p-4">
                  <Skeleton className="skeleton-text h-4 w-full" />
                </td>
              </tr>
            ))
          ) : assignmentCollection.pageResult.items.length === 0 ? (
            <tr>
              <td colSpan={5} className="p-12 text-center text-sm text-[var(--admin-secondary)]">
                {assignmentCollection.query ? "No assignments match the current search." : "No admin assignments found."}
              </td>
            </tr>
          ) : (
            assignmentCollection.pageResult.items.map((assignment) => (
              <tr key={assignment.id} data-row-id={assignment.id} className={cn(!assignment.isActive && "opacity-60 grayscale-[0.5]")}>
                <td>
                  <div className="space-y-0.5">
                    <p className="admin-row-title">{assignment.userName}</p>
                    <p className="admin-row-copy">{assignment.userPhone ?? assignment.userEmail ?? "No contact verified"}</p>
                  </div>
                </td>
                <td>
                  <AdminStatusBadge
                    label={formatAdminRoleLabel(assignment.role)}
                    tone={roleBadgeTone(assignment.role)}
                  />
                  {!assignment.isActive && (
                    <span className="ml-2 text-xs normal-case font-medium text-error bg-error/10 px-1.5 py-0.5 rounded">Revoked</span>
                  )}
                </td>
                <td>
                  <div className="space-y-0.5">
                    <p className="text-sm font-medium text-[var(--admin-foreground)]">{assignment.clubName ?? "Platform scope"}</p>
                    {assignment.publicUserId && (
                      <p className="text-xs normal-case font-medium text-[var(--admin-secondary)] tracking-tighter">ID: {assignment.publicUserId}</p>
                    )}
                  </div>
                </td>
                <td>
                  <div className="space-y-0.5 text-xs text-[var(--admin-secondary)]">
                    <p className="font-medium text-[var(--admin-foreground)]">{new Date(assignment.grantedAt).toLocaleDateString("en-RW", { month: "short", day: "numeric", year: "numeric" })}</p>
                    <p className="text-xs">by {assignment.grantedByName ?? "system"}</p>
                  </div>
                </td>
                <td className="text-right">
                  {assignment.isActive ? (
                    <div className="flex justify-end">
                      <button
                        onClick={() => handleRevoke(assignment).catch(() => {})}
                        className="admin-action-button admin-action-button-danger"
                        title="Revoke access"
                      >
                        <Trash2 size={13} />
                        Revoke
                      </button>
                    </div>
                  ) : null}
                </td>
              </tr>
            ))
          )}
        </AdminDataGrid>
        <AdminPagination page={assignmentCollection.pageResult} onPageChange={assignmentCollection.setPage} label="Administrator assignments" />
      </div>
      ) : (
        <AdminErrorState
          title={statusCopy.label}
          description={statusCopy.detail}
          onRetry={
            status === "permission_denied"
              ? undefined
              : () => void loadAssignments()
          }
        />
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title="Grant operational access"
        footer={
          <div className="flex gap-3">
            <button
              onClick={() => handleAssign().catch(() => {})}
              disabled={busyAction != null || candidate == null || (selectedRole.requiresClub && !clubId)}
              className="admin-action-button flex-1 !bg-[var(--admin-accent)] !text-[var(--admin-canvas)]"
            >
              {busyAction === "assign" ? "Granting access..." : "Confirm access"}
            </button>
            <button
              onClick={() => setDrawerOpen(false)}
              className="admin-action-button flex-1"
            >
              Cancel
            </button>
          </div>
        }
      >
        <div className="space-y-6">
          <div className="space-y-4">
            <p className="text-xs font-medium normal-case tracking-normal text-[var(--admin-secondary)]">User identity</p>
            <label className="grid gap-2">
              <div className="flex gap-2">
                <input
                  value={lookupInput}
                  onChange={(e) => setLookupInput(e.target.value)}
                  placeholder="Phone, email, or UUID..."
                  className="admin-input flex-1"
                />
                <button
                  onClick={() => handleLookup().catch(() => {})}
                  disabled={busyAction != null || !lookupInput.trim()}
                  className="admin-action-button !h-auto aspect-square"
                >
                  <Search size={14} />
                </button>
              </div>
            </label>

            {candidate ? (
              <div className="rounded-xl border border-success/20 bg-success/5 p-4">
                <p className="font-medium text-[var(--admin-text-strong)] text-lg">{candidate.fullName}</p>
                <p className="text-xs text-[var(--admin-text-muted)] font-mono tracking-tighter mt-1">{candidate.userId}</p>
                <div className="mt-4 grid gap-1 text-xs font-medium text-[var(--admin-secondary)]">
                  <p>{candidate.phone ?? "No phone"}</p>
                  <p>{candidate.email ?? "No email"}</p>
                </div>
              </div>
            ) : (
               <div className="p-8 text-center rounded-xl border border-dashed border-[var(--admin-border)]">
                 <p className="text-xs text-[var(--admin-secondary)]">Search for a registered user to assign them an administrative role.</p>
               </div>
            )}
          </div>

          <div className="space-y-4 pt-6 border-t border-[var(--admin-border)]">
            <p className="text-xs font-medium normal-case tracking-normal text-[var(--admin-secondary)]">Permission profile</p>
            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-foreground)]">
              Assign role
              <select
                value={role}
                onChange={(e) => setRole(e.target.value as AdminAssignableRole)}
                className="admin-input"
              >
                {roleOptions.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </label>

            {selectedRole.requiresClub && (
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-foreground)]">
                Club scope
                <select
                  value={clubId}
                  onChange={(e) => setClubId(e.target.value)}
                  className="admin-input"
                >
                  {clubOptions.map((o) => (
                    <option key={o.id} value={o.id}>{o.shortName || o.clubName}</option>
                  ))}
                </select>
              </label>
            )}

            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-foreground)]">
              Governance notes
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={4}
                placeholder="Reason for granting access (required for audit logs)..."
                className="admin-input min-h-24"
              />
            </label>
          </div>
        </div>
      </AdminActionDrawer>
      <AdminActionDrawer open={detailAssignment != null} onClose={() => setDetailAssignment(null)} title="Administrator assignment details">
        {detailAssignment ? (
          <dl className="grid gap-4 text-sm">
            <div><dt className="text-[var(--admin-text-muted)]">Administrator</dt><dd className="mt-1 text-[var(--admin-text-strong)]">{detailAssignment.userName}</dd></div>
            <div><dt className="text-[var(--admin-text-muted)]">Contact</dt><dd className="mt-1 text-[var(--admin-text-strong)]">{detailAssignment.userPhone ?? detailAssignment.userEmail ?? "No contact verified"}</dd></div>
            <div><dt className="text-[var(--admin-text-muted)]">Role</dt><dd className="mt-1 text-[var(--admin-text-strong)]">{formatAdminRoleLabel(detailAssignment.role)}</dd></div>
            <div><dt className="text-[var(--admin-text-muted)]">Scope</dt><dd className="mt-1 text-[var(--admin-text-strong)]">{detailAssignment.clubName ?? "Platform scope"}</dd></div>
            <div><dt className="text-[var(--admin-text-muted)]">Authorized</dt><dd className="mt-1 text-[var(--admin-text-strong)]">{new Date(detailAssignment.grantedAt).toLocaleString("en-RW")} by {detailAssignment.grantedByName ?? "system"}</dd></div>
            <div><dt className="text-[var(--admin-text-muted)]">Status</dt><dd className="mt-1 text-[var(--admin-text-strong)]">{detailAssignment.isActive ? "Active" : "Revoked"}</dd></div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </section>
  );
}
