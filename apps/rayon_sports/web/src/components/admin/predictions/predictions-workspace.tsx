"use client";

import { Target, Trophy, Calendar, Globe, Handshake } from "lucide-react";
import { AdminErrorState } from "../admin-error-state";
import { AdminPageHeader } from "../admin-page-header";
import { AdminResourceStatusBanner } from "../admin-resource-status-banner";
import { AdminStateCard } from "../admin-state-card";
import { AdminSurface } from "../admin-surface";
import { AdminFreePredictOperations } from "../admin-free-predict-operations";
import { Skeleton } from "@/components/skeleton";
import { statusCopy, type PredictionTab } from "./prediction-presenters";
import { usePredictionsWorkspace } from "./use-predictions-workspace";
import { HistoricalPoolsTab } from "./historical-pools-tab";
import { PredictionTemplatesTab } from "./prediction-templates-tab";
import { PredictionFixturesTab, PredictionFixtureDrawer } from "./prediction-fixtures-tab";
import { CompetitionTab } from "./competition-tab";
import { SeasonTab } from "./season-tab";

const tabs: { key: PredictionTab; label: string; icon: typeof Target }[] = [
  { key: "markets", label: "Templates", icon: Target },
  { key: "partnerPools", label: "Historical pools", icon: Handshake },
  { key: "fixtures", label: "Fixtures", icon: Calendar },
  { key: "competitions", label: "Competitions", icon: Trophy },
  { key: "seasons", label: "Seasons", icon: Globe },
];

export function PredictionsWorkspace() {
  const { access, interaction, setInteraction, activeTab, setActiveTab,
    detailFixture, setDetailFixture, status, hasConfirmed, busy, initialLoading,
    refresh, mutationLocked, globalMutationLocked, unrecoveredFailure,
    markets, competitions, seasons, fixtures, partnerPools, fixtureById,
    fixtureCollection, poolCollection, marketCollection, competitionCollection,
    seasonCollection, toggleMarketActive, toggleCompetitionActive } = usePredictionsWorkspace();

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

      <AdminFreePredictOperations />

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
          label="Historical pools"
          value={initialLoading ? "..." : partnerPools.length.toString()}
          helper="Legacy liabilities."
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
          Club administrators manage free predictions. Historical paid pools require service reconciliation.
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
              {activeTab === "partnerPools" && <HistoricalPoolsTab poolCollection={poolCollection} partnerPools={partnerPools} fixtureById={fixtureById} access={access} mutationLocked={mutationLocked} refresh={refresh} />}

              {/* Markets tab */}
              {activeTab === "markets" && <PredictionTemplatesTab marketCollection={marketCollection} markets={markets} globalMutationLocked={globalMutationLocked} toggleMarketActive={toggleMarketActive} />}

              {/* Fixtures tab */}
              {activeTab === "fixtures" && <PredictionFixturesTab fixtureCollection={fixtureCollection} fixtures={fixtures} setDetailFixture={setDetailFixture} setInteraction={setInteraction} />}

              {/* Competitions tab */}
              {activeTab === "competitions" && <CompetitionTab competitionCollection={competitionCollection} competitions={competitions} globalMutationLocked={globalMutationLocked} toggleCompetitionActive={toggleCompetitionActive} />}

              {/* Seasons tab */}
              {activeTab === "seasons" && <SeasonTab seasonCollection={seasonCollection} seasons={seasons} />}
            </>
          </section>
        </>
      )}
      <PredictionFixtureDrawer detailFixture={detailFixture} setDetailFixture={setDetailFixture} permissionDenied={status === "permission_denied"} />
    </div>
  );
}
