"use client";

import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import { Target, Trophy, Calendar, Globe, Handshake } from "lucide-react";
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
import {
  getAdminPartnerOptions,
  getAdminPartnerPredictionPools,
  saveAdminPartnerPredictionPool,
  settleAdminPartnerPredictionPool,
} from "@/lib/data/admin/partner-pools";
import type {
  AdminPartnerOption,
  AdminPartnerPredictionPool,
} from "@/lib/data/admin/partner-pools";

type Tab = "markets" | "partnerPools" | "fixtures" | "competitions" | "seasons";

const tabs: { key: Tab; label: string; icon: typeof Target }[] = [
  { key: "markets", label: "Templates", icon: Target },
  { key: "partnerPools", label: "Partner Pools", icon: Handshake },
  { key: "fixtures", label: "Fixtures", icon: Calendar },
  { key: "competitions", label: "Competitions", icon: Trophy },
  { key: "seasons", label: "Seasons", icon: Globe },
];

const defaultPoolForm = {
  partnerId: "",
  fixtureId: "",
  title: "",
  partnerStakeFet: "5000",
  fanEntryFet: "100",
  eligibilityMode: "partner_earn_required",
  maxEntries: "",
};

export default function AdminPredictionsPage() {
  const { access, client } = useAdminPortal();
  const [activeTab, setActiveTab] = useState<Tab>("partnerPools");
  const [markets, setMarkets] = useState<AdminPredictionMarket[]>([]);
  const [competitions, setCompetitions] = useState<AdminCompetition[]>([]);
  const [seasons, setSeasons] = useState<AdminSeason[]>([]);
  const [fixtures, setFixtures] = useState<AdminFixture[]>([]);
  const [partnerPools, setPartnerPools] = useState<AdminPartnerPredictionPool[]>([]);
  const [partnerOptions, setPartnerOptions] = useState<AdminPartnerOption[]>([]);
  const [poolForm, setPoolForm] = useState(defaultPoolForm);
  const [submittingPool, setSubmittingPool] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const [m, c, s, f, pools, partners] = await Promise.all([
        getAdminPredictionMarkets(client, access),
        getAdminCompetitions(client, access),
        getAdminSeasons(client, access),
        getAdminFixtures(client, access),
        getAdminPartnerPredictionPools(client, access),
        getAdminPartnerOptions(client, access),
      ]);
      setMarkets(m);
      setCompetitions(c);
      setSeasons(s);
      setFixtures(f);
      setPartnerPools(pools);
      setPartnerOptions(partners);
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load predictions data.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  const fixtureById = useMemo(() => {
    const map = new Map<string, AdminFixture>();
    fixtures.forEach((fixture) => {
      map.set(fixture.id, fixture);
    });
    return map;
  }, [fixtures]);

  const upcomingFixtures = useMemo(
    () =>
      fixtures.filter((fixture) =>
        ["scheduled", "pending"].includes(fixture.status.toLowerCase()),
      ),
    [fixtures],
  );

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

  async function handleCreatePartnerPool(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (client == null) return;

    setSubmittingPool(true);
    try {
      await saveAdminPartnerPredictionPool(client, access, {
        partnerId: poolForm.partnerId,
        fixtureId: poolForm.fixtureId,
        title: poolForm.title,
        partnerStakeFet: Number(poolForm.partnerStakeFet),
        fanEntryFet: Number(poolForm.fanEntryFet),
        eligibilityMode: poolForm.eligibilityMode as "open_to_all" | "partner_earn_required" | "initiative_earn_required",
        maxEntries: poolForm.maxEntries ? Number(poolForm.maxEntries) : null,
        idempotencyKey: `admin-partner-pool:${poolForm.partnerId}:${poolForm.fixtureId}:${poolForm.title.trim().toLowerCase()}`,
      });
      setPoolForm(defaultPoolForm);
      await load();
      showAdminToast("Partner WDW pool created.", "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not create partner pool.", "error");
    } finally {
      setSubmittingPool(false);
    }
  }

  async function settlePartnerPool(pool: AdminPartnerPredictionPool) {
    if (client == null) return;
    try {
      await settleAdminPartnerPredictionPool(client, access, pool.id);
      await load();
      showAdminToast(`${pool.title} settlement refreshed.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not settle partner pool.", "error");
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

      <div className="grid gap-5 md:grid-cols-5">
        <AdminStateCard label="WDW pools" value={loading ? "..." : partnerPools.length.toString()} helper="Partner-funded." icon={Handshake} tone="accent" />
        <AdminStateCard label="Templates" value={loading ? "..." : markets.length.toString()} helper="Prediction catalog." icon={Target} />
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
            {/* Partner pools tab */}
            {activeTab === "partnerPools" && (
              <div className="space-y-6">
                <div>
                  <p className="font-display text-2xl font-bold uppercase">Partner WDW Pools ({partnerPools.length})</p>
                  <p className="mt-1 text-sm text-slate-400">
                    Partner-funded football result pools using fixed fan entry FET and Home win / Draw / Away win picks.
                  </p>
                </div>

                <form onSubmit={handleCreatePartnerPool} className="grid gap-4 rounded-[24px] border border-border-soft bg-white/5 p-5">
                  <div className="grid gap-4 lg:grid-cols-2">
                    <label className="grid gap-2 text-sm text-slate-300">
                      Partner
                      <select
                        required
                        value={poolForm.partnerId}
                        onChange={(event) => setPoolForm((current) => ({ ...current, partnerId: event.target.value }))}
                        className="admin-input"
                      >
                        <option value="">Select partner</option>
                        {partnerOptions.map((partner) => (
                          <option key={partner.id} value={partner.id}>
                            {partner.name}
                          </option>
                        ))}
                      </select>
                    </label>

                    <label className="grid gap-2 text-sm text-slate-300">
                      Fixture
                      <select
                        required
                        value={poolForm.fixtureId}
                        onChange={(event) => setPoolForm((current) => ({ ...current, fixtureId: event.target.value }))}
                        className="admin-input"
                      >
                        <option value="">Select upcoming fixture</option>
                        {upcomingFixtures.map((fixture) => (
                          <option key={fixture.id} value={fixture.id}>
                            {fixture.homeTeamShortName || fixture.homeTeamName} vs {fixture.awayTeamShortName || fixture.awayTeamName} · {formatKickoff(fixture.kickoffAt)}
                          </option>
                        ))}
                      </select>
                    </label>
                  </div>

                  <label className="grid gap-2 text-sm text-slate-300">
                    Pool title
                    <input
                      required
                      value={poolForm.title}
                      onChange={(event) => setPoolForm((current) => ({ ...current, title: event.target.value }))}
                      className="admin-input"
                      placeholder="Partner Derby WDW Pool"
                    />
                  </label>

                  <div className="grid gap-4 md:grid-cols-4">
                    <label className="grid gap-2 text-sm text-slate-300">
                      Partner-funded FET
                      <input
                        required
                        type="number"
                        min={1}
                        value={poolForm.partnerStakeFet}
                        onChange={(event) => setPoolForm((current) => ({ ...current, partnerStakeFet: event.target.value }))}
                        className="admin-input"
                      />
                    </label>
                    <label className="grid gap-2 text-sm text-slate-300">
                      Fan entry FET
                      <input
                        required
                        type="number"
                        min={1}
                        value={poolForm.fanEntryFet}
                        onChange={(event) => setPoolForm((current) => ({ ...current, fanEntryFet: event.target.value }))}
                        className="admin-input"
                      />
                    </label>
                    <label className="grid gap-2 text-sm text-slate-300">
                      Eligibility
                      <select
                        value={poolForm.eligibilityMode}
                        onChange={(event) => setPoolForm((current) => ({ ...current, eligibilityMode: event.target.value }))}
                        className="admin-input"
                      >
                        <option value="partner_earn_required">Partner earn required</option>
                        <option value="open_to_all">Open to all fans</option>
                      </select>
                    </label>
                    <label className="grid gap-2 text-sm text-slate-300">
                      Entry limit
                      <input
                        type="number"
                        min={1}
                        value={poolForm.maxEntries}
                        onChange={(event) => setPoolForm((current) => ({ ...current, maxEntries: event.target.value }))}
                        className="admin-input"
                        placeholder="No limit"
                      />
                    </label>
                  </div>

                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <p className="text-xs text-slate-500">
                      WDW only: Home win, Draw, Away win. No multipliers or dynamic odds are used.
                    </p>
                    <button
                      type="submit"
                      disabled={submittingPool || partnerOptions.length === 0 || upcomingFixtures.length === 0}
                      className="admin-button admin-button-primary disabled:opacity-60"
                    >
                      {submittingPool ? "Creating..." : "Create WDW pool"}
                    </button>
                  </div>
                </form>

                {partnerPools.length === 0 ? (
                  <p className="rounded-[24px] border border-dashed border-border-soft bg-white/5 p-5 text-sm text-slate-400">
                    No partner WDW pools yet.
                  </p>
                ) : null}

                <div className="space-y-3">
                  {partnerPools.map((pool) => {
                    const fixture = fixtureById.get(pool.fixtureId);
                    return (
                      <article key={pool.id} className="rounded-[24px] border border-border-soft bg-white/5 p-5">
                        <div className="flex flex-wrap items-start justify-between gap-4">
                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <p className="font-semibold text-white">{pool.title}</p>
                              <AdminStatusBadge label={pool.status} tone={statusTone(pool.status)} />
                            </div>
                            <p className="mt-1 text-sm text-slate-400">
                              {pool.partnerName} · {fixture ? `${fixture.homeTeamShortName || fixture.homeTeamName} vs ${fixture.awayTeamShortName || fixture.awayTeamName}` : pool.fixtureId}
                            </p>
                            <p className="mt-2 text-xs text-slate-500">
                              Partner {pool.partnerStakeFet.toLocaleString()} pts · Fan entry {pool.fanEntryFet.toLocaleString()} pts · {pool.totalEntries} entries · {pool.eligibilityMode.replaceAll("_", " ")}
                            </p>
                            {pool.settlement ? (
                              <p className="mt-2 text-xs text-slate-400">
                                Result review: {pool.settlement.settlementMode.replaceAll("_", " ")} · credited {pool.settlement.totalPaidFet.toLocaleString()} pts · ineligible winners {pool.settlement.ineligibleWinners}
                              </p>
                            ) : null}
                          </div>
                          <button
                            type="button"
                            onClick={() => { settlePartnerPool(pool).catch(() => {}); }}
                            disabled={pool.status === "settled" || pool.status === "void" || pool.status === "cancelled"}
                            className="admin-button admin-button-secondary disabled:opacity-50"
                          >
                            Settle
                          </button>
                        </div>
                      </article>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Markets tab */}
            {activeTab === "markets" && (
              <div className="space-y-3">
                <p className="font-display text-2xl font-bold uppercase">Prediction Templates ({markets.length})</p>
                {markets.length === 0 ? <p className="text-sm text-slate-400">No prediction templates found.</p> : null}
                <div className="space-y-2">
                  {markets.map((market) => (
                    <div key={market.id} className={cn("flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition", market.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-white truncate">{market.name}</p>
                        <p className="text-xs text-slate-400 mt-0.5">{market.marketCategory} · {market.difficultyTier} · {market.defaultFetValue} pts</p>
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
