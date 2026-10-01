import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { AdminFreePredictOperations } from "./admin-free-predict-operations";
import { retainLegacyPredictOperation } from "@/lib/data/admin/predict-free";

const portal = vi.hoisted(() => ({ current: {} as Record<string, unknown> }));
vi.mock("./admin-portal-provider", () => ({ useAdminPortal: () => portal.current }));
const fixtureId = "99900000-0000-4000-8000-000000000001";
const poolId = "99900000-0000-4000-8000-000000000002";
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: false, userId: "operator-a", role: "club_admin", clubId: "24", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1 };
const fixture = { id: fixtureId, pool_id: poolId, competition: "League", home_team: "Home", away_team: "Away", kickoff_at: "2099-10-02T12:00:00Z", fixture_status: "finished", status: "locked", home_score: 1, away_score: 0, stake_fet: 0, entry_count: 3, staked_fet: 0, paid_fet: 0, result_confirmed: true, economics_version: "free_v1", winner_count: 0 };
let rows: unknown[];
let enabled: boolean;
let commands: Record<string, unknown>[];
let mutation: (body: Record<string, unknown>) => unknown;
const snapshot = () => ({ settings: { enabled, entry_fet: 0, welcome_fet: 0, economics_version: "free_v1" }, fixtures: rows });
const json = (data: unknown) => new Response(JSON.stringify({ data }), { status: 200, headers: { "content-type": "application/json" } });

beforeEach(() => {
  rows = [fixture]; enabled = true; commands = [];
  portal.current = { access, client: {} };
  localStorage.clear();
  vi.spyOn(window, "confirm").mockReturnValue(true);
  mutation = (body) => {
    if (body.action === "settings") { enabled = body.enabled as boolean; return { enabled, entry_fet: 0, economics_version: "free_v1" }; }
    return { status: body.voidReason == null ? "settled" : "refunded", paid_fet: 0, winner_count: 0, economics_version: "free_v1" };
  };
  vi.stubGlobal("fetch", vi.fn(async (_url, options?: RequestInit) => {
    if (options?.method !== "POST") return json(snapshot());
    const body = JSON.parse(String(options.body)) as Record<string, unknown>;
    commands.push(body);
    return json(await mutation(body));
  }));
});
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

