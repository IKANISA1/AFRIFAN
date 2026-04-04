const STATIC_CACHE = "gikundiro-static-v3";
const PAGE_CACHE = "gikundiro-pages-v3";
const ASSET_CACHE = "gikundiro-assets-v3";
const PRECACHE_URLS = ["/offline", "/admin-offline", "/media/rayon-crest.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(STATIC_CACHE)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting()),
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
                ![STATIC_CACHE, PAGE_CACHE, ASSET_CACHE].includes(key),
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
});

async function networkFirst(request) {
  const cache = await caches.open(PAGE_CACHE);
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    const cached = await cache.match(request);
    if (cached) {
      return cached;
    }
    return caches.match("/offline");
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(ASSET_CACHE);
  const cached = await cache.match(request);
  const network = fetch(request)
    .then((response) => {
      if (response && response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => cached);

  return cached || network;
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

  if (url.pathname.startsWith("/api/")) {
    return;
  }

  if (request.mode === "navigate" && url.pathname.startsWith("/admin")) {
    // Network-only for admin navigations — never serve stale admin content from cache
    event.respondWith(
      fetch(request).catch(() => caches.match("/admin-offline")),
    );
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(networkFirst(request));
    return;
  }

  if (
    url.pathname.startsWith("/_next/") ||
    url.pathname.startsWith("/media/") ||
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
    icon: data.icon || "/icons/icon-192x192.png",
    badge: data.badge || "/icons/icon-72x72.png",
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
        return self.navigator.setAppBadge();
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
        await fetch(entry.url, {
          method: entry.method,
          headers: entry.headers,
          body: entry.body,
        });
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
  if (event.tag === "admin-mutation-sync") {
    event.waitUntil(replayOfflineQueue());
  }
});

/* ─── Periodic Background Sync ───────────────────────────── */

self.addEventListener("periodicsync", (event) => {
  if (event.tag === "admin-dashboard-refresh") {
    event.waitUntil(
      // Pre-fetch dashboard data so it's fresh when the admin opens the app
      caches.open(PAGE_CACHE).then((cache) =>
        cache.add("/admin").catch(() => {
          // Silently fail — periodic sync is best-effort
        }),
      ),
    );
  }
});

