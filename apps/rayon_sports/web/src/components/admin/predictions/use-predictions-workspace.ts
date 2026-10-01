"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useAdminPortal } from "../admin-portal-provider";
import { showAdminToast } from "../admin-toast";
import type { AdminResourceInteraction } from "../admin-resource-status-banner";
import { getAdminPredictionsWorkspace, normalizeAdminPredictionsWorkspace, saveAdminPredictionMarket, saveAdminCompetition, type AdminCompetition, type AdminFixture, type AdminPredictionMarket, type AdminPredictionsWorkspace } from "@/lib/data/admin/predictions";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { useFixtureTab, useHistoricalPoolsTab, usePredictionTemplatesTab, useCompetitionTab, useSeasonTab } from "./use-prediction-tabs";
import type { PredictionTab } from "./prediction-presenters";

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

export function usePredictionsWorkspace() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const [activeTab, setActiveTab] = useState<PredictionTab>("partnerPools");
  const [detailFixture, setDetailFixture] = useState<AdminFixture | null>(null);
  const [mutationPending, setMutationPending] = useState(false);
  const denialClearedRef = useRef(false);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

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
  } = workspace;
  const mutationLocked =
    mutationPending ||
    (status !== "ready" && status !== "empty");
  const globalMutationLocked = mutationLocked || !access.isSuperAdmin;
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  const fixtureCollection = useFixtureTab(workspace.fixtures);
  const poolCollection = useHistoricalPoolsTab(workspace.partnerPools);
  const marketCollection = usePredictionTemplatesTab(workspace.markets);
  const competitionCollection = useCompetitionTab(workspace.competitions);
  const seasonCollection = useSeasonTab(workspace.seasons);

  const fixtureById = useMemo(() => {
    const map = new Map<string, AdminFixture>();
    fixtures.forEach((fixture) => {
      map.set(fixture.id, fixture);
    });
    return map;
  }, [fixtures]);

  useEffect(() => {
    if (status !== "permission_denied") {
      denialClearedRef.current = false;
      return;
    }
    if (denialClearedRef.current) return;
    denialClearedRef.current = true;
    setActiveTab("partnerPools");
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
      if (!mounted.current) return;
      await refresh();
      if (!mounted.current) return;
      showAdminToast(
        `${market.name} ${market.isActive ? "disabled" : "enabled"}.`,
        "success",
      );
    } catch (caught) {
      if (!mounted.current) return;
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      if (!mounted.current) return;
      showAdminToast(
        "Could not confirm the prediction-template change.",
        "error",
      );
    } finally {
      if (mounted.current) setMutationPending(false);
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
      if (!mounted.current) return;
      await refresh();
      if (!mounted.current) return;
      showAdminToast(
        `${comp.name} ${comp.isActive ? "disabled" : "enabled"}.`,
        "success",
      );
    } catch (caught) {
      if (!mounted.current) return;
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      if (!mounted.current) return;
      showAdminToast("Could not confirm the competition change.", "error");
    } finally {
      if (mounted.current) setMutationPending(false);
    }
  }

  return { access, workspace, interaction, setInteraction, activeTab, setActiveTab,
    detailFixture, setDetailFixture, status, hasConfirmed, busy, initialLoading,
    refresh, mutationLocked, globalMutationLocked, unrecoveredFailure,
    markets, competitions, seasons, fixtures, partnerPools, fixtureById,
    fixtureCollection, poolCollection, marketCollection, competitionCollection,
    seasonCollection, toggleMarketActive, toggleCompetitionActive };
}
