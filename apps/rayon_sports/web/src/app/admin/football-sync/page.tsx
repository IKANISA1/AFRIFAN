"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Activity,
  Clock,
  Database,
  Globe,
  Save,
  Search,
  Trash2,
} from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { handleAdminTabKeyDown } from "@/components/admin/admin-tab-keyboard";
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminLiveScoreCompetitionSource,
  getAdminLiveScoreCompetitionSources,
  getAdminSyncLogs,
  getAdminSyncOverview,
  normalizeAdminFootballSyncSnapshot,
  saveAdminLiveScoreCompetitionSource,
  type AdminFootballSyncSnapshot,
  type AdminLiveScoreCompetitionSource,
  type AdminSyncLog,
} from "@/lib/data/admin/football-sync";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { cn } from "@/lib/utils";

type Tab = "overview" | "sources" | "logs";

const tabs: { key: Tab; label: string; icon: typeof Activity }[] = [
  { key: "overview", label: "Overview", icon: Activity },
  { key: "sources", label: "LiveScore sources", icon: Database },
  { key: "logs", label: "Sync logs", icon: Clock },
];

const emptySourceForm = {
  id: "",
  expectedUpdatedAt: "",
  sourceKey: "",
  displayName: "",
  matchAliases: "",
  countryAliases: "",
  externalCompetitionIds: "",
  sourceUrls: "https://www.livescore.com/en/",
  priority: 100,
  isActive: true,
};

const emptySnapshot: AdminFootballSyncSnapshot =
  normalizeAdminFootballSyncSnapshot(null);

const snapshotIsEmpty = (snapshot: AdminFootballSyncSnapshot) =>
  snapshot.sources.length === 0 &&
  snapshot.logs.length === 0 &&
  Object.entries(snapshot.overview)
    .filter(([key]) => key !== "lastSyncAt")
    .every(([, value]) => value === 0) &&
  snapshot.overview.lastSyncAt == null;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading football synchronization",
    detail: "Waiting for the first authenticated synchronization snapshot.",
  },
  ready: {
    label: "Synchronization snapshot confirmed",
    detail: "Source definitions and the bounded operational log are current.",
  },
  empty: {
    label: "No synchronization records in this scope",
    detail: "Create an approved LiveScore source before automated collection.",
  },
  error: {
    label: "Football synchronization unavailable",
    detail: "Confirmed records remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Synchronization workspace is offline",
    detail:
      "Confirmed records remain visible; mutations are locked until reconnect.",
  },
  permission_denied: {
    label: "Synchronization access denied",
    detail:
      "Previously loaded records, filters, selection, details, and drafts were cleared.",
  },
  syncing: {
    label: "Refreshing football synchronization",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Synchronization records changed",
    detail: "Review the current source before restarting the change.",
  },
  security_timeout: {
    label: "Synchronization request timed out",
    detail: "No source change or synchronization result was confirmed.",
  },
};

function listToText(values: string[]) {
  return values.join(", ");
}

