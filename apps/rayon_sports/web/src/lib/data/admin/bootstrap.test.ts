// @vitest-environment node

import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  headers: vi.fn(), cookies: vi.fn(), getServerSupabase: vi.fn(),
  resolveAccess: vi.fn(), clubOptions: vi.fn(),
}));
vi.mock("next/headers", () => ({ headers: mocks.headers, cookies: mocks.cookies }));
vi.mock("@/lib/supabase/server", () => ({ getServerSupabase: mocks.getServerSupabase }));
vi.mock("@/lib/data/admin/access", async (original) => ({
  ...await original<typeof import("@/lib/data/admin/access")>(), resolveAdminAccess: mocks.resolveAccess,
}));
vi.mock("@/lib/data/admin/settings", () => ({ getAdminClubScopeOptions: mocks.clubOptions }));
import { getAdminPortalInitialState } from "./bootstrap";

describe("controlled five club admin bootstrap", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.stubEnv("AFRICLUB_ALLOW_HTTP_PREVIEW", "1");
    vi.stubEnv("AFRICLUB_CONTROLLED_ADMIN_EVIDENCE", "1");
    mocks.headers.mockResolvedValue(new Headers({
      host: "127.0.0.1:3200", "x-africlub-controlled-admin-evidence": "1",
    }));
    mocks.cookies.mockResolvedValue({ get: () => undefined });
    mocks.getServerSupabase.mockResolvedValue(null);
  });
  afterEach(() => vi.unstubAllEnvs());

  it.each([
    ["6", "AS Vita Club", "CDF"], ["24", "Rayon Sports FC", "RWF"],
    ["26", "Nkana FC", "ZMW"], ["44", "Vital'O FC", "BIF"],
    ["1001", "CD Costa do Sol", "MZN"],
  ])("binds only the selected declared tenant %s", async (clubId, name, currency) => {
    mocks.cookies.mockResolvedValue({ get: (key: string) => key === "africlub_admin_club" ? { value: clubId } : undefined });
    const state = await getAdminPortalInitialState();
    expect(state.access.hasAccess).toBe(true);
    expect(state.access.clubId).toBe(clubId);
    expect(state.access.availableClubIds).toEqual([clubId]);
    expect(state.clubOptions).toHaveLength(1);
    expect(state.clubOptions[0]).toMatchObject({ id: clubId, clubName: name, currencyCode: currency });
    expect(state.controlledEvidence).toBe(true);
    expect(mocks.getServerSupabase).not.toHaveBeenCalled();
  });

  it("retains the default declared club when no scope was selected", async () => {
    expect((await getAdminPortalInitialState()).access.clubId).toBe("24");
  });

  it.each(["999", "0", "024", "-24", "24,6", "24/../6", "rayon-sports", "all", "<script>"])(
    "denies an undeclared or malformed selected scope %s", async (clubId) => {
      mocks.cookies.mockResolvedValue({ get: () => ({ value: clubId }) });
      const state = await getAdminPortalInitialState();
      expect(state.access.hasAccess).toBe(false);
      expect(state.user).toBeNull();
      expect(state.clubOptions).toEqual([]);
      expect(state.error).toBe("The controlled club scope is not declared.");
      expect(mocks.getServerSupabase).not.toHaveBeenCalled();
    },
  );

  it.each(["admin.gikundiro.com", "127.0.0.1.attacker.invalid", "127.0.0.1:3200, attacker.invalid"])(
    "rejects forwarded external or ambiguous host %s before controlled scope", async (host) => {
      mocks.headers.mockResolvedValue(new Headers({ host: "127.0.0.1:3200", "x-forwarded-host": host, "x-africlub-controlled-admin-evidence": "1" }));
      const state = await getAdminPortalInitialState();
      expect(state.access.hasAccess).toBe(false);
      expect(state.controlledEvidence).not.toBe(true);
      expect(mocks.getServerSupabase).toHaveBeenCalledOnce();
    },
  );

  it.each(["AFRICLUB_ALLOW_HTTP_PREVIEW", "AFRICLUB_CONTROLLED_ADMIN_EVIDENCE"])(
    "requires explicit runtime switch %s", async (key) => {
      vi.stubEnv(key, "0");
      const state = await getAdminPortalInitialState();
      expect(state.access.hasAccess).toBe(false);
      expect(state.controlledEvidence).not.toBe(true);
    },
  );

  it("requires the explicit request header", async () => {
    mocks.headers.mockResolvedValue(new Headers({ host: "127.0.0.1:3200" }));
    expect((await getAdminPortalInitialState()).controlledEvidence).not.toBe(true);
  });
});

describe("actual staff bootstrap privacy", () => {
  const user = { id: "current-staff" };
  const access = { hasAccess: true, isAuthenticated: true, userId: user.id, role: "club_admin", clubId: "24" };
  beforeEach(() => {
    vi.resetAllMocks();
    mocks.headers.mockResolvedValue(new Headers({ host: "admin.gikundiro.com" }));
    mocks.cookies.mockResolvedValue({ get: () => undefined });
    mocks.resolveAccess.mockResolvedValue(access);
    mocks.clubOptions.mockResolvedValue([{ id: "24", clubName: "Synthetic club" }]);
  });
  function client(claims: unknown) {
    const value = { auth: {
      getSession: vi.fn().mockResolvedValue({ data: { session: { user } }, error: null }),
      getUser: vi.fn().mockResolvedValue({ data: { user }, error: null }),
      getClaims: vi.fn().mockResolvedValue({ data: { claims }, error: null }),
    } };
    mocks.getServerSupabase.mockResolvedValue(value);
    return value;
  }
  const fresh = () => ({ sub: user.id, role: "authenticated", is_anonymous: false, aal: "aal2",
    exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) }] });

  it.each(["aal1", "foreign-subject", "expired"])("does not load private club options before %s assurance is corrected", async (failure) => {
    const claims = fresh();
    if (failure === "aal1") claims.aal = "aal1";
    if (failure === "foreign-subject") claims.sub = "other-staff";
    if (failure === "expired") claims.amr[0].timestamp -= 300;
    const value = client(claims);
    const state = await getAdminPortalInitialState();
    expect(state.user).toEqual(user);
    expect(state.access).toEqual(access);
    expect(state.clubOptions).toEqual([]);
    expect(value.auth.getUser).toHaveBeenCalledOnce();
    expect(mocks.clubOptions).not.toHaveBeenCalled();
  });

  it("loads options only after provider identity, current grants and same-subject recent MFA", async () => {
    client(fresh());
    expect((await getAdminPortalInitialState()).clubOptions).toEqual([{ id: "24", clubName: "Synthetic club" }]);
    expect(mocks.clubOptions).toHaveBeenCalledOnce();
  });

  it("rejects cached identity mismatch before grants or private options", async () => {
    const value = client(fresh());
    value.auth.getUser.mockResolvedValueOnce({ data: { user: { id: "other-staff" } }, error: null });
    const state = await getAdminPortalInitialState();
    expect(state.user).toBeNull();
    expect(state.access.hasAccess).toBe(false);
    expect(mocks.resolveAccess).not.toHaveBeenCalled();
    expect(mocks.clubOptions).not.toHaveBeenCalled();
  });
});
