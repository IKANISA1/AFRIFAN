// @vitest-environment node
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { describe, expect, it, vi } from "vitest";

const source = readFileSync(new URL("../../public/sw.js", import.meta.url), "utf8");

function worker() {
  const listeners = new Map<string, (event: unknown) => void>();
  const cache = {
    addAll: vi.fn(async (urls: string[]) => { if (new Set(urls).size !== urls.length) throw new DOMException("Duplicate requests", "InvalidStateError"); }),
    put: vi.fn(async () => {}),
    match: vi.fn(async () => undefined as Response | undefined),
    add: vi.fn(async () => {}),
  };
  const caches = {
    open: vi.fn(async () => cache),
    match: vi.fn(async () => new Response("Offline recovery", { status: 503 })),
    keys: vi.fn(async () => ["gikundiro-pages-v4", "another-feature-cache"]),
    delete: vi.fn(async () => true),
  };
  const fetch = vi.fn(async () => new Response("Live response"));
  const self = {
    addEventListener: (name: string, callback: (event: unknown) => void) => listeners.set(name, callback),
    location: { origin: "https://qa.example.invalid" },
    skipWaiting: vi.fn(async () => {}),
    clients: { claim: vi.fn(async () => {}) },
  };
  const context = vm.createContext({ self, caches, fetch, URL, Request, Response, Headers, console });
  vm.runInContext(source, context);
  async function event(name: string, fields: object = {}) {
    let pending: Promise<unknown> | undefined;
    listeners.get(name)?.({ ...fields, waitUntil: (promise: Promise<unknown>) => { pending = promise; } });
    await pending;
  }
  async function navigate(pathname: string) {
    let pending: Promise<Response> | undefined;
    listeners.get("fetch")?.({ request: { url: self.location.origin + pathname, method: "GET", mode: "navigate", headers: new Headers() }, respondWith: (promise: Promise<Response>) => { pending = promise; }, waitUntil: () => {} });
    return pending;
  }
  return { event, navigate, cache, caches, fetch, self, context };
}

