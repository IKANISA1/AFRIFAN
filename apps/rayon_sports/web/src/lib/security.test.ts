import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  getClientIp,
  isSameOriginMutation,
  rejectInsecureMutation,
  rejectRateLimitedRequest,
} from "@/lib/security";

function makeRequest(headers: Record<string, string> = {}) {
  return new NextRequest("https://gikundiro.com/api/test", {
    headers,
  });
}

describe("security helpers", () => {
  it("prefers the first forwarded IP address", () => {
    const request = makeRequest({
      "x-forwarded-for": "198.51.100.10, 203.0.113.9",
      "x-real-ip": "203.0.113.20",
    });

    expect(getClientIp(request)).toBe("198.51.100.10");
  });

  it("honors the shared rate-limit RPC result when available", async () => {
    const client = {
      rpc: vi.fn().mockResolvedValue({
        data: [
          {
            allowed: false,
            retry_after_seconds: 17,
            remaining: 0,
            reset_at: new Date().toISOString(),
          },
        ],
        error: null,
      }),
    };

    const response = await rejectRateLimitedRequest(
      makeRequest({ "x-forwarded-for": "198.51.100.10" }),
      "admin-mutation-test",
      10,
      60_000,
      client,
    );

    expect(client.rpc).toHaveBeenCalledWith("consume_request_rate_limit", {
      p_bucket_key: "admin-mutation-test:198.51.100.10",
      p_limit: 10,
      p_window_ms: 60_000,
    });
    expect(response?.status).toBe(429);
    expect(response?.headers.get("Retry-After")).toBe("17");
  });

  it("falls back to local in-memory limiting when no shared client is available", async () => {
    const request = makeRequest({ "x-forwarded-for": "203.0.113.44" });

    const first = await rejectRateLimitedRequest(
      request,
      "local-fallback-test",
      1,
      60_000,
      null,
    );
    const second = await rejectRateLimitedRequest(
      request,
      "local-fallback-test",
      1,
      60_000,
      null,
    );

    expect(first).toBeNull();
    expect(second?.status).toBe(429);
    expect(second?.headers.get("Retry-After")).toBeTruthy();
  });

  it("accepts same-site mutations with the Africlub CSRF header even after cross-origin auth redirects", () => {
    const request = makeRequest({
      "x-africlub-csrf": "1",
      "sec-fetch-site": "same-origin",
      referer:
        "https://mmpbzcdhfvplxplnfucy.supabase.co/auth/v1/verify?token=test",
    });

    expect(isSameOriginMutation(request)).toBe(true);
    expect(rejectInsecureMutation(request)).toBeNull();
  });

  it("still blocks cross-site mutations even when the Africlub CSRF header is present", async () => {
    const request = makeRequest({
      "x-africlub-csrf": "1",
      "sec-fetch-site": "cross-site",
      origin: "https://evil.example",
    });

    expect(isSameOriginMutation(request)).toBe(false);
    const response = rejectInsecureMutation(request);
    expect(response?.status).toBe(403);
    expect(response?.headers.get("cache-control")).toBe("no-store");
    await expect(response?.json()).resolves.toMatchObject({
      code: "MUTATION_ACCESS_DENIED",
    });
  });
  it.each(["https://foreign.invalid", "null", "https://gikundiro.com/private", "not an origin"])(
    "a CSRF marker cannot override explicit foreign or malformed origin %s", origin => {
      const request = makeRequest({ origin, "x-africlub-csrf": "1", "sec-fetch-site": "same-origin" });
      expect(isSameOriginMutation(request)).toBe(false);
      expect(rejectInsecureMutation(request)?.status).toBe(403);
    });
  it("an exact same-origin mutation preserves the valid browser contract", () => {
    expect(isSameOriginMutation(makeRequest({ origin: "https://gikundiro.com",
      "sec-fetch-site": "same-origin", "x-africlub-csrf": "1" }))).toBe(true);
  });
});

describe("isolated preview connection policy", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.resetModules();
  });
  it("an obsolete analytics endpoint cannot expand the production CSP", async () => {
    vi.stubEnv("NEXT_PUBLIC_VITALS_ENDPOINT", "https://foreign.invalid/?token=synthetic");
    vi.resetModules();
    const { default: config } = await import("../../next.config");
    const policy = (await config.headers?.())?.find(entry => entry.source === "/(.*)")
      ?.headers.find(header => header.key === "Content-Security-Policy")?.value;
    expect(policy).not.toContain("foreign.invalid");
    expect(policy).not.toContain("synthetic");
  });

  it.each([
    ["http://127.0.0.1:54321", "1", true],
    ["http://localhost:54321", "1", true],
    ["http://[::1]:54321", "1", true],
    ["http://127.0.0.1:54321", "0", false],
    ["http://127.0.0.1:54321", undefined, false],
    ["http://192.168.1.10:54321", "1", false],
    ["http://localhost.example.invalid:54321", "1", false],
  ])("limits %s with preview=%s to its explicit loopback origin", async (url, preview, allowed) => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", url);
    vi.stubEnv("NEXT_PUBLIC_VITALS_ENDPOINT", "");
    vi.stubEnv("AFRICLUB_ALLOW_HTTP_PREVIEW", preview);
    vi.resetModules();
    const { default: config } = await import("../../next.config");
    const headers = (await config.headers?.())?.find(
      (entry) => entry.source === "/(.*)",
    )?.headers;
    const policy = headers?.find(
      (header) => header.key === "Content-Security-Policy",
    )?.value;
    expect(policy).toBeDefined();
    const connections = policy?.split(";").find(
      (directive) => directive.trim().startsWith("connect-src "),
    )?.trim().split(/\s+/);
    const origin = new URL(url).origin;
    expect(connections?.includes(origin)).toBe(allowed);
    expect(connections?.includes(origin.replace(/^http:/, "ws:"))).toBe(allowed);
    expect(connections).not.toContain("http:");
    expect(connections).not.toContain("ws:");
    expect(policy).toContain("object-src 'none'");
    expect(policy).toContain("frame-ancestors 'none'");
    expect(headers?.some((header) => header.key === "Strict-Transport-Security"))
      .toBe(preview !== "1");
  });
});
