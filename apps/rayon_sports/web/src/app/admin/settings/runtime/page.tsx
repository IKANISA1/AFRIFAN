"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Database,
  FileText,
  ListTree,
  Map,
  Navigation,
  Save,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
} from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminPlatformOptionSet,
  deleteAdminPlatformOptionValue,
  deleteAdminPlatformRoute,
  deleteAdminRuntimeCopyEntry,
  deleteAdminSiteNavigationItem,
  deleteAdminSiteSearchItem,
  deleteAdminVenueGovernanceControl,
  getAdminRuntimeRegistrySnapshot,
  saveAdminPlatformOptionSet,
  saveAdminPlatformOptionValue,
  saveAdminPlatformRoute,
  saveAdminRuntimeCopyEntry,
  saveAdminSiteNavigationItem,
  saveAdminSiteSearchItem,
  saveAdminVenueGovernanceControl,
} from "@/lib/data/admin/runtime-registries";
import type {
  AdminAccess,
  AdminPlatformOptionSet,
  AdminPlatformOptionValue,
  AdminPlatformRoute,
  AdminRuntimeCopyEntry,
  AdminRuntimeRegistrySnapshot,
  AdminSiteNavigationItem,
  AdminSiteSearchItem,
  AdminVenueGovernanceControl,
} from "@/lib/types";
import { cn } from "@/lib/utils";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

type RuntimeResourceKey =
  | "routes"
  | "optionSets"
  | "optionValues"
  | "runtimeCopy"
  | "navigation"
  | "search"
  | "venueControls";

type EditableRuntimeRecord =
  | AdminPlatformRoute
  | AdminPlatformOptionSet
  | AdminPlatformOptionValue
  | AdminRuntimeCopyEntry
  | AdminSiteNavigationItem
  | AdminSiteSearchItem
  | AdminVenueGovernanceControl;

type RuntimeResourceDefinition = {
  key: RuntimeResourceKey;
  label: string;
  icon: typeof Database;
  rows: (snapshot: AdminRuntimeRegistrySnapshot) => EditableRuntimeRecord[];
  emptyDraft: (access: AdminAccess) => Record<string, unknown>;
  save: (
    client: Parameters<typeof saveAdminPlatformRoute>[0],
    access: AdminAccess,
    input: never,
  ) => Promise<unknown>;
  delete: (
    client: Parameters<typeof saveAdminPlatformRoute>[0],
    access: AdminAccess,
    id: string,
    expectedUpdatedAt: string,
  ) => Promise<unknown>;
};

