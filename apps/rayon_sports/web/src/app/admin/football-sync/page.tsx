"use client";

import { useCallback, useEffect, useState } from "react";
import { Zap, RefreshCw, Database, Globe, Activity, Clock, AlertTriangle, CheckCircle2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import {
  getAdminSyncConfigs,
  getAdminSyncLogs,
  getAdminSyncOverview,
  triggerSyncCommand,
  triggerMultiplierGeneration,
} from "@/lib/data/admin/football-sync";
import type {
  AdminSyncConfig,
  AdminSyncLog,
  AdminSyncOverview,
} from "@/lib/data/admin/football-sync";

type Tab = "overview" | "leagues" | "logs";

const tabs: { key: Tab; label: string; icon: typeof Zap }[] = [
  { key: "overview", label: "Overview", icon: Activity },
  { key: "leagues", label: "Tracked Leagues", icon: Globe },
  { key: "logs", label: "Sync Logs", icon: Clock },
];

const syncCommands = [
  { command: "full-sync", label: "Full Sync", description: "Fixtures + standings for all tracked leagues", icon: RefreshCw },
  { command: "sync-fixtures", label: "Sync Fixtures", description: "Fetch latest fixture data", icon: Database },
  { command: "sync-standings", label: "Sync Standings", description: "Fetch latest standings", icon: Activity },
  { command: "sync-history", label: "Sync History", description: "Backfill historical results", icon: Clock },
  { command: "seed-leagues", label: "Seed Leagues", description: "Register all 13 target leagues", icon: Globe },
];

export default function AdminFootballSyncPage() {
  const { access, client } = useAdminPortal();
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [overview, setOverview] = useState<AdminSyncOverview | null>(null);
  const [configs, setConfigs] = useState<AdminSyncConfig[]>([]);
  const [logs, setLogs] = useState<AdminSyncLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [runningCommand, setRunningCommand] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const [ov, cf, lg] = await Promise.all([
        getAdminSyncOverview(client, access),
        getAdminSyncConfigs(client, access),
        getAdminSyncLogs(client, access, 30),
      ]);
      setOverview(ov);
      setConfigs(cf);
      setLogs(lg);
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load sync data.";
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

  async function handleSyncCommand(command: string) {
    if (client == null || runningCommand) return;
    setRunningCommand(command);
    try {
      const result = await triggerSyncCommand(client, access, command);
      showAdminToast(result.message, "success");
      // Reload after short delay
      setTimeout(() => { load().catch(() => {}); }, 2000);
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Sync command failed.", "error");
    } finally {
      setRunningCommand(null);
    }
  }

  async function handleGenerateMultipliers() {
    if (client == null || runningCommand) return;
    setRunningCommand("generate-multipliers");
    try {
      const result = await triggerMultiplierGeneration(client, access);
      showAdminToast(result.message, "success");
      setTimeout(() => { load().catch(() => {}); }, 2000);
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Multiplier generation failed.", "error");
    } finally {
      setRunningCommand(null);
    }
  }

  function formatRelativeTime(iso: string | null): string {
    if (!iso) return "Never";
    try {
      const diff = Date.now() - new Date(iso).getTime();
      const minutes = Math.floor(diff / 60000);
      if (minutes < 1) return "Just now";
      if (minutes < 60) return `${minutes}m ago`;
      const hours = Math.floor(minutes / 60);
      if (hours < 24) return `${hours}h ago`;
      return `${Math.floor(hours / 24)}d ago`;
    } catch { return iso; }
  }

  function formatDuration(ms: number | null): string {
    if (ms == null) return "—";
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(1)}s`;
  }

  function statusTone(status: string) {
    switch (status) {
      case "completed": case "success": return "success" as const;
      case "running": case "in_progress": return "accent" as const;
      case "failed": case "error": return "warning" as const;
      default: return "neutral" as const;
    }
  }

  const quotaPct = overview ? Math.round((overview.apiCallsToday / overview.apiCallsLimit) * 100) : 0;

  return (
    <div className="section-grid">
      <AdminPageHeader eyebrow="Platform" title="Football Sync" />

      {/* KPI Cards */}
      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Tracked Leagues"
          value={loading ? "..." : `${overview?.activeLeagues ?? 0}/${overview?.totalLeagues ?? 0}`}
          helper="Active / Total"
          icon={Globe}
        />
        <AdminStateCard
          label="Fixtures"
          value={loading ? "..." : `${overview?.scheduledFixtures ?? 0}`}
          helper={`${overview?.finishedFixtures ?? 0} finished · ${overview?.totalFixtures ?? 0} total`}
          icon={Database}
        />
        <AdminStateCard
          label="Teams"
          value={loading ? "..." : (overview?.totalTeams ?? 0).toString()}
          helper="Registered teams"
          icon={Activity}
        />
        <div className={cn(
          "rounded-[22px] border border-border-soft p-5 transition",
          quotaPct > 80 ? "bg-red-500/10 border-red-500/30" : "bg-white/5"
        )}>
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">API Quota</span>
            {quotaPct > 80 && <AlertTriangle size={14} className="text-red-400" />}
          </div>
          <p className="mt-2 font-display text-2xl font-bold text-white">
            {loading ? "..." : `${overview?.apiCallsToday ?? 0}/${overview?.apiCallsLimit ?? 100}`}
          </p>
          <div className="mt-2 h-1.5 rounded-full bg-white/10 overflow-hidden">
            <div
              className={cn("h-full rounded-full transition-all duration-500", quotaPct > 80 ? "bg-red-400" : "bg-emerald-400")}
              style={{ width: `${Math.min(quotaPct, 100)}%` }}
            />
          </div>
          <p className="mt-1.5 text-xs text-slate-400">
            {quotaPct}% used today · {formatRelativeTime(overview?.lastSyncAt ?? null)}
          </p>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex flex-wrap gap-3">
        {syncCommands.map((cmd) => {
          const Icon = cmd.icon;
          const isRunning = runningCommand === cmd.command;
          return (
            <button
              key={cmd.command}
              type="button"
              disabled={runningCommand != null}
              onClick={() => { handleSyncCommand(cmd.command).catch(() => {}); }}
              title={cmd.description}
              className={cn(
                "flex items-center gap-2 rounded-full border border-border-soft px-4 py-2 text-xs font-semibold transition",
                isRunning
                  ? "bg-club-primary/20 text-club-primary animate-pulse"
                  : "bg-white/5 text-slate-300 hover:bg-white/8",
                runningCommand != null && !isRunning && "opacity-50 cursor-not-allowed",
              )}
            >
              <Icon size={14} className={cn(isRunning && "animate-spin")} />
              {cmd.label}
            </button>
          );
        })}
        <button
          type="button"
          disabled={runningCommand != null}
          onClick={() => { handleGenerateMultipliers().catch(() => {}); }}
          className={cn(
            "flex items-center gap-2 rounded-full border border-club-primary/40 px-4 py-2 text-xs font-semibold bg-club-primary/10 text-club-primary transition hover:bg-club-primary/20",
            runningCommand != null && "opacity-50 cursor-not-allowed",
          )}
        >
          <Zap size={14} />
          Generate Multipliers
        </button>
      </div>

      {/* Tab Bar */}
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

      {/* Content */}
      <section className="glass-panel rounded-[32px] p-6">
        {loading ? (
          <div className="space-y-4">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="rounded-[22px] border border-border-soft bg-white/5 p-4">
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        ) : loadError ? (
          <AdminErrorState title="Sync data unavailable" description={loadError} onRetry={() => { load().catch(() => {}); }} />
        ) : (
          <>
            {/* Overview tab */}
            {activeTab === "overview" && overview && (
              <div className="space-y-6">
                <p className="font-display text-2xl font-bold uppercase">System Overview</p>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Data Pipeline</p>
                    <p className="mt-2 text-sm text-white">
                      <span className="font-bold text-emerald-400">{overview.activeLeagues}</span> leagues tracked ·{" "}
                      <span className="font-bold">{overview.totalFixtures}</span> fixtures ·{" "}
                      <span className="font-bold">{overview.totalTeams}</span> teams
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Fixture Breakdown</p>
                    <p className="mt-2 text-sm text-white">
                      <span className="text-blue-400 font-bold">{overview.scheduledFixtures}</span> scheduled ·{" "}
                      <span className="text-emerald-400 font-bold">{overview.finishedFixtures}</span> finished
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-white/5 p-5">
                    <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Last Sync</p>
                    <p className="mt-2 text-sm text-white">{formatRelativeTime(overview.lastSyncAt)}</p>
                  </div>
                </div>
              </div>
            )}

            {/* Leagues tab */}
            {activeTab === "leagues" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Tracked Leagues ({configs.length})</p>
                {configs.length === 0 ? (
                  <p className="text-sm text-slate-400">No leagues registered. Click &quot;Seed Leagues&quot; to register the 13 target leagues.</p>
                ) : null}
                <div className="space-y-2">
                  {configs.map((config) => (
                    <div
                      key={config.id}
                      className={cn(
                        "flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition",
                        config.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60",
                      )}
                    >
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-white truncate">{config.leagueName}</p>
                        <p className="text-xs text-slate-400 mt-0.5">
                          {config.leagueCountry} · League ID: {config.leagueId} · Season {config.season}
                        </p>
                        {config.lastSyncAt && (
                          <p className="text-xs text-slate-500 mt-0.5">
                            Last sync: {formatRelativeTime(config.lastSyncAt)}
                          </p>
                        )}
                      </div>
                      <AdminStatusBadge
                        label={config.isActive ? "Active" : "Disabled"}
                        tone={config.isActive ? "success" : "neutral"}
                      />
                      {config.competitionId && (
                        <CheckCircle2
                          size={14}
                          className="text-emerald-400"
                          aria-label="Linked to competition"
                        />
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Logs tab */}
            {activeTab === "logs" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Recent Sync Logs ({logs.length})</p>
                {logs.length === 0 ? (
                  <p className="text-sm text-slate-400">No sync logs yet. Run a sync command to see activity here.</p>
                ) : null}
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-border-soft text-left text-xs uppercase tracking-wider text-slate-500">
                        <th className="pb-3 pr-4">Type</th>
                        <th className="pb-3 pr-4">Status</th>
                        <th className="pb-3 pr-4">Records</th>
                        <th className="pb-3 pr-4">API Calls</th>
                        <th className="pb-3 pr-4">Duration</th>
                        <th className="pb-3 pr-4">Time</th>
                        <th className="pb-3">Error</th>
                      </tr>
                    </thead>
                    <tbody>
                      {logs.map((log) => (
                        <tr key={log.id} className="border-b border-border-soft/50 hover:bg-white/[0.03] transition">
                          <td className="py-3 pr-4 font-semibold text-white">{log.syncType}</td>
                          <td className="py-3 pr-4">
                            <AdminStatusBadge label={log.status} tone={statusTone(log.status)} />
                          </td>
                          <td className="py-3 pr-4 text-slate-300">{log.recordsProcessed}</td>
                          <td className="py-3 pr-4 text-slate-300">{log.apiCallsUsed}</td>
                          <td className="py-3 pr-4 text-slate-400">{formatDuration(log.durationMs)}</td>
                          <td className="py-3 pr-4 text-slate-400">{formatRelativeTime(log.startedAt)}</td>
                          <td className="py-3 max-w-[200px] truncate text-red-400 text-xs">
                            {log.errorMessage ?? "—"}
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
