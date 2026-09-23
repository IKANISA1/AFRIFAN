import { beforeEach, describe, expect, it, vi } from "vitest";

const rpc = vi.fn();

vi.mock("./club-context", () => ({
  getActiveClubReference: vi.fn(async () => ({
    numericId: 7,
    slug: "rayon-sports",
    name: "Rayon Sports",
    shortName: "Rayon",
  })),
}));

vi.mock("./supabase/admin", () => ({
  getAdminSupabase: vi.fn(() => ({ rpc })),
}));

import { enforceFeatureState } from "./server-feature-guard";

describe("server-feature-guard", () => {
  beforeEach(() => {
    rpc.mockReset();
  });

  it("allows access to an enabled feature", async () => {
    rpc.mockResolvedValue({
      data: {
        is_registered: true,
        is_visible: true,
        is_operational: true,
        is_available: true,
        reason: "ok",
      },
      error: null,
    });

    const result = await enforceFeatureState("shop", "web");
    expect(result).toEqual({ allowed: true });
  });

  it("blocks route access when the feature is hidden", async () => {
    rpc.mockResolvedValue({
      data: {
        is_registered: true,
        is_visible: false,
        is_operational: true,
        is_available: true,
        reason: "hidden",
      },
      error: null,
    });

    const result = await enforceFeatureState("news", "web", "route");
    expect(result.allowed).toBe(false);
    expect(result.error).toContain("not currently available");
  });

  it("blocks action access when the feature is disabled operationally", async () => {
    rpc.mockResolvedValue({
      data: {
        is_registered: true,
        is_visible: true,
        is_operational: false,
        is_available: false,
        reason: "global_disabled",
      },
      error: null,
    });

    const result = await enforceFeatureState("tickets", "web", "action");
    expect(result.allowed).toBe(false);
    expect(result.error).toContain("disabled");
  });

  it("fails closed for unregistered features", async () => {
    rpc.mockResolvedValue({
      data: {
        is_registered: false,
        is_visible: false,
        is_operational: false,
        is_available: false,
        reason: "unregistered",
      },
      error: null,
    });

    const result = await enforceFeatureState("unknown_feature", "web");
    expect(result.allowed).toBe(false);
    expect(result.error).toContain("not registered");
  });

  it("passes scoped club, auth, and role context to the RPC", async () => {
    rpc.mockResolvedValue({
      data: {
        is_registered: true,
        is_visible: true,
        is_operational: true,
        is_available: true,
        reason: "ok",
      },
      error: null,
    });

    await enforceFeatureState("notifications", "web", "action", {
      clubId: "24",
      isAuthenticated: true,
      roles: ["club_admin"],
    });

    expect(rpc).toHaveBeenCalledWith("get_feature_access_state", {
      p_feature_key: "notifications",
      p_channel: "web",
      p_club_id: 24,
      p_is_authenticated: true,
      p_roles: ["club_admin"],
    });
  });
});
