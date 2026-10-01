// @vitest-environment node
import { createClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { confirmAdminLegacyPredictResultForActor, getAdminFreePredictDashboard, mutateAdminFreePredict, normalizeAdminFreePredictDashboard, settleAdminLegacyPredictForActor } from "./predict-free";

const fixtureId = "99900000-0000-4000-8000-000000000001";
const poolId = "99900000-0000-4000-8000-000000000002";
const operationId = "99900000-0000-4000-8000-000000000003";
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: false, userId: "99900000-0000-4000-8000-000000000004", role: "club_admin", clubId: "24", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1 };
const fixture = { id: fixtureId, pool_id: poolId, competition: "League", home_team: "Home", away_team: "Away", kickoff_at: "2026-10-02T12:00:00Z", fixture_status: "finished", status: "locked", home_score: 1, away_score: 0, stake_fet: 0, entry_count: 3, staked_fet: 0, paid_fet: 0, result_confirmed: true, economics_version: "free_v1", winner_count: 0 };
const snapshot = (rows: unknown[] = [fixture]) => ({ settings: { enabled: true, entry_fet: 0, welcome_fet: 0, economics_version: "free_v1" }, fixtures: rows });
function client(token: string, handle: (name: string, args: Record<string, unknown>) => unknown) {
  const fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    expect(new Headers(init?.headers).get("authorization")).toBe(`Bearer ${token}`);
    const result = handle(String(input).split("/").at(-1)!, JSON.parse(String(init?.body)));
    if (result instanceof Response) return result;
    return new Response(JSON.stringify(result), { status: 200, headers: { "content-type": "application/json" } });
  });
  return { fetch, value: createClient("http://127.0.0.1:54321", "test-anon-key", { global: { fetch, headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } }) };
}
function admission(args: Record<string, unknown>, expectedAction: string, expectedArguments: Record<string, unknown>) {
  expect(args).toEqual({ p_operation_id: operationId, p_action: expectedAction, p_resource_id: poolId, p_arguments: expectedArguments });
  return { operation_id: operationId, actor_id: access.userId, action: expectedAction, resource_id: poolId,
    club_id: 24, status: "admitted", expires_at: new Date(Date.now() + 120_000).toISOString() };
}

