"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  getAdminFreePredictDashboard,
  confirmAdminLegacyPredictResultForActor,
  mutateAdminFreePredict,
  retainLegacyPredictOperation,
  retainLegacyPredictResultOperation,
  settleAdminLegacyPredictForActor,
  type AdminFreePredictCommand,
  type AdminFreePredictDashboard,
  type AdminPredictFixture,
} from "@/lib/data/admin/predict-free";
import { AdminActionDrawer } from "./admin-action-drawer";
import { useAdminPortal } from "./admin-portal-provider";
import { AdminResourceStatusBanner } from "./admin-resource-status-banner";
import { AdminStatusBadge } from "./admin-status-badge";
import { AdminSurface } from "./admin-surface";

const emptyDashboard: AdminFreePredictDashboard = { enabled: false, fixtures: [] };
const isEmpty = (value: AdminFreePredictDashboard) => value.fixtures.length === 0;
const confirmedDashboard = (value: unknown) => value as AdminFreePredictDashboard;
const ignoreInteraction = () => {};

export function AdminFreePredictOperations() {
  const { access, client } = useAdminPortal();
  if (!client || !access.hasAccess || !access.isAuthenticated || !access.clubId || !access.userId) return null;
  return <FreePredictOperations key={`${access.userId}:${access.clubId}:${access.role}`} client={client} access={access} />;
}

