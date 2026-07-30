import { describe, expect, it, vi } from "vitest";
import { AdminApiError } from "@/lib/data/admin/http";
import {
  AdminResourceTimeoutError,
  resolveAdminResourceFailure,
  withAdminResourceTimeout,
} from "./admin-resource-state";

describe("admin resource state", () => {
  it.each([
    [new AdminApiError("private", 403, "ADMIN_ACCESS_DENIED"), true, "permission_denied"],
    [new AdminApiError("private", 409, "STALE_RECORD"), true, "conflict"],
    [new AdminApiError("private", 504, "ADMIN_OPERATION_TIMEOUT"), true, "security_timeout"],
    [new AdminResourceTimeoutError("Access assignments"), true, "security_timeout"],
    [new Error("private"), true, "error"],
    [new Error("private"), false, "offline"],
  ] as const)("classifies controlled failures", (error, online, expected) => {
    expect(resolveAdminResourceFailure(error, online)).toBe(expected);
  });

  it("aborts an operation that exceeds the bounded timeout", async () => {
    vi.useFakeTimers();
    const controller = new AbortController();
    const result = withAdminResourceTimeout({
      operation: new Promise<never>(() => {}),
      controller,
      resourceLabel: "Access assignments",
      timeoutMs: 25,
    });
    const rejection = expect(result).rejects.toBeInstanceOf(
      AdminResourceTimeoutError,
    );

    await vi.advanceTimersByTimeAsync(25);

    await rejection;
    expect(controller.signal.aborted).toBe(true);
    vi.useRealTimers();
  });
});
