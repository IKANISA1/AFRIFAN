"use client";

import { useCallback, useMemo, useState } from "react";
import {
  Check,
  Search,
  Server,
  Settings2,
  ShieldCheck,
  X,
  Zap,
} from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import {
  filterAdminRecords,
  paginateAdminRecords,
  stableSortAdminRecords,
  type AdminSortDirection,
} from "@/lib/admin-collection";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  getAdminFeatures,
  normalizeAdminFeatures,
  updateAdminFeature,
} from "@/lib/data/admin/features";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { PlatformFeature } from "@/lib/types";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

type FeatureSortKey = "feature" | "scope" | "category" | "status";

const pageSize = 25;
const emptyFeatures: PlatformFeature[] = [];
const featuresAreEmpty = (features: PlatformFeature[]) => features.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading feature registry",
    detail: "Waiting for the first authenticated, scope-confirmed snapshot.",
  },
  ready: {
    label: "Feature registry confirmed",
    detail: "The latest bounded feature controls are ready for review.",
  },
  empty: {
    label: "No features in this scope",
    detail: "No governed feature controls are available for the active scope.",
  },
  error: {
    label: "Feature registry unavailable",
    detail:
      "Confirmed controls remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Feature registry is offline",
    detail: "Confirmed controls remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "Feature access denied",
    detail:
      "Controls, filters, pagination, and open configuration were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing feature registry",
    detail: "Confirmed controls remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Feature configuration changed",
    detail: "Review the retained snapshot, then refresh before making changes.",
  },
  security_timeout: {
    label: "Feature request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained controls.",
  },
};

const emptyRules: NonNullable<PlatformFeature["rules"]> = {
  authRequired: false,
  roleRestrictions: [],
  dependencyRules: {},
  rolloutRules: {},
  metadata: {},
  scheduleStartAt: null,
  scheduleEndAt: null,
};

function toDateTimeLocalValue(value: string | null | undefined) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60_000).toISOString().slice(0, 16);
}

function fromDateTimeLocalValue(value: string) {
  if (!value.trim()) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function parseJsonObject(raw: string) {
  const parsed = JSON.parse(raw);
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Enter a JSON object.");
  }
  return parsed as Record<string, unknown>;
}

function createDraft(feature: PlatformFeature): PlatformFeature {
  return {
    ...feature,
    channels: feature.channels.map((channel) => ({ ...channel })),
    rules:
      feature.rules == null
        ? { ...emptyRules }
        : {
            ...feature.rules,
            roleRestrictions: [...feature.rules.roleRestrictions],
            dependencyRules: { ...feature.rules.dependencyRules },
            rolloutRules: { ...feature.rules.rolloutRules },
            metadata: { ...feature.rules.metadata },
          },
  };
}

function ChannelState({
  channel,
  enabled,
}: {
  channel: "Mobile" | "Website";
  enabled: boolean;
}) {
  return (
    <span
      className={
        enabled
          ? "inline-flex min-h-12 min-w-12 items-center justify-center text-success"
          : "inline-flex min-h-12 min-w-12 items-center justify-center text-[var(--admin-secondary)]"
      }
      title={`${channel} ${enabled ? "enabled" : "disabled"}`}
    >
      {enabled ? (
        <Check size={18} strokeWidth={3} aria-hidden="true" />
      ) : (
        <X size={18} strokeWidth={3} aria-hidden="true" />
      )}
      <span className="sr-only">
        {channel} {enabled ? "enabled" : "disabled"}
      </span>
    </span>
  );
}

