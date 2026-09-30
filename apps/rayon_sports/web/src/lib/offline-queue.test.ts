import { afterEach, describe, expect, it, vi } from "vitest";
import { clearOfflineQueue, fetchWithOfflineQueue, getQueuedMutationCount,
  OfflineRequestFailure, queueOfflineMutation } from "./offline-queue";

afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); vi.useRealTimers(); });

function legacyStore(abort = false) {
  const count = vi.fn(), clear = vi.fn(), close = vi.fn();
  const request = { result: 3, onsuccess: null as null | (() => void), onerror: null };
  const tx = { oncomplete: null as null | (() => void), onabort: null as null | (() => void),
    onerror: null, objectStore: () => ({ count, clear }) };
  const finish = () => {
    queueMicrotask(() => {
      if (abort) tx.onabort?.();
      else { request.onsuccess?.(); tx.oncomplete?.(); }
    });
    return request;
  };
  count.mockImplementation(finish); clear.mockImplementation(finish);
  const transaction = vi.fn(() => tx);
  const db = { transaction, close };
  const open = vi.fn(() => {
    const opening = { result: db, onsuccess: null as null | (() => void),
      onerror: null, onblocked: null, onupgradeneeded: null };
    queueMicrotask(() => opening.onsuccess?.());
    return opening;
  });
  vi.stubGlobal("indexedDB", { open });
  return { open, count, clear, close, transaction };
}

describe("quarantined offline requests", () => {
  it.each(["POST", "PUT", "PATCH", "DELETE", "patch"])(
    "%s lost acknowledgement remains unknown with one submission and no persistence", async method => {
      const storage = legacyStore();
      const sync = vi.fn(); vi.stubGlobal("navigator", { serviceWorker: { ready: { sync: { register: sync } } } });
      const log = vi.spyOn(console, "warn").mockImplementation(() => {});
      let committed = 0;
      const fetch = vi.fn(async () => { committed++; throw Error("synthetic-private-token +250700000099"); });
      vi.stubGlobal("fetch", fetch);
      const url = "https://private.invalid/payment?token=synthetic-private-token";
      await expect(fetchWithOfflineQueue(url, { method,
        headers: { Authorization: "Bearer synthetic-private-token" }, body: "private payment body" }))
        .rejects.toMatchObject({ code: "mutation_outcome_unknown", requestOutcome: "unknown" });
      expect(committed).toBe(1); expect(fetch).toHaveBeenCalledTimes(1);
      expect(storage.open).not.toHaveBeenCalled(); expect(sync).not.toHaveBeenCalled();
      expect(log).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1, service: "web",
        event: "offline_mutation_outcome_unknown", level: "warn" });
      for (const secret of [url, "synthetic-private-token", "+250700000099", "private payment body"])
        expect(JSON.stringify(log.mock.calls)).not.toContain(secret);
    });
  it("direct queue calls reject before inspecting headers or opening storage", async () => {
    const storage = legacyStore();
    const headers = Object.defineProperty({}, "Authorization", {
      get: () => { throw Error("private header was inspected"); }, enumerable: true,
    });
    await expect(queueOfflineMutation("private", "POST", headers, "private"))
      .rejects.toMatchObject({ code: "offline_queue_disabled", requestOutcome: "not_sent" });
    expect(storage.open).not.toHaveBeenCalled();
  });
  it.each(["GET", "HEAD", "OPTIONS"])("%s failures do not persist or expose transport errors", async method => {
    const storage = legacyStore();
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(Error("private transport token")));
    await expect(fetchWithOfflineQueue("/private", { method }))
      .rejects.toMatchObject({ message: "read_unavailable", requestOutcome: "unavailable" });
    expect(storage.open).not.toHaveBeenCalled();
  });
  it.each([200, 202, 403, 503])("preserves actual server response %s without a second request", async status => {
    const response = new Response("server result", { status });
    const fetch = vi.fn().mockResolvedValue(response); vi.stubGlobal("fetch", fetch);
    expect(await fetchWithOfflineQueue("/mutation", { method: "POST" })).toBe(response);
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("legacy inspection reads only a count, closes storage and cannot delete or replay", async () => {
    const storage = legacyStore(), fetch = vi.fn(); vi.stubGlobal("fetch", fetch);
    expect(await getQueuedMutationCount()).toBe(3);
    expect(storage.transaction).toHaveBeenCalledExactlyOnceWith("requests", "readonly");
    expect(storage.clear).not.toHaveBeenCalled(); expect(fetch).not.toHaveBeenCalled();
    expect(storage.close).toHaveBeenCalledTimes(1);
  });
  it("unavailable legacy storage cannot be reported as an empty queue", async () => {
    vi.stubGlobal("indexedDB", { open: () => { throw Error("private database error"); } });
    await expect(getQueuedMutationCount()).rejects.toMatchObject({
      message: "offline_queue_unavailable", requestOutcome: "unavailable" });
  });
  it("explicit clearing deletes retained entries without sending them", async () => {
    const storage = legacyStore(), fetch = vi.fn(); vi.stubGlobal("fetch", fetch);
    await clearOfflineQueue();
    expect(storage.clear).toHaveBeenCalledTimes(1);
    expect(storage.transaction).toHaveBeenCalledExactlyOnceWith("requests", "readwrite");
    expect(storage.close).toHaveBeenCalledTimes(1); expect(fetch).not.toHaveBeenCalled();
  });
  it("aborted clearing rejects, closes storage and emits only the finite failure", async () => {
    const storage = legacyStore(true), log = vi.spyOn(console, "error").mockImplementation(() => {});
    await expect(clearOfflineQueue()).rejects.toBeInstanceOf(OfflineRequestFailure);
    expect(storage.close).toHaveBeenCalledTimes(1);
    expect(log).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1, service: "web",
      event: "offline_queue_clear_failed", level: "error" });
  });
  it("an open deadline is finite and a late database handle is closed", async () => {
    vi.useFakeTimers();
    const close = vi.fn(), opening = { result: { close }, onsuccess: null as null | (() => void),
      onerror: null, onblocked: null, onupgradeneeded: null };
    vi.stubGlobal("indexedDB", { open: () => opening });
    const observed = expect(getQueuedMutationCount()).rejects.toMatchObject({ code: "offline_queue_unavailable" });
    await vi.advanceTimersByTimeAsync(5000); await observed;
    opening.onsuccess?.(); expect(close).toHaveBeenCalledTimes(1);
  });
});
