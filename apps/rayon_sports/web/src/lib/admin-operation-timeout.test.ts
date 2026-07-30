import { afterEach, describe, expect, it, vi } from "vitest";

import {
  AdminOperationTimeoutError,
  fetchAdminWithTimeout,
  withAdminOperationTimeout,
} from "@/lib/admin-operation-timeout";

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe("admin operation timeout", () => {
  it("returns a successful operation and clears its timer", async () => {
    vi.useFakeTimers();

    await expect(
      withAdminOperationTimeout(Promise.resolve("ready"), "Admin refresh", 50),
    ).resolves.toBe("ready");
    expect(vi.getTimerCount()).toBe(0);
  });

  it("fails closed with a retryable non-confirmation message", async () => {
    vi.useFakeTimers();
    const pending = new Promise<never>(() => {});
    const result = withAdminOperationTimeout(pending, "Admin sign-in", 50);
    const rejection = expect(result).rejects.toEqual(
      new AdminOperationTimeoutError("Admin sign-in"),
    );

    await vi.advanceTimersByTimeAsync(50);

    await rejection;
    expect(vi.getTimerCount()).toBe(0);
  });

  it("aborts a timed-out fetch", async () => {
    vi.useFakeTimers();
    let observedSignal: AbortSignal | undefined;

    vi.stubGlobal(
      "fetch",
      vi.fn((_input: RequestInfo | URL, init?: RequestInit) => {
        observedSignal = init?.signal ?? undefined;
        return new Promise<Response>((_resolve, reject) => {
          observedSignal?.addEventListener("abort", () => {
            reject(new DOMException("Aborted", "AbortError"));
          });
        });
      }),
    );

    const result = fetchAdminWithTimeout(
      "/api/admin/auth/eligible",
      { method: "POST" },
      "Admin eligibility check",
      50,
    );
    const rejection = expect(result).rejects.toThrow(
      "Admin eligibility check timed out",
    );

    await vi.advanceTimersByTimeAsync(50);

    await rejection;
    expect(observedSignal?.aborted).toBe(true);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("preserves a non-timeout fetch failure", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockRejectedValue(new Error("Service unavailable")),
    );

    await expect(
      fetchAdminWithTimeout(
        "/api/admin/auth/eligible",
        { method: "POST" },
        "Admin eligibility check",
      ),
    ).rejects.toThrow("Service unavailable");
  });
});
