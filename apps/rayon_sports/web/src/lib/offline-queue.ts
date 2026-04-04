/**
 * IndexedDB-backed offline mutation queue.
 *
 * When the app is offline, failed POST/PUT/DELETE requests are saved here.
 * The service worker replays them via Background Sync when connectivity returns.
 */

const DB_NAME = "gikundiro-offline-queue";
const DB_VERSION = 1;
const STORE_NAME = "requests";

interface QueuedRequest {
  id?: number;
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string | null;
  timestamp: number;
}

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: "id", autoIncrement: true });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

/**
 * Queue a failed mutation for later replay via Background Sync.
 */
export async function queueOfflineMutation(
  url: string,
  method: string,
  headers: Record<string, string>,
  body: string | null,
): Promise<void> {
  try {
    const db = await openDB();
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);

    const entry: QueuedRequest = {
      url,
      method,
      headers,
      body,
      timestamp: Date.now(),
    };

    store.add(entry);

    await new Promise<void>((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });

    // Register for Background Sync
    if ("serviceWorker" in navigator && "SyncManager" in window) {
      const registration = await navigator.serviceWorker.ready;
      await (registration as ServiceWorkerRegistration & { sync: { register: (tag: string) => Promise<void> } })
        .sync.register("admin-mutation-sync");
    }
  } catch (error) {
    console.error("[offline-queue] Failed to queue mutation:", error);
  }
}

/**
 * Get the count of queued mutations.
 */
export async function getQueuedMutationCount(): Promise<number> {
  try {
    const db = await openDB();
    const tx = db.transaction(STORE_NAME, "readonly");
    const store = tx.objectStore(STORE_NAME);

    return new Promise((resolve, reject) => {
      const request = store.count();
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  } catch {
    return 0;
  }
}

/**
 * Clear all queued mutations (e.g., after manual sync).
 */
export async function clearOfflineQueue(): Promise<void> {
  try {
    const db = await openDB();
    const tx = db.transaction(STORE_NAME, "readwrite");
    tx.objectStore(STORE_NAME).clear();

    await new Promise<void>((resolve, reject) => {
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    console.error("[offline-queue] Failed to clear queue");
  }
}

/**
 * Fetch wrapper that queues failed mutations for offline replay.
 */
export async function fetchWithOfflineQueue(
  url: string,
  init: RequestInit = {},
): Promise<Response> {
  try {
    const response = await fetch(url, init);
    return response;
  } catch (error) {
    const method = init.method ?? "GET";

    // Only queue mutations, not reads
    if (["POST", "PUT", "PATCH", "DELETE"].includes(method.toUpperCase())) {
      const headers: Record<string, string> = {};
      if (init.headers) {
        const h = init.headers as Record<string, string>;
        for (const key of Object.keys(h)) {
          headers[key] = h[key];
        }
      }

      await queueOfflineMutation(
        url,
        method,
        headers,
        typeof init.body === "string" ? init.body : null,
      );

      // Return a synthetic response indicating queued
      return new Response(
        JSON.stringify({ queued: true, message: "Saved offline — will sync when connected" }),
        { status: 202, headers: { "Content-Type": "application/json" } },
      );
    }

    throw error;
  }
}
