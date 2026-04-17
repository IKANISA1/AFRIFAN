"use client";

import { useCallback, useEffect, useState } from "react";
import { Target, Trophy, Calendar, Globe } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import {
  getAdminPredictionMarkets,
  getAdminCompetitions,
  getAdminSeasons,
  getAdminFixtures,
  saveAdminPredictionMarket,
  saveAdminCompetition,
  saveAdminSeason,
  saveAdminFixture,
} from "@/lib/data/admin/predictions";
import type {
  AdminPredictionMarket,
  AdminCompetition,
  AdminSeason,
  AdminFixture,
} from "@/lib/data/admin/predictions";

type Tab = "markets" | "fixtures" | "competitions" | "seasons";

const tabs: { key: Tab; label: string; icon: typeof Target }[] = [
  { key: "markets", label: "Markets", icon: Target },
  { key: "fixtures", label: "Fixtures", icon: Calendar },
  { key: "competitions", label: "Competitions", icon: Trophy },
  { key: "seasons", label: "Seasons", icon: Globe },
];

export default function AdminPredictionsPage() {
  const { access, client } = useAdminPortal();
  const [activeTab, setActiveTab] = useState<Tab>("markets");
  const [markets, setMarkets] = useState<AdminPredictionMarket[]>([]);
  const [competitions, setCompetitions] = useState<AdminCompetition[]>([]);
  const [seasons, setSeasons] = useState<AdminSeason[]>([]);
  const [fixtures, setFixtures] = useState<AdminFixture[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const [m, c, s, f] = await Promise.all([
        getAdminPredictionMarkets(client, access),
        getAdminCompetitions(client, access),
        getAdminSeasons(client, access),
        getAdminFixtures(client, access),
      ]);
      setMarkets(m);
      setCompetitions(c);
      setSeasons(s);
      setFixtures(f);
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load predictions data.";
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

  async function toggleMarketActive(market: AdminPredictionMarket) {
    if (client == null) return;
    try {
      await saveAdminPredictionMarket(client, access, {
        id: market.id,
        name: market.name,
        isActive: !market.isActive,
      });
      await load();
      showAdminToast(`${market.name} ${market.isActive ? "disabled" : "enabled"}.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Failed to update.", "error");
    }
  }

  async function toggleCompetitionActive(comp: AdminCompetition) {
    if (client == null) return;
    try {
      await saveAdminCompetition(client, access, {
        id: comp.id,
        name: comp.name,
        isActive: !comp.isActive,
      });
      await load();
      showAdminToast(`${comp.name} ${comp.isActive ? "disabled" : "enabled"}.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Failed to update.", "error");
    }
  }

  async function updateFixtureStatus(fixture: AdminFixture, status: string) {
    if (client == null) return;
    try {
      await saveAdminFixture(client, access, { id: fixture.id, status });
      await load();
      showAdminToast(`${fixture.homeTeamShortName} vs ${fixture.awayTeamShortName} → ${status}.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Failed to update fixture.", "error");
    }
  }

  function formatKickoff(iso: string) {
    try {
      return new Intl.DateTimeFormat("en-US", {
        month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
      }).format(new Date(iso));
    } catch { return iso; }
  }

  function statusTone(status: string) {
    switch (status) {
      case "completed": case "finished": return "success" as const;
      case "live": case "in_progress": return "accent" as const;
      case "postponed": case "cancelled": return "warning" as const;
      default: return "neutral" as const;
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader eyebrow="Platform" title="Predictions" />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard label="Markets" value={loading ? "..." : markets.length.toString()} helper="Bet types." icon={Target} />
        <AdminStateCard label="Competitions" value={loading ? "..." : competitions.length.toString()} helper="Leagues & cups." icon={Trophy} />
        <AdminStateCard label="Seasons" value={loading ? "..." : seasons.length.toString()} helper="Active seasons." icon={Globe} />
        <AdminStateCard label="Fixtures" value={loading ? "..." : fixtures.length.toString()} helper="Scheduled matches." icon={Calendar} />
      </div>

      {/* Tab bar */}
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
          <AdminErrorState title="Data could not be loaded" description={loadError} onRetry={() => { load().catch(() => {}); }} />
        ) : (
          <>
            {/* Markets tab */}
            {activeTab === "markets" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Prediction Markets ({markets.length})</p>
                {markets.length === 0 ? <p className="text-sm text-slate-400">No prediction markets found.</p> : null}
                <div className="space-y-2">
                  {markets.map((market) => (
                    <div key={market.id} className={cn("flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition", market.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-white truncate">{market.name}</p>
                        <p className="text-xs text-slate-400 mt-0.5">{market.marketCategory} · {market.betType} · {market.difficultyTier} · {market.defaultFetValue} FET</p>
                        {market.leagueAvailability.length > 0 && (
                          <div className="mt-2 flex flex-wrap gap-1">
                            {market.leagueAvailability.map((league) => (
                              <span key={league} className="rounded-full border border-border-soft px-2 py-0.5 text-[10px] text-slate-400">{league}</span>
                            ))}
                          </div>
                        )}
                      </div>
                      <AdminStatusBadge label={market.isActive ? "Active" : "Disabled"} tone={market.isActive ? "success" : "neutral"} />
                      <button type="button" onClick={() => { toggleMarketActive(market).catch(() => {}); }} className="rounded-full border border-border-soft px-3 py-1.5 text-xs font-semibold text-slate-300 hover:bg-white/8 transition">
                        {market.isActive ? "Disable" : "Enable"}
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Fixtures tab */}
            {activeTab === "fixtures" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Fixtures ({fixtures.length})</p>
                {fixtures.length === 0 ? <p className="text-sm text-slate-400">No fixtures found.</p> : null}
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-border-soft text-left text-xs uppercase tracking-wider text-slate-500">
                        <th className="pb-3 pr-4">Match</th>
                        <th className="pb-3 pr-4">Competition</th>
                        <th className="pb-3 pr-4">Kickoff</th>
                        <th className="pb-3 pr-4">Score</th>
                        <th className="pb-3 pr-4">Status</th>
                        <th className="pb-3">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {fixtures.map((fixture) => (
                        <tr key={fixture.id} className="border-b border-border-soft/50 hover:bg-white/[0.03] transition">
                          <td className="py-3 pr-4">
                            <span className="font-semibold text-white">{fixture.homeTeamShortName}</span>
                            <span className="text-slate-500 mx-1">vs</span>
                            <span className="font-semibold text-white">{fixture.awayTeamShortName}</span>
                          </td>
                          <td className="py-3 pr-4 text-slate-400">{fixture.competitionName}</td>
                          <td className="py-3 pr-4 text-slate-400">{formatKickoff(fixture.kickoffAt)}</td>
                          <td className="py-3 pr-4">
                            {fixture.homeScore != null ? (
                              <span className="font-bold text-white">{fixture.homeScore} - {fixture.awayScore}</span>
                            ) : (
                              <span className="text-slate-500">—</span>
                            )}
                          </td>
                          <td className="py-3 pr-4">
                            <AdminStatusBadge label={fixture.status} tone={statusTone(fixture.status)} />
                          </td>
                          <td className="py-3">
                            <select
                              value={fixture.status}
                              onChange={(e) => { updateFixtureStatus(fixture, e.target.value).catch(() => {}); }}
                              className="rounded-lg border border-border-soft bg-transparent px-2 py-1 text-xs text-slate-300 outline-none"
                            >
                              <option value="scheduled">Scheduled</option>
                              <option value="live">Live</option>
                              <option value="completed">Completed</option>
                              <option value="postponed">Postponed</option>
                              <option value="cancelled">Cancelled</option>
                            </select>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Competitions tab */}
            {activeTab === "competitions" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Competitions ({competitions.length})</p>
                {competitions.length === 0 ? <p className="text-sm text-slate-400">No competitions found.</p> : null}
                <div className="grid gap-3 sm:grid-cols-2">
                  {competitions.map((comp) => (
                    <div key={comp.id} className={cn("rounded-[22px] border border-border-soft p-4 transition", comp.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="font-semibold text-white truncate">{comp.name}</p>
                          <p className="text-xs text-slate-400 mt-0.5">{comp.shortName} · {comp.competitionKind} · {comp.countryName || comp.region}</p>
                        </div>
                        <div className="flex items-center gap-2 shrink-0">
                          <AdminStatusBadge label={comp.isActive ? "Active" : "Disabled"} tone={comp.isActive ? "success" : "neutral"} />
                          <button type="button" onClick={() => { toggleCompetitionActive(comp).catch(() => {}); }} className="rounded-full border border-border-soft px-2.5 py-1 text-[10px] font-semibold text-slate-400 hover:bg-white/8 transition">
                            {comp.isActive ? "Disable" : "Enable"}
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Seasons tab */}
            {activeTab === "seasons" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Seasons ({seasons.length})</p>
                {seasons.length === 0 ? <p className="text-sm text-slate-400">No seasons found.</p> : null}
                <div className="space-y-2">
                  {seasons.map((season) => (
                    <div key={season.id} className={cn("flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition", season.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-white">{season.competitionName} — {season.label}</p>
                        <p className="text-xs text-slate-400 mt-0.5">{season.startsOn} → {season.endsOn} · {season.status}</p>
                      </div>
                      <AdminStatusBadge label={season.status} tone={season.status === "active" ? "success" : "neutral"} />
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </section>
    </div>
  );
}
