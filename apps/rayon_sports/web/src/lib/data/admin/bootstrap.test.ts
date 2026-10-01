// @vitest-environment node

import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  headers: vi.fn(), cookies: vi.fn(), getServerSupabase: vi.fn(),
}));
vi.mock("next/headers", () => ({ headers: mocks.headers, cookies: mocks.cookies }));
vi.mock("@/lib/supabase/server", () => ({ getServerSupabase: mocks.getServerSupabase }));
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