const runtimeResources: RuntimeResourceDefinition[] = [
  {
    key: "routes",
    label: "Routes",
    icon: Map,
    rows: (snapshot) => snapshot.routes,
    emptyDraft: (access) => ({
      scope: access.isSuperAdmin ? "global" : "club",
      routeKey: "",
      pathPattern: "/",
      surface: "mobile",
      featureKey: "",
      label: "",
      authRequired: false,
      requiredRoles: [],
      presentation: "screen",
      showInNavigation: false,
      showOnHome: false,
      sortOrder: 0,
      isActive: true,
      metadata: {},
    }),
    save: saveAdminPlatformRoute as RuntimeResourceDefinition["save"],
    delete: deleteAdminPlatformRoute,
  },
  {
    key: "optionSets",
    label: "Option Sets",
    icon: SlidersHorizontal,
    rows: (snapshot) => snapshot.optionSets,
    emptyDraft: (access) => ({
      scope: access.isSuperAdmin ? "global" : "club",
      optionSetKey: "",
      label: "",
      description: "",
      valueType: "text",
      surface: "both",
      isActive: true,
      metadata: {},
    }),
    save: saveAdminPlatformOptionSet as RuntimeResourceDefinition["save"],
    delete: deleteAdminPlatformOptionSet,
  },
  {
    key: "optionValues",
    label: "Option Values",
    icon: ListTree,
    rows: (snapshot) => snapshot.optionValues,
    emptyDraft: () => ({
      optionSetId: "",
      optionKey: "",
      label: "",
      value: "",
      sortOrder: 0,
      isDefault: false,
      isActive: true,
      metadata: {},
    }),
    save: saveAdminPlatformOptionValue as RuntimeResourceDefinition["save"],
    delete: deleteAdminPlatformOptionValue,
  },
  {
    key: "runtimeCopy",
    label: "Runtime Copy",
    icon: FileText,
    rows: (snapshot) => snapshot.runtimeCopy,
    emptyDraft: (access) => ({
      scope: access.isSuperAdmin ? "global" : "club",
      copyKey: "",
      surface: "both",
      locale: "en",
      textValue: "",
      description: "",
      isActive: true,
      metadata: {},
    }),
    save: saveAdminRuntimeCopyEntry as RuntimeResourceDefinition["save"],
    delete: deleteAdminRuntimeCopyEntry,
  },
  {
    key: "navigation",
    label: "Navigation",
    icon: Navigation,
    rows: (snapshot) => snapshot.navigation,
    emptyDraft: (access) => ({
      scope: access.isSuperAdmin ? "global" : "club",
      navKey: "",
      label: "",
      href: "/",
      navGroup: "primary",
      surface: "web",
      featureKey: "",
      sortOrder: 0,
      isActive: true,
      metadata: {},
    }),
    save: saveAdminSiteNavigationItem as RuntimeResourceDefinition["save"],
    delete: deleteAdminSiteNavigationItem,
  },
  {
    key: "search",
    label: "Search",
    icon: Search,
    rows: (snapshot) => snapshot.search,
    emptyDraft: (access) => ({
      scope: access.isSuperAdmin ? "global" : "club",
      searchKey: "",
      title: "",
      description: "",
      href: "/",
      category: "Page",
      metaLabel: "",
      surface: "web",
      featureKey: "",
      sortOrder: 0,
      isActive: true,
      metadata: {},
    }),
    save: saveAdminSiteSearchItem as RuntimeResourceDefinition["save"],
    delete: deleteAdminSiteSearchItem,
  },
  {
    key: "venueControls",
    label: "Venue Controls",
    icon: ShieldCheck,
    rows: (snapshot) => snapshot.venueControls,
    emptyDraft: (access) => ({
      scope: access.isSuperAdmin ? "global" : "club",
      controlKey: "",
      label: "",
      detail: "",
      statusLabel: "review_required",
      actionLabel: "",
      controlGroup: "general",
      venueId: "",
      sortOrder: 0,
      isActive: true,
      metadata: {},
    }),
    save: saveAdminVenueGovernanceControl as RuntimeResourceDefinition["save"],
    delete: deleteAdminVenueGovernanceControl,
  },
];

function cleanRecord(record: EditableRuntimeRecord | Record<string, unknown>) {
  const { createdAt: _createdAt, updatedAt, ...editable } = record as Record<string, unknown>;
  return {
    ...editable,
    expectedUpdatedAt: updatedAt,
  };
}

function recordTitle(record: EditableRuntimeRecord) {
  if ("routeKey" in record) return record.routeKey;
  if ("optionSetKey" in record) return record.optionSetKey;
  if ("optionKey" in record) return record.optionKey;
  if ("copyKey" in record) return record.copyKey;
  if ("navKey" in record) return record.navKey;
  if ("searchKey" in record) return record.searchKey;
  return record.controlKey;
}

function recordSubtitle(record: EditableRuntimeRecord) {
  if ("pathPattern" in record) return record.pathPattern;
  if ("textValue" in record) return record.textValue;
  if ("href" in record) return record.href;
  if ("detail" in record) return record.detail;
  if ("optionSetId" in record) return record.optionSetId;
  return record.id;
}

function parseEditorJson(value: string) {
  const parsed = JSON.parse(value) as unknown;
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("The editor must contain one JSON object.");
  }
  return parsed as Record<string, unknown>;
}

export default function AdminRuntimeSettingsPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState<AdminRuntimeRegistrySnapshot | null>(null);
  const [activeKey, setActiveKey] = useState<RuntimeResourceKey>("routes");
  const [editorValue, setEditorValue] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  const activeResource = useMemo(
    () => runtimeResources.find((resource) => resource.key === activeKey) ?? runtimeResources[0],
    [activeKey],
  );

  const activeRows = useMemo(
    () => (snapshot == null ? [] : activeResource.rows(snapshot)),
    [activeResource, snapshot],
  );
  const rowCollection = useAdminCollection({
    records: activeRows,
    getId: (record) => record.id,
    getSearchValues: (record) => [
      recordTitle(record),
      recordSubtitle(record),
      "scope" in record ? record.scope : null,
      record.isActive ? "active" : "inactive",
      JSON.stringify(record.metadata ?? {}),
    ],
    getSortValue: (
      record,
      key: "title" | "subtitle" | "scope" | "status",
    ) => {
      switch (key) {
        case "title": return recordTitle(record);
        case "subtitle": return recordSubtitle(record);
        case "scope": return "scope" in record ? record.scope : "";
        case "status": return record.isActive;
      }
    },
    initialSortKey: "title" as const,
    pageSize: 25,
  });

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const nextSnapshot = await getAdminRuntimeRegistrySnapshot(client, access);
      setSnapshot(nextSnapshot);
      setLoadError(null);
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      const message =
        caught instanceof Error ? caught.message : "Could not load runtime registries.";
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

  useEffect(() => {
    setEditorValue(
      JSON.stringify(activeResource.emptyDraft(access), null, 2),
    );
  }, [access, activeResource]);

  async function saveEditorRecord() {
    if (client == null || saving) return;
    setSaving(true);
    try {
      const parsed = parseEditorJson(editorValue);
      await activeResource.save(client, access, parsed as never);
      showAdminToast(`${activeResource.label} record saved.`, "success");
      await load();
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save runtime record.",
        "error",
      );
    } finally {
      setSaving(false);
    }
  }

  async function deleteEditorRecord() {
    if (client == null || saving) return;
    try {
      const parsed = parseEditorJson(editorValue);
      const id = typeof parsed.id === "string" ? parsed.id.trim() : "";
      const expectedUpdatedAt =
        typeof parsed.expectedUpdatedAt === "string"
          ? parsed.expectedUpdatedAt.trim()
          : "";
      if (!id) {
        throw new Error("Record id is required for delete.");
      }
      if (!confirmAdminDestructiveAction({
        action: "Delete",
        subject: `${activeResource.label} record ${id}`,
        scope: access.isSuperAdmin
          ? "Selected platform or club runtime scope"
          : `Active club ${access.clubId ?? "not selected"}`,
        impact: "The runtime registry record will stop governing the connected app surfaces.",
        undo: "not_available",
      })) {
        return;
      }
      setSaving(true);
      await activeResource.delete(
        client,
        access,
        id,
        expectedUpdatedAt,
      );
      showAdminToast(`${activeResource.label} record deleted.`, "success");
      setEditorValue(JSON.stringify(activeResource.emptyDraft(access), null, 2));
      await load();
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not delete runtime record.",
        "error",
      );
    } finally {
      setSaving(false);
    }
  }

  const totalRecords = snapshot == null
    ? 0
    : runtimeResources.reduce(
        (total, resource) => total + resource.rows(snapshot).length,
        0,
      );
  const activeRecords = snapshot == null
    ? 0
    : runtimeResources.reduce(
        (total, resource) =>
          total + resource.rows(snapshot).filter((row) => row.isActive).length,
        0,
      );

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Configuration"
        title="Runtime Registries"
        meta={
          <span className="admin-meta-chip">
            <Database size={12} className="mr-1 inline" />
            Supabase managed
          </span>
        }
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Collections"
          value={runtimeResources.length.toString()}
          icon={Database}
        />
        <AdminStateCard
          label="Records"
          value={loading ? "..." : totalRecords.toString()}
          icon={ListTree}
        />
        <AdminStateCard
          label="Active"
          value={loading ? "..." : activeRecords.toString()}
          icon={ShieldCheck}
        />
      </div>

      <div className="flex flex-wrap gap-2">
        {runtimeResources.map((resource) => {
          const Icon = resource.icon;
          return (
            <button
              key={resource.key}
              type="button"
              onClick={() => setActiveKey(resource.key)}
              className={cn(
                "flex items-center gap-2 rounded-full px-4 py-2 text-sm font-semibold transition",
                activeKey === resource.key
                  ? "bg-club-primary text-white"
                  : "border border-border-soft bg-white/5 text-slate-300 hover:bg-white/8",
              )}
            >
              <Icon size={16} />
              {resource.label}
            </button>
          );
        })}
      </div>

      {loadError && !loading ? (
        <AdminErrorState
          title="Runtime registries could not be loaded"
          description={loadError}
          onRetry={() => {
            load().catch(() => {});
          }}
        />
      ) : (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(420px,0.8fr)]">
          <section className="admin-surface">
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 className="admin-section-title">{activeResource.label}</h2>
                <p className="admin-row-meta">
                  {loading ? "Loading" : `${activeRows.length} records`}
                </p>
              </div>
              <button
                type="button"
                onClick={() =>
                  setEditorValue(
                    JSON.stringify(activeResource.emptyDraft(access), null, 2),
                  )
                }
                className="admin-secondary-button"
              >
                New
              </button>
            </div>
            <AdminFilterBar>
              <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search {activeResource.label}</span><input type="search" value={rowCollection.query} onChange={(event) => rowCollection.setQuery(event.target.value)} placeholder={`Search ${activeResource.label.toLowerCase()}, scope, or state`} /></label>
              {(["title", "subtitle", "scope", "status"] as const).map((key) => <button key={key} type="button" data-active={rowCollection.sortKey === key} onClick={() => rowCollection.toggleSort(key)} className="dashboard-chip">Sort {key}</button>)}
            </AdminFilterBar>

            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 5 }).map((_, index) => (
                  <div
                    key={index}
                    className="rounded-[22px] border border-border-soft bg-white/5 p-4"
                  >
                    <Skeleton className="skeleton-text h-5 w-1/3" />
                  </div>
                ))}
              </div>
            ) : (
              <div className="divide-y divide-border-soft overflow-hidden rounded-[22px] border border-border-soft">
                {rowCollection.pageResult.items.length === 0 ? (
                  <div className="p-5 text-sm text-slate-300">{rowCollection.query ? "No records match the current search." : "No records."}</div>
                ) : (
                  rowCollection.pageResult.items.map((record) => (
                    <button
                      key={record.id}
                      type="button"
                      onClick={() =>
                        setEditorValue(JSON.stringify(cleanRecord(record), null, 2))
                      }
                      className="grid w-full gap-3 bg-white/[0.03] p-4 text-left transition hover:bg-white/[0.07] md:grid-cols-[minmax(0,1fr)_auto_auto]"
                    >
                      <div className="min-w-0">
                        <p className="admin-row-title">{recordTitle(record)}</p>
                        <p className="admin-row-meta truncate">
                          {recordSubtitle(record)}
                        </p>
                      </div>
                      {"scope" in record ? (
                        <AdminStatusBadge
                          label={record.scope}
                          tone={record.scope === "global" ? "accent" : "info"}
                        />
                      ) : null}
                      <AdminStatusBadge
                        label={record.isActive ? "Active" : "Inactive"}
                        tone={record.isActive ? "success" : "neutral"}
                      />
                    </button>
                  ))
                )}
              </div>
            )}
            <AdminPagination page={rowCollection.pageResult} onPageChange={rowCollection.setPage} label={activeResource.label} />
          </section>

          <section className="admin-surface">
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 className="admin-section-title">Record</h2>
                <p className="admin-row-meta">{activeResource.label}</p>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => {
                    deleteEditorRecord().catch(() => {});
                  }}
                  disabled={saving}
                  className="admin-icon-button text-red-300 hover:text-red-100"
                  aria-label="Delete record"
                >
                  <Trash2 size={16} />
                </button>
                <button
                  type="button"
                  onClick={() => {
                    saveEditorRecord().catch(() => {});
                  }}
                  disabled={saving}
                  className="admin-primary-button"
                >
                  <Save size={16} />
                  Save
                </button>
              </div>
            </div>
            <textarea
              value={editorValue}
              onChange={(event) => setEditorValue(event.target.value)}
              spellCheck={false}
              className="min-h-[520px] w-full resize-y rounded-[22px] border border-border-soft bg-slate-950/80 p-4 font-mono text-sm leading-6 text-slate-100 outline-none transition focus:border-club-accent"
            />
          </section>
        </div>
      )}
    </div>
  );
}
