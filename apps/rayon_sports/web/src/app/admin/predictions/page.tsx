"use client";

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent,
} from "react";
import {
  Target,
  Trophy,
  Calendar,
  Globe,
  Handshake,
  Search,
} from "lucide-react";
import { FixtureTeams } from "@/components/team-card";
import { fixtureInitials } from "@/lib/team-identity";
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
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { cn } from "@/lib/utils";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  getAdminPredictionsWorkspace,
  normalizeAdminPredictionsWorkspace,
  saveAdminPredictionMarket,
  saveAdminCompetition,
} from "@/lib/data/admin/predictions";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type {
  AdminPredictionMarket,
  AdminCompetition,
  AdminFixture,
  AdminPredictionsWorkspace,
} from "@/lib/data/admin/predictions";
import {
  saveAdminPartnerPredictionPool,
  settleAdminPartnerPredictionPool,
} from "@/lib/data/admin/partner-pools";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import type { AdminPartnerPredictionPool } from "@/lib/data/admin/partner-pools";

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

const emptyWorkspace: AdminPredictionsWorkspace = {
  markets: [],
  competitions: [],
  seasons: [],
  fixtures: [],
  partnerPools: [],
  partners: [],
};

const workspaceIsEmpty = (workspace: AdminPredictionsWorkspace) =>
  workspace.markets.length === 0 &&
  workspace.competitions.length === 0 &&
  workspace.seasons.length === 0 &&
  workspace.fixtures.length === 0 &&
  workspace.partnerPools.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading prediction operations",
    detail: "Waiting for the first authenticated, bounded workspace snapshot.",
  },
  ready: {
    label: "Prediction workspace confirmed",
    detail:
      "Templates, football sources, partners, and club pools are current.",
  },
  empty: {
    label: "No prediction records in this scope",
    detail:
      "Pool creation remains locked until a partner and upcoming fixture exist.",
  },
  error: {
    label: "Prediction workspace unavailable",
    detail:
      "Confirmed records remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Prediction workspace is offline",
    detail: "Confirmed records remain visible; all changes are locked.",
  },
  permission_denied: {
    label: "Prediction access denied",
    detail:
      "Records, filters, selection, fixture details, and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing prediction operations",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Prediction data changed",
    detail: "Review the refreshed source before restarting the change.",
  },
  security_timeout: {
    label: "Prediction request timed out",
    detail:
      "No operation was confirmed. Retry from the latest retained snapshot.",
  },
};