function FreePredictOperations({ client, access }: { client: SupabaseClient; access: AdminAccess }) {
  const mounted = useRef(true);
  const inFlight = useRef(false);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [sourceUrl, setSourceUrl] = useState("");
  const [voidReason, setVoidReason] = useState("");
  const clearDraft = useCallback(() => {
    setSelectedId(null);
    setSourceUrl("");
    setVoidReason("");
  }, []);
  const load = useCallback((signal: AbortSignal) => getAdminFreePredictDashboard(client, access, signal), [client, access]);
  const { data, status, hasConfirmed, busy, refresh, applyFailure } = useAdminResourceState({
    emptyValue: emptyDashboard, isEmpty, load, normalize: confirmedDashboard,
    onPermissionDenied: clearDraft, resourceLabel: "free prediction operations",
  });
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);
  const locked = pending || !hasConfirmed || (status !== "ready" && status !== "empty");
  const selected = data.fixtures.find((fixture) => fixture.id === selectedId) ?? null;
  const readySource = (() => {
    try { const url = new URL(sourceUrl); return url.protocol === "https:" && !url.username && !url.password; } catch { return false; }
  })();
  const isGlobal = access.isSuperAdmin && access.role === "super_admin";

  async function perform(command: AdminFreePredictCommand, success: string) {
    if (locked || inFlight.current) return;
    inFlight.current = true;
    setPending(true);
    setNotice("");
    try {
      await mutateAdminFreePredict(client, access, command);
      if (!mounted.current) return;
      clearDraft();
      setNotice(success);
      await refresh();
    } catch (error) {
      if (!mounted.current) return;
      applyFailure(error);
      setNotice("The operation was not confirmed. Refresh the current status before retrying.");
    } finally {
      inFlight.current = false;
      if (mounted.current) setPending(false);
    }
  }
  async function settle(fixture: AdminPredictFixture, reason: string | null) {
    if (!fixture.poolId || locked || inFlight.current) return;
    const historical = fixture.economicsVersion === "legacy_paid_v1";
    if (!confirmAdminDestructiveAction({
      action: reason == null ? "Settle" : "Void",
      subject: `${fixture.homeTeam} versus ${fixture.awayTeam}`,
      scope: `${access.clubId} · ${fixture.entryCount} entries · ${historical ? "historical paid liabilities" : "free predictions"}`,
      impact: historical ? "The historical ledger will be reconciled and this command will be attributed to your authenticated global account." :
        reason == null ? "Correct predictions receive one score point. No FET is charged or awarded." : "Entries will be marked void with zero score points. No FET is moved.",
      undo: "not_available",
    })) return;
    if (!historical) {
      await perform({ action: "settle", poolId: fixture.poolId, voidReason: reason }, reason == null ? "Free predictions settled." : "Free predictions marked void.");
      return;
    }
    if (!isGlobal) return;
    inFlight.current = true;
    setPending(true);
    setNotice("");
    let operationId: string | null = null;
    try {
      operationId = retainLegacyPredictOperation(access, "predict", fixture.poolId, reason);
      await settleAdminLegacyPredictForActor(client, client, access, { engine: "predict", poolId: fixture.poolId, operationId, voidReason: reason });
      if (!mounted.current) return;
      clearDraft();
      setNotice("Historical reconciliation confirmed and attributed to your account.");
      await refresh();
    } catch (error) {
      if (!mounted.current) return;
      applyFailure(error);
      setNotice(operationId ? `Historical reconciliation was not confirmed. Its original operation reference is retained; refresh status and retry the same command if needed. Reference: ${operationId}` : "The reconciliation reference could not be retained. No command was sent in this attempt; refresh historical status before continuing.");
    } finally {
      inFlight.current = false;
      if (mounted.current) setPending(false);
    }
  }
  async function confirmHistoricalResult(fixture: AdminPredictFixture) {
    if (locked || inFlight.current || !isGlobal || !fixture.poolId || fixture.homeScore == null || fixture.awayScore == null) return;
    if (!confirmAdminDestructiveAction({ action: "Confirm historical result", subject: `${fixture.homeTeam} versus ${fixture.awayTeam}`,
      scope: `${access.clubId} · official score ${fixture.homeScore}–${fixture.awayScore}`,
      impact: "The official source and immutable scores will be attributed to your global account. Historical settlement requires a separate reviewed command.", undo: "not_available" })) return;
    inFlight.current = true;
    setPending(true);
    let operationId: string | null = null;
    try {
      const command = { poolId: fixture.poolId, homeScore: fixture.homeScore, awayScore: fixture.awayScore, sourceUrl };
      operationId = retainLegacyPredictResultOperation(access, command);
      await confirmAdminLegacyPredictResultForActor(client, client, access, { ...command, operationId });
      if (!mounted.current) return;
      clearDraft();
      setNotice("Historical result confirmed and attributed to your account. Review settlement separately.");
      await refresh();
    } catch (error) {
      if (!mounted.current) return;
      applyFailure(error);
      setNotice(operationId ? `Historical result confirmation was not confirmed. Refresh status and retry the original source and scores if needed. Reference: ${operationId}` : "The result confirmation reference could not be retained. No command was sent in this attempt.");
    } finally {
      inFlight.current = false;
      if (mounted.current) setPending(false);
    }
  }
  const statusLabel = status === "loading" ? "Loading free predictions" : status === "syncing" ? "Refreshing free predictions" :
    status === "ready" ? "Free prediction operations confirmed" : status === "empty" ? "No free prediction fixtures available" :
    status === "permission_denied" ? "Free prediction access denied" : status === "offline" ? "Free prediction operations are offline" : "Free prediction operations unavailable";

  return (
    <AdminSurface title="Free predictions" contentClassName="space-y-5">
      <p className="text-sm text-[var(--admin-text-muted)]">Supporters choose a home win, draw, or away win for free. A correct prediction earns one score point; incorrect and void entries earn zero. There are no entry charges, prizes, or welcome credits.</p>
      <AdminResourceStatusBanner status={status} label={statusLabel}
        detail={status === "permission_denied" ? "The previous scope and draft were cleared." : "Changes use the current authenticated club. Refresh status after an unconfirmed operation."}
        busy={busy || pending} permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh free prediction status" onRefresh={() => { void refresh(); }} onInteractionChange={ignoreInteraction} />
      {notice ? <p role="status" className="text-sm text-[var(--admin-text-muted)]">{notice}</p> : null}
      {hasConfirmed ? (
        <div className="flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm font-medium">Entry: Free · {data.enabled ? "Enabled" : "Disabled"}</p>
          <button type="button" className="ui-button ui-button-secondary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none" disabled={locked}
            onClick={() => { void perform({ action: "settings", enabled: !data.enabled }, "Free prediction availability confirmed."); }}>
            {data.enabled ? "Disable free predictions" : "Enable free predictions"}
          </button>
        </div>
      ) : null}
      <div className="space-y-3">
        {data.fixtures.map((fixture) => {
          const historical = fixture.economicsVersion === "legacy_paid_v1";
          return (
            <article key={fixture.id} className="rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)] p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="min-w-0 space-y-2">
                  <h3 className="font-medium">{fixture.homeTeam} versus {fixture.awayTeam}</h3>
                  <p className="text-sm text-[var(--admin-text-muted)]">{fixture.competition} · {fixture.kickoffAt ? new Date(fixture.kickoffAt).toLocaleString() : "Kickoff unavailable"}</p>
                  <AdminStatusBadge label={fixture.status === "refunded" && !historical ? "Void" : fixture.status.replaceAll("_", " ")} tone="neutral" />
                  <p className="text-sm text-[var(--admin-text-muted)]">{historical ? `Historical paid pool · ${fixture.stakedFet} FET entered · ${fixture.paidFet} FET reconciled` : `Free · ${fixture.entryCount} entries · ${fixture.winnerCount} correct`}</p>
                  {historical ? <p className="text-sm text-[var(--admin-text-muted)]">{fixture.status === "settled" || fixture.status === "refunded" ? "Service reconciliation recorded" : "Awaiting service reconciliation"}</p> : null}
                </div>
                {!historical || isGlobal ? <button type="button" disabled={locked} className="ui-button ui-button-secondary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none"
                  onClick={() => { setSelectedId(fixture.id); setSourceUrl(""); setVoidReason(""); }}>
                  {historical ? "Review historical reconciliation" : fixture.poolId ? "Manage free prediction" : "Prepare free prediction"}
                </button> : null}
              </div>
            </article>
          );
        })}
      </div>
      <AdminActionDrawer open={selected != null} onClose={clearDraft} title={selected?.economicsVersion === "legacy_paid_v1" ? "Historical reconciliation" : "Free prediction review"}>
        {selected ? (
          <div className="space-y-5">
            <p className="font-medium">{selected.homeTeam} versus {selected.awayTeam}</p>
            <p className="text-sm">{selected.economicsVersion === "legacy_paid_v1" ? "This action reconciles historical paid liabilities using the approved service and records your authenticated global identity." : "Entry: Free. Correct: 1 score point. Incorrect or void: 0. No FET moves."}</p>
            {(selected.poolId == null || !selected.resultConfirmed) ? (
              <label className="grid gap-2 text-sm">Confirmed source URL
                <input className="dashboard-input" type="url" maxLength={2000} value={sourceUrl} disabled={locked} onChange={(event) => setSourceUrl(event.target.value)} placeholder="https://" />
              </label>
            ) : null}
            {selected.poolId == null ? (
              <button type="button" className="ui-button ui-button-primary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none" disabled={locked || !readySource || selected.fixtureStatus !== "scheduled" || !selected.kickoffAt || Date.parse(selected.kickoffAt) <= Date.now()}
                onClick={() => { void perform({ action: "prepare", fixtureId: selected.id, sourceUrl }, "Free prediction prepared from the confirmed fixture."); }}>Confirm free preparation</button>
            ) : (
              <>
                <p className="text-sm">Official score: {selected.homeScore ?? "Unconfirmed"} – {selected.awayScore ?? "Unconfirmed"} · {selected.fixtureStatus}</p>
                {!selected.resultConfirmed ? (
                  <button type="button" className="ui-button ui-button-primary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none" disabled={locked || !readySource || selected.fixtureStatus !== "finished" || selected.homeScore == null || selected.awayScore == null || !["open", "locked"].includes(selected.status)}
                    onClick={() => { if (selected.economicsVersion === "legacy_paid_v1") void confirmHistoricalResult(selected); else if (selected.poolId && selected.homeScore != null && selected.awayScore != null) void perform({ action: "confirm-result", poolId: selected.poolId, homeScore: selected.homeScore, awayScore: selected.awayScore, sourceUrl }, "Official prediction result confirmed."); }}>{selected.economicsVersion === "legacy_paid_v1" ? "Confirm historical result" : "Confirm official result"}</button>
                ) : null}
                <button type="button" className="ui-button ui-button-primary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none" disabled={locked || !selected.resultConfirmed || ["settled", "refunded"].includes(selected.status)}
                  onClick={() => { void settle(selected, null); }}>{selected.economicsVersion === "legacy_paid_v1" ? "Confirm historical settlement" : "Settle free predictions"}</button>
                <label className="grid gap-2 text-sm">Void reason
                  <textarea className="dashboard-input" minLength={8} maxLength={500} value={voidReason} disabled={locked} onChange={(event) => setVoidReason(event.target.value)} />
                </label>
                <button type="button" className="ui-button ui-button-secondary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none" disabled={locked || voidReason.trim().length < 8 || ["settled", "refunded"].includes(selected.status)} onClick={() => { void settle(selected, voidReason); }}>Confirm void</button>
              </>
            )}
          </div>
        ) : null}
      </AdminActionDrawer>
    </AdminSurface>
  );
}
