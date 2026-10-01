// @vitest-environment node
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { refundIds, refundReceipt } from "@/lib/data/admin/payment-refunds.test-fixtures";

const state = vi.hoisted(() => ({ client: null as SupabaseClient | null, service: { rpc: vi.fn() },
  getUser: vi.fn(), getClaims: vi.fn(), limit: vi.fn(), calls: [] as { name: string; args: Record<string, unknown> }[], role: "super_admin" }));
vi.mock("@/lib/supabase/server", () => ({ getServerSupabase: async () => state.client }));
vi.mock("@/lib/supabase/admin", () => ({ getAdminSupabase: () => state.service }));
vi.mock("@/lib/security", async importOriginal => ({ ...await importOriginal<typeof import("@/lib/security")>(), rejectRateLimitedRequest: state.limit }));
import { GET, POST } from "./route";
const command = { action: "prepare", paymentEventId: refundIds.payment, amount: 2500, reason: "cancelled_order", operationId: refundIds.operation };
function request(method = "GET", body: unknown = command, origin = "https://admin.gikundiro.com") {
  return new NextRequest("https://admin.gikundiro.com/api/admin/refunds?club=24", { method, headers: { origin, "content-type": "application/json", "x-africlub-csrf": "1" }, ...(method === "POST" ? { body: JSON.stringify(body) } : {}) });
}
beforeEach(() => {
  state.calls = []; state.role = "super_admin"; state.service.rpc.mockReset(); state.getUser.mockReset(); state.getClaims.mockReset(); state.limit.mockResolvedValue(null);
  state.getUser.mockResolvedValue({ data: { user: { id: refundIds.maker, app_metadata: { club_id: 24 } } }, error: null });
  state.getClaims.mockImplementation(async () => ({ data: { claims: { sub: refundIds.maker, role: "authenticated", is_anonymous: false, aal: "aal2",
    exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) }] } }, error: null }));
  state.client = createClient("http://127.0.0.1:54321", "test-anon", { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { headers: { Authorization: "Bearer current-human-jwt" }, fetch: async (input, options) => {
      expect(new Headers(options?.headers).get("authorization")).toBe("Bearer current-human-jwt");
      const url = new URL(String(input));
      let data: unknown;
      if (url.pathname.endsWith("admin_role_assignments")) {
        expect(url.searchParams.get("user_id")).toBe(`eq.${refundIds.maker}`);
        data = [{ role: state.role, club_id: 24, is_active: true, revoked_at: null }];
      } else {
        const name = url.pathname.split("/").at(-1)!; const args = JSON.parse(String(options?.body)); state.calls.push({ name, args });
        data = name === "admin_payment_refund_dashboard" ? { club_id: 24, payments: [], requests: [] } : refundReceipt();
      }
      return new Response(JSON.stringify(data), { status: 200, headers: { "content-type": "application/json" } });
    } } });
  state.client.auth.getUser = state.getUser; state.client.auth.getClaims = state.getClaims;
});
describe("reachable refund API through actual shared transport and current role query", () => {
  it("reads selected scope with verified fresh same-subject TOTP and no service writer", async () => {
    const response = await GET(request()); expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toEqual({ data: { clubId: 24, payments: [], requests: [] } });
    expect(state.calls).toEqual([{ name: "admin_payment_refund_dashboard", args: { p_club_id: 24 } }]);
    expect(state.getClaims).toHaveBeenCalledTimes(1); expect(state.service.rpc).not.toHaveBeenCalled();
  });
  it("mutates with original reference and real caller-scoped RPC after transport guards", async () => {
    const response = await POST(request("POST")); expect(response.status).toBe(200);
    expect(state.calls).toEqual([{ name: "admin_prepare_payment_refund", args: { p_club_id: 24, p_payment_event_id: refundIds.payment, p_amount: 2500, p_reason: "cancelled_order", p_operation_id: refundIds.operation } }]);
    expect(state.service.rpc).not.toHaveBeenCalled();
  });
  it.each([{ aal: "aal1" }, { sub: refundIds.checker }, { amr: [{ method: "otp", timestamp: Math.floor(Date.now() / 1000) }] },
    { amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) - 301 }] }])("denies weak/stale/foreign assurance before refund dispatch %j", async patch => {
    state.getClaims.mockResolvedValue({ data: { claims: { sub: refundIds.maker, role: "authenticated", is_anonymous: false, aal: "aal2", exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) }], ...patch } }, error: null });
    const response = await POST(request("POST")); expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({ code: "STAFF_STEP_UP_REQUIRED", change_confirmed: false }); expect(state.calls).toEqual([]);
  });
  it("denies a current club assignment and issuer verification failure", async () => {
    state.role = "club_admin"; expect((await GET(request())).status).toBe(403); expect(state.calls).toEqual([]);
    state.role = "super_admin"; state.getClaims.mockResolvedValue({ data: null, error: new Error("issuer unavailable") });
    const response = await GET(request()); expect(response.status).toBe(503); expect(await response.json()).toMatchObject({ code: "STAFF_ASSURANCE_UNAVAILABLE" });
  });
  it("blocks actual foreign origin before authentication or authoritative mutation", async () => {
    const response = await POST(request("POST", command, "https://foreign.example")); expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({ code: "MUTATION_ACCESS_DENIED" }); expect(state.getUser).not.toHaveBeenCalled(); expect(state.calls).toEqual([]);
  });
  it("rejects caller-selected actor/tenant fields and missing original operation", async () => {
    for (const body of [{ ...command, actorId: refundIds.checker }, { ...command, clubId: 25 }, { ...command, operationId: null }]) {
      expect((await POST(request("POST", body))).status).toBe(400);
    }
    expect(state.calls).toEqual([]);
  });
  it("recovers original key through actual route without another financial command", async () => {
    const req = new NextRequest(`https://admin.gikundiro.com/api/admin/refunds?club=24&operation_id=${refundIds.operation}`);
    expect((await GET(req)).status).toBe(200);
    expect(state.calls).toEqual([{ name: "admin_recover_payment_refund_operation", args: { p_club_id: 24, p_operation_id: refundIds.operation } }]);
  });
});
