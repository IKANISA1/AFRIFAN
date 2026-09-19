"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
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
  getAdminRuntimeRegistrySnapshot,
  normalizeAdminRuntimeRegistrySnapshot,
  saveAdminPlatformOptionSet,
  saveAdminPlatformOptionValue,
  saveAdminPlatformRoute,
  saveAdminRuntimeCopyEntry,
  saveAdminSiteNavigationItem,
  saveAdminSiteSearchItem,
} from "@/lib/data/admin/runtime-registries";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import type {
  AdminAccess,
  AdminPlatformOptionSet,
  AdminPlatformOptionValue,
  AdminPlatformRoute,
  AdminRuntimeCopyEntry,
  AdminRuntimeRegistrySnapshot,
  AdminSiteNavigationItem,
  AdminSiteSearchItem,
} from "@/lib/types";
import { cn } from "@/lib/utils";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

type RuntimeResourceKey =
  | "routes"
  | "optionSets"
  | "optionValues"
  | "runtimeCopy"
  | "navigation"
  | "search";

type EditableRuntimeRecord =
  | AdminPlatformRoute
  | AdminPlatformOptionSet
  | AdminPlatformOptionValue
  | AdminRuntimeCopyEntry
  | AdminSiteNavigationItem
  | AdminSiteSearchItem;

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
];

function cleanRecord(record: EditableRuntimeRecord | Record<string, unknown>) {
  const {
    createdAt: _createdAt,
    updatedAt,
    ...editable
  } = record as Record<string, unknown>;
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
  return record.searchKey;
}

function recordSubtitle(record: EditableRuntimeRecord) {
  if ("pathPattern" in record) return record.pathPattern;
  if ("textValue" in record) return record.textValue;
  if ("href" in record) return record.href;
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

const emptySnapshot: AdminRuntimeRegistrySnapshot = {
  routes: [],
  optionSets: [],
  optionValues: [],
  runtimeCopy: [],
  navigation: [],
  search: [],
};

const runtimeSnapshotIsEmpty = (snapshot: AdminRuntimeRegistrySnapshot) =>
  runtimeResources.every((resource) => resource.rows(snapshot).length === 0);

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading runtime registries",
    detail: "Waiting for the first authenticated, scope-confirmed snapshot.",
  },
  ready: {
    label: "Runtime registries confirmed",
    detail: "The latest bounded controls are ready for review.",
  },
  empty: {
    label: "No runtime records in this scope",
    detail: "The seven governed collections are confirmed empty.",
  },
  error: {
    label: "Runtime registries unavailable",
    detail:
      "Confirmed records remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Runtime registries are offline",
    detail: "Confirmed records remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "Runtime registry access denied",
    detail:
      "Records, filters, pagination, and editor content were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing runtime registries",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Runtime registry changed",
    detail: "Review the retained snapshot, then refresh before making changes.",
  },
  security_timeout: {
    label: "Runtime registry request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained records.",
  },
};

export default function AdminRuntimeSettingsPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [activeKey, setActiveKey] = useState<RuntimeResourceKey>("routes");
  const [editorValue, setEditorValue] = useState("");
  const [editorError, setEditorError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const clearPrivateStateRef = useRef<() => void>(() => {});

  const activeResource = useMemo(
    () =>
      runtimeResources.find((resource) => resource.key === activeKey) ??
      runtimeResources[0],
    [activeKey],
  );

  const loadSnapshot = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptySnapshot;
      return getAdminRuntimeRegistrySnapshot(client, access, { signal });
    },
    [access, client],
  );
  const clearPrivateState = useCallback(() => {
    clearPrivateStateRef.current();
  }, []);
  const {
    data: snapshot,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState<AdminRuntimeRegistrySnapshot>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptySnapshot,
    isEmpty: runtimeSnapshotIsEmpty,
    load: loadSnapshot,
    normalize: normalizeAdminRuntimeRegistrySnapshot,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "runtime registries",
  });

  const activeRows = useMemo(
    () => activeResource.rows(snapshot),
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
    getSortValue: (record, key: "title" | "subtitle" | "scope" | "status") => {
      switch (key) {
        case "title":
          return recordTitle(record);
        case "subtitle":
          return recordSubtitle(record);
        case "scope":
          return "scope" in record ? record.scope : "";
        case "status":
          return record.isActive;
      }
    },
    initialSortKey: "title" as const,
    pageSize: 25,
  });

  clearPrivateStateRef.current = () => {
    setActiveKey("routes");
    setEditorValue("");
    setEditorError(null);
    rowCollection.setQuery("");
    rowCollection.setPage(1);
    setInteraction("idle");
  };

  useEffect(() => {
    setEditorValue(JSON.stringify(activeResource.emptyDraft(access), null, 2));
    setEditorError(null);
  }, [access, activeResource]);

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

  async function handleMutationFailure(error: unknown) {
    const nextStatus = applyFailure(error);
    if (isAdminMutationConflict(error) || nextStatus === "conflict") {
      await refresh();
    }
    showAdminToast(statusCopy[nextStatus].label, "error");
  }

  async function saveEditorRecord() {
    if (client == null || mutationLocked) return;
    let parsed: Record<string, unknown>;
    try {
      parsed = parseEditorJson(editorValue);
      setEditorError(null);
    } catch {
      setEditorError("Enter one valid JSON object before saving.");
      return;
    }
    setSaving(true);
    try {
      await activeResource.save(client, access, parsed as never);
      showAdminToast(`${activeResource.label} record saved.`, "success");
      await refresh();
    } catch (error) {
      await handleMutationFailure(error);
    } finally {
      setSaving(false);
    }
  }

  async function deleteEditorRecord() {
    if (client == null || mutationLocked) return;
    let parsed: Record<string, unknown>;
    try {
      parsed = parseEditorJson(editorValue);
      setEditorError(null);
    } catch {
      setEditorError("Enter one valid JSON object before deleting.");
      return;
    }
    const id = typeof parsed.id === "string" ? parsed.id.trim() : "";
    const expectedUpdatedAt =
      typeof parsed.expectedUpdatedAt === "string"
        ? parsed.expectedUpdatedAt.trim()
        : "";
    if (!id || !expectedUpdatedAt) {
      setEditorError(
        "Select a confirmed record with an id and loaded version before deleting.",
      );
      return;
    }
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: `${activeResource.label} record ${id}`,
        scope: access.isSuperAdmin
          ? "Selected platform or club runtime scope"
          : `Active club ${access.clubId ?? "not selected"}`,
        impact:
          "The runtime registry record will stop governing the connected app surfaces.",
        undo: "not_available",
      })
    ) {
      return;
    }

    setSaving(true);
    try {
      await activeResource.delete(client, access, id, expectedUpdatedAt);
      showAdminToast(`${activeResource.label} record deleted.`, "success");
      setEditorValue(
        JSON.stringify(activeResource.emptyDraft(access), null, 2),
      );
      await refresh();
    } catch (error) {
      await handleMutationFailure(error);
    } finally {
      setSaving(false);
    }
  }

  const totalRecords = runtimeResources.reduce(
    (total, resource) => total + resource.rows(snapshot).length,
    0,
  );
  const activeRecords = runtimeResources.reduce(
    (total, resource) =>
      total + resource.rows(snapshot).filter((row) => row.isActive).length,
    0,
  );

  return (
    <div
      className="admin-runtime-state-surface section-grid min-w-0 max-w-full"
      data-admin-runtime-status={status}
      data-admin-runtime-interaction={interaction}
      data-admin-runtime-refresh-disabled={busy}
      data-admin-runtime-mutation-locked={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Configuration"
        title="Runtime registries"
        meta={
          <span className="admin-meta-chip">
            <Database size={12} className="mr-1 inline" aria-hidden="true" />7
            registries · 500 records each
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh runtime registries"
        selected={interaction === "selected"}
        onRefresh={() => {
          void refresh();
        }}
        onInteractionChange={setInteraction}
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Collections"
          value={runtimeResources.length.toString()}
          icon={Database}
        />
        <AdminStateCard
          label="Records"
          value={hasConfirmed ? totalRecords.toString() : "—"}
          icon={ListTree}
          helper={
            hasConfirmed ? "Confirmed bounded records" : "Awaiting confirmation"
          }
        />
        <AdminStateCard
          label="Active"
          value={hasConfirmed ? activeRecords.toString() : "—"}
          icon={ShieldCheck}
          helper="Active in the resolved scope"
        />
      </div>

      <div className="flex flex-wrap gap-2">
        {runtimeResources.map((resource) => {
          const Icon = resource.icon;
          return (
            <button
              key={resource.key}
              type="button"
              disabled={busy && !hasConfirmed}
              aria-pressed={activeKey === resource.key}
              onFocus={() => setInteraction("focused")}
              onBlur={() =>
                setInteraction(activeKey === resource.key ? "selected" : "idle")
              }
              onClick={() => {
                setActiveKey(resource.key);
                setInteraction("selected");
              }}
              className={cn(
                "flex min-h-12 items-center gap-2 rounded-full px-4 py-3 text-sm font-semibold transition motion-reduce:transition-none disabled:cursor-not-allowed disabled:opacity-60",
                activeKey === resource.key
                  ? "bg-club-primary text-white"
                  : "border border-border-soft bg-white/5 text-slate-300 hover:bg-white/8",
              )}
            >
              <Icon size={16} aria-hidden="true" />
              {resource.label}
            </button>
          );
        })}
      </div>

      {!unrecoveredFailure ? (
        <div className="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(420px,0.8fr)]">
          <section className="admin-surface min-w-0">
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 className="admin-section-title">{activeResource.label}</h2>
                <p className="admin-row-meta">
                  {hasConfirmed
                    ? `${activeRows.length} confirmed records`
                    : "Awaiting confirmation"}
                </p>
              </div>
              {canEdit ? (
                <button
                  type="button"
                  disabled={mutationLocked}
                  onClick={() => {
                    setEditorValue(
                      JSON.stringify(
                        activeResource.emptyDraft(access),
                        null,
                        2,
                      ),
                    );
                    setEditorError(null);
                    setInteraction("selected");
                  }}
                  className="admin-secondary-button min-h-12 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  New record
                </button>
              ) : null}
            </div>
            <AdminFilterBar>
              <label className="admin-search-field">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">Search {activeResource.label}</span>
                <input
                  type="search"
                  value={rowCollection.query}
                  disabled={busy && !hasConfirmed}
                  onFocus={() => setInteraction("focused")}
                  onBlur={() =>
                    setInteraction(rowCollection.query ? "selected" : "idle")
                  }
                  onChange={(event) => {
                    rowCollection.setQuery(event.target.value);
                    setInteraction(event.target.value ? "selected" : "focused");
                  }}
                  placeholder={`Search ${activeResource.label.toLowerCase()}, scope, or state`}
                />
              </label>
              {(["title", "subtitle", "scope", "status"] as const).map(
                (key) => (
                  <button
                    key={key}
                    type="button"
                    disabled={busy && !hasConfirmed}
                    data-active={rowCollection.sortKey === key}
                    onClick={() => rowCollection.toggleSort(key)}
                    className="dashboard-chip min-h-12 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    Sort {key}
                  </button>
                ),
              )}
            </AdminFilterBar>

            {initialLoading ? (
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
                  <div className="p-5 text-sm text-slate-300">
                    {rowCollection.query
                      ? "No records match the current search."
                      : "No records are available in this collection."}
                  </div>
                ) : (
                  rowCollection.pageResult.items.map((record) => (
                    <button
                      key={record.id}
                      type="button"
                      onFocus={() => setInteraction("focused")}
                      onBlur={() => setInteraction("selected")}
                      onClick={() => {
                        setEditorValue(
                          JSON.stringify(cleanRecord(record), null, 2),
                        );
                        setEditorError(null);
                        setInteraction("selected");
                      }}
                      className="grid min-h-12 w-full gap-3 bg-white/[0.03] p-4 text-left transition hover:bg-white/[0.07] motion-reduce:transition-none md:grid-cols-[minmax(0,1fr)_auto_auto]"
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
            <AdminPagination
              page={rowCollection.pageResult}
              onPageChange={rowCollection.setPage}
              label={activeResource.label}
            />
          </section>

          <section className="admin-surface min-w-0">
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 className="admin-section-title">
                  Structured record editor
                </h2>
                <p className="admin-row-meta">
                  {canEdit
                    ? `${activeResource.label} · bounded fields only`
                    : `${activeResource.label} · read-only`}
                </p>
              </div>
              {canEdit ? (
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      void deleteEditorRecord();
                    }}
                    disabled={mutationLocked}
                    className="admin-icon-button min-h-12 min-w-12 text-red-300 hover:text-red-100 disabled:cursor-not-allowed disabled:opacity-60"
                    aria-label="Delete selected runtime record"
                  >
                    <Trash2 size={16} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      void saveEditorRecord();
                    }}
                    disabled={mutationLocked}
                    className="admin-primary-button min-h-12 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <Save size={16} aria-hidden="true" />
                    {saving ? "Saving…" : "Save record"}
                  </button>
                </div>
              ) : null}
            </div>
            <p className="mb-3 text-sm leading-6 text-[var(--admin-zinc-400)]">
              Use one JSON object. Sensitive-key metadata and records outside
              the active scope are rejected.
            </p>
            <textarea
              value={editorValue}
              disabled={!canEdit || saving}
              aria-label={`${activeResource.label} structured record`}
              aria-invalid={editorError != null}
              aria-describedby={
                editorError ? "runtime-editor-error" : undefined
              }
              onFocus={() => setInteraction("focused")}
              onBlur={() => setInteraction("selected")}
              onChange={(event) => {
                setEditorValue(event.target.value);
                setEditorError(null);
              }}
              spellCheck={false}
              className="min-h-[520px] w-full resize-y rounded-[22px] border border-border-soft bg-slate-950/80 p-4 font-mono text-sm leading-6 text-slate-100 outline-none transition focus:border-club-accent disabled:cursor-not-allowed disabled:opacity-70 motion-reduce:transition-none"
            />
            {editorError ? (
              <p
                id="runtime-editor-error"
                role="alert"
                className="mt-3 text-sm font-semibold text-rose-400"
              >
                {editorError}
              </p>
            ) : null}
          </section>
        </div>
      ) : null}
    </div>
  );
}