function textToList(value: string) {
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function formatRelativeTime(iso: string | null): string {
  if (!iso) return "Never";
  const timestamp = new Date(iso).getTime();
  if (!Number.isFinite(timestamp)) return "Unavailable";
  const minutes = Math.max(0, Math.floor((Date.now() - timestamp) / 60_000));
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function formatDuration(ms: number | null): string {
  if (ms == null) return "Not confirmed";
  if (ms < 1_000) return `${ms}ms`;
  return `${(ms / 1_000).toFixed(1)}s`;
}

function statusTone(status: string) {
  switch (status) {
    case "completed":
    case "success":
      return "success" as const;
    case "completed_with_errors":
    case "failed":
    case "error":
      return "warning" as const;
    default:
      return "neutral" as const;
  }
}

export default function AdminFootballSyncPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [sourceForm, setSourceForm] = useState(emptySourceForm);
  const [savingSource, setSavingSource] = useState(false);
  const [detailLog, setDetailLog] = useState<AdminSyncLog | null>(null);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadSnapshot = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptySnapshot;
      const [overview, sources, logs] = await Promise.all([
        getAdminSyncOverview(client, access, { signal }),
        getAdminLiveScoreCompetitionSources(client, access, { signal }),
        getAdminSyncLogs(client, access, 500, { signal }),
      ]);
      return { overview, sources, logs };
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setActiveTab("overview");
    setSourceForm(emptySourceForm);
    setDetailLog(null);
    setInteraction("idle");
  }, []);

  const {
    data,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptySnapshot,
    isEmpty: snapshotIsEmpty,
    load: loadSnapshot,
    normalize: normalizeAdminFootballSyncSnapshot,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "football synchronization",
  });

  const sourceCollection = useAdminCollection({
    records: data.sources,
    getId: (source) => source.id,
    getSearchValues: (source) => [
      source.displayName,
      source.sourceKey,
      source.matchAliases.join(" "),
      source.countryAliases.join(" "),
      source.externalCompetitionIds.join(" "),
      source.sourceUrls.join(" "),
      source.isActive ? "active" : "disabled",
    ],
    getSortValue: (
      source,
      key: "name" | "key" | "priority" | "status" | "urls",
    ) => {
      switch (key) {
        case "name":
          return source.displayName;
        case "key":
          return source.sourceKey;
        case "priority":
          return source.priority;
        case "status":
          return source.isActive;
        case "urls":
          return source.sourceUrls.length;
      }
    },
    initialSortKey: "priority" as const,
    pageSize: 25,
  });

  const logCollection = useAdminCollection({
    records: data.logs,
    getId: (log) => log.id,
    getSearchValues: (log) => [
      log.status,
      log.errorMessage,
      log.recordsFetched,
      log.recordsUpserted,
      log.webRequestsUsed,
    ],
    getSortValue: (
      log,
      key: "status" | "fetched" | "duration" | "startedAt",
    ) => {
      switch (key) {
        case "status":
          return log.status;
        case "fetched":
          return log.recordsFetched;
        case "duration":
          return log.durationMs;
        case "startedAt":
          return new Date(log.startedAt);
      }
    },
    initialSortKey: "startedAt" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  const { setPage: setSourcePage, setQuery: setSourceQuery } = sourceCollection;
  const { setPage: setLogPage, setQuery: setLogQuery } = logCollection;
  useEffect(() => {
    if (status !== "permission_denied") return;
    setSourceQuery("");
    setSourcePage(1);
    setLogQuery("");
    setLogPage(1);
  }, [setLogPage, setLogQuery, setSourcePage, setSourceQuery, status]);

  const mutationLocked =
    !hydrated ||
    client == null ||
    savingSource ||
    (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  function selectTab(tab: Tab) {
    setActiveTab(tab);
    setInteraction("selected");
    if (tab !== "logs") setDetailLog(null);
  }

  function editSource(source: AdminLiveScoreCompetitionSource) {
    setSourceForm({
      id: source.id,
      expectedUpdatedAt: source.updatedAt,
      sourceKey: source.sourceKey,
      displayName: source.displayName,
      matchAliases: listToText(source.matchAliases),
      countryAliases: listToText(source.countryAliases),
      externalCompetitionIds: listToText(source.externalCompetitionIds),
      sourceUrls: listToText(source.sourceUrls),
      priority: source.priority,
      isActive: source.isActive,
    });
    setActiveTab("sources");
    setInteraction("selected");
    showAdminToast(`Editing ${source.displayName}.`, "info");
  }

  function mutationFailureMessage(caught: unknown, fallback: string) {
    const nextStatus = applyFailure(caught);
    return nextStatus === "conflict" ? statusCopy.conflict.label : fallback;
  }

  async function handleSaveSource() {
    if (client == null || mutationLocked) return;
    setSavingSource(true);
    try {
      await saveAdminLiveScoreCompetitionSource(client, access, {
        id: sourceForm.id || null,
        expectedUpdatedAt: sourceForm.expectedUpdatedAt || null,
        sourceKey: sourceForm.sourceKey,
        displayName: sourceForm.displayName,
        matchAliases: textToList(sourceForm.matchAliases),
        countryAliases: textToList(sourceForm.countryAliases),
        externalCompetitionIds: textToList(sourceForm.externalCompetitionIds),
        sourceUrls: textToList(sourceForm.sourceUrls),
        priority: sourceForm.priority,
        isActive: sourceForm.isActive,
      });
      setSourceForm(emptySourceForm);
      setInteraction("idle");
      await refresh();
      showAdminToast("LiveScore source saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) await refresh();
      showAdminToast(
        mutationFailureMessage(
          caught,
          "Could not confirm the LiveScore source change.",
        ),
        "error",
      );
    } finally {
      setSavingSource(false);
    }
  }

  async function handleDeleteSource(source: AdminLiveScoreCompetitionSource) {
    if (
      client == null ||
      mutationLocked ||
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: source.displayName,
        scope:
          source.clubId == null
            ? "Platform LiveScore source registry"
            : `Club ${source.clubId}`,
        impact:
          "Automated fixture synchronization will stop using this source definition.",
        undo: "not_available",
      })
    ) {
      return;
    }
    setSavingSource(true);
    try {
      await deleteAdminLiveScoreCompetitionSource(
        client,
        access,
        source.id,
        source.updatedAt,
      );
      if (sourceForm.id === source.id) setSourceForm(emptySourceForm);
      setInteraction("idle");
      await refresh();
      showAdminToast("LiveScore source deleted.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) await refresh();
      showAdminToast(
        mutationFailureMessage(
          caught,
          "Could not confirm LiveScore source deletion.",
        ),
        "error",
      );
    } finally {
      setSavingSource(false);
    }
  }

  function updateSourceForm(update: Partial<typeof emptySourceForm>) {
    setSourceForm((current) => ({ ...current, ...update }));
    setInteraction("selected");
  }

  return (
    <section
      className="admin-football-sync-state-surface section-grid min-w-0 max-w-full"
      data-admin-football-sync-status={status}
      data-admin-football-sync-interaction={interaction}
      data-admin-football-sync-refresh-disabled={busy}
      data-admin-football-sync-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Platform"
        title="LiveScore Sync"
        meta={
          <span className="admin-meta-chip">
            Bounded provider sources and operational health
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh football synchronization"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-football-sync-status"
      />

      <div className="admin-football-sync-metrics-grid">
        <AdminStateCard
          label="Active sources"
          value={
            initialLoading
              ? "..."
              : `${data.overview.activeSources}/${data.overview.totalSources}`
          }
          helper="Enabled / configured."
          icon={Globe}
        />
        <AdminStateCard
          label="LiveScore fixtures"
          value={initialLoading ? "..." : `${data.overview.totalFixtures}`}
          helper={`${data.overview.scheduledFixtures} scheduled · ${data.overview.liveFixtures} live · ${data.overview.finishedFixtures} finished.`}
          icon={Database}
        />
        <AdminStateCard
          label="LiveScore teams"
          value={initialLoading ? "..." : data.overview.totalTeams.toString()}
          helper="Confirmed provider-linked teams."
          icon={Activity}
        />
        <AdminStateCard
          label="Errors today"
          value={initialLoading ? "..." : data.overview.errorsToday.toString()}
          helper={`${data.overview.webRequestsToday} web reads in latest ${data.overview.inspectedLogRowsToday}/500 logs · ${formatRelativeTime(data.overview.lastSyncAt)}.`}
          icon={Clock}
        />
      </div>

      <div
        className="flex flex-wrap gap-2"
        role="tablist"
        aria-label="Football synchronization views"
      >
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.key}
              type="button"
              role="tab"
              id={`football-sync-tab-${tab.key}`}
              aria-selected={activeTab === tab.key}
              aria-controls="football-sync-panel"
              tabIndex={activeTab === tab.key ? 0 : -1}
              disabled={status === "permission_denied"}
              onKeyDown={handleAdminTabKeyDown}
              onClick={() => selectTab(tab.key)}
              className={cn(
                "flex min-h-12 items-center gap-2 rounded-full px-5 py-3 text-sm font-semibold transition motion-reduce:transition-none disabled:cursor-not-allowed disabled:opacity-60",
                activeTab === tab.key
                  ? "bg-action-blue text-white"
                  : "border border-[var(--admin-border)] bg-[var(--admin-widget)] text-[var(--admin-text-strong)] hover:bg-[var(--admin-raised)]",
              )}
            >
              <Icon size={16} aria-hidden="true" />
              {tab.label}
            </button>
          );
        })}
      </div>

      <div
        id="football-sync-panel"
        role="tabpanel"
        aria-labelledby={`football-sync-tab-${activeTab}`}
        tabIndex={0}
        className="min-w-0"
      >
      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry football synchronization"
        />
      ) : (
        <AdminSurface
          title={
            activeTab === "overview"
              ? "LiveScore overview"
              : activeTab === "sources"
                ? "LiveScore sources"
                : "Synchronization logs"
          }
          className="min-w-0"
        >
          {initialLoading ? (
            <div className="space-y-4 p-5 sm:p-6">
              {Array.from({ length: 4 }).map((_, index) => (
                <div
                  key={index}
                  className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-4"
                >
                  <Skeleton className="skeleton-text h-5 w-1/3" />
                  <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
                </div>
              ))}
            </div>
          ) : activeTab === "overview" ? (
            <div
              id="football-sync-overview"
              className="grid gap-4 p-5 sm:grid-cols-2 sm:p-6 lg:grid-cols-3"
            >
              <div className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-5">
                <p className="admin-row-meta">Source control</p>
                <p className="mt-2 text-sm text-[var(--admin-text-strong)]">
                  <strong>{data.overview.activeSources}</strong> active source
                  rows · <strong>{data.overview.totalSources}</strong>{" "}
                  configured
                </p>
              </div>
              <div className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-5">
                <p className="admin-row-meta">Fixture breakdown</p>
                <p className="mt-2 text-sm text-[var(--admin-text-strong)]">
                  <strong>{data.overview.scheduledFixtures}</strong> scheduled ·{" "}
                  <strong>{data.overview.liveFixtures}</strong> live ·{" "}
                  <strong>{data.overview.finishedFixtures}</strong> finished
                </p>
              </div>
              <div className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-5">
                <p className="admin-row-meta">Latest confirmed sync</p>
                <p className="mt-2 text-sm text-[var(--admin-text-strong)]">
                  {formatRelativeTime(data.overview.lastSyncAt)}
                </p>
              </div>
            </div>
          ) : activeTab === "sources" ? (
            <div
              id="football-sync-sources"
              className="admin-football-sync-source-grid grid min-w-0 gap-4 p-5 sm:p-6 lg:grid-cols-[minmax(0,1fr)_420px]"
            >
              <div className="min-w-0 space-y-3">
                <AdminFilterBar
                  actions={
                    <div className="flex flex-wrap gap-2">
                      {(
                        ["priority", "name", "key", "status", "urls"] as const
                      ).map((key) => (
                        <button
                          key={key}
                          type="button"
                          disabled={status === "permission_denied"}
                          data-active={sourceCollection.sortKey === key}
                          onClick={() => sourceCollection.toggleSort(key)}
                          className="dashboard-chip min-h-12 disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          Sort {key}
                        </button>
                      ))}
                    </div>
                  }
                >
                  <label className="admin-search-field">
                    <Search size={16} aria-hidden="true" />
                    <span className="sr-only">Search LiveScore sources</span>
                    <input
                      type="search"
                      value={sourceCollection.query}
                      disabled={status === "permission_denied"}
                      onChange={(event) =>
                        sourceCollection.setQuery(event.target.value)
                      }
                      placeholder="Search source, alias, country, URL, or state"
                    />
                  </label>
                </AdminFilterBar>

                {sourceCollection.pageResult.items.length === 0 ? (
                  <div className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-5 text-sm text-[var(--admin-text-muted)]">
                    {sourceCollection.query
                      ? "No LiveScore sources match the current search."
                      : "No approved LiveScore competition source is configured."}
                  </div>
                ) : (
                  sourceCollection.pageResult.items.map((source) => (
                    <article
                      key={source.id}
                      className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-4"
                    >
                      <div className="flex flex-wrap items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="font-semibold text-[var(--admin-text-strong)]">
                            {source.displayName}
                          </p>
                          <p className="admin-row-meta mt-1">
                            {source.sourceKey} · priority {source.priority}
                          </p>
                        </div>
                        <AdminStatusBadge
                          label={source.isActive ? "Active" : "Disabled"}
                          tone={source.isActive ? "success" : "neutral"}
                        />
                      </div>
                      <p className="admin-row-copy mt-3">
                        Aliases: {source.matchAliases.join(", ")}
                      </p>
                      <p className="admin-row-meta mt-1">
                        Countries: {source.countryAliases.join(", ") || "Any"} ·
                        approved URLs: {source.sourceUrls.length}
                      </p>
                      <div className="mt-3 flex flex-wrap gap-2">
                        <button
                          type="button"
                          disabled={mutationLocked}
                          onClick={() => editSource(source)}
                          aria-label={`Edit ${source.displayName}`}
                          className="admin-action-button min-h-12 disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          disabled={mutationLocked}
                          onClick={() => void handleDeleteSource(source)}
                          aria-label={`Delete ${source.displayName}`}
                          className="admin-action-button admin-action-button-danger min-h-12 disabled:cursor-not-allowed disabled:opacity-60"
                        >
                          <Trash2 size={16} aria-hidden="true" />
                          Delete
                        </button>
                      </div>
                    </article>
                  ))
                )}
                <AdminPagination
                  page={sourceCollection.pageResult}
                  onPageChange={sourceCollection.setPage}
                  label="LiveScore sources"
                />
              </div>

              <form
                className="min-w-0 rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-4"
                onSubmit={(event) => {
                  event.preventDefault();
                  void handleSaveSource();
                }}
              >
                <fieldset disabled={mutationLocked} className="space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <p className="font-semibold text-[var(--admin-text-strong)]">
                      {sourceForm.id
                        ? "Edit LiveScore source"
                        : "New LiveScore source"}
                    </p>
                    {sourceForm.id ? (
                      <button
                        type="button"
                        onClick={() => {
                          setSourceForm(emptySourceForm);
                          setInteraction("idle");
                        }}
                        className="admin-action-button min-h-12"
                      >
                        Clear
                      </button>
                    ) : null}
                  </div>
                  <label className="grid gap-2 text-sm">
                    Display name
                    <input
                      required
                      maxLength={160}
                      autoComplete="off"
                      value={sourceForm.displayName}
                      onChange={(event) =>
                        updateSourceForm({ displayName: event.target.value })
                      }
                      className="admin-input"
                    />
                  </label>
                  <label className="grid gap-2 text-sm">
                    Source key
                    <input
                      maxLength={80}
                      pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
                      autoComplete="off"
                      value={sourceForm.sourceKey}
                      onChange={(event) =>
                        updateSourceForm({ sourceKey: event.target.value })
                      }
                      className="admin-input"
                      placeholder="Derived from the name when blank"
                    />
                  </label>
                  <label className="grid gap-2 text-sm">
                    Match aliases
                    <textarea
                      required
                      maxLength={8_000}
                      value={sourceForm.matchAliases}
                      onChange={(event) =>
                        updateSourceForm({ matchAliases: event.target.value })
                      }
                      className="admin-input min-h-24 resize-y"
                    />
                  </label>
                  <label className="grid gap-2 text-sm">
                    Country aliases
                    <input
                      maxLength={8_000}
                      value={sourceForm.countryAliases}
                      onChange={(event) =>
                        updateSourceForm({ countryAliases: event.target.value })
                      }
                      className="admin-input"
                    />
                  </label>
                  <label className="grid gap-2 text-sm">
                    External competition IDs
                    <input
                      maxLength={8_000}
                      value={sourceForm.externalCompetitionIds}
                      onChange={(event) =>
                        updateSourceForm({
                          externalCompetitionIds: event.target.value,
                        })
                      }
                      className="admin-input"
                    />
                  </label>
                  <label className="grid gap-2 text-sm">
                    Approved LiveScore HTTPS URLs
                    <textarea
                      required
                      maxLength={20_000}
                      value={sourceForm.sourceUrls}
                      onChange={(event) =>
                        updateSourceForm({ sourceUrls: event.target.value })
                      }
                      className="admin-input min-h-24 resize-y"
                    />
                  </label>
                  <div className="grid gap-3 sm:grid-cols-2">
                    <label className="grid gap-2 text-sm">
                      Priority
                      <input
                        type="number"
                        required
                        min={0}
                        max={10_000}
                        step={1}
                        value={sourceForm.priority}
                        onChange={(event) =>
                          updateSourceForm({
                            priority: Number(event.target.value),
                          })
                        }
                        className="admin-input"
                      />
                    </label>
                    <label className="flex min-h-12 items-center gap-3 rounded-xl border border-[var(--admin-border)] px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)]">
                      <input
                        type="checkbox"
                        checked={sourceForm.isActive}
                        onChange={(event) =>
                          updateSourceForm({ isActive: event.target.checked })
                        }
                      />
                      Active
                    </label>
                  </div>
                  <button
                    type="submit"
                    className="admin-action-button min-h-12 !bg-action-blue !text-white disabled:opacity-70"
                  >
                    <Save size={16} aria-hidden="true" />
                    {sourceForm.id ? "Save source" : "Create source"}
                  </button>
                </fieldset>
              </form>
            </div>
          ) : (
            <div
              id="football-sync-logs"
              className="min-w-0 space-y-3 p-5 sm:p-6"
            >
              <AdminFilterBar>
                <label className="admin-search-field">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Search synchronization logs</span>
                  <input
                    type="search"
                    value={logCollection.query}
                    disabled={status === "permission_denied"}
                    onChange={(event) =>
                      logCollection.setQuery(event.target.value)
                    }
                    placeholder="Search status, counts, or controlled errors"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="LiveScore synchronization logs"
                busy={busy}
                onRowActivate={(rowId) => {
                  const log =
                    data.logs.find((item) => item.id === rowId) ?? null;
                  setDetailLog(log);
                  setInteraction(log == null ? "idle" : "selected");
                }}
                columns={[
                  {
                    key: "status",
                    label: "Status",
                    priority: "primary",
                    sortable: true,
                    sortDirection: logCollection.sortDirectionFor("status"),
                    onSort: () => logCollection.toggleSort("status"),
                  },
                  {
                    key: "fetched",
                    label: "Fetched",
                    priority: "primary",
                    sortable: true,
                    sortDirection: logCollection.sortDirectionFor("fetched"),
                    onSort: () => logCollection.toggleSort("fetched"),
                  },
                  {
                    key: "upserted",
                    label: "Upserted",
                    priority: "secondary",
                  },
                  { key: "web", label: "Web reads", priority: "tertiary" },
                  {
                    key: "duration",
                    label: "Duration",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: logCollection.sortDirectionFor("duration"),
                    onSort: () => logCollection.toggleSort("duration"),
                  },
                  {
                    key: "time",
                    label: "Time",
                    priority: "primary",
                    sortable: true,
                    sortDirection: logCollection.sortDirectionFor("startedAt"),
                    onSort: () => logCollection.toggleSort("startedAt"),
                  },
                  { key: "error", label: "Error", priority: "tertiary" },
                ]}
              >
                {logCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td
                      colSpan={7}
                      className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                    >
                      {logCollection.query
                        ? "No synchronization logs match the current search."
                        : "No LiveScore synchronization logs yet."}
                    </td>
                  </tr>
                ) : (
                  logCollection.pageResult.items.map((log) => (
                    <tr key={log.id} data-row-id={log.id}>
                      <td>
                        <AdminStatusBadge
                          label={log.status}
                          tone={statusTone(log.status)}
                        />
                      </td>
                      <td>{log.recordsFetched}</td>
                      <td>{log.recordsUpserted}</td>
                      <td>{log.webRequestsUsed}</td>
                      <td>{formatDuration(log.durationMs)}</td>
                      <td>{formatRelativeTime(log.startedAt)}</td>
                      <td className="max-w-[240px] truncate">
                        {log.errorMessage ?? "No error"}
                      </td>
                    </tr>
                  ))
                )}
              </AdminDataGrid>
              <AdminPagination
                page={logCollection.pageResult}
                onPageChange={logCollection.setPage}
                label="LiveScore synchronization logs"
              />
            </div>
          )}
        </AdminSurface>
      )}
      </div>

      <AdminActionDrawer
        open={detailLog != null}
        onClose={() => {
          setDetailLog(null);
          setInteraction(activeTab === "logs" ? "selected" : "idle");
        }}
        title="Synchronization log details"
      >
        {detailLog ? (
          <dl className="grid gap-4 text-sm">
            <div>
              <dt className="text-[var(--admin-text-muted)]">Status</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailLog.status}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Started</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                <time dateTime={detailLog.startedAt}>
                  {new Date(detailLog.startedAt).toLocaleString()}
                </time>
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Records</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailLog.recordsFetched} fetched; {detailLog.recordsUpserted}{" "}
                upserted
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Web reads</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailLog.webRequestsUsed}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Duration</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {formatDuration(detailLog.durationMs)}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">
                Controlled error
              </dt>
              <dd className="mt-1 break-words text-[var(--admin-text-strong)]">
                {detailLog.errorMessage ?? "No error recorded."}
              </dd>
            </div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </section>
  );
}
