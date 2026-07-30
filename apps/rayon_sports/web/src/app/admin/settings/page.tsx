"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  Building2,
  Clock3,
  Cpu,
  Languages,
  ScrollText,
  Settings2,
  ShieldCheck,
} from "lucide-react";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  getAdminClubProfile,
  normalizeAdminClubProfile,
  saveAdminClubProfile,
  type AdminClubProfile,
} from "@/lib/data/admin/settings";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { cn } from "@/lib/utils";
import {
  formToProfile,
  profileToForm,
  type SettingsForm,
} from "./_components/settings-form-state";
import { IdentityForm } from "./_components/identity-form";
import { BrandPreview } from "./_components/brand-preview";

type SettingsTab = "organization" | "infrastructure";

const profileIsEmpty = (profile: AdminClubProfile | null) => profile == null;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading club settings",
    detail: "Waiting for the first authenticated club-profile snapshot.",
  },
  ready: {
    label: "Club settings confirmed",
    detail: "Identity, language, brand, and feature values are current.",
  },
  empty: {
    label: "No club settings record",
    detail:
      "No profile exists in the active club scope. Contact a platform administrator.",
  },
  error: {
    label: "Club settings unavailable",
    detail: "Confirmed values remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Club settings are offline",
    detail: "Confirmed values remain visible; saving is locked.",
  },
  permission_denied: {
    label: "Settings access denied",
    detail:
      "Profile values and the active draft were cleared. Use an authorized admin account.",
  },
  syncing: {
    label: "Refreshing club settings",
    detail: "Confirmed values remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Club settings changed",
    detail:
      "Another update won the race. Refresh the latest profile before editing again.",
  },
  security_timeout: {
    label: "Settings request timed out",
    detail: "No change was confirmed. Retry from the retained profile.",
  },
};

function formatProfileVersion(value: string) {
  try {
    return new Intl.DateTimeFormat("en", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date(value));
  } catch {
    return "Confirmed";
  }
}

