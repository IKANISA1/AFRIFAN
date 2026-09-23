import { act, renderHook, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AdminApiError } from "@/lib/data/admin/http";
import { useAdminResourceState } from "./use-admin-resource-state";

const emptyItems: string[] = [];
const normalize = (value: unknown) =>
  Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
const isEmpty = (value: string[]) => value.length === 0;

describe("useAdminResourceState", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("retains confirmed data through a recoverable refresh failure", async () => {
    const load = vi
      .fn<(signal: AbortSignal) => Promise<unknown>>()
      .mockResolvedValueOnce(["confirmed"])
      .mockRejectedValueOnce(new Error("private"));
    const { result } = renderHook(() =>
      useAdminResourceState({
        emptyValue: emptyItems,
        isEmpty,
        load,
        normalize,
        resourceLabel: "Test records",
      }),
    );

    await waitFor(() => expect(result.current.status).toBe("ready"));
    await act(async () => {
      await result.current.refresh();
    });

    expect(result.current.status).toBe("error");
    expect(result.current.data).toEqual(["confirmed"]);
    expect(result.current.hasConfirmed).toBe(true);
  });

  it("clears confirmed data after authorization denial", async () => {
    const load = vi
      .fn<(signal: AbortSignal) => Promise<unknown>>()
      .mockResolvedValueOnce(["confirmed"])
      .mockRejectedValueOnce(
        new AdminApiError("private", 403, "ADMIN_ACCESS_DENIED"),
      );
    const { result } = renderHook(() =>
      useAdminResourceState({
        emptyValue: emptyItems,
        isEmpty,
        load,
        normalize,
        resourceLabel: "Test records",
      }),
    );

    await waitFor(() => expect(result.current.status).toBe("ready"));
    await act(async () => {
      await result.current.refresh();
    });

    expect(result.current.status).toBe("permission_denied");
    expect(result.current.data).toEqual([]);
    expect(result.current.hasConfirmed).toBe(false);
  });
});