describe("rendered free prediction review", () => {
  it("shows fixed Free and changes settings with no financial input", async () => {
    render(<AdminFreePredictOperations />);
    await screen.findByText("Entry: Free · Enabled");
    expect(screen.queryByLabelText(/FET/i)).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Disable free predictions" }));
    await screen.findByText("Entry: Free · Disabled");
    expect(commands).toEqual([{ action: "settings", enabled: false }]);
  });

  it("prepares an actual future fixture using a confirmed HTTPS source", async () => {
    rows = [{ ...fixture, fixture_status: "scheduled", pool_id: null, economics_version: null, status: "no_pool", stake_fet: null, entry_count: 0, result_confirmed: false }];
    mutation = (body) => { expect(body).toEqual({ action: "prepare", fixtureId, sourceUrl: "https://league.example/fixture" }); return { id: fixtureId, pool_id: poolId, stake_fet: 0, payout_fet: null, economics_version: "free_v1" }; };
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Prepare free prediction" }));
    const confirm = screen.getByRole("button", { name: "Confirm free preparation" });
    expect(confirm).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Confirmed source URL"), { target: { value: "https://league.example/fixture" } });
    fireEvent.click(confirm);
    await screen.findByText("Free prediction prepared from the confirmed fixture.");
    expect(commands).toHaveLength(1);
  });

  it("confirms the displayed official result with exact existing RPC input names", async () => {
    rows = [{ ...fixture, result_confirmed: false }];
    mutation = (body) => { expect(body).toEqual({ action: "confirm-result", poolId, homeScore: 1, awayScore: 0, sourceUrl: "https://league.example/result" }); return { result: "home", economics_version: "free_v1" }; };
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Manage free prediction" }));
    expect(screen.getByRole("button", { name: "Settle free predictions" })).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Confirmed source URL"), { target: { value: "https://league.example/result" } });
    fireEvent.click(screen.getByRole("button", { name: "Confirm official result" }));
    await screen.findByText("Official prediction result confirmed.");
  });

  it("settles zero winners correctly without claiming a refund or FET award", async () => {
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Manage free prediction" }));
    fireEvent.click(screen.getByRole("button", { name: "Settle free predictions" }));
    await screen.findByText("Free predictions settled.");
    expect(commands).toEqual([{ action: "settle", poolId, voidReason: null }]);
    expect(window.confirm).toHaveBeenCalledWith(expect.stringContaining("No FET is charged or awarded"));
  });

  it("requires an explicit void reason and shows zero financial impact", async () => {
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Manage free prediction" }));
    expect(screen.getByRole("button", { name: "Confirm void" })).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Void reason"), { target: { value: "Fixture cancelled by the league" } });
    fireEvent.click(screen.getByRole("button", { name: "Confirm void" }));
    await screen.findByText("Free predictions marked void.");
    expect(commands[0].voidReason).toBe("Fixture cancelled by the league");
    expect(window.confirm).toHaveBeenCalledWith(expect.stringContaining("No FET is moved"));
  });

  it("does not promote a malformed paid response to free success", async () => {
    mutation = () => ({ status: "settled", paid_fet: 300, winner_count: 1, economics_version: "free_v1" });
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Manage free prediction" }));
    fireEvent.click(screen.getByRole("button", { name: "Settle free predictions" }));
    await screen.findByText("The operation was not confirmed. Refresh the current status before retrying.");
    expect(screen.queryByText("Free predictions settled.")).toBeNull();
    expect(screen.getByRole("button", { name: "Settle free predictions" })).toBeDisabled();
  });

  it("keeps historical liabilities readable without club-admin paid controls", async () => {
    rows = [{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300 }];
    render(<AdminFreePredictOperations />);
    await screen.findByText("Historical paid pool · 300 FET entered · 0 FET reconciled");
    expect(screen.queryByRole("button", { name: /historical/i })).toBeNull();
    expect(screen.queryByRole("button", { name: "Manage free prediction" })).toBeNull();
    expect(commands).toHaveLength(0);
  });

  it("retains the original attributed operation across response loss and relaunch", async () => {
    portal.current = { access: { ...access, isSuperAdmin: true, role: "super_admin" }, client: {} };
    rows = [{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300 }];
    mutation = () => { throw new TypeError("Response lost after commit"); };
    const first = render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Review historical reconciliation" }));
    fireEvent.click(screen.getByRole("button", { name: "Confirm historical settlement" }));
    await screen.findByText(/Its original operation reference is retained/);
    const original = commands[0].operationId;
    expect(original).toMatch(/^[0-9a-f-]{36}$/);
    first.unmount();
    mutation = (body) => ({ status: "settled", paid_fet: 300, winner_count: 1, economics_version: "legacy_paid_v1", operation_id: body.operationId });
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Review historical reconciliation" }));
    fireEvent.click(screen.getByRole("button", { name: "Confirm historical settlement" }));
    await screen.findByText("Historical reconciliation confirmed and attributed to your account.");
    expect(commands).toHaveLength(2);
    expect(commands[1].operationId).toBe(original);
    expect(commands[1]).not.toHaveProperty("actorId");
  });

  it("confirms an unconfirmed historical result separately before settlement", async () => {
    portal.current = { access: { ...access, isSuperAdmin: true, role: "super_admin" }, client: {} };
    rows = [{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300, result_confirmed: false }];
    mutation = (body) => {
      expect(body).toMatchObject({ poolId, homeScore: 1, awayScore: 0, sourceUrl: "https://league.example/result" });
      expect(body).not.toHaveProperty("actorId");
      return { result: "home", economics_version: "legacy_paid_v1", operation_id: body.operationId };
    };
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Review historical reconciliation" }));
    expect(screen.getByRole("button", { name: "Confirm historical settlement" })).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Confirmed source URL"), { target: { value: "https://league.example/result" } });
    fireEvent.click(screen.getByRole("button", { name: "Confirm historical result" }));
    await screen.findByText("Historical result confirmed and attributed to your account. Review settlement separately.");
    expect(commands).toHaveLength(1);
    expect(String(vi.mocked(fetch).mock.calls.find((call) => call[1]?.method === "POST")?.[0])).toContain("predict-legacy-confirm-result");
  });

  it("fails closed when the operation reference cannot be persisted", async () => {
    portal.current = { access: { ...access, isSuperAdmin: true, role: "super_admin" }, client: {} };
    rows = [{ ...fixture, economics_version: "legacy_paid_v1", stake_fet: 100, staked_fet: 300 }];
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("Storage unavailable"); });
    render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Review historical reconciliation" }));
    fireEvent.click(screen.getByRole("button", { name: "Confirm historical settlement" }));
    await screen.findByText(/The reconciliation reference could not be retained/);
    expect(commands).toHaveLength(0);
  });

  it("isolates retained operation IDs by account, club and engine and binds the original reason", () => {
    const original = retainLegacyPredictOperation(access, "predict", poolId, "Fixture cancelled");
    expect(retainLegacyPredictOperation(access, "predict", poolId, "Fixture cancelled")).toBe(original);
    expect(() => retainLegacyPredictOperation(access, "predict", poolId, "Changed void reason")).toThrow();
    expect(retainLegacyPredictOperation({ ...access, userId: "operator-b" }, "predict", poolId, "Fixture cancelled")).not.toBe(original);
    expect(retainLegacyPredictOperation({ ...access, clubId: "25" }, "predict", poolId, "Fixture cancelled")).not.toBe(original);
    expect(retainLegacyPredictOperation(access, "partner", poolId, null)).not.toBe(original);
  });

  it("clears a private review on account switch and ignores the previous late read", async () => {
    const view = render(<AdminFreePredictOperations />);
    fireEvent.click(await screen.findByRole("button", { name: "Manage free prediction" }));
    fireEvent.change(screen.getByLabelText("Void reason"), { target: { value: "Private original scope note" } });
    let release!: (value: Response) => void;
    vi.mocked(fetch).mockImplementationOnce(() => new Promise((resolve) => { release = resolve; }));
    fireEvent.click(screen.getByRole("button", { name: "Close Free prediction review" }));
    fireEvent.click(screen.getByRole("button", { name: "Refresh free prediction status" }));
    portal.current = { access: { ...access, userId: "operator-b", clubId: "25" }, client: {} };
    rows = [];
    view.rerender(<AdminFreePredictOperations />);
    await screen.findByText("No free prediction fixtures available");
    await act(async () => release(json({ settings: { enabled: true, entry_fet: 0, welcome_fet: 0, economics_version: "free_v1" }, fixtures: [fixture] })));
    expect(screen.queryByText("Home versus Away")).toBeNull();
    expect(screen.queryByText("Private original scope note")).toBeNull();
    expect(screen.queryByRole("dialog")).toBeNull();
  });
});