export default function AdminSettingsPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [activeTab, setActiveTab] = useState<SettingsTab>("organization");
  const [form, setForm] = useState<SettingsForm | null>(null);
  const [mutationPending, setMutationPending] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const clearDraft = useCallback(() => {
    setForm(null);
  }, []);

  const loadProfile = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return null;
      return getAdminClubProfile(client, access, { signal });
    },
    [access, client],
  );

  const {
    data: profile,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState<AdminClubProfile | null>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: null,
    isEmpty: profileIsEmpty,
    load: loadProfile,
    normalize: normalizeAdminClubProfile,
    onPermissionDenied: clearDraft,
    resourceLabel: "club settings",
  });

  useEffect(() => {
    if (profile != null) {
      setForm(profileToForm(profile));
    } else if (hasConfirmed) {
      setForm(null);
    }
  }, [hasConfirmed, profile]);

  const enabledFlags = useMemo(
    () => (form == null
      ? null
      : Object.values(form.featureFlags).filter(Boolean).length),
    [form],
  );
  const languageCount = useMemo(
    () => (form == null
      ? null
      : new Set(
          form.supportedLanguagesText
            .split(",")
            .map((item) => item.trim().toLowerCase())
            .filter(Boolean),
        ).size),
    [form],
  );
  const canSave = access.isSuperAdmin || access.role === "club_admin";
  const mutationLocked =
    mutationPending || status !== "ready" || form == null || !canSave;
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  async function submitForm() {
    if (client == null || form == null || mutationLocked) return;

    setMutationPending(true);
    try {
      await saveAdminClubProfile(client, access, formToProfile(form));
      await refresh();
      showAdminToast("Club settings update confirmed.", "success");
    } catch (caught) {
      applyFailure(caught);
      showAdminToast(
        isAdminMutationConflict(caught)
          ? "Club settings changed. Refresh before editing again."
          : "Could not confirm the club settings update.",
        "error",
      );
    } finally {
      setMutationPending(false);
    }
  }

  return (
    <div
      className="admin-settings-state-surface section-grid min-w-0 max-w-full !gap-6"
      data-admin-settings-status={status}
      data-admin-settings-interaction={interaction}
      data-admin-settings-refresh-disabled={busy}
      data-admin-settings-mutation-disabled={mutationLocked}
      aria-busy={busy || mutationPending || undefined}
    >
      <AdminPageHeader
        eyebrow="Configuration"
        title="Platform settings"
        meta={
          <span className="admin-meta-chip">
            {access.isSuperAdmin ? "Platform admin" : "Club scope"}
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh club settings"
        selected={interaction === "selected"}
        onRefresh={() => {
          void refresh();
        }}
        onInteractionChange={setInteraction}
      />

      <div className="admin-settings-metrics-grid grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <AdminStateCard
          label="Enabled features"
          value={initialLoading || enabledFlags == null ? "—" : enabledFlags.toString()}
          helper="From the stored club profile."
          icon={ShieldCheck}
        />
        <AdminStateCard
          label="Languages"
          value={initialLoading || languageCount == null ? "—" : languageCount.toString()}
          helper="Unique configured language codes."
          icon={Languages}
        />
        <AdminStateCard
          label="Edit scope"
          value={canSave ? "Write" : "Read only"}
          helper={access.isSuperAdmin ? "Platform administrator." : "Role controlled."}
          icon={Settings2}
          tone={canSave ? "accent" : "neutral"}
        />
        <AdminStateCard
          label="Profile version"
          value={profile == null ? "—" : formatProfileVersion(profile.updatedAt)}
          helper="Last confirmed database update."
          icon={Clock3}
        />
      </div>

      <div
        className="flex items-center gap-1 overflow-x-auto border-b border-[var(--admin-border)] no-scrollbar"
        role="tablist"
        aria-label="Settings sections"
      >
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "organization"}
          onClick={() => {
            setActiveTab("organization");
            setInteraction("selected");
          }}
          className={cn(
            "relative flex min-h-12 items-center gap-2 px-5 py-3 text-xs font-bold uppercase tracking-widest transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-club-accent motion-reduce:transition-none",
            activeTab === "organization"
              ? "text-white"
              : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]",
          )}
        >
          <Building2 size={14} aria-hidden="true" />
          Organization
          {activeTab === "organization" ? (
            <span
              className="absolute inset-x-0 bottom-0 h-0.5 bg-club-accent"
              aria-hidden="true"
            />
          ) : null}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "infrastructure"}
          onClick={() => {
            setActiveTab("infrastructure");
            setInteraction("selected");
          }}
          className={cn(
            "relative flex min-h-12 items-center gap-2 px-5 py-3 text-xs font-bold uppercase tracking-widest transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-club-accent motion-reduce:transition-none",
            activeTab === "infrastructure"
              ? "text-white"
              : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]",
          )}
        >
          <Cpu size={14} aria-hidden="true" />
          Related controls
          {activeTab === "infrastructure" ? (
            <span
              className="absolute inset-x-0 bottom-0 h-0.5 bg-club-accent"
              aria-hidden="true"
            />
          ) : null}
        </button>
      </div>

      {activeTab === "organization" ? (
        unrecoveredFailure || status === "empty" ? null : (
          <div className="admin-settings-workspace grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
            <IdentityForm
              form={form}
              setForm={setForm}
              loading={initialLoading}
              canSave={canSave && status === "ready"}
              saving={mutationPending}
              onSave={() => {
                void submitForm();
              }}
            />
            <BrandPreview
              form={form}
              setForm={setForm}
              loading={initialLoading}
              canEdit={canSave && status === "ready" && !mutationPending}
            />
          </div>
        )
      ) : (
        <section
          className="admin-settings-related-grid grid gap-5 lg:grid-cols-3"
          aria-label="Related governed controls"
        >
          {[
            {
              href: "/admin/settings/features",
              title: "Feature controls",
              detail:
                "Review route availability and club-scoped feature decisions.",
              icon: ShieldCheck,
            },
            {
              href: "/admin/settings/runtime",
              title: "Runtime registry",
              detail:
                "Manage governed routes, option sets, navigation, and copy.",
              icon: Cpu,
            },
            {
              href: "/admin/settings/audit",
              title: "Audit review",
              detail:
                "Inspect recorded configuration activity and operator history.",
              icon: ScrollText,
            },
          ].map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className="glass-panel group min-h-48 rounded-[28px] p-6 transition hover:-translate-y-0.5 hover:border-club-accent/40 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-club-accent motion-reduce:transform-none motion-reduce:transition-none"
              >
                <div className="flex items-start justify-between gap-4">
                  <span className="rounded-2xl border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] p-3 text-club-accent">
                    <Icon size={20} aria-hidden="true" />
                  </span>
                  <AdminStatusBadge label="Separate route" tone="neutral" />
                </div>
                <h2 className="mt-6 font-display text-2xl font-bold uppercase">
                  {item.title}
                </h2>
                <p className="mt-3 text-sm leading-6 text-slate-300">
                  {item.detail}
                </p>
              </Link>
            );
          })}
        </section>
      )}
    </div>
  );
}
