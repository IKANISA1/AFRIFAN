"use client";

import { useCallback, useEffect, useState } from "react";
import { Activity, Clock, Database, Globe, Search, Save, Trash2 } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { cn } from "@/lib/utils";
import {
  deleteAdminLiveScoreCompetitionSource,
  getAdminLiveScoreCompetitionSources,
  getAdminSyncLogs,
  getAdminSyncOverview,
  saveAdminLiveScoreCompetitionSource,
} from "@/lib/data/admin/football-sync";
import type {
  AdminLiveScoreCompetitionSource,
  AdminSyncLog,
  AdminSyncOverview,
} from "@/lib/data/admin/football-sync";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

type Tab = "overview" | "sources" | "logs";

const tabs: { key: Tab; label: string; icon: typeof Activity }[] = [
  { key: "overview", label: "Overview", icon: Activity },
  { key: "sources", label: "LiveScore Sources", icon: Database },
  { key: "logs", label: "Sync Logs", icon: Clock },
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

export default function AdminFootballSyncPage() {
  const { access, client } = useAdminPortal();
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [overview, setOverview] = useState<AdminSyncOverview | null>(null);
  const [sources, setSources] = useState<AdminLiveScoreCompetitionSource[]>([]);
  const [logs, setLogs] = useState<AdminSyncLog[]>([]);
  const [sourceForm, setSourceForm] = useState(emptySourceForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [savingSource, setSavingSource] = useState(false);
  const [detailLog, setDetailLog] = useState<AdminSyncLog | null>(null);

  const logCollection = useAdminCollection({
    records: logs,
    getId: (log) => log.id,
    getSearchValues: (log) => [
      log.status,
      log.errorMessage,
      log.recordsFetched,
      log.recordsUpserted,
      log.webRequestsUsed,
    ],
    getSortValue: (log, key: "status" | "fetched" | "duration" | "startedAt") => {
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
    pageSize: 20,
  });
  const sourceCollection = useAdminCollection({
    records: sources,
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
        case "name": return source.displayName;
        case "key": return source.sourceKey;
        case "priority": return source.priority;
        case "status": return source.isActive;
        case "urls": return source.sourceUrls.length;
      }
    },
    initialSortKey: "priority" as const,
    pageSize: 20,
  });

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const [nextOverview, nextSources, nextLogs] = await Promise.all([
        getAdminSyncOverview(client, access),
        getAdminLiveScoreCompetitionSources(client, access),
        getAdminSyncLogs(client, access, 30),
      ]);
      setOverview(nextOverview);
      setSources(nextSources);
      setLogs(nextLogs);
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load LiveScore sync data.";
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

  function listToText(values: string[]) {
    return values.join(", ");
  }

  function textToList(value: string) {
    return value
      .split(",")
      .map((entry) => entry.trim())
      .filter(Boolean);
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
  }

  async function handleSaveSource() {
    if (client == null || savingSource) return;
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
      showAdminToast("LiveScore source saved.", "success");
      setSourceForm(emptySourceForm);
      await load();
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not save LiveScore source.",
        "error",
      );
    } finally {
      setSavingSource(false);
    }
  }

  async function handleDeleteSource(source: AdminLiveScoreCompetitionSource) {
    if (client == null || savingSource) return;
    if (!confirmAdminDestructiveAction({
      action: "Delete",
      subject: source.displayName,
      scope: source.clubId == null
        ? "Platform LiveScore source registry"
        : `Club ${source.clubId}`,
      impact: "Automated fixture synchronization will stop using this source definition.",
      undo: "not_available",
    })) return;
    setSavingSource(true);
    try {
      await deleteAdminLiveScoreCompetitionSource(
        client,
        access,
        source.id,
        source.updatedAt,
      );
      showAdminToast("LiveScore source deleted.", "success");
      if (sourceForm.id === source.id) setSourceForm(emptySourceForm);
      await load();
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not delete LiveScore source.",
        "error",
      );
    } finally {
      setSavingSource(false);
    }
  }

  function formatRelativeTime(iso: string | null): string {
    if (!iso) return "Never";
    const timestamp = new Date(iso).getTime();
    if (Number.isNaN(timestamp)) return iso;
    const minutes = Math.floor((Date.now() - timestamp) / 60000);
    if (minutes < 1) return "Just now";
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
  }

  function formatDuration(ms: number | null): string {
    if (ms == null) return "-";
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(1)}s`;
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

  return (
    <div className="section-grid">
      <AdminPageHeader eyebrow="Platform" title="LiveScore Sync" />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Active Sources"
          value={
            loading
              ? "..."
              : `${overview?.activeSources ?? 0}/${overview?.totalSources ?? 0}`
          }
          helper="Enabled / configured"
          icon={Globe}
        />
        <AdminStateCard
          label="LiveScore Fixtures"
          value={loading ? "..." : `${overview?.totalFixtures ?? 0}`}
          helper={`${overview?.scheduledFixtures ?? 0} scheduled · ${overview?.liveFixtures ?? 0} live · ${overview?.finishedFixtures ?? 0} finished`}
          icon={Database}
        />
        <AdminStateCard
          label="LiveScore Teams"
          value={loading ? "..." : (overview?.totalTeams ?? 0).toString()}
          helper="Synced from LiveScore"
          icon={Activity}
        />
        <AdminStateCard
          label="Sync Health"
          value={loading ? "..." : `${overview?.errorsToday ?? 0}`}
          helper={`${overview?.webRequestsToday ?? 0} web reads today · ${formatRelativeTime(overview?.lastSyncAt ?? null)}`}
          icon={Clock}
        />
      </div>

      <div className="flex flex-wrap gap-2">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveTab(tab.key)}
              className={cn(
                "flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold transition",
                activeTab === tab.key
                  ? "bg-club-primary text-white"
                  : "border border-border-soft bg-white/5 text-slate-300 hover:bg-white/8",
              )}
            >
              <Icon size={16} />
              {tab.label}
            </button>
          );
        })}
      </div>

      <section className="glass-panel rounded-[32px] p-6">
        {loading ? (
          <div className="space-y-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[22px] border border-border-soft bg-white/5 p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        ) : loadError ? (
          <AdminErrorState
            title="LiveScore sync unavailable"
            description={loadError}
            onRetry={() => {
              load().catch(() => {});
            }}
          />
        ) : (
          <>
            {activeTab === "overview" && overview && (
              <div className="space-y-6">
                <p className="font-display text-2xl font-bold uppercase">
                  LiveScore Overview
                </p>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                      Source Control
                    </p>
                    <p className="mt-2 text-sm text-white">
                      <span className="font-bold text-emerald-400">
                        {overview.activeSources}
                      </span>{" "}
                      active source rows ·{" "}
                      <span className="font-bold">{overview.totalSources}</span>{" "}
                      configured
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                      Fixture Breakdown
                    </p>
                    <p className="mt-2 text-sm text-white">
                      <span className="font-bold text-blue-400">
                        {overview.scheduledFixtures}
                      </span>{" "}
                      scheduled ·{" "}
                      <span className="font-bold text-emerald-400">
                        {overview.liveFixtures}
                      </span>{" "}
                      live ·{" "}
                      <span className="font-bold">
                        {overview.finishedFixtures}
                      </span>{" "}
                      finished
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                      Last Sync
                    </p>
                    <p className="mt-2 text-sm text-white">
                      {formatRelativeTime(overview.lastSyncAt)}
                    </p>
                  </div>
                </div>
              </div>
            )}

            {activeTab === "sources" && (
              <div className="space-y-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <p className="font-display text-2xl font-bold uppercase">
                    LiveScore Sources ({sources.length})
                  </p>
                  <button
                    type="button"
                    onClick={() => setSourceForm(emptySourceForm)}
                    className="admin-action-button"
                  >
                    New Source
                  </button>
                </div>

                <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_420px]">
                  <div className="space-y-2">
                    <AdminFilterBar actions={<div className="flex flex-wrap gap-2">{(["priority", "name", "key", "status", "urls"] as const).map((key) => <button key={key} type="button" data-active={sourceCollection.sortKey === key} onClick={() => sourceCollection.toggleSort(key)} className="dashboard-chip">Sort {key}</button>)}</div>}>
                      <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search LiveScore sources</span><input type="search" value={sourceCollection.query} onChange={(event) => sourceCollection.setQuery(event.target.value)} placeholder="Search source, alias, country, URL, or state" /></label>
                    </AdminFilterBar>
                    {sourceCollection.pageResult.items.length === 0 ? (
                      <p className="text-sm text-slate-400">
                        {sourceCollection.query
                          ? "No LiveScore sources match the current search."
                          : "No active LiveScore competition sources are configured. The sync script will not write fixtures until at least one source exists."}
                      </p>
                    ) : null}
                    {sourceCollection.pageResult.items.map((source) => (
                      <div
                        key={source.id}
                        className="rounded-[22px] border border-border-soft bg-white/5 p-4"
                      >
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="font-semibold text-white">
                              {source.displayName}
                            </p>
                            <p className="mt-1 text-xs text-slate-400">
                              {source.sourceKey} · priority {source.priority}
                            </p>
                          </div>
                          <AdminStatusBadge
                            label={source.isActive ? "Active" : "Disabled"}
                            tone={source.isActive ? "success" : "neutral"}
                          />
                        </div>
                        <p className="mt-3 text-xs text-slate-300">
                          Aliases: {source.matchAliases.join(", ")}
                        </p>
                        <p className="mt-1 text-xs text-slate-400">
                          Countries: {source.countryAliases.join(", ") || "Any"}{" "}
                          · URLs: {source.sourceUrls.length}
                        </p>
                        <div className="mt-3 flex flex-wrap gap-2">
                          <button
                            type="button"
                            onClick={() => editSource(source)}
                            className="admin-action-button"
                          >
                            Edit
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              handleDeleteSource(source).catch(() => {});
                            }}
                            className="admin-action-button admin-action-button-danger"
                            disabled={savingSource}
                          >
                            <Trash2 size={14} />
                            Delete
                          </button>
                        </div>
                      </div>
                    ))}
                    <AdminPagination page={sourceCollection.pageResult} onPageChange={sourceCollection.setPage} label="LiveScore sources" />
                  </div>

                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-4">
                    <p className="font-semibold text-white">
                      {sourceForm.id
                        ? "Edit LiveScore Source"
                        : "New LiveScore Source"}
                    </p>
                    <div className="mt-4 space-y-3">
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Display name
                        <input
                          value={sourceForm.displayName}
                          onChange={(event) =>
                            setSourceForm({
                              ...sourceForm,
                              displayName: event.target.value,
                            })
                          }
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Source key
                        <input
                          value={sourceForm.sourceKey}
                          onChange={(event) =>
                            setSourceForm({
                              ...sourceForm,
                              sourceKey: event.target.value,
                            })
                          }
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Match aliases
                        <textarea
                          value={sourceForm.matchAliases}
                          onChange={(event) =>
                            setSourceForm({
                              ...sourceForm,
                              matchAliases: event.target.value,
                            })
                          }
                          className="admin-input mt-1 min-h-[72px]"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Country aliases
                        <input
                          value={sourceForm.countryAliases}
                          onChange={(event) =>
                            setSourceForm({
                              ...sourceForm,
                              countryAliases: event.target.value,
                            })
                          }
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        External competition IDs
                        <input
                          value={sourceForm.externalCompetitionIds}
                          onChange={(event) =>
                            setSourceForm({
                              ...sourceForm,
                              externalCompetitionIds: event.target.value,
                            })
                          }
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        LiveScore URLs
                        <textarea
                          value={sourceForm.sourceUrls}
                          onChange={(event) =>
                            setSourceForm({
                              ...sourceForm,
                              sourceUrls: event.target.value,
                            })
                          }
                          className="admin-input mt-1 min-h-[72px]"
                        />
                      </label>
                      <div className="grid gap-3 sm:grid-cols-2">
                        <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                          Priority
                          <input
                            type="number"
                            value={sourceForm.priority}
                            onChange={(event) =>
                              setSourceForm({
                                ...sourceForm,
                                priority: Number(event.target.value),
                              })
                            }
                            className="admin-input mt-1"
                          />
                        </label>
                        <label className="flex items-center gap-2 pt-6 text-sm font-semibold text-slate-200">
                          <input
                            type="checkbox"
                            checked={sourceForm.isActive}
                            onChange={(event) =>
                              setSourceForm({
                                ...sourceForm,
                                isActive: event.target.checked,
                              })
                            }
                          />
                          Active
                        </label>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          handleSaveSource().catch(() => {});
                        }}
                        className="admin-action-button !bg-club-accent !text-white"
                        disabled={savingSource}
                      >
                        <Save size={14} />
                        Save Source
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === "logs" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">
                  Recent LiveScore Logs ({logs.length})
                </p>
                <AdminFilterBar>
                  <label className="admin-search-field">
                    <Search size={16} aria-hidden="true" />
                    <span className="sr-only">Search sync logs</span>
                    <input
                      type="search"
                      value={logCollection.query}
                      onChange={(event) => logCollection.setQuery(event.target.value)}
                      placeholder="Search status, counts, or errors"
                    />
                  </label>
                </AdminFilterBar>
                <AdminDataGrid
                  caption="LiveScore synchronization logs"
                  onRowActivate={(rowId) =>
                    setDetailLog(logs.find((log) => log.id === rowId) ?? null)
                  }
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
                    { key: "upserted", label: "Upserted", priority: "secondary" },
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
                      <td colSpan={7} className="py-8 text-center text-sm text-slate-400">
                        {logCollection.query
                          ? "No sync logs match the current search."
                          : "No LiveScore sync logs yet."}
                      </td>
                    </tr>
                  ) : (
                    logCollection.pageResult.items.map((log) => (
                      <tr key={log.id} data-row-id={log.id}>
                        <td className="py-3 pr-4">
                          <AdminStatusBadge
                            label={log.status}
                            tone={statusTone(log.status)}
                          />
                        </td>
                        <td className="py-3 pr-4 text-slate-300">
                          {log.recordsFetched}
                        </td>
                        <td className="py-3 pr-4 text-slate-300">
                          {log.recordsUpserted}
                        </td>
                        <td className="py-3 pr-4 text-slate-300">
                          {log.webRequestsUsed}
                        </td>
                        <td className="py-3 pr-4 text-slate-400">
                          {formatDuration(log.durationMs)}
                        </td>
                        <td className="py-3 pr-4 text-slate-400">
                          {formatRelativeTime(log.startedAt)}
                        </td>
                        <td className="max-w-[240px] truncate py-3 text-xs text-red-400">
                          {log.errorMessage ?? "-"}
                        </td>
                      </tr>
                    ))
                  )}
                </AdminDataGrid>
                <AdminPagination
                  page={logCollection.pageResult}
                  onPageChange={logCollection.setPage}
                  label="LiveScore sync logs"
                />
              </div>
            )}
          </>
        )}
      </section>
      <AdminActionDrawer
        open={detailLog != null}
        onClose={() => setDetailLog(null)}
        title="Synchronization log details"
      >
        {detailLog ? (
          <dl className="grid gap-4 text-sm">
            <div><dt className="text-slate-500">Status</dt><dd className="mt-1 text-slate-100">{detailLog.status}</dd></div>
            <div><dt className="text-slate-500">Started</dt><dd className="mt-1 text-slate-100">{new Date(detailLog.startedAt).toLocaleString()}</dd></div>
            <div><dt className="text-slate-500">Records</dt><dd className="mt-1 text-slate-100">{detailLog.recordsFetched} fetched; {detailLog.recordsUpserted} upserted</dd></div>
            <div><dt className="text-slate-500">Web reads</dt><dd className="mt-1 text-slate-100">{detailLog.webRequestsUsed}</dd></div>
            <div><dt className="text-slate-500">Duration</dt><dd className="mt-1 text-slate-100">{formatDuration(detailLog.durationMs)}</dd></div>
            <div><dt className="text-slate-500">Error</dt><dd className="mt-1 break-words text-slate-100">{detailLog.errorMessage ?? "No error recorded."}</dd></div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}
