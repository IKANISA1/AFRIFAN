"use client";

import { useCallback, useEffect, useState } from "react";
import { Search, Server, Settings2, ShieldCheck, Zap } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { getAdminFeatures, updateAdminFeature } from "@/lib/data/admin/features";
import type { PlatformFeature } from "@/lib/types";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

function toDateTimeLocalValue(value: string | null | undefined) {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60_000)
    .toISOString()
    .slice(0, 16);
}

function fromDateTimeLocalValue(value: string) {
  return value.trim().length > 0 ? new Date(value).toISOString() : null;
}

function parseJsonValue<T extends Record<string, unknown>>(
  raw: string,
  fallback: T,
) {
  if (raw.trim().length === 0) {
    return fallback;
  }

  const parsed = JSON.parse(raw);
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Expected a JSON object.");
  }
  return parsed as T;
}

function createDraft(feature: PlatformFeature): PlatformFeature {
  return {
    ...feature,
    channels: feature.channels.map((channel) => ({ ...channel })),
    rules: feature.rules == null
      ? {
          authRequired: false,
          roleRestrictions: [],
          dependencyRules: {},
          rolloutRules: {},
          metadata: {},
          scheduleStartAt: null,
          scheduleEndAt: null,
        }
      : {
          ...feature.rules,
          roleRestrictions: [...feature.rules.roleRestrictions],
          dependencyRules: { ...feature.rules.dependencyRules },
          rolloutRules: { ...feature.rules.rolloutRules },
          metadata: { ...feature.rules.metadata },
        },
  };
}

