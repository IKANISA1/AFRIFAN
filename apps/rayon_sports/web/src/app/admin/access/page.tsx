"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Plus, Search, Trash2, KeyRound, ShieldCheck, UserPlus, Users } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { KPISummaryRibbon, KPITile } from "@/components/admin/kpi-summary-ribbon";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
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
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [busyAction, setBusyAction] = useState<"lookup" | "assign" | "revoke" | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const selectedRole = roleOptions.find((entry) => entry.value === role) ?? roleOptions[0];

  const loadAssignments = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const nextAssignments = await getAdminRoleAssignments(client, access, {
        activeOnly: !showInactive,
      });
      setAssignments(nextAssignments);
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load admin role assignments.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client, showInactive]);

  useEffect(() => {
    if (activeClub?.id && !clubId) setClubId(activeClub.id);
  }, [activeClub?.id, clubId]);

  useEffect(() => {
    if (client == null || !access.hasAccess || !access.isSuperAdmin) return;
    loadAssignments().catch(() => {});
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

  async function handleLookup() {
    if (client == null) return;
    setBusyAction("lookup");
    try {
      const nextCandidate = await findAdminUserCandidate(client, access, lookupInput);
      setCandidate(nextCandidate);
      showAdminToast(`Loaded ${nextCandidate.fullName}.`, "success");
    } catch (caught) {
      setCandidate(null);
      showAdminToast(caught instanceof Error ? caught.message : "Could not find that user.", "error");
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
      showAdminToast(caught instanceof Error ? caught.message : "Could not save admin assignment.", "error");
    } finally {
      setBusyAction(null);
    }
  }

  async function handleRevoke(assignment: AdminRoleAssignment) {
    if (client == null) return;
    if (!confirmAdminDestructiveAction({
      action: "Revoke",
      subject: `${assignment.userName} (${formatAdminRoleLabel(assignment.role)})`,
      detail: "This admin assignment will be disabled immediately.",
    })) return;

    setBusyAction("revoke");
    try {
      await revokeAdminRole(client, access, assignment.id);
      showAdminToast("Admin assignment revoked.", "success");
      await loadAssignments();
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not revoke admin assignment.", "error");
    } finally {
      setBusyAction(null);
    }
  }

  if (!access.isSuperAdmin) {
    return (
      <div className="section-grid">
        <AdminPageHeader eyebrow="Access" title="Admin access management" />
        <AdminErrorState title="Platform admin access is required" description="Only platform administrators can add or revoke admin assignments." />
      </div>
    );
  }

  return (
    <div className="section-grid !gap-6">
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
            className="admin-action-button !bg-club-accent !text-white"
          >
            <UserPlus size={16} />
            <span>Grant access</span>
          </button>
        }
      />

      <KPISummaryRibbon>
        <KPITile label="Platform admins" value={loading ? "..." : summary.platform.toString()} icon={ShieldCheck} />
        <KPITile label="Club-scoped" value={loading ? "..." : summary.clubScoped.toString()} icon={Users} />
        <KPITile label="Clubs touched" value={loading ? "..." : summary.clubsTouched.toString()} />
      </KPISummaryRibbon>

      <div className="admin-surface">
        <AdminFilterBar
          actions={
            <label className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-widest text-[var(--admin-zinc-500)] cursor-pointer hover:text-[var(--admin-zinc-300)] transition-colors">
              <input
                type="checkbox"
                checked={showInactive}
                onChange={(event) => setShowInactive(event.target.checked)}
                className="rounded border-[var(--admin-border)] bg-[var(--admin-zinc-950)] text-club-accent focus:ring-club-accent"
              />
              Show revoked
            </label>
          }
        >
          <div className="flex items-center gap-2 rounded-lg border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] px-3 py-1.5 text-sm text-[var(--admin-zinc-400)]">
            <Search size={14} />
            <span className="text-[11px] uppercase tracking-wider">Administrator list</span>
          </div>
        </AdminFilterBar>

        {loadError && !loading ? (
          <div className="p-8">
            <AdminErrorState title="Could not load assignments" description={loadError} onRetry={() => { loadAssignments().catch(() => {}); }} />
          </div>
        ) : null}

        <AdminDataGrid
          columns={[
            { key: "user", label: "User / Administrator" },
            { key: "role", label: "Permission Role" },
            { key: "scope", label: "Operational Scope" },
            { key: "granted", label: "Authorized On" },
            { key: "actions", label: "", className: "w-24" },
          ]}
        >
          {loading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <tr key={i}>
                <td colSpan={5} className="p-4">
                  <Skeleton className="skeleton-text h-4 w-full" />
                </td>
              </tr>
            ))
          ) : assignments.length === 0 ? (
            <tr>
              <td colSpan={5} className="p-12 text-center text-sm text-[var(--admin-zinc-500)]">
                No admin assignments found.
              </td>
            </tr>
          ) : (
            assignments.map((assignment) => (
              <tr key={assignment.id} className={cn(!assignment.isActive && "opacity-60 grayscale-[0.5]")}>
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
                    <span className="ml-2 text-[9px] uppercase font-bold text-rose-500 bg-rose-500/10 px-1.5 py-0.5 rounded">Revoked</span>
                  )}
                </td>
                <td>
                  <div className="space-y-0.5">
                    <p className="text-sm font-medium text-[var(--admin-zinc-100)]">{assignment.clubName ?? "Platform scope"}</p>
                    {assignment.publicUserId && (
                      <p className="text-[10px] uppercase font-bold text-[var(--admin-zinc-500)] tracking-tighter">ID: {assignment.publicUserId}</p>
                    )}
                  </div>
                </td>
                <td>
                  <div className="space-y-0.5 text-xs text-[var(--admin-zinc-400)]">
                    <p className="font-medium text-[var(--admin-zinc-300)]">{new Date(assignment.grantedAt).toLocaleDateString("en-RW", { month: "short", day: "numeric", year: "numeric" })}</p>
                    <p className="text-[10px]">by {assignment.grantedByName ?? "system"}</p>
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
      </div>

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title="Grant operational access"
        footer={
          <div className="flex gap-3">
            <button
              onClick={() => handleAssign().catch(() => {})}
              disabled={busyAction != null || candidate == null || (selectedRole.requiresClub && !clubId)}
              className="admin-action-button flex-1 !bg-club-accent !text-white"
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
            <p className="text-[10px] font-bold uppercase tracking-widest text-[var(--admin-zinc-500)]">User identity</p>
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
              <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/5 p-4">
                <p className="font-bold text-white text-lg">{candidate.fullName}</p>
                <p className="text-[10px] text-emerald-400/60 font-mono tracking-tighter mt-1">{candidate.userId}</p>
                <div className="mt-4 grid gap-1 text-xs font-medium text-[var(--admin-zinc-400)]">
                  <p>{candidate.phone ?? "No phone"}</p>
                  <p>{candidate.email ?? "No email"}</p>
                </div>
              </div>
            ) : (
               <div className="p-8 text-center rounded-xl border border-dashed border-[var(--admin-border)]">
                 <p className="text-xs text-[var(--admin-zinc-500)]">Search for a registered user to assign them an administrative role.</p>
               </div>
            )}
          </div>

          <div className="space-y-4 pt-6 border-t border-[var(--admin-border)]">
            <p className="text-[10px] font-bold uppercase tracking-widest text-[var(--admin-zinc-500)]">Permission profile</p>
            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-zinc-100)]">
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
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-zinc-100)]">
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

            <label className="grid gap-2 text-sm font-semibold text-[var(--admin-zinc-100)]">
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
    </div>
  );
}
