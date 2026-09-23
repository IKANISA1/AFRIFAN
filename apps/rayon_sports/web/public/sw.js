const STATIC_CACHE = "gikundiro-static-v8";
const PAGE_CACHE = "gikundiro-pages-v8";
const ASSET_CACHE = "gikundiro-assets-v8";
const API_CACHE = "gikundiro-api-v8";
const PRECACHE_URLS = [
  "/offline",
  "/admin-offline",
  "/manifest.webmanifest",
  "/brand-mark.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(STATIC_CACHE)
      .then(async (cache) => {
        await cache.addAll(PRECACHE_URLS);
        // Recovery must render even when its first navigation has no network.
        // These pages use the shared stylesheet and locally hosted fonts.
        const assets = new Set();
        for (const pathname of ["/offline", "/admin-offline"]) {
          const response = await cache.match(pathname);
          if (!response) continue;
          const html = await response.text();
          for (const link of html.matchAll(/<link\b[^>]*>/gi)) {
            if (!/\brel=["']stylesheet["']|\bas=["']font["']/i.test(link[0])) continue;
            const href = /\bhref=["']([^"']+)["']/i.exec(link[0])?.[1];
            if (!href) continue;
            const url = new URL(href, self.location.origin);
            if (url.origin === self.location.origin && url.pathname.startsWith("/_next/static/")) assets.add(url.href);
          }
        }
        if (assets.size) await cache.addAll([...assets]);
      }),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (key) =>
                /^gikundiro-(static|pages|assets|api)-v\d+$/.test(key) &&
                ![STATIC_CACHE, PAGE_CACHE, ASSET_CACHE, API_CACHE].includes(key),
            )
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }

  if (event.data && event.data.type === "CLEAR_BADGE") {
    if ("clearAppBadge" in self.navigator) {
      self.navigator.clearAppBadge();
    }
  }
});

async function openCache(name) {
  try {
    return await caches.open(name);
  } catch {
    return null;
  }
}

async function readCache(cache, request) {
  try {
    return await cache?.match(request);
  } catch {
    return undefined;
  }
}

async function storePublicResponse(cache, request, response) {
  if (!cache || !response?.ok || request.headers?.has("authorization")) return;
  if (/(?:^|,)\s*(?:private|no-store)\b/i.test(response.headers.get("cache-control") ?? "")) return;
  try {
    await cache.put(request, response.clone());
  } catch {
    // Quota or unavailable storage must not turn a live response into failure.
  }
}