describe("service worker recovery and cache boundaries", () => {
  it("installs a valid unique precache without forcing an in-progress app update", async () => {
    const w = worker();
    await w.event("install");
    expect(w.cache.addAll).toHaveBeenCalledOnce();
    expect(w.self.skipWaiting).not.toHaveBeenCalled();
    await w.event("message", { data: { type: "SKIP_WAITING" } });
    expect(w.self.skipWaiting).toHaveBeenCalledOnce();
  });

  it("removes previous app caches without deleting unrelated origin storage", async () => {
    const w = worker(); await w.event("activate");
    expect(w.caches.delete).toHaveBeenCalledWith("gikundiro-pages-v4");
    expect(w.caches.delete).not.toHaveBeenCalledWith("another-feature-cache");
  });

  it.each(["/admin/settings", "/supporters", "/membership"])("keeps %s out of page caches", async (pathname) => {
    const w = worker();
    const response = await w.navigate(pathname);
    expect(await response?.text()).toBe("Live response");
    expect(w.cache.put).not.toHaveBeenCalled();
    w.fetch.mockRejectedValue(new TypeError("Offline"));
    expect(await (await w.navigate(pathname))?.text()).toBe("Offline recovery");
    expect(w.cache.match).not.toHaveBeenCalled();
  });

  it.each(["private, max-age=0", "no-store"])("respects %s on a successful page response", async (policy) => {
    const w = worker(); w.fetch.mockResolvedValue(new Response("Account-specific page", { headers: { "Cache-Control": policy } }));
    expect(await (await w.navigate("/news"))?.text()).toBe("Account-specific page");
    expect(w.cache.put).not.toHaveBeenCalled();
  });

  it("keeps the live page available when browser cache storage is denied", async () => {
    const w = worker(); w.caches.open.mockRejectedValue(new DOMException("Storage denied", "SecurityError"));
    expect(await (await w.navigate("/news"))?.text()).toBe("Live response");
  });

  it("renders cached recovery without unavailable hydration scripts", async () => {
    const w = worker();
    w.caches.match.mockResolvedValue(new Response("<h1>You are offline</h1>", { headers: { "Content-Type": "text/html", "Content-Encoding": "gzip", "Content-Length": "24" } }));
    w.fetch.mockRejectedValue(new TypeError("Origin disconnected"));
    const response = await w.navigate("/membership");
    expect(response?.headers.get("content-security-policy")).toContain("script-src 'none'");
    expect(response?.headers.get("x-africlub-offline")).toBe("1");
    expect(response?.headers.has("content-encoding")).toBe(false);
    expect(response?.headers.has("content-length")).toBe(false);
    expect(await response?.text()).toBe("<h1>You are offline</h1>");
  });

  it("precaches recovery styles and fonts while excluding foreign assets and scripts", async () => {
    const w = worker();
    w.cache.match.mockImplementation(async () => new Response('<link rel="stylesheet" href="/_next/static/recovery.css"><link as="font" href="/_next/static/recovery.woff2"><link rel="stylesheet" href="https://external.invalid/style.css"><script src="/_next/static/runtime.js"></script>'));
    await w.event("install");
    expect(w.cache.addAll).toHaveBeenLastCalledWith([
      "https://qa.example.invalid/_next/static/recovery.css",
      "https://qa.example.invalid/_next/static/recovery.woff2",
    ]);
  });

  it("does not report a successful empty search when offline with no cache", async () => {
    const w = worker(); w.fetch.mockRejectedValue(new TypeError("Offline"));
    const response = await vm.runInContext("apiNetworkFirst(new Request('https://qa.example.invalid/api/search-index'))", w.context) as Response;
    expect(response.status).toBe(503);
  });

  it("keeps a successful response available after a quota write failure", async () => {
    const w = worker(); w.cache.put.mockRejectedValue(new DOMException("Quota exceeded", "QuotaExceededError"));
    expect(await (await w.navigate("/news"))?.text()).toBe("Live response");
  });

  it.each(["https://qa.example.invalid/api/admin/content-blocks/save", "https://other.example.invalid/submit", "/api/pwa/push", "/api/shop/orders", "/api/subscriptions"])(
    "retains legacy queued %s without sending it in a later session", async (url) => {
      const w = worker(); const deleted = vi.fn();
      const db = {
        transaction: () => ({ objectStore: () => ({
          getAll: () => {
            const request = { result: [{ id: 1, url, method: "POST", headers: {}, body: "{}" }], onsuccess: null as null | (() => void) };
            queueMicrotask(() => request.onsuccess?.()); return request;
          },
          delete: deleted,
        }) }),
      };
      w.context.queuedDb = db;
      vm.runInContext("openOfflineDB = async () => queuedDb", w.context);
      await w.event("sync", { tag: "admin-mutation-sync" });
      expect(w.fetch).not.toHaveBeenCalled(); expect(deleted).not.toHaveBeenCalled();
    },
  );

  it("retains unbound queued requests without a speculative retry", async () => {
    const w = worker(); const deleted = vi.fn();
    w.fetch.mockResolvedValue(new Response("Unconfirmed", { status: 503 }));
    w.context.queuedDb = { transaction: () => ({ objectStore: () => ({
      getAll: () => {
        const request = { result: [{ id: 1, url: "/api/qa-retained-request", method: "POST", headers: {}, body: "{}" }], onsuccess: null as null | (() => void) };
        queueMicrotask(() => request.onsuccess?.()); return request;
      }, delete: deleted,
    }) }) };
    vm.runInContext("openOfflineDB = async () => queuedDb", w.context);
    await w.event("sync", { tag: "gikundiro-mutation-sync" });
    expect(w.fetch).not.toHaveBeenCalled(); expect(deleted).not.toHaveBeenCalled();
  });
});
