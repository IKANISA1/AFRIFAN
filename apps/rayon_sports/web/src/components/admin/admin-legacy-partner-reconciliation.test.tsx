import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import type { AdminPartnerPredictionPool } from "@/lib/data/admin/partner-pools";
import { AdminLegacyPartnerReconciliation } from "./admin-legacy-partner-reconciliation";

const portal = vi.hoisted(() => ({ current: {} as Record<string, unknown> }));
vi.mock("./admin-portal-provider", () => ({ useAdminPortal: () => portal.current }));
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: true, userId: "global-actor", role: "super_admin", clubId: "24", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1 };
const pool: AdminPartnerPredictionPool = { id: "99900000-0000-4000-8000-000000000002", clubId: 24, partnerId: "partner", partnerName: "Partner", partnerSlug: "partner", initiativeId: null, fixtureId: "fixture", title: "Historical derby", predictionKind: "wdw", partnerStakeFet: 5000, fanEntryFet: 100, eligibilityMode: "open_to_all", status: "locked", lockAt: "2026-10-01T12:00:00Z", totalEntries: 3, totalFanEntryFet: 300, settlement: null };
beforeEach(() => {
  portal.current = { access, client: {} };
  localStorage.clear();
  vi.spyOn(window, "confirm").mockReturnValue(true);
});
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

it("uses the reachable global partner command and retains the same operation through response loss", async () => {
  const commands: Record<string, unknown>[] = [];
  let loseResponse = true;
  vi.stubGlobal("fetch", vi.fn(async (url, options?: RequestInit) => {
    expect(String(url)).toContain("/api/admin/predict-legacy-settlement");
    const body = JSON.parse(String(options?.body));
    commands.push(body);
    if (loseResponse) throw new TypeError("Response lost");
    return new Response(JSON.stringify({ data: { ...pool, status: "settled", operation_id: body.operationId, economics_version: "legacy_paid_v1" } }), { status: 200, headers: { "content-type": "application/json" } });
  }));
  const onConfirmed = vi.fn(async () => {});
  const first = render(<AdminLegacyPartnerReconciliation pool={pool} disabled={false} onConfirmed={onConfirmed} />);
  fireEvent.click(screen.getByRole("button", { name: "Reconcile historical partner pool" }));
  await screen.findByText(/Original reference:/);
  const operation = commands[0].operationId;
  expect(onConfirmed).not.toHaveBeenCalled();
  first.unmount();
  loseResponse = false;
  render(<AdminLegacyPartnerReconciliation pool={pool} disabled={false} onConfirmed={onConfirmed} />);
  fireEvent.click(screen.getByRole("button", { name: "Reconcile historical partner pool" }));
  await screen.findByText(/Historical reconciliation confirmed/);
  expect(commands[1]).toEqual({ engine: "partner", poolId: pool.id, operationId: operation });
  expect(onConfirmed).toHaveBeenCalledTimes(1);
  expect(window.confirm).toHaveBeenCalledWith(expect.stringContaining("Historical rewards and refunds may be posted"));
});

it("hides partner service commands for ordinary club administrators", () => {
  portal.current = { access: { ...access, isSuperAdmin: false, role: "club_admin" }, client: {} };
  render(<AdminLegacyPartnerReconciliation pool={pool} disabled={false} onConfirmed={async () => {}} />);
  expect(screen.queryByRole("button")).toBeNull();
});

it("blocks a historical command before mutation when its reference cannot persist", async () => {
  const fetch = vi.fn(); vi.stubGlobal("fetch", fetch);
  vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("Unavailable"); });
  render(<AdminLegacyPartnerReconciliation pool={pool} disabled={false} onConfirmed={async () => {}} />);
  fireEvent.click(screen.getByRole("button", { name: "Reconcile historical partner pool" }));
  await screen.findByText(/no command was sent/);
  expect(fetch).not.toHaveBeenCalled();
});