async function offlineRecovery(pathname) {
  try {
    const response = await caches.match(pathname);
    if (response) {
      const headers = new Headers(response.headers);
      // Render the server's recovery document without hydrating a different
      // route or loading unavailable Next chunks. Its links remain ordinary
      // navigation and recover normally once the origin is reachable again.
      headers.set("Content-Security-Policy", "default-src 'self'; script-src 'none'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; form-action 'none'");
      headers.set("Cache-Control", "no-store");
      headers.set("X-Africlub-Offline", "1");
      headers.delete("content-length");
      headers.delete("content-encoding");
      return new Response(await response.text(), { status: response.status, headers });
    }
  } catch {
    // A first visit or denied storage can leave the offline shell unavailable.
  }
  return new Response("You are offline. Reconnect and try again.", {
    status: 503,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

function isPrivatePath(pathname) {
  return /^\/(?:admin|supporters|membership)(?:\/|$)/.test(pathname);
}

async function networkFirst(request) {
  try {
    const response = await fetch(request);
    await storePublicResponse(await openCache(PAGE_CACHE), request, response);
    return response;
  } catch {
    const cached = await readCache(await openCache(PAGE_CACHE), request);
    if (cached) {
      return cached;
    }
    return offlineRecovery("/offline");
  }
}

async function staleWhileRevalidate(request) {
  const cache = await openCache(ASSET_CACHE);
  const cached = await readCache(cache, request) ??
    await readCache(await openCache(STATIC_CACHE), request);
  const network = fetch(request)
    .then(async (response) => {
      await storePublicResponse(cache, request, response);
      return response;
    })
    .catch(() => cached || Response.error());

  return cached || network;
}

async function apiNetworkFirst(request) {
  try {
    const response = await fetch(request);
    await storePublicResponse(await openCache(API_CACHE), request, response);
    return response;
  } catch {
    const cached = await readCache(await openCache(API_CACHE), request);
    if (cached) {
      return cached;
    }
    return new Response(JSON.stringify({ error: "Search needs a connection.", code: "OFFLINE_UNAVAILABLE" }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") {
    return;
  }

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  if (url.pathname === "/api/search-index") {
    event.respondWith(apiNetworkFirst(request));
    return;
  }

  if (url.pathname.startsWith("/api/")) {
    return;
  }

  if (request.mode === "navigate" && isPrivatePath(url.pathname)) {
    // Authenticated pages are never reusable public offline snapshots.
    event.respondWith(
      fetch(request).catch(() => offlineRecovery(url.pathname.startsWith("/admin") ? "/admin-offline" : "/offline")),
    );
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(networkFirst(request));
    return;
  }

  if (
    url.pathname.startsWith("/_next/static/") ||
    request.destination === "image" ||
    request.destination === "style" ||
    request.destination === "script" ||
    request.destination === "font"
  ) {
    event.respondWith(staleWhileRevalidate(request));
  }
});

/* ─── Push Notifications ─────────────────────────────────── */

self.addEventListener("push", (event) => {
  if (!event.data) return;

  let data;
  try {
    data = event.data.json();
  } catch {
    data = { title: "Gikundiro Admin", body: event.data.text() };
  }

  const title = data.title || "Gikundiro Admin";
  const options = {
    body: data.body || "",
    icon: data.icon || "/brand-mark.svg",
    badge: data.badge || "/brand-mark.svg",
    tag: data.tag || "admin-notification",
    renotify: true,
    requireInteraction: data.requireInteraction || false,
    data: {
      url: data.url || "/admin",
      timestamp: Date.now(),
    },
    actions: data.actions || [
      { action: "open", title: "Open dashboard" },
      { action: "dismiss", title: "Dismiss" },
    ],
    vibrate: [100, 50, 100],
  };

  event.waitUntil(
    self.registration.showNotification(title, options).then(() => {
      // Update badge count
      if ("setAppBadge" in self.navigator) {
        return self.navigator.setAppBadge(data.badgeCount ?? 1);
      }
    }),
  );
});

/* ─── Notification Click ─────────────────────────────────── */

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  if (event.action === "dismiss") return;

  const targetUrl = event.notification.data?.url || "/admin";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      // Try to focus an existing window
      for (const client of clients) {
        if (client.url.includes("/admin") && "focus" in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      // No existing window — open a new one
      return self.clients.openWindow(targetUrl);
    }).then(() => {
      // Clear badge after clicking
      if ("clearAppBadge" in self.navigator) {
        return self.navigator.clearAppBadge();
      }
    }),
  );
});

/* ─── Background Sync — Preserve Legacy Mutations ────────── */

async function replayOfflineQueue() {
  // Every legacy record lacks an account binding and an idempotency key.
  // A later session cannot safely infer who submitted it or whether the first
  // request committed. Preserve IndexedDB records for explicit reconciliation;
  // do not send or delete any of them, including non-admin and renamed routes.
  return;
}

self.addEventListener("sync", (event) => {
  if (
    event.tag === "admin-mutation-sync" ||
    event.tag === "gikundiro-mutation-sync"
  ) {
    event.waitUntil(replayOfflineQueue());
  }
});

/* ─── Periodic Background Sync ───────────────────────────── */

self.addEventListener("periodicsync", (event) => {
  if (event.tag === "admin-dashboard-refresh") {
    event.waitUntil(
      fetch("/admin", { cache: "no-store" }).catch(() => {}),
    );
  }

  if (event.tag === "public-content-refresh") {
    event.waitUntil(
      Promise.all(
        ["/", "/fixtures", "/news", "/shop", "/membership"].map((url) =>
          networkFirst(new Request(new URL(url, self.location.origin))),
        ),
      ),
    );
  }
});
