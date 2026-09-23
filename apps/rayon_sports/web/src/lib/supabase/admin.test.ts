import { afterEach, describe, expect, it, vi } from "vitest";

const originalEnv = { ...process.env };

afterEach(() => {
  vi.resetModules();
  process.env = { ...originalEnv };
});

describe("supabase admin clients", () => {
  it("allows read-only server access with anon credentials only", async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;

    const { getAdminSupabase, getReadOnlySupabase } = await import(
      "@/lib/supabase/admin"
    );

    expect(getReadOnlySupabase()).not.toBeNull();
    expect(getAdminSupabase()).toBeNull();
  });

  it("requires a service role key before creating the admin client", async () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
    process.env.SUPABASE_SERVICE_ROLE_KEY = "service-role-key";

    const { getAdminSupabase } = await import("@/lib/supabase/admin");

    expect(getAdminSupabase()).not.toBeNull();
  });
});