export default function AdminPredictionsPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const [activeTab, setActiveTab] = useState<Tab>("partnerPools");
  const [poolForm, setPoolForm] = useState(defaultPoolForm);
  const [poolIdempotencyKey, setPoolIdempotencyKey] = useState(
    () => `admin-partner-pool:${crypto.randomUUID()}`,
  );
  const [submittingPool, setSubmittingPool] = useState(false);
  const [detailFixture, setDetailFixture] = useState<AdminFixture | null>(null);
  const [mutationPending, setMutationPending] = useState(false);
  const denialClearedRef = useRef(false);

  const loadWorkspace = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyWorkspace;
      return getAdminPredictionsWorkspace(client, access, { signal });
    },
    [access, client],
  );

  const {
    data: workspace,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyWorkspace,
    isEmpty: workspaceIsEmpty,
    load: loadWorkspace,
    normalize: normalizeAdminPredictionsWorkspace,
    resourceLabel: "prediction operations",
  });

  const {
    markets,
    competitions,
    seasons,
    fixtures,
    partnerPools,
    partners: partnerOptions,
  } = workspace;
  const mutationLocked =
    mutationPending ||
    submittingPool ||
    (status !== "ready" && status !== "empty");
  const globalMutationLocked = mutationLocked || !access.isSuperAdmin;
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  const fixtureCollection = useAdminCollection({
    records: workspace.fixtures,
    getId: (fixture) => fixture.id,
    getSearchValues: (fixture) => [
      fixture.homeTeamShortName,
      fixture.awayTeamShortName,
      fixture.competitionName,
      fixture.status,
    ],
    getSortValue: (
      fixture,
      key: "match" | "competition" | "kickoff" | "status",
    ) => {
      switch (key) {
        case "match":
          return `${fixture.homeTeamShortName} ${fixture.awayTeamShortName}`;
        case "competition":
          return fixture.competitionName;
        case "kickoff":
          return new Date(fixture.kickoffAt);
        case "status":
          return fixture.status;
      }
    },
    initialSortKey: "kickoff" as const,
    initialSortDirection: "ascending",
    pageSize: 25,
  });
  const poolCollection = useAdminCollection({
    records: workspace.partnerPools,
    getId: (pool) => pool.id,
    getSearchValues: (pool) => [
      pool.title,
      pool.partnerName,
      pool.status,
      pool.eligibilityMode,
      pool.fixtureId,
    ],
    getSortValue: (
      pool,
      key: "title" | "partner" | "status" | "stake" | "entries",
    ) => {
      switch (key) {
        case "title":
          return pool.title;
        case "partner":
          return pool.partnerName;
        case "status":
          return pool.status;
        case "stake":
          return pool.partnerStakeFet;
        case "entries":
          return pool.totalEntries;
      }
    },
    initialSortKey: "title" as const,
    pageSize: 25,
  });
  const marketCollection = useAdminCollection({
    records: workspace.markets,
    getId: (market) => market.id,
    getSearchValues: (market) => [
      market.name,
      market.marketCategory,
      market.difficultyTier,
      market.leagueAvailability.join(" "),
      market.isActive ? "active" : "disabled",
    ],
    getSortValue: (
      market,
      key: "name" | "category" | "difficulty" | "value" | "status",
    ) => {
      switch (key) {
        case "name":
          return market.name;
        case "category":
          return market.marketCategory;
        case "difficulty":
          return market.difficultyTier;
        case "value":
          return market.defaultFetValue;
        case "status":
          return market.isActive;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });
  const competitionCollection = useAdminCollection({
    records: workspace.competitions,
    getId: (competition) => competition.id,
    getSearchValues: (competition) => [
      competition.name,
      competition.shortName,
      competition.competitionKind,
      competition.countryName,
      competition.region,
      competition.isActive ? "active" : "disabled",
    ],
    getSortValue: (competition, key: "name" | "kind" | "region" | "status") => {
      switch (key) {
        case "name":
          return competition.name;
        case "kind":
          return competition.competitionKind;
        case "region":
          return competition.countryName || competition.region;
        case "status":
          return competition.isActive;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });
  const seasonCollection = useAdminCollection({
    records: workspace.seasons,
    getId: (season) => season.id,
    getSearchValues: (season) => [
      season.competitionName,
      season.label,
      season.status,
      season.startsOn,
      season.endsOn,
      season.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      season,
      key: "competition" | "label" | "start" | "end" | "status",
    ) => {
      switch (key) {
        case "competition":
          return season.competitionName;
        case "label":
          return season.label;
        case "start":
          return season.startsOn ? new Date(season.startsOn) : null;
        case "end":
          return season.endsOn ? new Date(season.endsOn) : null;
        case "status":
          return season.status;
      }
    },
    initialSortKey: "start" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  const fixtureById = useMemo(() => {
    const map = new Map<string, AdminFixture>();
    fixtures.forEach((fixture) => {
      map.set(fixture.id, fixture);
    });
    return map;
  }, [fixtures]);

  const upcomingFixtures = useMemo(
    () => fixtures.filter((fixture) => fixture.status === "scheduled"),
    [fixtures],
  );

  useEffect(() => {
    if (status !== "permission_denied") {
      denialClearedRef.current = false;
      return;
    }
    if (denialClearedRef.current) return;
    denialClearedRef.current = true;
    setActiveTab("partnerPools");
    setPoolForm(defaultPoolForm);
    setPoolIdempotencyKey(`admin-partner-pool:${crypto.randomUUID()}`);
    setSubmittingPool(false);
    setMutationPending(false);
    setDetailFixture(null);
    setInteraction("idle");
    fixtureCollection.setQuery("");
    poolCollection.setQuery("");
    marketCollection.setQuery("");
    competitionCollection.setQuery("");
    seasonCollection.setQuery("");
  }, [
    competitionCollection,
    fixtureCollection,
    marketCollection,
    poolCollection,
    seasonCollection,
    status,
  ]);

  async function toggleMarketActive(market: AdminPredictionMarket) {
    if (client == null || globalMutationLocked) return;
    setMutationPending(true);
    try {
      await saveAdminPredictionMarket(client, access, {
        id: market.id,
        expectedUpdatedAt: market.updatedAt,
        slug: market.slug,
        name: market.name,
        shortName: market.shortName,
        marketGroup: market.marketGroup,
        marketCategory: market.marketCategory,
        betType: market.betType,
        difficultyTier: market.difficultyTier,
        defaultFetValue: market.defaultFetValue,
        description: market.description,
        isActive: !market.isActive,
        leagueAvailability: market.leagueAvailability,
        sortOrder: market.sortOrder,
      });
      await refresh();
      showAdminToast(
        `${market.name} ${market.isActive ? "disabled" : "enabled"}.`,
        "success",
      );
    } catch (caught) {
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        "Could not confirm the prediction-template change.",
        "error",
      );
    } finally {
      setMutationPending(false);
    }
  }

  async function toggleCompetitionActive(comp: AdminCompetition) {
    if (client == null || globalMutationLocked) return;
    setMutationPending(true);
    try {
      await saveAdminCompetition(client, access, {
        id: comp.id,
        expectedUpdatedAt: comp.updatedAt,
        slug: comp.slug,
        name: comp.name,
        shortName: comp.shortName,
        competitionKind: comp.competitionKind,
        region: comp.region,
        countryCode: comp.countryCode,
        countryName: comp.countryName,
        isActive: !comp.isActive,
      });
      await refresh();
      showAdminToast(
        `${comp.name} ${comp.isActive ? "disabled" : "enabled"}.`,
        "success",
      );
    } catch (caught) {
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast("Could not confirm the competition change.", "error");
    } finally {
      setMutationPending(false);
    }
  }

  async function handleCreatePartnerPool(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (client == null || mutationLocked) return;
    const partnerStakeFet = Number(poolForm.partnerStakeFet);
    const fanEntryFet = Number(poolForm.fanEntryFet);
    const maxEntries = poolForm.maxEntries ? Number(poolForm.maxEntries) : null;
    if (
      !poolForm.partnerId ||
      !poolForm.fixtureId ||
      !poolForm.title.trim() ||
      poolForm.title.trim().length > 160 ||
      !Number.isInteger(partnerStakeFet) ||
      partnerStakeFet <= 0 ||
      !Number.isInteger(fanEntryFet) ||
      fanEntryFet <= 0 ||
      (maxEntries != null && (!Number.isInteger(maxEntries) || maxEntries <= 0))
    ) {
      showAdminToast(
        "Choose a partner and upcoming fixture, use a title within 160 characters, and enter positive whole-number FET values.",
        "error",
      );
      return;
    }

    setSubmittingPool(true);
    try {
      await saveAdminPartnerPredictionPool(client, access, {
        partnerId: poolForm.partnerId,
        fixtureId: poolForm.fixtureId,
        title: poolForm.title,
        partnerStakeFet,
        fanEntryFet,
        eligibilityMode: poolForm.eligibilityMode as
          "open_to_all" | "partner_earn_required" | "initiative_earn_required",
        maxEntries,
        idempotencyKey: poolIdempotencyKey,
      });
      setPoolForm(defaultPoolForm);
      setPoolIdempotencyKey(`admin-partner-pool:${crypto.randomUUID()}`);
      await refresh();
      showAdminToast("Partner WDW pool created.", "success");
    } catch (caught) {
      applyFailure(caught);
      showAdminToast("Could not confirm partner-pool creation.", "error");
    } finally {
      setSubmittingPool(false);
    }
  }

  async function settlePartnerPool(pool: AdminPartnerPredictionPool) {
    if (client == null || mutationLocked) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Settle",
        subject: pool.title,
        scope: `${pool.partnerName} · ${pool.totalEntries} confirmed entries`,
        impact:
          "The official fixture result will be applied and eligible rewards or refunds may be posted.",
        undo: "not_available",
      })
    ) {
      return;
    }
    setMutationPending(true);
    try {
      await settleAdminPartnerPredictionPool(client, access, pool.id);
      await refresh();
      showAdminToast("Partner-pool settlement confirmed.", "success");
    } catch (caught) {
      applyFailure(caught);
      showAdminToast("Could not confirm partner-pool settlement.", "error");
    } finally {
      setMutationPending(false);
    }
  }

  function formatKickoff(iso: string) {
    try {
      return new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      }).format(new Date(iso));
    } catch {
      return iso;
    }
  }

  function statusTone(status: string) {
    switch (status) {
      case "completed":
      case "finished":
        return "success" as const;
      case "live":
      case "in_progress":
        return "accent" as const;
      case "postponed":
      case "cancelled":
        return "warning" as const;
      default:
        return "neutral" as const;
    }
  }

  return (
    <div
      className="admin-predictions-state-surface section-grid min-w-0 max-w-full"
      data-admin-predictions-status={status}
      data-admin-predictions-interaction={interaction}
      data-admin-predictions-refresh-disabled={busy}
      data-admin-predictions-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Platform"
        title="Predictions"
        meta={
          <span className="admin-meta-chip">
            Club pools · governed platform sources
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh prediction operations"
        selected={interaction === "selected"}
        onRefresh={() => {
          void refresh();
        }}
        onInteractionChange={setInteraction}
      />

      <div className="admin-predictions-metrics-grid grid gap-5 sm:grid-cols-2 xl:grid-cols-5">
        <AdminStateCard
          label="WDW pools"
          value={initialLoading ? "..." : partnerPools.length.toString()}
          helper="Partner-funded."
          icon={Handshake}
          tone="accent"
        />
        <AdminStateCard
          label="Templates"
          value={initialLoading ? "..." : markets.length.toString()}
          helper="Prediction catalog."
          icon={Target}
        />
        <AdminStateCard
          label="Competitions"
          value={initialLoading ? "..." : competitions.length.toString()}
          helper="Leagues & cups."
          icon={Trophy}
        />
        <AdminStateCard
          label="Seasons"
          value={initialLoading ? "..." : seasons.length.toString()}
          helper="Active seasons."
          icon={Globe}
        />
        <AdminStateCard
          label="Fixtures"
          value={initialLoading ? "..." : fixtures.length.toString()}
          helper="Scheduled matches."
          icon={Calendar}
        />
      </div>

      {hasConfirmed && !access.isSuperAdmin ? (
        <p className="admin-predictions-scope-note" role="note">
          Club administrators can create and settle club partner pools.
          Platform-owned templates, competitions, and fixture status remain
          read-only.
        </p>
      ) : null}

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={() => {
            void refresh();
          }}
        />
      ) : initialLoading ? (
        <AdminSurface
          title="Loading prediction workspace"
          className="admin-predictions-workspace"
        >
          <div className="space-y-4" role="group" aria-label="Loading prediction records">
            {Array.from({ length: 5 }).map((_, i) => (
              <div
                key={i}
                className="rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        </AdminSurface>
      ) : (
        <>
          <div
            className="admin-predictions-tabs flex flex-wrap gap-2"
            role="group"
            aria-label="Prediction workspace sections"
          >
            {tabs.map((tab) => {
              const Icon = tab.icon;
              const selected = activeTab === tab.key;
              return (
                <button
                  key={tab.key}
                  type="button"
                  aria-pressed={selected}
                  onClick={() => {
                    setActiveTab(tab.key);
                    setInteraction("selected");
                  }}
                  className="admin-predictions-tab"
                >
                  <Icon size={17} aria-hidden="true" />
                  {tab.label}
                </button>
              );
            })}
          </div>

          <section className="admin-predictions-workspace ui-panel min-w-0 rounded-[32px] p-4 sm:p-6">
            <>
              {/* Partner pools tab */}
              {activeTab === "partnerPools" && (
                <div className="space-y-6">
                  <div>
                    <p className="font-display text-2xl font-medium normal-case">
                      Partner WDW Pools ({partnerPools.length})
                    </p>
                    <p className="mt-1 text-sm text-[var(--admin-text-muted)]">
                      Partner-funded football result pools using fixed fan entry
                      FET. Pick either team to win or choose a draw.
                    </p>
                  </div>

                  <form
                    onSubmit={handleCreatePartnerPool}
                    className="grid gap-4 rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)] p-5"
                  >
                    <div className="grid gap-4 lg:grid-cols-2">
                      <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                        Partner
                        <select
                          required
                          disabled={mutationLocked}
                          value={poolForm.partnerId}
                          onChange={(event) =>
                            setPoolForm((current) => ({
                              ...current,
                              partnerId: event.target.value,
                            }))
                          }
                          className="dashboard-input"
                        >
                          <option value="">Select partner</option>
                          {partnerOptions.map((partner) => (
                            <option key={partner.id} value={partner.id}>
                              {partner.name}
                            </option>
                          ))}
                        </select>
                      </label>

                      <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                        Fixture
                        <select
                          required
                          disabled={mutationLocked}
                          value={poolForm.fixtureId}
                          onChange={(event) =>
                            setPoolForm((current) => ({
                              ...current,
                              fixtureId: event.target.value,
                            }))
                          }
                          className="dashboard-input"
                        >
                          <option value="">Select upcoming fixture</option>
                          {upcomingFixtures.map((fixture) => (
                            <option key={fixture.id} value={fixture.id}>
                              {fixtureInitials(fixture.homeTeamName, fixture.awayTeamName)}{" "}
                              · {formatKickoff(fixture.kickoffAt)}
                            </option>
                          ))}
                        </select>
                      </label>
                    </div>

                    <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                      Pool title
                      <input
                        required
                        disabled={mutationLocked}
                        maxLength={160}
                        value={poolForm.title}
                        onChange={(event) =>
                          setPoolForm((current) => ({
                            ...current,
                            title: event.target.value,
                          }))
                        }
                        className="dashboard-input"
                        placeholder="Partner Derby WDW Pool"
                      />
                    </label>

                    <div className="grid gap-4 md:grid-cols-4">
                      <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                        Partner-funded FET
                        <input
                          required
                          disabled={mutationLocked}
                          type="number"
                          min={1}
                          max={1_000_000_000}
                          value={poolForm.partnerStakeFet}
                          onChange={(event) =>
                            setPoolForm((current) => ({
                              ...current,
                              partnerStakeFet: event.target.value,
                            }))
                          }
                          className="dashboard-input"
                        />
                      </label>
                      <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                        Fan entry FET
                        <input
                          required
                          disabled={mutationLocked}
                          type="number"
                          min={1}
                          max={1_000_000_000}
                          value={poolForm.fanEntryFet}
                          onChange={(event) =>
                            setPoolForm((current) => ({
                              ...current,
                              fanEntryFet: event.target.value,
                            }))
                          }
                          className="dashboard-input"
                        />
                      </label>
                      <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                        Eligibility
                        <select
                          disabled={mutationLocked}
                          value={poolForm.eligibilityMode}
                          onChange={(event) =>
                            setPoolForm((current) => ({
                              ...current,
                              eligibilityMode: event.target.value,
                            }))
                          }
                          className="dashboard-input"
                        >
                          <option value="partner_earn_required">
                            Partner earn required
                          </option>
                          <option value="open_to_all">Open to all fans</option>
                        </select>
                      </label>
                      <label className="grid gap-2 text-sm text-[var(--admin-text-muted)]">
                        Entry limit
                        <input
                          disabled={mutationLocked}
                          type="number"
                          min={1}
                          max={1_000_000_000}
                          value={poolForm.maxEntries}
                          onChange={(event) =>
                            setPoolForm((current) => ({
                              ...current,
                              maxEntries: event.target.value,
                            }))
                          }
                          className="dashboard-input"
                          placeholder="No limit"
                        />
                      </label>
                    </div>

                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <p className="text-xs text-[var(--admin-text-muted)]">
                        Pick either team to win or choose a draw. No multipliers or
                        dynamic odds are used.
                      </p>
                      <button
                        type="submit"
                        disabled={
                          mutationLocked ||
                          partnerOptions.length === 0 ||
                          upcomingFixtures.length === 0
                        }
                        className="admin-button admin-button-primary disabled:opacity-60"
                      >
                        {submittingPool ? "Creating..." : "Create WDW pool"}
                      </button>
                    </div>
                  </form>

                  <AdminFilterBar
                    actions={
                      <div className="flex flex-wrap gap-2">
                        {(
                          [
                            "title",
                            "partner",
                            "status",
                            "stake",
                            "entries",
                          ] as const
                        ).map((key) => (
                          <button
                            key={key}
                            type="button"
                            data-active={poolCollection.sortKey === key}
                            onClick={() => poolCollection.toggleSort(key)}
                            className="dashboard-chip"
                          >
                            Sort {key}
                          </button>
                        ))}
                      </div>
                    }
                  >
                    <label className="admin-search-field">
                      <Search size={16} aria-hidden="true" />
                      <span className="sr-only">
                        Search partner prediction pools
                      </span>
                      <input
                        type="search"
                        value={poolCollection.query}
                        onChange={(event) =>
                          poolCollection.setQuery(event.target.value)
                        }
                        placeholder="Search pool, partner, fixture, eligibility, or status"
                      />
                    </label>
                  </AdminFilterBar>
                  {poolCollection.pageResult.items.length === 0 ? (
                    <p className="rounded-[24px] border border-dashed border-border-soft bg-[var(--admin-surface-muted)] p-5 text-sm text-[var(--admin-text-muted)]">
                      {poolCollection.query
                        ? "No partner WDW pools match the current search."
                        : "No partner WDW pools yet."}
                    </p>
                  ) : null}

                  <div className="space-y-3">
                    {poolCollection.pageResult.items.map((pool) => {
                      const fixture = fixtureById.get(pool.fixtureId);
                      return (
                        <article
                          key={pool.id}
                          className="admin-predictions-pool-card rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)] p-5"
                        >
                          <div className="flex flex-wrap items-start justify-between gap-4">
                            <div className="min-w-0 flex-1">
                              <div className="flex flex-wrap items-center gap-2">
                                <p className="font-semibold text-[var(--admin-text-strong)]">
                                  {pool.title}
                                </p>
                                <AdminStatusBadge
                                  label={pool.status}
                                  tone={statusTone(pool.status)}
                                />
                              </div>
                              <p className="mt-1 text-sm text-[var(--admin-text-muted)]">
                                {pool.partnerName} ·{" "}
                                {fixture
                                  ? fixtureInitials(fixture.homeTeamName, fixture.awayTeamName)
                                  : "Linked fixture unavailable"}
                              </p>
                              <p className="mt-2 text-xs text-[var(--admin-text-muted)]">
                                Partner {pool.partnerStakeFet.toLocaleString()}{" "}
                                pts · Fan entry{" "}
                                {pool.fanEntryFet.toLocaleString()} pts ·{" "}
                                {pool.totalEntries} entries ·{" "}
                                {pool.eligibilityMode.replaceAll("_", " ")}
                              </p>
                              {pool.settlement ? (
                                <p className="mt-2 text-xs text-[var(--admin-text-muted)]">
                                  Result review:{" "}
                                  {pool.settlement.settlementMode.replaceAll(
                                    "_",
                                    " ",
                                  )}{" "}
                                  · credited{" "}
                                  {pool.settlement.totalPaidFet.toLocaleString()}{" "}
                                  pts · ineligible winners{" "}
                                  {pool.settlement.ineligibleWinners}
                                </p>
                              ) : null}
                            </div>
                            <button
                              type="button"
                              onClick={() => {
                                settlePartnerPool(pool).catch(() => {});
                              }}
                              disabled={
                                mutationLocked ||
                                pool.status === "settled" ||
                                pool.status === "void" ||
                                pool.status === "cancelled"
                              }
                              className="admin-button admin-button-secondary disabled:opacity-50"
                            >
                              Settle
                            </button>
                          </div>
                        </article>
                      );
                    })}
                  </div>
                  <AdminPagination
                    page={poolCollection.pageResult}
                    onPageChange={poolCollection.setPage}
                    label="Partner prediction pools"
                  />
                </div>
              )}

              {/* Markets tab */}
              {activeTab === "markets" && (
                <div className="space-y-3">
                  <p className="font-display text-2xl font-medium normal-case">
                    Prediction Templates ({markets.length})
                  </p>
                  <AdminFilterBar
                    actions={
                      <div className="flex flex-wrap gap-2">
                        {(
                          [
                            "name",
                            "category",
                            "difficulty",
                            "value",
                            "status",
                          ] as const
                        ).map((key) => (
                          <button
                            key={key}
                            type="button"
                            data-active={marketCollection.sortKey === key}
                            onClick={() => marketCollection.toggleSort(key)}
                            className="dashboard-chip"
                          >
                            Sort {key}
                          </button>
                        ))}
                      </div>
                    }
                  >
                    <label className="admin-search-field">
                      <Search size={16} aria-hidden="true" />
                      <span className="sr-only">
                        Search prediction templates
                      </span>
                      <input
                        type="search"
                        value={marketCollection.query}
                        onChange={(event) =>
                          marketCollection.setQuery(event.target.value)
                        }
                        placeholder="Search template, league, category, difficulty, or state"
                      />
                    </label>
                  </AdminFilterBar>
                  {marketCollection.pageResult.items.length === 0 ? (
                    <p className="text-sm text-[var(--admin-text-muted)]">
                      {marketCollection.query
                        ? "No prediction templates match the current search."
                        : "No prediction templates found."}
                    </p>
                  ) : null}
                  <div className="space-y-2">
                    {marketCollection.pageResult.items.map((market) => (
                      <div
                        key={market.id}
                        data-inactive={!market.isActive}
                        className={cn(
                          "admin-predictions-catalog-card flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition",
                          market.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
                        )}
                      >
                        <div className="flex-1 min-w-0">
                          <p className="font-semibold text-[var(--admin-text-strong)] truncate">
                            {market.name}
                          </p>
                          <p className="text-xs text-[var(--admin-text-muted)] mt-0.5">
                            {market.marketCategory} · {market.difficultyTier} ·{" "}
                            {market.defaultFetValue} pts
                          </p>
                          {market.leagueAvailability.length > 0 && (
                            <div className="mt-2 flex flex-wrap gap-1">
                              {market.leagueAvailability.map((league) => (
                                <span
                                  key={league}
                                  className="rounded-full border border-border-soft px-2 py-0.5 text-xs text-[var(--admin-text-muted)]"
                                >
                                  {league}
                                </span>
                              ))}
                            </div>
                          )}
                        </div>
                        <AdminStatusBadge
                          label={market.isActive ? "Active" : "Disabled"}
                          tone={market.isActive ? "success" : "neutral"}
                        />
                        <button
                          type="button"
                          onClick={() => {
                            toggleMarketActive(market).catch(() => {});
                          }}
                          disabled={globalMutationLocked}
                          className="admin-predictions-catalog-action rounded-full border border-border-soft px-3 py-2 text-xs font-semibold text-[var(--admin-text-muted)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed"
                        >
                          {market.isActive ? "Disable" : "Enable"}
                        </button>
                      </div>
                    ))}
                  </div>
                  <AdminPagination
                    page={marketCollection.pageResult}
                    onPageChange={marketCollection.setPage}
                    label="Prediction templates"
                  />
                </div>
              )}

              {/* Fixtures tab */}
              {activeTab === "fixtures" && (
                <div className="space-y-3">
                  <p className="font-display text-2xl font-medium normal-case">
                    Fixtures ({fixtures.length})
                  </p>
                  <AdminFilterBar>
                    <label className="admin-search-field">
                      <Search size={16} aria-hidden="true" />
                      <span className="sr-only">Search fixtures</span>
                      <input
                        type="search"
                        value={fixtureCollection.query}
                        onChange={(event) =>
                          fixtureCollection.setQuery(event.target.value)
                        }
                        placeholder="Search teams, competition, or status"
                      />
                    </label>
                  </AdminFilterBar>
                  <p className="mb-4 text-sm text-[var(--admin-text-muted)]">
                    Match status and results are read-only. LiveScore validates and confirms results automatically.
                  </p>
                  <AdminDataGrid
                    caption="Prediction fixtures"
                    onRowActivate={(rowId) => {
                      setDetailFixture(
                        fixtures.find((fixture) => fixture.id === rowId) ??
                          null,
                      );
                      setInteraction("selected");
                    }}
                    columns={[
                      {
                        key: "match",
                        label: "Match",
                        priority: "primary",
                        sortable: true,
                        sortDirection:
                          fixtureCollection.sortDirectionFor("match"),
                        onSort: () => fixtureCollection.toggleSort("match"),
                      },
                      {
                        key: "competition",
                        label: "Competition",
                        priority: "secondary",
                        sortable: true,
                        sortDirection:
                          fixtureCollection.sortDirectionFor("competition"),
                        onSort: () =>
                          fixtureCollection.toggleSort("competition"),
                      },
                      {
                        key: "kickoff",
                        label: "Kickoff",
                        priority: "primary",
                        sortable: true,
                        sortDirection:
                          fixtureCollection.sortDirectionFor("kickoff"),
                        onSort: () => fixtureCollection.toggleSort("kickoff"),
                      },
                      { key: "score", label: "Score", priority: "secondary" },
                      {
                        key: "status",
                        label: "Status",
                        priority: "primary",
                        sortable: true,
                        sortDirection:
                          fixtureCollection.sortDirectionFor("status"),
                        onSort: () => fixtureCollection.toggleSort("status"),
                      },
                      { key: "actions", label: "Actions", priority: "primary" },
                    ]}
                  >
                    {fixtureCollection.pageResult.items.length === 0 ? (
                      <tr>
                        <td
                          colSpan={6}
                          className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                        >
                          {fixtureCollection.query
                            ? "No fixtures match the current search."
                            : "No fixtures found."}
                        </td>
                      </tr>
                    ) : (
                      fixtureCollection.pageResult.items.map((fixture) => (
                        <tr key={fixture.id} data-row-id={fixture.id}>
                          <td className="py-3 pr-4">
                            <FixtureTeams homeTeam={fixture.homeTeamName} awayTeam={fixture.awayTeamName} />
                          </td>
                          <td className="py-3 pr-4 text-[var(--admin-text-muted)]">
                            {fixture.competitionName}
                          </td>
                          <td className="py-3 pr-4 text-[var(--admin-text-muted)]">
                            {formatKickoff(fixture.kickoffAt)}
                          </td>
                          <td className="py-3 pr-4">
                            {fixture.homeScore != null ? (
                              <span className="font-medium text-[var(--admin-text-strong)]">
                                {fixture.homeScore} - {fixture.awayScore}
                              </span>
                            ) : (
                              <span className="text-[var(--admin-text-muted)]">—</span>
                            )}
                          </td>
                          <td className="py-3 pr-4">
                            <AdminStatusBadge
                              label={fixture.status}
                              tone={statusTone(fixture.status)}
                            />
                          </td>
                          <td className="py-3">
                            <button
                              type="button"
                              onClick={() => setDetailFixture(fixture)}
                              className="min-h-12 rounded-full px-3 text-sm text-[var(--admin-text-strong)] hover:bg-[var(--admin-surface-hover)]"
                              aria-label={`View fixture ${fixture.homeTeamShortName} versus ${fixture.awayTeamShortName}`}
                            >
                              View
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </AdminDataGrid>
                  <AdminPagination
                    page={fixtureCollection.pageResult}
                    onPageChange={fixtureCollection.setPage}
                    label="Prediction fixtures"
                  />
                </div>
              )}

              {/* Competitions tab */}
              {activeTab === "competitions" && (
                <div className="space-y-3">
                  <p className="font-display text-2xl font-medium normal-case">
                    Competitions ({competitions.length})
                  </p>
                  <AdminFilterBar
                    actions={
                      <div className="flex flex-wrap gap-2">
                        {(["name", "kind", "region", "status"] as const).map(
                          (key) => (
                            <button
                              key={key}
                              type="button"
                              data-active={
                                competitionCollection.sortKey === key
                              }
                              onClick={() =>
                                competitionCollection.toggleSort(key)
                              }
                              className="dashboard-chip"
                            >
                              Sort {key}
                            </button>
                          ),
                        )}
                      </div>
                    }
                  >
                    <label className="admin-search-field">
                      <Search size={16} aria-hidden="true" />
                      <span className="sr-only">Search competitions</span>
                      <input
                        type="search"
                        value={competitionCollection.query}
                        onChange={(event) =>
                          competitionCollection.setQuery(event.target.value)
                        }
                        placeholder="Search competition, kind, region, or state"
                      />
                    </label>
                  </AdminFilterBar>
                  {competitionCollection.pageResult.items.length === 0 ? (
                    <p className="text-sm text-[var(--admin-text-muted)]">
                      {competitionCollection.query
                        ? "No competitions match the current search."
                        : "No competitions found."}
                    </p>
                  ) : null}
                  <div className="grid gap-3 sm:grid-cols-2">
                    {competitionCollection.pageResult.items.map((comp) => (
                      <div
                        key={comp.id}
                        data-inactive={!comp.isActive}
                        className={cn(
                          "admin-predictions-catalog-card rounded-[22px] border border-border-soft p-4 transition",
                          comp.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
                        )}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="font-semibold text-[var(--admin-text-strong)] truncate">
                              {comp.name}
                            </p>
                            <p className="text-xs text-[var(--admin-text-muted)] mt-0.5">
                              {comp.shortName} · {comp.competitionKind} ·{" "}
                              {comp.countryName || comp.region}
                            </p>
                          </div>
                          <div className="flex items-center gap-2 shrink-0">
                            <AdminStatusBadge
                              label={comp.isActive ? "Active" : "Disabled"}
                              tone={comp.isActive ? "success" : "neutral"}
                            />
                            <button
                              type="button"
                              onClick={() => {
                                toggleCompetitionActive(comp).catch(() => {});
                              }}
                              disabled={globalMutationLocked}
                              className="admin-predictions-catalog-action rounded-full border border-border-soft px-3 py-2 text-xs font-semibold text-[var(--admin-text-muted)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed"
                            >
                              {comp.isActive ? "Disable" : "Enable"}
                            </button>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                  <AdminPagination
                    page={competitionCollection.pageResult}
                    onPageChange={competitionCollection.setPage}
                    label="Competitions"
                  />
                </div>
              )}

              {/* Seasons tab */}
              {activeTab === "seasons" && (
                <div className="space-y-3">
                  <p className="font-display text-2xl font-medium normal-case">
                    Seasons ({seasons.length})
                  </p>
                  <AdminFilterBar
                    actions={
                      <div className="flex flex-wrap gap-2">
                        {(
                          [
                            "competition",
                            "label",
                            "start",
                            "end",
                            "status",
                          ] as const
                        ).map((key) => (
                          <button
                            key={key}
                            type="button"
                            data-active={seasonCollection.sortKey === key}
                            onClick={() => seasonCollection.toggleSort(key)}
                            className="dashboard-chip"
                          >
                            Sort {key}
                          </button>
                        ))}
                      </div>
                    }
                  >
                    <label className="admin-search-field">
                      <Search size={16} aria-hidden="true" />
                      <span className="sr-only">Search seasons</span>
                      <input
                        type="search"
                        value={seasonCollection.query}
                        onChange={(event) =>
                          seasonCollection.setQuery(event.target.value)
                        }
                        placeholder="Search competition, season, date, or status"
                      />
                    </label>
                  </AdminFilterBar>
                  {seasonCollection.pageResult.items.length === 0 ? (
                    <p className="text-sm text-[var(--admin-text-muted)]">
                      {seasonCollection.query
                        ? "No seasons match the current search."
                        : "No seasons found."}
                    </p>
                  ) : null}
                  <div className="space-y-2">
                    {seasonCollection.pageResult.items.map((season) => (
                      <div
                        key={season.id}
                        data-inactive={!season.isActive}
                        className={cn(
                          "admin-predictions-catalog-card flex items-center gap-4 rounded-[22px] border border-border-soft p-4 transition",
                          season.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
                        )}
                      >
                        <div className="flex-1 min-w-0">
                          <p className="font-semibold text-[var(--admin-text-strong)]">
                            {season.competitionName} — {season.label}
                          </p>
                          <p className="text-xs text-[var(--admin-text-muted)] mt-0.5">
                            {season.startsOn ?? "Start not recorded"} →{" "}
                            {season.endsOn ?? "End not recorded"} ·{" "}
                            {season.status}
                          </p>
                        </div>
                        <AdminStatusBadge
                          label={season.status}
                          tone={
                            season.status === "active" ? "success" : "neutral"
                          }
                        />
                      </div>
                    ))}
                  </div>
                  <AdminPagination
                    page={seasonCollection.pageResult}
                    onPageChange={seasonCollection.setPage}
                    label="Competition seasons"
                  />
                </div>
              )}
            </>
          </section>
        </>
      )}
      <AdminActionDrawer
        open={detailFixture != null && status !== "permission_denied"}
        onClose={() => setDetailFixture(null)}
        title="Fixture details"
      >
        {detailFixture ? (
          <dl className="grid gap-4 text-sm">
            <div>
              <dt className="text-[var(--admin-text-muted)]">Match</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                <FixtureTeams homeTeam={detailFixture.homeTeamName} awayTeam={detailFixture.awayTeamName} />
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Competition</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailFixture.competitionName}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Kickoff</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {new Date(detailFixture.kickoffAt).toLocaleString()}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Status</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">{detailFixture.status}</dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Score</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailFixture.homeScore == null
                  ? "Not recorded"
                  : `${detailFixture.homeScore} - ${detailFixture.awayScore}`}
              </dd>
            </div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}
