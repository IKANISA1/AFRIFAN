import { enforceFeatureState } from "./server-feature-guard";

// Mocking the supabase admin client
jest.mock("./supabase/admin", () => ({
  getAdminSupabase: jest.fn(() => ({
    rpc: jest.fn().mockResolvedValue({
      data: [
        {
          feature_key: "shop",
          is_enabled: true,
          visibility_state: "visible",
        },
        {
          feature_key: "tickets",
          is_enabled: false,
          visibility_state: "disabled",
        },
      ],
      error: null,
    }),
  })),
}));

describe("server-feature-guard", () => {
  it("allows access to an enabled feature", async () => {
    const result = await enforceFeatureState("shop", "web");
    expect(result.allowed).toBe(true);
    expect(result.error).toBeUndefined();
  });

  it("blocks access to a disabled feature", async () => {
    const result = await enforceFeatureState("tickets", "web");
    expect(result.allowed).toBe(false);
    expect(result.error).toContain("disabled operationally");
  });

  it("blocks access to an unregistered feature", async () => {
    const result = await enforceFeatureState("unknown_feature", "web");
    expect(result.allowed).toBe(false);
    expect(result.error).toContain("not registered");
  });
});
