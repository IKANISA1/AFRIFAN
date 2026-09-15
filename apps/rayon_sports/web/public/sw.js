const STATIC_CACHE = "gikundiro-static-v6";
const PAGE_CACHE = "gikundiro-pages-v6";
const ASSET_CACHE = "gikundiro-assets-v6";
const API_CACHE = "gikundiro-api-v6";
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
      .then((cache) => cache.addAll(PRECACHE_URLS)),
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
    if (response) return response;
  } catch {
    // A first visit or denied storage can leave the offline shell unavailable.
  }
  return new Response("You are offline. Reconnect and try again.", {
    status: 503,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

function isPrivatePath(pathname) {
  return /^\/(?:admin|venue|supporters)(?:\/|$)/.test(pathname);
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
  const cached = await readCache(cache, request);
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

/* ─── Background Sync — Replay Offline Mutations ─────────── */

const OFFLINE_QUEUE_STORE = "gikundiro-offline-queue";

async function openOfflineDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(OFFLINE_QUEUE_STORE, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains("requests")) {
        db.createObjectStore("requests", { keyPath: "id", autoIncrement: true });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function replayOfflineQueue() {
  try {
    const db = await openOfflineDB();
    const tx = db.transaction("requests", "readwrite");
    const store = tx.objectStore("requests");
    const all = await new Promise((resolve, reject) => {
      const req = store.getAll();
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });

    for (const entry of all) {
      try {
        const target = new URL(entry.url, self.location.origin);
        // Legacy operator entries have no account binding or idempotency key.
        // Retain them for reconciliation; never replay under a later session.
        if (target.origin !== self.location.origin || /^\/api\/(?:admin|venue)(?:\/|$)/.test(target.pathname)) continue;
        const response = await fetch(target.href, {
          method: entry.method,
          headers: entry.headers,
          body: entry.body,
        });
        if (!response.ok) break;
        // Remove successfully replayed request
        const deleteTx = db.transaction("requests", "readwrite");
        deleteTx.objectStore("requests").delete(entry.id);
      } catch {
        // Leave it in queue for next sync
        console.log("[sw] Failed to replay request, will retry:", entry.url);
        break;
      }
    }
  } catch {
    console.error("[sw] Background sync replay failed");
  }
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
