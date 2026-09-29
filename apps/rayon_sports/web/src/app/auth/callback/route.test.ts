import { beforeEach, describe, expect, it, vi } from "vitest";
import { getServerSupabase } from "@/lib/supabase/server";
import * as callbackRoute from "./route";
import {
  authCallbackOperationTimeoutMs,
  resolveNextPath,
} from "@/lib/auth-callback";
import { GET } from "./route";

vi.mock("@/lib/supabase/server", () => ({
  getServerSupabase: vi.fn(),
}));

function request(query = "") {
  return new Request(`https://club.example/auth/callback${query}`);
}

function exchangeClient(result: unknown) {
  return {
    auth: {
      exchangeCodeForSession: vi.fn(() => result),
    },
  };
}

function destination(response: Response) {
  return new URL(response.headers.get("location")!);
}

describe("auth callback controlled states", () => {
  it("keeps the route entry module limited to its Next HTTP handler export", () => {
    expect(Object.keys(callbackRoute)).toEqual(["GET"]);
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
  });

  it("uses a controlled empty state when the authorization code is absent", async () => {
    const response = await GET(request("?next=/admin/events?tab=live"));
    const target = destination(response);

    expect(response.status).toBe(307);
    expect(target.pathname).toBe("/admin/events");
    expect(target.searchParams.get("tab")).toBe("live");
    expect(target.searchParams.get("error")).toBe("missing_auth_code");
    expect(target.searchParams.get("state")).toBe("empty");
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(getServerSupabase).not.toHaveBeenCalled();
  });

  it("uses a sanitized error state when authentication is unavailable", async () => {
    vi.mocked(getServerSupabase).mockResolvedValue(null);

    const response = await GET(request("?code=secret-provider-code"));
    const target = destination(response);

    expect(target.pathname).toBe("/admin");
    expect(target.searchParams.get("error")).toBe("auth_service_unavailable");
    expect(target.searchParams.get("state")).toBe("error");
    expect(target.toString()).not.toContain("secret-provider-code");
  });

  it("maps permission denial without exposing provider diagnostics", async () => {
    const client = exchangeClient(
      Promise.resolve({
        error: {
          status: 403,
          message: "User user@example.com cannot exchange code raw-token",
        },
      }),
    );
    vi.mocked(getServerSupabase).mockResolvedValue(client as never);

    const response = await GET(request("?code=raw-token&next=/admin"));
    const target = destination(response);

    expect(target.searchParams.get("error")).toBe("auth_access_denied");
    expect(target.searchParams.get("state")).toBe("permission_denied");
    expect(target.toString()).not.toContain("user@example.com");
    expect(target.toString()).not.toContain("raw-token");
  });

  it("maps a stale session collision to a controlled conflict state", async () => {
    const client = exchangeClient(
      Promise.resolve({
        error: { status: 409, message: "session version 99 is stale" },
      }),
    );
    vi.mocked(getServerSupabase).mockResolvedValue(client as never);

    const response = await GET(request("?code=valid&next=/admin/users"));
    const target = destination(response);

    expect(target.pathname).toBe("/admin/users");
    expect(target.searchParams.get("error")).toBe("auth_session_conflict");
    expect(target.searchParams.get("state")).toBe("conflict");
    expect(target.toString()).not.toContain("version");
  });

  it("does not redirect while the code exchange is still syncing", async () => {
    let resolveExchange:
      | ((value: { error: null }) => void)
      | undefined;
    const exchange = new Promise<{ error: null }>((resolve) => {
      resolveExchange = resolve;
    });
    const client = exchangeClient(exchange);
    vi.mocked(getServerSupabase).mockResolvedValue(client as never);

    let settled = false;
    const responsePromise = GET(request("?code=valid&next=/admin")).then(
      (response) => {
        settled = true;
        return response;
      },
    );
    await Promise.resolve();
    await Promise.resolve();

    expect(settled).toBe(false);
    resolveExchange?.({ error: null });
    const response = await responsePromise;
    expect(destination(response).toString()).toBe("https://club.example/admin");
  });

  it("uses a controlled timeout state when exchange exceeds its deadline", async () => {
    vi.useFakeTimers();
    const client = exchangeClient(new Promise(() => undefined));
    vi.mocked(getServerSupabase).mockResolvedValue(client as never);

    const responsePromise = GET(request("?code=valid&next=/admin"));
    await vi.advanceTimersByTimeAsync(authCallbackOperationTimeoutMs);
    const response = await responsePromise;
    const target = destination(response);

    expect(target.searchParams.get("error")).toBe("auth_callback_timeout");
    expect(target.searchParams.get("state")).toBe("security_timeout");
  });

  it("uses a sanitized error state for an unexpected provider failure", async () => {
    const client = exchangeClient(
      Promise.reject(
        new Error("provider secret: sk-test and user user@example.com"),
      ),
    );
    vi.mocked(getServerSupabase).mockResolvedValue(client as never);

    const response = await GET(request("?code=secret-code"));
    const target = destination(response);

    expect(target.searchParams.get("error")).toBe("auth_callback_failed");
    expect(target.searchParams.get("state")).toBe("error");
    expect(target.toString()).not.toContain("sk-test");
    expect(target.toString()).not.toContain("user@example.com");
    expect(target.toString()).not.toContain("secret-code");
  });

  it.each([
    "https://evil.example/steal",
    "//evil.example/steal",
    "/\\evil.example/steal",
    "/\u0000admin",
    "admin/users",
  ])("rejects unsafe next destination %s", async (nextValue) => {
    const client = exchangeClient(Promise.resolve({ error: null }));
    vi.mocked(getServerSupabase).mockResolvedValue(client as never);

    const response = await GET(
      request(`?code=valid&next=${encodeURIComponent(nextValue)}`),
    );

    expect(destination(response).toString()).toBe("https://club.example/admin");
  });

  it("normalizes a safe same-origin relative destination", () => {
    expect(
      resolveNextPath("/admin/users?tab=active#members", "https://club.example"),
    ).toBe("/admin/users?tab=active#members");
  });
});