export default function AdminFeaturesPage() {
  const { access, client } = useAdminPortal();
  const [features, setFeatures] = useState<PlatformFeature[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [draftFeature, setDraftFeature] = useState<PlatformFeature | null>(null);
  const [saving, setSaving] = useState(false);
  const featureCollection = useAdminCollection({
    records: features,
    getId: (feature) => feature.id,
    getSearchValues: (feature) => [
      feature.displayName,
      feature.description,
      feature.featureKey,
      feature.scope,
      feature.category,
      feature.visibilityState,
      feature.isEnabled ? "active enabled" : "disabled",
    ],
    getSortValue: (
      feature,
      key: "feature" | "scope" | "category" | "status",
    ) => {
      switch (key) {
        case "feature": return feature.displayName;
        case "scope": return feature.scope;
        case "category": return feature.category;
        case "status": return feature.isEnabled ? feature.visibilityState : "disabled";
      }
    },
    initialSortKey: "feature" as const,
    pageSize: 25,
  });

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setFeatures(await getAdminFeatures(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "Could not load features.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

  async function toggleFeatureEnabled(feature: PlatformFeature) {
    if (!client) return;
    try {
      await updateAdminFeature(client, access, feature.id, feature.updatedAt, {
        isEnabled: !feature.isEnabled,
      });
      showAdminToast(
        !feature.isEnabled ? "Feature enabled." : "Feature disabled.",
        "success",
      );
      await load();
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      showAdminToast(
        caught instanceof Error ? caught.message : "Failed to toggle feature.",
        "error",
      );
    }
  }

  function beginEdit(feature: PlatformFeature) {
    setDraftFeature(createDraft(feature));
    setDrawerOpen(true);
  }

  async function saveDraftFeature() {
    if (!client || draftFeature == null) {
      return;
    }

    setSaving(true);
    try {
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
          rules: draftFeature.rules == null
            ? undefined
            : {
                authRequired: draftFeature.rules.authRequired,
                roleRestrictions: draftFeature.rules.roleRestrictions,
                dependencyRules: draftFeature.rules.dependencyRules,
                rolloutRules: draftFeature.rules.rolloutRules,
                metadata: draftFeature.rules.metadata,
                scheduleStartAt: draftFeature.rules.scheduleStartAt,
                scheduleEndAt: draftFeature.rules.scheduleEndAt,
              },
        },
      );

      showAdminToast("Feature settings saved.", "success");
      setDrawerOpen(false);
      setDraftFeature(null);
      await load();
    } catch (error) {
      if (isAdminMutationConflict(error)) {
        await load();
      }
      showAdminToast(
        error instanceof Error ? error.message : "Could not save feature.",
        "error",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Configuration"
        title="Feature flags"
        meta={
          <span className="admin-meta-chip">
            <Server size={12} className="mr-1 inline" />
            Central source of truth
          </span>
        }
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="Total Features"
          value={loading ? "..." : features.length.toString()}
          icon={Settings2}
        />
        <AdminStateCard
          label="Enabled"
          value={
            loading ? "..." : features.filter((feature) => feature.isEnabled).length.toString()
          }
          icon={Zap}
          helper="Globally enabled features"
        />
        <AdminStateCard
          label="Hidden / Maintenance"
          value={
            loading
              ? "..."
              : features
                  .filter(
                    (feature) =>
                      !feature.isEnabled || feature.visibilityState !== "visible",
                  )
                  .length.toString()
          }
          icon={ShieldCheck}
          helper={
            features.some((feature) => !feature.isEnabled)
              ? "Includes disabled features"
              : "Visibility controlled per channel"
          }
        />
      </div>

      {loadError && !loading ? (
        <AdminErrorState
          title="Feature flags could not be loaded"
          description={loadError}
          onRetry={() => {
            load().catch(() => {});
          }}
        />
      ) : (
        <div className="admin-surface">
          <AdminFilterBar>
            <label className="admin-search-field">
              <Search size={16} aria-hidden="true" />
              <span className="sr-only">Search platform features</span>
              <input type="search" value={featureCollection.query} onChange={(event) => featureCollection.setQuery(event.target.value)} placeholder="Search feature, scope, category, or state" />
            </label>
          </AdminFilterBar>
          <AdminDataGrid
            caption="Platform feature controls"
            busy={loading}
            onRowActivate={(rowId) => {
              const feature = features.find((item) => item.id === rowId);
              if (feature) beginEdit(feature);
            }}
            columns={[
              { key: "feature", label: "Feature Module", priority: "primary", sortable: true, sortDirection: featureCollection.sortDirectionFor("feature"), onSort: () => featureCollection.toggleSort("feature") },
              { key: "scope", label: "Scope", priority: "secondary", sortable: true, sortDirection: featureCollection.sortDirectionFor("scope"), onSort: () => featureCollection.toggleSort("scope") },
              { key: "category", label: "Category", priority: "secondary", sortable: true, sortDirection: featureCollection.sortDirectionFor("category"), onSort: () => featureCollection.toggleSort("category") },
              { key: "status", label: "Global State", priority: "primary", sortable: true, sortDirection: featureCollection.sortDirectionFor("status"), onSort: () => featureCollection.toggleSort("status") },
              { key: "mobile", label: "Mobile", priority: "tertiary", className: "text-center" },
              { key: "web", label: "Website", priority: "tertiary", className: "text-center" },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
            {featureCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={7} className="py-8 text-center text-sm text-slate-400">{featureCollection.query ? "No features match the current search." : "No platform features found."}</td></tr>
            ) : featureCollection.pageResult.items.map((feature) => {
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
                    <p className="admin-row-meta">{feature.description || feature.featureKey}</p>
                  </td>
                  <td>
                    <AdminStatusBadge
                      label={feature.scope === "club" ? "Club override" : "Global"}
                      tone={feature.scope === "club" ? "info" : "neutral"}
                    />
                  </td>
                  <td>
                    <AdminStatusBadge label={feature.category || "core"} tone="neutral" />
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
                    {mobileChannel?.isEnabled ? (
                      <span className="font-bold text-emerald-400">✓</span>
                    ) : (
                      <span className="font-bold text-slate-500">✗</span>
                    )}
                  </td>
                  <td className="text-center">
                    {webChannel?.isEnabled ? (
                      <span className="font-bold text-emerald-400">✓</span>
                    ) : (
                      <span className="font-bold text-slate-500">✗</span>
                    )}
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => toggleFeatureEnabled(feature)}
                        className={`admin-action-button ${
                          feature.isEnabled
                            ? "!bg-rose-500/10 !text-rose-400"
                            : "!bg-emerald-500/10 !text-emerald-400"
                        }`}
                      >
                        {feature.isEnabled ? "Disable" : "Enable"}
                      </button>
                      <button
                        onClick={() => beginEdit(feature)}
                        className="admin-action-button"
                      >
                        Configure
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </AdminDataGrid>
          <AdminPagination page={featureCollection.pageResult} onPageChange={featureCollection.setPage} label="Platform features" />
        </div>
      )}

      {draftFeature && (
        <AdminActionDrawer
          isOpen={drawerOpen}
          onClose={() => {
            setDrawerOpen(false);
            setDraftFeature(null);
          }}
          title={`Configure ${draftFeature.displayName}`}
        >
          <div className="space-y-6 p-4">
            <div className="grid gap-4">
              <label className="grid gap-2 text-sm font-semibold text-white">
                Display name
                <input
                  value={draftFeature.displayName}
                  onChange={(event) =>
                    setDraftFeature({
                      ...draftFeature,
                      displayName: event.target.value,
                    })}
                  className="admin-input"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-white">
                Description
                <textarea
                  value={draftFeature.description ?? ""}
                  onChange={(event) =>
                    setDraftFeature({
                      ...draftFeature,
                      description: event.target.value || null,
                    })}
                  className="admin-input min-h-24"
                />
              </label>
              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-2 text-sm font-semibold text-white">
                  Category
                  <input
                    value={draftFeature.category ?? ""}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        category: event.target.value || null,
                      })}
                    className="admin-input"
                  />
                </label>
                <label className="grid gap-2 text-sm font-semibold text-white">
                  Visibility state
                  <select
                    value={draftFeature.visibilityState}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        visibilityState: event.target.value as PlatformFeature["visibilityState"],
                      })}
                    className="admin-input"
                  >
                    <option value="visible">Visible</option>
                    <option value="hidden">Hidden</option>
                    <option value="maintenance">Maintenance</option>
                  </select>
                </label>
              </div>
              <label className="flex items-center gap-3 rounded-[20px] border border-[var(--admin-border)] bg-white/5 px-4 py-3">
                <input
                  type="checkbox"
                  checked={draftFeature.isEnabled}
                  onChange={(event) =>
                    setDraftFeature({
                      ...draftFeature,
                      isEnabled: event.target.checked,
                    })}
                  className="accent-club-accent"
                />
                <span className="text-sm font-semibold text-white">
                  Feature enabled globally
                </span>
              </label>
            </div>

            <div className="glass-panel rounded-[24px] border border-[var(--admin-border)] p-4">
              <p className="mb-4 text-[10px] font-bold uppercase tracking-widest text-[var(--admin-zinc-500)]">
                Channel Settings
              </p>
              <div className="space-y-4">
                {draftFeature.channels.map((channel, index) => (
                  <div
                    key={channel.channel}
                    className="grid gap-4 rounded-[20px] border border-[var(--admin-border)] bg-white/5 p-4"
                  >
                    <div className="flex items-center justify-between">
                      <p className="text-sm font-semibold uppercase text-white">
                        {channel.channel}
                      </p>
                      <div className="flex flex-wrap gap-4 text-xs text-[var(--admin-zinc-400)]">
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            checked={channel.isEnabled}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map((entry, entryIndex) =>
                                  entryIndex === index
                                    ? { ...entry, isEnabled: event.target.checked }
                                    : entry,
                                ),
                              })}
                            className="accent-club-accent"
                          />
                          Enabled
                        </label>
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            checked={channel.isVisible}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map((entry, entryIndex) =>
                                  entryIndex === index
                                    ? { ...entry, isVisible: event.target.checked }
                                    : entry,
                                ),
                              })}
                            className="accent-club-accent"
                          />
                          Visible
                        </label>
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            checked={channel.showInNavigation}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map((entry, entryIndex) =>
                                  entryIndex === index
                                    ? {
                                        ...entry,
                                        showInNavigation: event.target.checked,
                                      }
                                    : entry,
                                ),
                              })}
                            className="accent-club-accent"
                          />
                          Navigation
                        </label>
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            checked={channel.showOnHome}
                            onChange={(event) =>
                              setDraftFeature({
                                ...draftFeature,
                                channels: draftFeature.channels.map((entry, entryIndex) =>
                                  entryIndex === index
                                    ? { ...entry, showOnHome: event.target.checked }
                                    : entry,
                                ),
                              })}
                            className="accent-club-accent"
                          />
                          Home
                        </label>
                      </div>
                    </div>
                    <div className="grid gap-4 md:grid-cols-3">
                      <label className="grid gap-2 text-xs font-semibold uppercase tracking-wider text-[var(--admin-zinc-400)]">
                        Sort order
                        <input
                          type="number"
                          value={channel.sortOrder ?? ""}
                          onChange={(event) =>
                            setDraftFeature({
                              ...draftFeature,
                              channels: draftFeature.channels.map((entry, entryIndex) =>
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
                            })}
                          className="admin-input"
                        />
                      </label>
                      <label className="grid gap-2 text-xs font-semibold uppercase tracking-wider text-[var(--admin-zinc-400)]">
                        Route key
                        <input
                          value={channel.routeKey ?? ""}
                          onChange={(event) =>
                            setDraftFeature({
                              ...draftFeature,
                              channels: draftFeature.channels.map((entry, entryIndex) =>
                                entryIndex === index
                                  ? { ...entry, routeKey: event.target.value || null }
                                  : entry,
                              ),
                            })}
                          className="admin-input"
                        />
                      </label>
                      <label className="grid gap-2 text-xs font-semibold uppercase tracking-wider text-[var(--admin-zinc-400)]">
                        Placement key
                        <input
                          value={channel.placementKey ?? ""}
                          onChange={(event) =>
                            setDraftFeature({
                              ...draftFeature,
                              channels: draftFeature.channels.map((entry, entryIndex) =>
                                entryIndex === index
                                  ? {
                                      ...entry,
                                      placementKey: event.target.value || null,
                                    }
                                  : entry,
                              ),
                            })}
                          className="admin-input"
                        />
                      </label>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="glass-panel rounded-[24px] border border-[var(--admin-border)] p-4">
              <p className="mb-4 text-[10px] font-bold uppercase tracking-widest text-[var(--admin-zinc-500)]">
                Access Rules
              </p>
              <div className="grid gap-4">
                <label className="flex items-center gap-3 rounded-[20px] border border-[var(--admin-border)] bg-white/5 px-4 py-3">
                  <input
                    type="checkbox"
                    checked={draftFeature.rules?.authRequired ?? false}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        rules: {
                          ...(draftFeature.rules ?? {
                            authRequired: false,
                            roleRestrictions: [],
                            dependencyRules: {},
                            rolloutRules: {},
                            metadata: {},
                            scheduleStartAt: null,
                            scheduleEndAt: null,
                          }),
                          authRequired: event.target.checked,
                        },
                      })}
                    className="accent-club-accent"
                  />
                  <span className="text-sm font-semibold text-white">
                    Authentication required
                  </span>
                </label>
                <label className="grid gap-2 text-sm font-semibold text-white">
                  Role restrictions
                  <input
                    value={(draftFeature.rules?.roleRestrictions ?? []).join(", ")}
                    onChange={(event) =>
                      setDraftFeature({
                        ...draftFeature,
                        rules: {
                          ...(draftFeature.rules ?? {
                            authRequired: false,
                            roleRestrictions: [],
                            dependencyRules: {},
                            rolloutRules: {},
                            metadata: {},
                            scheduleStartAt: null,
                            scheduleEndAt: null,
                          }),
                          roleRestrictions: event.target.value
                            .split(",")
                            .map((value) => value.trim())
                            .filter(Boolean),
                        },
                      })}
                    className="admin-input"
                    placeholder="admin, member, vip"
                  />
                </label>
                <label className="grid gap-2 text-sm font-semibold text-white">
                  Dependencies JSON
                  <textarea
                    value={JSON.stringify(draftFeature.rules?.dependencyRules ?? {}, null, 2)}
                    onChange={(event) => {
                      try {
                        const dependencyRules = parseJsonValue(
                          event.target.value,
                          {},
                        );
                        setDraftFeature({
                          ...draftFeature,
                          rules: {
                            ...(draftFeature.rules ?? {
                              authRequired: false,
                              roleRestrictions: [],
                              dependencyRules: {},
                              rolloutRules: {},
                              metadata: {},
                              scheduleStartAt: null,
                              scheduleEndAt: null,
                            }),
                            dependencyRules,
                          },
                        });
                      } catch {
                        // Keep draft untouched until valid JSON is entered.
                      }
                    }}
                    className="admin-input min-h-28 font-mono text-xs"
                  />
                </label>
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="grid gap-2 text-sm font-semibold text-white">
                    Schedule start
                    <input
                      type="datetime-local"
                      value={toDateTimeLocalValue(draftFeature.rules?.scheduleStartAt)}
                      onChange={(event) =>
                        setDraftFeature({
                          ...draftFeature,
                          rules: {
                            ...(draftFeature.rules ?? {
                              authRequired: false,
                              roleRestrictions: [],
                              dependencyRules: {},
                              rolloutRules: {},
                              metadata: {},
                              scheduleStartAt: null,
                              scheduleEndAt: null,
                            }),
                            scheduleStartAt: fromDateTimeLocalValue(event.target.value),
                          },
                        })}
                      className="admin-input"
                    />
                  </label>
                  <label className="grid gap-2 text-sm font-semibold text-white">
                    Schedule end
                    <input
                      type="datetime-local"
                      value={toDateTimeLocalValue(draftFeature.rules?.scheduleEndAt)}
                      onChange={(event) =>
                        setDraftFeature({
                          ...draftFeature,
                          rules: {
                            ...(draftFeature.rules ?? {
                              authRequired: false,
                              roleRestrictions: [],
                              dependencyRules: {},
                              rolloutRules: {},
                              metadata: {},
                              scheduleStartAt: null,
                              scheduleEndAt: null,
                            }),
                            scheduleEndAt: fromDateTimeLocalValue(event.target.value),
                          },
                        })}
                      className="admin-input"
                    />
                  </label>
                </div>
              </div>
            </div>

            <div className="flex gap-3 border-t border-[var(--admin-border)] pt-4">
              <button
                type="button"
                onClick={saveDraftFeature}
                disabled={saving}
                className="admin-action-button flex-1 !bg-club-accent !text-white disabled:opacity-60"
              >
                {saving ? "Saving..." : "Save feature"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setDrawerOpen(false);
                  setDraftFeature(null);
                }}
                className="admin-action-button flex-1"
              >
                Cancel
              </button>
            </div>
          </div>
        </AdminActionDrawer>
      )}
    </div>
  );
}
