const STATIC_CACHE = "gikundiro-static-v9";
const PAGE_CACHE = "gikundiro-pages-v9";
const ASSET_CACHE = "gikundiro-assets-v9";
const API_CACHE = "gikundiro-api-v9";
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
  if (event.data?.type === "AFRICLUB_PRIVATE_CACHE_CHECK") {
    let trusted=false;
    try { trusted=!!event.source?.url&&new URL(event.source.url).origin===self.location.origin; } catch {}
    if(trusted)event.waitUntil(purgePrivateCaches().then(purged=>event.ports?.[0]?.postMessage({protocol:"africlub-private-cache-v1",purged}))
      .catch(()=>event.ports?.[0]?.postMessage({protocol:"africlub-private-cache-v1",purged:false})));
    return;
  }
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
  if (!cache || !response?.ok || privateRequest(request) || response.redirected) return;
  const url=new URL(request.url);
  if(isPrivatePath(url.pathname)&&url.pathname!=="/api/search-index")return;
  if(/(?:^|,)\s*cookie\s*(?:,|$)/i.test(response.headers.get("vary")??""))return;
  if(!url.pathname.startsWith("/_next/static/")&&!/(?:^|,)\s*public\b/i.test(response.headers.get("cache-control")??""))return;
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
  return /^\/(?:admin|operator|supporters|membership|auth|account-deletion|v1|api)(?:\/|$)/.test(pathname);
}
function privateRequest(request) {
  const url=new URL(request.url);
  return url.pathname.includes("%") || (isPrivatePath(url.pathname)&&url.pathname!=="/api/search-index")||
    request.headers.has("authorization")||request.headers.has("rsc")||request.headers.has("next-action")||request.headers.has("next-router-prefetch");
}
async function privateNetwork(request) {
  try { return await fetch(request,{cache:"no-store"}); }
  catch {
    if(request.mode==="navigate") {
      const page=await offlineRecovery(new URL(request.url).pathname.startsWith("/admin")?"/admin-offline":"/offline");
      return new Response(page.body,{status:503,headers:page.headers});
    }
    return new Response(JSON.stringify({error:"connection_required"}),{status:503,headers:{"Content-Type":"application/json","Cache-Control":"private, no-store"}});
  }
}
async function purgePrivateCaches() {
  // Only this application's dynamic cache namespaces; never localStorage/IndexedDB or another app's caches.
  const keys=await caches.keys();
  const results=await Promise.all(keys.filter(key=>/^gikundiro-(pages|api)-v\d+$/.test(key)).map(key=>caches.delete(key)));
  return results.every(Boolean);
}


async function networkFirst(request) {
  if(privateRequest(request))return privateNetwork(request);
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

  if (privateRequest(request)) {
    event.respondWith(privateNetwork(request));
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

/* ─── Data-minimized notifications; never a payment or login command ─── */

function notificationPath(value) {
  // Only app landing pages are accepted. No external URLs, query credentials,
  // account IDs, redirects or encoded/normalized alternate paths are followed.
  if (typeof value !== "string" || value.length > 256 || /[%\\\s]/.test(value)) return "/admin";
  try {
    const url = new URL(value, self.location.origin);
    if (url.origin !== self.location.origin || url.protocol !== "https:" || url.username || url.password || url.search || url.hash) return "/admin";
    const allowed = new Set(["/admin", "/membership", "/news", "/fixtures", "/results", "/support"]);
    // Reject raw dot segments and URL normalization, even if the result is allowed.
    if (value !== url.pathname && value !== self.location.origin + url.pathname) return "/admin";
    return allowed.has(url.pathname) ? url.pathname : "/admin";
  } catch { return "/admin"; }
}

self.addEventListener("push", (event) => {
  if (!event.data) return;
  let data;
  try {
    const raw = event.data.text();
    if (raw.length > 4096) return;
    data = JSON.parse(raw);
    if (!data || typeof data !== "object" || Array.isArray(data)) return;
  } catch { return; }
  const options = {
    body: "Open the app to view this update.", icon: "/brand-mark.svg", badge: "/brand-mark.svg",
    tag: "africlub-update", data: { url: notificationPath(data.url) },
    actions: [{ action: "open", title: "Open app" }, { action: "dismiss", title: "Dismiss" }],
  };
  // Payload titles, amounts, raw messages, icons and arbitrary actions are not
  // displayed on a lock screen or persisted in notification metadata.
  event.waitUntil(self.registration.showNotification("AFRICLUB", options).then(async () => {
    try { if ("setAppBadge" in self.navigator) await self.navigator.setAppBadge(1); } catch { /* Cosmetic only. */ }
  }));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  if (event.action && event.action !== "open") return;
  // Validate again: already displayed legacy notifications may contain unsafe data.
  const path = notificationPath(event.notification.data?.url);
  const target = self.location.origin + path;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    const existing = windows.find(client => client.url === target && typeof client.focus === "function");
    if (existing) await existing.focus();
    else await self.clients.openWindow(target);
    try { if ("clearAppBadge" in self.navigator) await self.navigator.clearAppBadge(); } catch { /* Cosmetic only. */ }
  })());
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
        ["/", "/fixtures", "/news", "/shop"].map((url) =>
          networkFirst(new Request(new URL(url, self.location.origin))),
        ),
      ),
    );
  }
});