describe("free Predict through the actual Supabase HTTP consumer", () => {
  it("requires explicit versions and zero financial settings and totals", () => {
    expect(normalizeAdminFreePredictDashboard(snapshot()).fixtures[0].economicsVersion).toBe("free_v1");
    for (const changed of [{ economics_version: undefined }, { stake_fet: 1 }, { paid_fet: 1 }, { winner_count: 4 }]) {
      expect(() => normalizeAdminFreePredictDashboard(snapshot([{ ...fixture, ...changed }]))).toThrow();
    }
    expect(() => normalizeAdminFreePredictDashboard({ ...snapshot(), settings: { enabled: true, entry_fet: 100, welcome_fet: 500, economics_version: "free_v1" } })).toThrow();
    expect(() => normalizeAdminFreePredictDashboard(snapshot([fixture, fixture]))).toThrow();
  });

  it("retains historical liability amounts with a distinct version", () => {
    const row = normalizeAdminFreePredictDashboard(snapshot([{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300, paid_fet: 200 }])).fixtures[0];
    expect(row.stakedFet).toBe(300);
    expect(row.paidFet).toBe(200);
    expect(row.economicsVersion).toBe("legacy_paid_v1");
  });

  it("reads the selected club and sends fixed zero settings with the caller JWT", async () => {
    const c = client("caller-token", (name, args) => {
      if (name === "predict_admin_dashboard") { expect(args).toEqual({ p_club_id: 24 }); return snapshot(); }
      expect(name).toBe("predict_admin_settings");
      expect(args).toEqual({ p_club_id: 24, p_enabled: false, p_entry_fet: 0 });
      return { enabled: false, entry_fet: 0, economics_version: "free_v1" };
    });
    expect((await getAdminFreePredictDashboard(c.value, access)).fixtures).toHaveLength(1);
    await mutateAdminFreePredict(c.value, access, { action: "settings", enabled: false });
  });

  it("prepares with the existing fixture/source named RPC arguments", async () => {
    const c = client("caller-token", (name, args) => {
      if (name === "predict_admin_dashboard") return snapshot([{ ...fixture, pool_id: null, economics_version: null, status: "no_pool", stake_fet: null, entry_count: 0, winner_count: 0, result_confirmed: false }]);
      expect(name).toBe("predict_admin_prepare");
      expect(args).toEqual({ p_club_id: 24, p_fixture_id: fixtureId, p_source_url: "https://league.example/fixture" });
      return { id: fixtureId, pool_id: poolId, stake_fet: 0, payout_fet: null, economics_version: "free_v1" };
    });
    await mutateAdminFreePredict(c.value, access, { action: "prepare", fixtureId, sourceUrl: "https://league.example/fixture" });
  });

  it("confirms official scores and settles zero-winner free entries without refunding", async () => {
    const c = client("caller-token", (name, args) => {
      if (name === "predict_admin_dashboard") return snapshot();
      if (name === "predict_admin_confirm_result") {
        expect(args).toEqual({ p_pool_id: poolId, p_home_score: 1, p_away_score: 0, p_source_url: "https://league.example/result" });
        return { result: "home", economics_version: "free_v1" };
      }
      expect(args).toEqual({ p_pool_id: poolId, p_void_reason: null });
      return { status: "settled", paid_fet: 0, winner_count: 0, economics_version: "free_v1" };
    });
    await mutateAdminFreePredict(c.value, access, { action: "confirm-result", poolId, homeScore: 1, awayScore: 0, sourceUrl: "https://league.example/result" });
    await mutateAdminFreePredict(c.value, access, { action: "settle", poolId });
  });

  it("rejects foreign and legacy pools before the authenticated write", async () => {
    const c = client("caller-token", (name) => { expect(name).toBe("predict_admin_dashboard"); return snapshot([{ ...fixture, economics_version: "legacy_paid_v1" }]); });
    await expect(mutateAdminFreePredict(c.value, access, { action: "settle", poolId })).rejects.toThrow("unavailable");
    await expect(mutateAdminFreePredict(c.value, access, { action: "settle", poolId: operationId })).rejects.toThrow("unavailable");
    expect(c.fetch).toHaveBeenCalledTimes(2);
  });

  it("rejects invalid identities, sources, scores and void reasons without HTTP calls", async () => {
    const c = client("caller-token", () => ({}));
    await expect(mutateAdminFreePredict(c.value, access, { action: "prepare", fixtureId, sourceUrl: "https://user:secret@league.example" })).rejects.toThrow();
    await expect(mutateAdminFreePredict(c.value, access, { action: "confirm-result", poolId, homeScore: 0.5, awayScore: 0, sourceUrl: "https://league.example" })).rejects.toThrow();
    await expect(mutateAdminFreePredict(c.value, access, { action: "settle", poolId, voidReason: "short" })).rejects.toThrow();
    await expect(mutateAdminFreePredict(c.value, { ...access, isAuthenticated: false }, { action: "settings", enabled: true })).rejects.toThrow();
    expect(c.fetch).not.toHaveBeenCalled();
  });

  it("fails confirmation when a supposedly free receipt pays FET", async () => {
    const c = client("caller-token", (name) => name === "predict_admin_dashboard" ? snapshot() : { status: "settled", paid_fet: 300, winner_count: 1, economics_version: "free_v1" });
    await expect(mutateAdminFreePredict(c.value, access, { action: "settle", poolId })).rejects.toThrow("not confirmed");
  });

  it("attributes historical settlement to actual global access and original operation UUID", async () => {
    const caller = client("caller-token", (name, args) => {
      if (name === "admit_verified_staff_command") return admission(args, "predict_legacy_settle", { void_reason: null });
      expect(name).toBe("predict_admin_dashboard"); return snapshot([{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300 }]);
    });
    const service = client("service-token", (name, args) => {
      expect(name).toBe("predict_admin_settle_for_actor");
      expect(args).toEqual({ p_pool_id: poolId, p_actor_id: access.userId, p_operation_id: operationId, p_void_reason: null });
      return { status: "settled", paid_fet: 300, winner_count: 1, economics_version: "legacy_paid_v1", operation_id: operationId };
    });
    const command = { engine: "predict" as const, poolId, operationId, actorId: "spoofed" };
    const globalAccess: AdminAccess = { ...access, isSuperAdmin: true, role: "super_admin" };
    await settleAdminLegacyPredictForActor(service.value, caller.value, globalAccess, command);
    await settleAdminLegacyPredictForActor(service.value, caller.value, globalAccess, command);
    expect(service.fetch).toHaveBeenCalledTimes(2);
  });

  it("confirms a legacy official result with attributed service args and rejects changed scores", async () => {
    const caller = client("caller-token", (name, args) => name === "admit_verified_staff_command"
      ? admission(args, "predict_legacy_confirm", { home_score: 1, away_score: 0, source_url: "https://league.example/result" })
      : snapshot([{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300, result_confirmed: false }]));
    const service = client("service-token", (name, args) => {
      expect(name).toBe("predict_admin_confirm_result_for_actor");
      expect(args).toEqual({ p_pool_id: poolId, p_actor_id: access.userId, p_operation_id: operationId, p_home_score: 1, p_away_score: 0, p_source_url: "https://league.example/result" });
      return { result: "home", economics_version: "legacy_paid_v1", operation_id: operationId };
    });
    const command = { poolId, operationId, homeScore: 1, awayScore: 0, sourceUrl: "https://league.example/result" };
    const global: AdminAccess = { ...access, isSuperAdmin: true, role: "super_admin" };
    await confirmAdminLegacyPredictResultForActor(service.value, caller.value, global, command);
    await expect(confirmAdminLegacyPredictResultForActor(service.value, caller.value, global, { ...command, awayScore: 1 })).rejects.toThrow("changed");
    expect(service.fetch).toHaveBeenCalledTimes(1);
  });

  it("uses the attributed partner service RPC after caller-scoped historical feed validation", async () => {
    const pool = { id: poolId, club_id: 24, partner_id: fixtureId, partner_name: "Partner", partner_slug: "partner", initiative_id: null, fixture_id: fixtureId, title: "Historical derby", prediction_kind: "wdw", partner_stake_fet: 5000, fan_entry_fet: 100, eligibility_mode: "open_to_all", status: "open", lock_at: "2026-10-01T12:00:00Z", total_entries: 3, total_fan_entry_fet: 300, settlement: null };
    let rows = [pool];
    const caller = client("caller-token", (name, args) => {
      if (name === "admit_verified_staff_command") return admission(args, "partner_legacy_settle", {});
      expect(name).toBe("partner_prediction_pool_feed"); expect(args.p_club_id).toBe(24); return rows;
    });
    const service = client("service-token", (name, args) => {
      expect(name).toBe("partner_prediction_pool_settle_for_actor");
      expect(args).toEqual({ p_pool_id: poolId, p_actor_id: access.userId, p_operation_id: operationId });
      return { ...pool, status: "settled", economics_version: "legacy_paid_v1", operation_id: operationId, metadata: { private: "secret" } };
    });
    const global: AdminAccess = { ...access, isSuperAdmin: true, role: "super_admin" };
    const result = await settleAdminLegacyPredictForActor(service.value, caller.value, global, { engine: "partner", poolId, operationId });
    expect(result).not.toHaveProperty("metadata");
    rows = [{ ...pool, club_id: 25 }];
    await expect(settleAdminLegacyPredictForActor(service.value, caller.value, global, { engine: "partner", poolId, operationId })).rejects.toThrow("selected club");
    expect(service.fetch).toHaveBeenCalledTimes(1);
  });

  it("blocks service use for a normal administrator or a foreign tenant pool", async () => {
    const caller = client("caller-token", () => snapshot([]));
    const service = client("service-token", () => ({}));
    await expect(settleAdminLegacyPredictForActor(service.value, caller.value, access, { engine: "predict", poolId, operationId })).rejects.toThrow("Global");
    await expect(settleAdminLegacyPredictForActor(service.value, caller.value, { ...access, isSuperAdmin: true, role: "super_admin" }, { engine: "predict", poolId, operationId })).rejects.toThrow("selected club");
    expect(service.fetch).not.toHaveBeenCalled();
  });

  it.each(["expired-proof", "foreign-subject", "foreign-tenant", "changed-operation", "changed-action", "expired-receipt"])(
    "denies actual service dispatch when caller admission returns %s", async (failure) => {
      const caller = client("caller-token", (name, args) => {
        if (name !== "admit_verified_staff_command") return snapshot([{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300 }]);
        if (failure === "expired-proof") return new Response(JSON.stringify({ code: "42501", message: "STAFF_COMMAND_ASSURANCE_EXPIRED" }), { status: 403, headers: { "content-type": "application/json" } });
        return { ...admission(args, "predict_legacy_settle", { void_reason: null }),
          ...(failure === "foreign-subject" ? { actor_id: "other-staff" } : {}),
          ...(failure === "foreign-tenant" ? { club_id: 25 } : {}),
          ...(failure === "changed-operation" ? { operation_id: fixtureId } : {}),
          ...(failure === "changed-action" ? { action: "predict_legacy_confirm" } : {}),
          ...(failure === "expired-receipt" ? { expires_at: new Date(Date.now() - 1000).toISOString() } : {}),
        };
      });
      const service = client("service-token", () => ({}));
      await expect(settleAdminLegacyPredictForActor(service.value, caller.value, { ...access, isSuperAdmin: true, role: "super_admin" }, { engine: "predict", poolId, operationId })).rejects.toThrow();
      expect(service.fetch).not.toHaveBeenCalled();
    },
  );
});
