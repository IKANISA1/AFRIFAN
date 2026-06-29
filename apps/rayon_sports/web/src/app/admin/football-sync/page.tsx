"use client";

import { useCallback, useEffect, useState } from "react";
import { Activity, Clock, Database, Globe, Save, Trash2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
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

type Tab = "overview" | "sources" | "logs";

const tabs: { key: Tab; label: string; icon: typeof Activity }[] = [
  { key: "overview", label: "Overview", icon: Activity },
  { key: "sources", label: "LiveScore Sources", icon: Database },
  { key: "logs", label: "Sync Logs", icon: Clock },
];

const emptySourceForm = {
  id: "",
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
      const message = caught instanceof Error ? caught.message : "Could not load LiveScore sync data.";
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
      showAdminToast(caught instanceof Error ? caught.message : "Could not save LiveScore source.", "error");
    } finally {
      setSavingSource(false);
    }
  }

  async function handleDeleteSource(id: string) {
    if (client == null || savingSource) return;
    setSavingSource(true);
    try {
      await deleteAdminLiveScoreCompetitionSource(client, access, id);
      showAdminToast("LiveScore source deleted.", "success");
      if (sourceForm.id === id) setSourceForm(emptySourceForm);
      await load();
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not delete LiveScore source.", "error");
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
          value={loading ? "..." : `${overview?.activeSources ?? 0}/${overview?.totalSources ?? 0}`}
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
              <div key={index} className="rounded-[22px] border border-border-soft bg-white/5 p-4">
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        ) : loadError ? (
          <AdminErrorState title="LiveScore sync unavailable" description={loadError} onRetry={() => { load().catch(() => {}); }} />
        ) : (
          <>
            {activeTab === "overview" && overview && (
              <div className="space-y-6">
                <p className="font-display text-2xl font-bold uppercase">LiveScore Overview</p>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Source Control</p>
                    <p className="mt-2 text-sm text-white">
                      <span className="font-bold text-emerald-400">{overview.activeSources}</span> active source rows ·{" "}
                      <span className="font-bold">{overview.totalSources}</span> configured
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Fixture Breakdown</p>
                    <p className="mt-2 text-sm text-white">
                      <span className="font-bold text-blue-400">{overview.scheduledFixtures}</span> scheduled ·{" "}
                      <span className="font-bold text-emerald-400">{overview.liveFixtures}</span> live ·{" "}
                      <span className="font-bold">{overview.finishedFixtures}</span> finished
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Last Sync</p>
                    <p className="mt-2 text-sm text-white">{formatRelativeTime(overview.lastSyncAt)}</p>
                  </div>
                </div>
              </div>
            )}

            {activeTab === "sources" && (
              <div className="space-y-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <p className="font-display text-2xl font-bold uppercase">LiveScore Sources ({sources.length})</p>
                  <button type="button" onClick={() => setSourceForm(emptySourceForm)} className="admin-action-button">
                    New Source
                  </button>
                </div>

                <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_420px]">
                  <div className="space-y-2">
                    {sources.length === 0 ? (
                      <p className="text-sm text-slate-400">
                        No active LiveScore competition sources are configured. The sync script will not write fixtures until at least one source exists.
                      </p>
                    ) : null}
                    {sources.map((source) => (
                      <div key={source.id} className="rounded-[22px] border border-border-soft bg-white/5 p-4">
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="font-semibold text-white">{source.displayName}</p>
                            <p className="mt-1 text-xs text-slate-400">{source.sourceKey} · priority {source.priority}</p>
                          </div>
                          <AdminStatusBadge
                            label={source.isActive ? "Active" : "Disabled"}
                            tone={source.isActive ? "success" : "neutral"}
                          />
                        </div>
                        <p className="mt-3 text-xs text-slate-300">Aliases: {source.matchAliases.join(", ")}</p>
                        <p className="mt-1 text-xs text-slate-400">
                          Countries: {source.countryAliases.join(", ") || "Any"} · URLs: {source.sourceUrls.length}
                        </p>
                        <div className="mt-3 flex flex-wrap gap-2">
                          <button type="button" onClick={() => editSource(source)} className="admin-action-button">
                            Edit
                          </button>
                          <button
                            type="button"
                            onClick={() => { handleDeleteSource(source.id).catch(() => {}); }}
                            className="admin-action-button admin-action-button-danger"
                            disabled={savingSource}
                          >
                            <Trash2 size={14} />
                            Delete
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-4">
                    <p className="font-semibold text-white">
                      {sourceForm.id ? "Edit LiveScore Source" : "New LiveScore Source"}
                    </p>
                    <div className="mt-4 space-y-3">
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Display name
                        <input
                          value={sourceForm.displayName}
                          onChange={(event) => setSourceForm({ ...sourceForm, displayName: event.target.value })}
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Source key
                        <input
                          value={sourceForm.sourceKey}
                          onChange={(event) => setSourceForm({ ...sourceForm, sourceKey: event.target.value })}
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Match aliases
                        <textarea
                          value={sourceForm.matchAliases}
                          onChange={(event) => setSourceForm({ ...sourceForm, matchAliases: event.target.value })}
                          className="admin-input mt-1 min-h-[72px]"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        Country aliases
                        <input
                          value={sourceForm.countryAliases}
                          onChange={(event) => setSourceForm({ ...sourceForm, countryAliases: event.target.value })}
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        External competition IDs
                        <input
                          value={sourceForm.externalCompetitionIds}
                          onChange={(event) => setSourceForm({ ...sourceForm, externalCompetitionIds: event.target.value })}
                          className="admin-input mt-1"
                        />
                      </label>
                      <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                        LiveScore URLs
                        <textarea
                          value={sourceForm.sourceUrls}
                          onChange={(event) => setSourceForm({ ...sourceForm, sourceUrls: event.target.value })}
                          className="admin-input mt-1 min-h-[72px]"
                        />
                      </label>
                      <div className="grid gap-3 sm:grid-cols-2">
                        <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400">
                          Priority
                          <input
                            type="number"
                            value={sourceForm.priority}
                            onChange={(event) => setSourceForm({ ...sourceForm, priority: Number(event.target.value) })}
                            className="admin-input mt-1"
                          />
                        </label>
                        <label className="flex items-center gap-2 pt-6 text-sm font-semibold text-slate-200">
                          <input
                            type="checkbox"
                            checked={sourceForm.isActive}
                            onChange={(event) => setSourceForm({ ...sourceForm, isActive: event.target.checked })}
                          />
                          Active
                        </label>
                      </div>
                      <button
                        type="button"
                        onClick={() => { handleSaveSource().catch(() => {}); }}
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
                <p className="font-display text-2xl font-bold uppercase">Recent LiveScore Logs ({logs.length})</p>
                {logs.length === 0 ? (
                  <p className="text-sm text-slate-400">No LiveScore sync logs yet.</p>
                ) : null}
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-border-soft text-left text-xs uppercase tracking-wider text-slate-500">
                        <th className="pb-3 pr-4">Status</th>
                        <th className="pb-3 pr-4">Fetched</th>
                        <th className="pb-3 pr-4">Upserted</th>
                        <th className="pb-3 pr-4">Web Reads</th>
                        <th className="pb-3 pr-4">Duration</th>
                        <th className="pb-3 pr-4">Time</th>
                        <th className="pb-3">Error</th>
                      </tr>
                    </thead>
                    <tbody>
                      {logs.map((log) => (
                        <tr key={log.id} className="border-b border-border-soft/50 transition hover:bg-white/[0.03]">
                          <td className="py-3 pr-4">
                            <AdminStatusBadge label={log.status} tone={statusTone(log.status)} />
                          </td>
                          <td className="py-3 pr-4 text-slate-300">{log.recordsFetched}</td>
                          <td className="py-3 pr-4 text-slate-300">{log.recordsUpserted}</td>
                          <td className="py-3 pr-4 text-slate-300">{log.webRequestsUsed}</td>
                          <td className="py-3 pr-4 text-slate-400">{formatDuration(log.durationMs)}</td>
                          <td className="py-3 pr-4 text-slate-400">{formatRelativeTime(log.startedAt)}</td>
                          <td className="max-w-[240px] truncate py-3 text-xs text-red-400">
                            {log.errorMessage ?? "-"}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </>
        )}
      </section>
    </div>
  );
}
