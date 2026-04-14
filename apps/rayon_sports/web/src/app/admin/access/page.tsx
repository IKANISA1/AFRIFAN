"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { KeyRound, ShieldCheck, UserPlus, Users } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
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
    case "super_admin":
      return "border-amber-400/30 bg-amber-500/12 text-amber-200";
    case "admin":
      return "border-sky-400/30 bg-sky-500/12 text-sky-200";
    case "club_admin":
      return "border-emerald-400/30 bg-emerald-500/12 text-emerald-200";
    case "club_moderator":
      return "border-violet-400/30 bg-violet-500/12 text-violet-200";
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

  const selectedRole = roleOptions.find((entry) => entry.value === role) ?? roleOptions[0];

  const loadAssignments = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      const nextAssignments = await getAdminRoleAssignments(client, access, {
        activeOnly: !showInactive,
      });
      setAssignments(nextAssignments);
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load admin role assignments.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client, showInactive]);

  useEffect(() => {
    if (activeClub?.id && !clubId) {
      setClubId(activeClub.id);
    }
  }, [activeClub?.id, clubId]);

  useEffect(() => {
    if (client == null || !access.hasAccess || !access.isSuperAdmin) {
      return;
    }

    loadAssignments().catch(() => {});
  }, [access.hasAccess, access.isSuperAdmin, client, loadAssignments]);

  const summary = useMemo(() => {
    const activeAssignments = assignments.filter((assignment) => assignment.isActive);
    const platformAssignments = activeAssignments.filter(
      (assignment) =>
        assignment.role === "admin" || assignment.role === "super_admin",
    );
    const clubScopedAssignments = activeAssignments.filter(
      (assignment) => assignment.clubId != null,
    );
    const clubsTouched = new Set(
      clubScopedAssignments.map((assignment) => assignment.clubId).filter(Boolean),
    );

    return {
      total: activeAssignments.length,
      platform: platformAssignments.length,
      clubScoped: clubScopedAssignments.length,
      clubsTouched: clubsTouched.size,
    };
  }, [assignments]);

  async function handleLookup() {
    if (client == null) {
      return;
    }

    setBusyAction("lookup");
    try {
      const nextCandidate = await findAdminUserCandidate(client, access, lookupInput);
      setCandidate(nextCandidate);
      showAdminToast(`Loaded ${nextCandidate.fullName}.`, "success");
    } catch (caught) {
      setCandidate(null);
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not find that user.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function handleAssign() {
    if (client == null || candidate == null) {
      return;
    }

    setBusyAction("assign");
    showAdminToast("Saving admin assignment...", "info");
    try {
      await assignAdminRole(client, access, {
        userId: candidate.userId,
        role,
        clubId: selectedRole.requiresClub ? clubId : null,
        notes,
      });
      showAdminToast("Admin assignment saved.", "success");
      setNotes("");
      await loadAssignments();
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save admin assignment.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function handleRevoke(assignment: AdminRoleAssignment) {
    if (client == null) {
      return;
    }

    if (
      !confirmAdminDestructiveAction({
        action: "Revoke",
        subject: `${assignment.userName} (${formatAdminRoleLabel(assignment.role)})`,
        detail: "This admin assignment will be disabled immediately.",
      })
    ) {
      return;
    }

    setBusyAction("revoke");
    showAdminToast(`Revoking ${assignment.userName}...`, "info");
    try {
      await revokeAdminRole(client, access, assignment.id);
      showAdminToast("Admin assignment revoked.", "success");
      await loadAssignments();
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not revoke admin assignment.",
        "error",
      );
    } finally {
      setBusyAction(null);
    }
  }

  if (!access.isSuperAdmin) {
    return (
      <div className="section-grid">
        <AdminPageHeader
          eyebrow="Access"
          title="Admin access management"
          description="This workspace is limited to platform administrators."
        />
        <AdminErrorState
          title="Platform admin access is required"
          description="Only platform administrators can add or revoke admin assignments."
        />
      </div>
    );
  }

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Access"
        title="Admin access management"
        description="Add new admins, scope club roles, and revoke assignments without dropping into SQL."
      />

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
        <AdminStateCard
          label="Active assignments"
          value={loading ? "..." : summary.total.toString()}
          helper="Current admin grants."
          icon={KeyRound}
        />
        <AdminStateCard
          label="Platform admins"
          value={loading ? "..." : summary.platform.toString()}
          helper="Cross-club operators."
          icon={ShieldCheck}
        />
        <AdminStateCard
          label="Club-scoped"
          value={loading ? "..." : summary.clubScoped.toString()}
          helper="Assignments limited to one club."
          icon={Users}
        />
        <AdminStateCard
          label="Clubs touched"
          value={loading ? "..." : summary.clubsTouched.toString()}
          helper="Distinct scoped clubs."
          icon={UserPlus}
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.92fr_1.08fr]">
        <article className="glass-panel rounded-[32px] p-6">
          <div className="space-y-2">
            <p className="font-mono text-[11px] uppercase tracking-[0.3em] text-club-accent">
              Add admin
            </p>
            <h2 className="font-display text-3xl font-bold uppercase text-white">
              Resolve a user, then assign access
            </h2>
            <p className="text-sm leading-7 text-slate-300">
              Search by phone number, email, or user UUID. Club-scoped roles require an explicit club.
            </p>
          </div>

          <div className="mt-6 grid gap-4">
            <label className="grid gap-2 text-sm text-slate-300">
              User identifier
              <div className="flex flex-col gap-3 sm:flex-row">
                <input
                  value={lookupInput}
                  onChange={(event) => setLookupInput(event.target.value)}
                  placeholder="+2507..., admin@example.com, or user uuid"
                  className="admin-input flex-1"
                />
                <button
                  type="button"
                  onClick={() => handleLookup().catch(() => {})}
                  disabled={busyAction != null || lookupInput.trim().length === 0}
                  className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light disabled:opacity-60"
                >
                  {busyAction === "lookup" ? "Looking up…" : "Find user"}
                </button>
              </div>
            </label>

            {candidate ? (
              <div className="rounded-[24px] border border-white/8 bg-white/4 p-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="text-lg font-semibold text-white">{candidate.fullName}</p>
                    <p className="mt-1 text-xs uppercase tracking-[0.18em] text-slate-400">
                      {candidate.publicUserId ? `User ${candidate.publicUserId}` : candidate.userId}
                    </p>
                  </div>
                  {candidate.isPlatformAdmin ? (
                    <span className="rounded-full border border-amber-400/30 bg-amber-500/12 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-amber-200">
                      Platform admin
                    </span>
                  ) : null}
                </div>
                <div className="mt-4 grid gap-2 text-sm text-slate-300">
                  <p>{candidate.phone ?? "No phone on profile"}</p>
                  <p>{candidate.email ?? "No email on auth record"}</p>
                  {!candidate.hasProfile ? (
                    <p className="text-amber-200">
                      This account exists in auth but does not have a matching public profile row yet.
                    </p>
                  ) : null}
                </div>
              </div>
            ) : null}

            <label className="grid gap-2 text-sm text-slate-300">
              Role
              <select
                value={role}
                onChange={(event) => setRole(event.target.value as AdminAssignableRole)}
                className="admin-input"
              >
                {roleOptions.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>

            {selectedRole.requiresClub ? (
              <label className="grid gap-2 text-sm text-slate-300">
                Club scope
                <select
                  value={clubId}
                  onChange={(event) => setClubId(event.target.value)}
                  className="admin-input"
                >
                  {clubOptions.map((option) => (
                    <option key={option.id} value={option.id}>
                      {option.shortName || option.clubName}
                    </option>
                  ))}
                </select>
              </label>
            ) : null}

            <label className="grid gap-2 text-sm text-slate-300">
              Notes
              <textarea
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                rows={4}
                placeholder="Why is this assignment being granted?"
                className="admin-input min-h-28"
              />
            </label>

            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => handleAssign().catch(() => {})}
                disabled={
                  busyAction != null ||
                  candidate == null ||
                  (selectedRole.requiresClub && !clubId)
                }
                className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light disabled:opacity-60"
              >
                {busyAction === "assign" ? "Saving…" : "Grant admin role"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setCandidate(null);
                  setLookupInput("");
                  setNotes("");
                }}
                className="rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-slate-200 transition hover:bg-white/8"
              >
                Clear
              </button>
            </div>
          </div>
        </article>

        <article className="glass-panel rounded-[32px] p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="font-mono text-[11px] uppercase tracking-[0.3em] text-club-accent">
                Current assignments
              </p>
              <h2 className="mt-2 font-display text-3xl font-bold uppercase text-white">
                Role grants across the workspace
              </h2>
            </div>
            <label className="flex items-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-300">
              <input
                type="checkbox"
                checked={showInactive}
                onChange={(event) => setShowInactive(event.target.checked)}
              />
              Show revoked
            </label>
          </div>

          {loadError && !loading ? (
            <AdminErrorState
              className="mt-6"
              title="Assignments could not be loaded"
              description={loadError}
              onRetry={() => {
                loadAssignments().catch(() => {});
              }}
            />
          ) : null}

          <div className="mt-6 space-y-3">
            {loading ? (
              Array.from({ length: 4 }).map((_, index) => (
                <div
                  key={index}
                  className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
                >
                  <div className="skeleton h-5 w-40 rounded-xl" />
                  <div className="skeleton-text mt-3 h-3 w-56" />
                  <div className="skeleton-text mt-3 h-3 w-48" />
                </div>
              ))
            ) : null}

            {!loading && assignments.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No admin assignments matched the current filter.
              </p>
            ) : null}

            {!loading &&
              assignments.map((assignment) => (
                <article
                  key={assignment.id}
                  className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="text-lg font-semibold text-white">
                          {assignment.userName}
                        </p>
                        <span
                          className={cn(
                            "rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em]",
                            roleBadgeTone(assignment.role),
                          )}
                        >
                          {formatAdminRoleLabel(assignment.role)}
                        </span>
                        {!assignment.isActive ? (
                          <span className="rounded-full border border-white/10 bg-white/8 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300">
                            Revoked
                          </span>
                        ) : null}
                      </div>
                      <p className="mt-2 text-sm text-slate-300">
                        {assignment.userPhone ?? "No phone"}{" "}
                        {assignment.userEmail ? `• ${assignment.userEmail}` : ""}
                      </p>
                      <div className="mt-3 flex flex-wrap gap-2 text-xs text-slate-400">
                        <span className="rounded-full border border-white/10 bg-black/10 px-3 py-1.5">
                          {assignment.clubName ?? "Platform scope"}
                        </span>
                        {assignment.publicUserId ? (
                          <span className="rounded-full border border-white/10 bg-black/10 px-3 py-1.5">
                            User {assignment.publicUserId}
                          </span>
                        ) : null}
                        {assignment.partnerName ? (
                          <span className="rounded-full border border-white/10 bg-black/10 px-3 py-1.5">
                            {assignment.partnerName}
                          </span>
                        ) : null}
                      </div>
                    </div>

                    {assignment.isActive ? (
                      <button
                        type="button"
                        onClick={() => handleRevoke(assignment).catch(() => {})}
                        disabled={busyAction != null}
                        className="rounded-full border border-rose-400/30 bg-rose-500/10 px-4 py-2 text-sm font-semibold text-rose-100 transition hover:bg-rose-500/15 disabled:opacity-60"
                      >
                        Revoke
                      </button>
                    ) : null}
                  </div>

                  <div className="mt-4 grid gap-2 text-sm text-slate-400 sm:grid-cols-2">
                    <p>
                      Granted {new Date(assignment.grantedAt).toLocaleString("en-RW", {
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </p>
                    <p>
                      Granted by {assignment.grantedByName ?? assignment.grantedBy ?? "system"}
                    </p>
                  </div>

                  {assignment.notes ? (
                    <p className="mt-3 rounded-[18px] border border-white/8 bg-black/10 px-3 py-2 text-sm leading-6 text-slate-300">
                      {assignment.notes}
                    </p>
                  ) : null}
                </article>
              ))}
          </div>
        </article>
      </div>
    </div>
  );
}