export default function AdminFeaturesPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [filter, setFilter] = useState("");
  const [sortKey, setSortKey] = useState<FeatureSortKey>("feature");
  const [sortDirection, setSortDirection] =
    useState<AdminSortDirection>("ascending");
  const [page, setPage] = useState(1);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [draftFeature, setDraftFeature] = useState<PlatformFeature | null>(
    null,
  );
  const [dependencyRulesText, setDependencyRulesText] = useState("{}");
  const [jsonError, setJsonError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const clearPrivateState = useCallback(() => {
    setFilter("");
    setPage(1);
    setDrawerOpen(false);
    setDraftFeature(null);
    setDependencyRulesText("{}");
    setJsonError(null);
    setInteraction("idle");
  }, []);
  const loadFeatures = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyFeatures;
      return getAdminFeatures(client, access, { signal });
    },
    [access, client],
  );
  const {
    data: features,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState<PlatformFeature[]>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyFeatures,
    isEmpty: featuresAreEmpty,
    load: loadFeatures,
    normalize: normalizeAdminFeatures,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "feature registry",
  });

  const sortedFeatures = useMemo(() => {
    const filtered = filterAdminRecords(features, filter, (feature) => [
      feature.displayName,
      feature.description,
      feature.featureKey,
      feature.scope,
      feature.category,
      feature.visibilityState,
      feature.isEnabled ? "active enabled" : "disabled",
    ]);
    return stableSortAdminRecords(
      filtered,
      (feature) => {
        switch (sortKey) {
          case "feature":
            return feature.displayName;
          case "scope":
            return feature.scope;
          case "category":
            return feature.category ?? "";
          case "status":
            return feature.isEnabled ? feature.visibilityState : "disabled";
        }
      },
      sortDirection,
    );
  }, [features, filter, sortDirection, sortKey]);
  const featurePage = useMemo(
    () => paginateAdminRecords(sortedFeatures, page, pageSize),
    [page, sortedFeatures],
  );

  const canEdit = access.isSuperAdmin || access.role === "club_admin";
  const mutationLocked =
    saving || busy || !canEdit || (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  function changeSort(nextSortKey: FeatureSortKey) {
    setPage(1);
    if (sortKey === nextSortKey) {
      setSortDirection((current) =>
        current === "ascending" ? "descending" : "ascending",
      );
      return;
    }
    setSortKey(nextSortKey);
    setSortDirection("ascending");
  }

  function beginEdit(feature: PlatformFeature) {
    const draft = createDraft(feature);
    setDraftFeature(draft);
    setDependencyRulesText(
      JSON.stringify(draft.rules?.dependencyRules ?? {}, null, 2),
    );
    setJsonError(null);
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function closeDrawer() {
    setDrawerOpen(false);
    setDraftFeature(null);
    setDependencyRulesText("{}");
    setJsonError(null);
    setInteraction("idle");
  }

  async function handleMutationFailure(error: unknown) {
    const nextStatus = applyFailure(error);
    if (isAdminMutationConflict(error) || nextStatus === "conflict") {
      await refresh();
    }
    showAdminToast(statusCopy[nextStatus].label, "error");
  }

  async function toggleFeatureEnabled(feature: PlatformFeature) {
    if (client == null || mutationLocked) return;
    setSaving(true);
    try {
      await updateAdminFeature(client, access, feature.id, feature.updatedAt, {
        isEnabled: !feature.isEnabled,
      });
      showAdminToast(
        !feature.isEnabled ? "Feature enabled." : "Feature disabled.",
        "success",
      );
      await refresh();
    } catch (error) {
      await handleMutationFailure(error);
    } finally {
      setSaving(false);
    }
  }

  async function saveDraftFeature() {
    if (client == null || draftFeature == null || mutationLocked) return;

    let dependencyRules: Record<string, unknown>;
    try {
      dependencyRules = parseJsonObject(dependencyRulesText);
      setJsonError(null);
    } catch {
      setJsonError("Enter a valid JSON object before saving.");
      return;
    }

    setSaving(true);
    try {
      const rules = draftFeature.rules ?? emptyRules;
      await updateAdminFeature(
        client,
        access,
        draftFeature.id,
        draftFeature.updatedAt,
        {
          displayName: draftFeature.displayName,
          description: draftFeature.description,
          category: draftFeature.category,
          isEnabled: draftFeature.isEnabled,
          visibilityState: draftFeature.visibilityState,
          channels: draftFeature.channels.map((channel) => ({
            channel: channel.channel,
            isEnabled: channel.isEnabled,
            isVisible: channel.isVisible,
            showInNavigation: channel.showInNavigation,
            showOnHome: channel.showOnHome,
            sortOrder: channel.sortOrder,
            routeKey: channel.routeKey,
            placementKey: channel.placementKey,
          })),
          rules: {
            authRequired: rules.authRequired,
            roleRestrictions: rules.roleRestrictions,
            dependencyRules,
            rolloutRules: rules.rolloutRules,
            metadata: rules.metadata,
            scheduleStartAt: rules.scheduleStartAt,
            scheduleEndAt: rules.scheduleEndAt,
          },
        },
      );
      showAdminToast("Feature settings saved.", "success");
      closeDrawer();
      await refresh();
    } catch (error) {
      await handleMutationFailure(error);
    } finally {
      setSaving(false);
    }
  }

  const metricValue = (value: number) =>
    hasConfirmed ? value.toString() : "—";

  return (
    <div
      className="admin-features-state-surface section-grid min-w-0 w-full max-w-full overflow-x-hidden !gap-6"
      data-admin-features-status={status}
      data-admin-features-interaction={interaction}
      data-admin-features-refresh-disabled={busy}
      data-admin-features-mutation-locked={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Configuration"
        title="Feature flags"
        meta={
          <span className="admin-meta-chip">
            <Server size={12} className="mr-1 inline" aria-hidden="true" />
            Latest 500 bounded controls
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh feature registry"
        selected={interaction === "selected"}
        onRefresh={() => {
          void refresh();
        }}
        onInteractionChange={setInteraction}
      />

      <div className="admin-features-metrics-grid grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="Total features"
          value={metricValue(features.length)}
          icon={Settings2}
          helper={
            hasConfirmed
              ? "Confirmed for the active scope"
              : "Awaiting confirmation"
          }
        />
        <AdminStateCard
          label="Enabled"
          value={metricValue(
            features.filter((feature) => feature.isEnabled).length,
          )}
          icon={Zap}
          helper="Enabled in the resolved scope"
        />
        <AdminStateCard
          label="Restricted"
          value={metricValue(
            features.filter(
              (feature) =>
                !feature.isEnabled || feature.visibilityState !== "visible",
            ).length,
          )}
          icon={ShieldCheck}
          helper="Disabled, hidden, or in maintenance"
        />
      </div>

      {!unrecoveredFailure ? (
        <section className="grid min-w-0 gap-4" aria-label="Feature controls">
          <div className="relative max-w-md">
            <Search
              size={16}
              aria-hidden="true"
              className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[var(--admin-secondary)]"
            />
            <input
              type="search"
              value={filter}
              disabled={busy && !hasConfirmed}
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction(filter ? "selected" : "idle")}
              onChange={(event) => {
                setFilter(event.target.value);
                setPage(1);
                setInteraction(event.target.value ? "selected" : "focused");
              }}
              placeholder="Search feature, scope, category, or state"
              aria-label="Search platform features"
              className="admin-input min-h-12 w-full !pl-11"
            />
          </div>

          <div className="admin-surface min-w-0">
            <AdminDataGrid
              caption="Platform feature controls"
              busy={busy}
              onRowActivate={(rowId) => {
                const feature = features.find((item) => item.id === rowId);
                if (feature) beginEdit(feature);
              }}
              columns={[
                {
                  key: "feature",
                  label: "Feature module",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortKey === "feature" ? sortDirection : "none",
                  onSort: () => changeSort("feature"),
                },
                {
                  key: "scope",
                  label: "Scope",
                  priority: "secondary",
                  sortable: true,
                  sortDirection: sortKey === "scope" ? sortDirection : "none",
                  onSort: () => changeSort("scope"),
                },
                {
                  key: "category",
                  label: "Category",
                  priority: "secondary",
                  sortable: true,
                  sortDirection:
                    sortKey === "category" ? sortDirection : "none",
                  onSort: () => changeSort("category"),
                },
                {
                  key: "status",
                  label: "Resolved state",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortKey === "status" ? sortDirection : "none",
                  onSort: () => changeSort("status"),
                },
                {
                  key: "mobile",
                  label: "Mobile",
                  priority: "tertiary",
                  className: "text-center",
                },
                {
                  key: "web",
                  label: "Website",
                  priority: "tertiary",
                  className: "text-center",
                },
                {
                  key: "actions",
                  label: "Actions",
                  priority: "primary",
                  className: "text-right",
                },
              ]}
            >
              {initialLoading ? (
                Array.from({ length: 8 }).map((_, index) => (
                  <tr key={index}>
                    <td colSpan={7} className="p-4">
                      <Skeleton className="skeleton-text h-4 w-full" />
                    </td>
                  </tr>
                ))
              ) : featurePage.items.length === 0 ? (
                <tr>
                  <td
                    colSpan={7}
                    className="p-12 text-center text-sm text-[var(--admin-secondary)]"
                  >
                    {filter
                      ? "No features match the current search."
                      : "No platform features are available for this scope."}
                  </td>
                </tr>
              ) : (
                featurePage.items.map((feature) => {
                  const mobileChannel = feature.channels.find(
                    (channel) => channel.channel === "mobile",
                  );
                  const webChannel = feature.channels.find(
                    (channel) => channel.channel === "web",
                  );
                  return (
                    <tr key={feature.id} data-row-id={feature.id}>
                      <td>
                        <p className="admin-row-title">{feature.displayName}</p>
                        <p className="admin-row-meta">
                          {feature.description || feature.featureKey}
                        </p>
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={
                            feature.scope === "club"
                              ? "Club override"
                              : "Global"
                          }
                          tone={feature.scope === "club" ? "info" : "neutral"}
                        />
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={feature.category || "Uncategorised"}
                          tone="neutral"
                        />
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={
                            !feature.isEnabled
                              ? "Disabled"
                              : feature.visibilityState === "maintenance"
                                ? "Maintenance"
                                : feature.visibilityState === "hidden"
                                  ? "Hidden"
                                  : "Active"
                          }
                          tone={
                            !feature.isEnabled
                              ? "danger"
                              : feature.visibilityState === "visible"
                                ? "success"
                                : "warning"
                          }
                        />
                      </td>
                      <td className="text-center">
                        <ChannelState
                          channel="Mobile"
                          enabled={mobileChannel?.isEnabled === true}
                        />
                      </td>
                      <td className="text-center">
                        <ChannelState
                          channel="Website"
                          enabled={webChannel?.isEnabled === true}
                        />
                      </td>
                      <td className="text-right">
                        <div className="flex flex-wrap justify-end gap-2">
                          {canEdit ? (
                            <button
                              type="button"
                              disabled={mutationLocked}
                              onClick={() => {
                                void toggleFeatureEnabled(feature);
                              }}
                              className={`admin-action-button min-h-12 disabled:cursor-not-allowed disabled:opacity-60 ${
                                feature.isEnabled
                                  ? "!bg-error/10 !text-error"
                                  : "!bg-success/10 !text-success"
                              }`}
                              aria-label={`${feature.isEnabled ? "Disable" : "Enable"} ${feature.displayName}`}
                            >
                              {feature.isEnabled ? "Disable" : "Enable"}
                            </button>
                          ) : null}
                          <button
                            type="button"
                            onClick={() => beginEdit(feature)}
                            className="admin-action-button min-h-12"
                            aria-label={`${canEdit ? "Configure" : "View"} ${feature.displayName}`}
                          >
                            {canEdit ? "Configure" : "View"}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </AdminDataGrid>
            <AdminPagination
              page={featurePage}
              onPageChange={setPage}
              label="Platform features"
            />
          </div>
        </section>
      ) : null}

      {draftFeature && hasConfirmed && status !== "permission_denied" ? (
        <AdminActionDrawer
          isOpen={drawerOpen}
          onClose={closeDrawer}
          title={`${canEdit ? "Configure" : "View"} ${draftFeature.displayName}`}
        >
          <div className="space-y-6 p-4">
            {!canEdit ? (
              <p className="rounded-2xl border border-warning/30 bg-warning/10 p-4 text-sm leading-6 text-[var(--admin-text-strong)]">
                This role has read-only access to feature configuration.
              </p>
            ) : null}
            <fieldset
              disabled={!canEdit || saving}
              className="space-y-6 disabled:opacity-70"
            >
              <div className="grid gap-4">
                <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                  Display name
                  <input
                    value={draftFeature.displayName}
                    maxLength={120}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        displayName: event.target.value,
                      })
                    }
                    className="admin-input min-h-12"
                  />
                </label>
                <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                  Description
                  <textarea
                    value={draftFeature.description ?? ""}
                    maxLength={1_000}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        description: event.target.value || null,
                      })
                    }
                    className="admin-input min-h-24"
                  />
                </label>
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                    Category
                    <input
                      value={draftFeature.category ?? ""}
                      maxLength={64}
                      onChange={(event) =>
                        setDraftFeature({
                          ...draftFeature,
                          category: event.target.value || null,
                        })
                      }
                      className="admin-input min-h-12"
                    />
                  </label>
                  <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                    Visibility state
                    <select
                      value={draftFeature.visibilityState}
                      onChange={(event) =>
                        setDraftFeature({
                          ...draftFeature,
                          visibilityState: event.target
                            .value as PlatformFeature["visibilityState"],
                        })
                      }
                      className="admin-input min-h-12"
                    >
                      <option value="visible">Visible</option>
                      <option value="hidden">Hidden</option>
                      <option value="maintenance">Maintenance</option>
                    </select>
                  </label>
                </div>
                <label className="flex min-h-12 items-center gap-3 rounded-[20px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-3">
                  <input
                    type="checkbox"
                    checked={draftFeature.isEnabled}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        isEnabled: event.target.checked,
                      })
                    }
                    className="h-5 w-5 accent-action-neutral"
                  />
                  <span className="text-sm font-semibold text-[var(--admin-text-strong)]">
                    Feature enabled in this resolved scope
                  </span>
                </label>
              </div>

              <section className="ui-panel rounded-[24px] border border-[var(--admin-border)] p-4">
                <h3 className="mb-4 text-xs font-medium normal-case tracking-normal text-[var(--admin-secondary)]">
                  Channel settings
                </h3>
                <div className="space-y-4">
                  {draftFeature.channels.map((channel, index) => (
                    <div
                      key={channel.channel}
                      className="grid gap-4 rounded-[20px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] p-4"
                    >
                      <div className="flex flex-wrap items-center justify-between gap-4">
                        <p className="text-sm font-semibold normal-case text-[var(--admin-text-strong)]">
                          {channel.channel}
                        </p>
                        <div className="flex flex-wrap gap-4 text-xs text-[var(--admin-secondary)]">
                          {[
                            ["isEnabled", "Enabled"],
                            ["isVisible", "Visible"],
                            ["showInNavigation", "Navigation"],
                            ["showOnHome", "Home"],
                          ].map(([key, label]) => (
                            <label
                              key={key}
                              className="flex min-h-12 items-center gap-2"
                            >
                              <input
                                type="checkbox"
                                checked={
                                  channel[
                                    key as
                                      | "isEnabled"
                                      | "isVisible"
                                      | "showInNavigation"
                                      | "showOnHome"
                                  ]
                                }
                                onChange={(event) =>
                                  setDraftFeature({
                                    ...draftFeature,
                                    channels: draftFeature.channels.map(
                                      (entry, entryIndex) =>
                                        entryIndex === index
                                          ? {
                                              ...entry,
                                              [key]: event.target.checked,
                                            }
                                          : entry,
                                    ),
                                  })
                                }
                                className="h-5 w-5 accent-action-neutral"
                              />
                              {label}
                            </label>
                          ))}
                        </div>
                      </div>
                      <div className="grid gap-4 md:grid-cols-3">
                        <label className="grid gap-2 text-xs font-semibold normal-case tracking-normal text-[var(--admin-secondary)]">
                          Sort order
                          <input
                            type="number"
                            min={-10_000}
                            max={10_000}
                            value={channel.sortOrder ?? ""}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map(
                                  (entry, entryIndex) =>
                                    entryIndex === index
                                      ? {
                                          ...entry,
                                          sortOrder:
                                            event.target.value.length === 0
                                              ? null
                                              : Number(event.target.value),
                                        }
                                      : entry,
                                ),
                              })
                            }
                            className="admin-input min-h-12"
                          />
                        </label>
                        <label className="grid gap-2 text-xs font-semibold normal-case tracking-normal text-[var(--admin-secondary)]">
                          Route key
                          <input
                            value={channel.routeKey ?? ""}
                            maxLength={256}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map(
                                  (entry, entryIndex) =>
                                    entryIndex === index
                                      ? {
                                          ...entry,
                                          routeKey: event.target.value || null,
                                        }
                                      : entry,
                                ),
                              })
                            }
                            className="admin-input min-h-12"
                          />
                        </label>
                        <label className="grid gap-2 text-xs font-semibold normal-case tracking-normal text-[var(--admin-secondary)]">
                          Placement key
                          <input
                            value={channel.placementKey ?? ""}
                            maxLength={128}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map(
                                  (entry, entryIndex) =>
                                    entryIndex === index
                                      ? {
                                          ...entry,
                                          placementKey:
                                            event.target.value || null,
                                        }
                                      : entry,
                                ),
                              })
                            }
                            className="admin-input min-h-12"
                          />
                        </label>
                      </div>
                    </div>
                  ))}
                </div>
              </section>

              <section className="ui-panel rounded-[24px] border border-[var(--admin-border)] p-4">
                <h3 className="mb-4 text-xs font-medium normal-case tracking-normal text-[var(--admin-secondary)]">
                  Access rules
                </h3>
                <div className="grid gap-4">
                  <label className="flex min-h-12 items-center gap-3 rounded-[20px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-3">
                    <input
                      type="checkbox"
                      checked={draftFeature.rules?.authRequired ?? false}
                      onChange={(event) =>
                        setDraftFeature({
                          ...draftFeature,
                          rules: {
                            ...(draftFeature.rules ?? emptyRules),
                            authRequired: event.target.checked,
                          },
                        })
                      }
                      className="h-5 w-5 accent-action-neutral"
                    />
                    <span className="text-sm font-semibold text-[var(--admin-text-strong)]">
                      Authentication required
                    </span>
                  </label>
                  <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                    Role restrictions
                    <input
                      value={(draftFeature.rules?.roleRestrictions ?? []).join(
                        ", ",
                      )}
                      onChange={(event) =>
                        setDraftFeature({
                          ...draftFeature,
                          rules: {
                            ...(draftFeature.rules ?? emptyRules),
                            roleRestrictions: event.target.value
                              .split(",")
                              .map((value) => value.trim())
                              .filter(Boolean),
                          },
                        })
                      }
                      className="admin-input min-h-12"
                      placeholder="member, vip"
                    />
                  </label>
                  <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                    Dependency rules JSON
                    <textarea
                      value={dependencyRulesText}
                      onChange={(event) => {
                        setDependencyRulesText(event.target.value);
                        setJsonError(null);
                      }}
                      aria-invalid={jsonError != null}
                      aria-describedby={
                        jsonError ? "feature-json-error" : undefined
                      }
                      spellCheck={false}
                      className="admin-input min-h-32 font-mono text-xs"
                    />
                  </label>
                  {jsonError ? (
                    <p
                      id="feature-json-error"
                      role="alert"
                      className="text-sm font-semibold text-error"
                    >
                      {jsonError}
                    </p>
                  ) : null}
                  <div className="grid gap-4 md:grid-cols-2">
                    <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                      Schedule start
                      <input
                        type="datetime-local"
                        value={toDateTimeLocalValue(
                          draftFeature.rules?.scheduleStartAt,
                        )}
                        onChange={(event) =>
                          setDraftFeature({
                            ...draftFeature,
                            rules: {
                              ...(draftFeature.rules ?? emptyRules),
                              scheduleStartAt: fromDateTimeLocalValue(
                                event.target.value,
                              ),
                            },
                          })
                        }
                        className="admin-input min-h-12"
                      />
                    </label>
                    <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                      Schedule end
                      <input
                        type="datetime-local"
                        value={toDateTimeLocalValue(
                          draftFeature.rules?.scheduleEndAt,
                        )}
                        onChange={(event) =>
                          setDraftFeature({
                            ...draftFeature,
                            rules: {
                              ...(draftFeature.rules ?? emptyRules),
                              scheduleEndAt: fromDateTimeLocalValue(
                                event.target.value,
                              ),
                            },
                          })
                        }
                        className="admin-input min-h-12"
                      />
                    </label>
                  </div>
                </div>
              </section>
            </fieldset>

            <div className="flex flex-wrap gap-3 border-t border-[var(--admin-border)] pt-4">
              {canEdit ? (
                <button
                  type="button"
                  onClick={() => {
                    void saveDraftFeature();
                  }}
                  disabled={mutationLocked}
                  className="admin-action-button min-h-12 flex-1 !bg-action-blue !text-white hover:!bg-action-blue-hover disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {saving ? "Saving…" : "Save feature"}
                </button>
              ) : null}
              <button
                type="button"
                onClick={closeDrawer}
                className="admin-action-button min-h-12 flex-1"
              >
                {canEdit ? "Cancel" : "Close"}
              </button>
            </div>
          </div>
        </AdminActionDrawer>
      ) : null}
    </div>
  );
}
