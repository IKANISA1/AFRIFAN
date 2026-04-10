import { NextRequest } from "next/server";
import { describe, expect, it, vi } from "vitest";
import { getClientIp, rejectRateLimitedRequest } from "@/lib/security";

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
});
