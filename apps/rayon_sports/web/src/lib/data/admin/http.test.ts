import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { requestAdminApi } from "./http";

const { offlineFetch } = vi.hoisted(() => ({ offlineFetch: vi.fn() }));
vi.mock("@/lib/offline-queue", () => ({ fetchWithOfflineQueue: offlineFetch }));

describe("admin HTTP mutation confirmation", () => {
  beforeEach(() => {
    vi.stubGlobal("window", { location: { origin: "https://qa.example.invalid", href: "https://qa.example.invalid/admin?club=24" } });
    offlineFetch.mockReset();
    offlineFetch.mockResolvedValue(new Response(JSON.stringify({ data: { queued: true } }), { status: 202 }));
  });
  afterEach(() => vi.unstubAllGlobals());

  it.each([new TypeError("Connection lost after submission"), new DOMException("Cancelled", "AbortError")])(
    "does not retry or queue a mutation after %s",
    async (failure) => {
      const fetch = vi.fn().mockRejectedValue(failure);
      vi.stubGlobal("fetch", fetch);
      await expect(requestAdminApi("content-blocks/save", { method: "POST", body: { input: { title: "Draft" } } })).rejects.toBe(failure);
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(offlineFetch).not.toHaveBeenCalled();
    },
  );

  it("preserves the selected scope and CSRF header on one confirmed mutation", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({ data: { success: true } })));
    vi.stubGlobal("fetch", fetch);
    await expect(requestAdminApi("content-blocks/save", { method: "POST", body: { input: { title: "Draft" } } })).resolves.toEqual({ success: true });
    expect(fetch).toHaveBeenCalledExactlyOnceWith(expect.any(URL), expect.objectContaining({ method: "POST", credentials: "same-origin", headers: expect.objectContaining({ "X-Africlub-CSRF": "1" }) }));
    expect(String(fetch.mock.calls[0][0])).toBe("https://qa.example.invalid/api/admin/content-blocks/save?club=24");
    expect(offlineFetch).not.toHaveBeenCalled();
  });

  it.each([403, 409, 500])("preserves a %s rejection without retry", async (status) => {
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: "Not confirmed", code: "QA_REJECTION" }), { status }));
    vi.stubGlobal("fetch", fetch);
    await expect(requestAdminApi("content-blocks/delete", { method: "POST", body: { id: "record" } })).rejects.toMatchObject({ status, code: "QA_REJECTION" });
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(offlineFetch).not.toHaveBeenCalled();
  });
});
