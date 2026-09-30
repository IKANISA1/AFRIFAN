import { recordProductDiagnostic } from "./privacy-safe-diagnostics";

/** Inspect retained legacy requests. New requests are never persisted or replayed. */
const DB_NAME = "gikundiro-offline-queue";
const DB_VERSION = 1;
const STORE_NAME = "requests";

type OfflineFailureCode = "offline_queue_disabled" | "offline_queue_unavailable" |
  "mutation_outcome_unknown" | "read_unavailable";

export class OfflineRequestFailure extends Error {
  constructor(
    readonly code: OfflineFailureCode,
    readonly requestOutcome: "unknown" | "unavailable" | "not_sent",
  ) {
    super(code);
    this.name = "OfflineRequestFailure";
  }
}

function unavailable() {
  return new OfflineRequestFailure("offline_queue_unavailable", "unavailable");
}

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const fail = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      reject(unavailable());
    };
    const timer = setTimeout(fail, 5000);
    try {
      const request = indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = () => {
        if (settled) { request.transaction?.abort(); return; }
        const db = request.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: "id", autoIncrement: true });
        }
      };
      request.onsuccess = () => {
        if (settled) { request.result.close(); return; }
        settled = true;
        clearTimeout(timer);
        resolve(request.result);
      };
      request.onerror = fail;
      request.onblocked = fail;
    } catch {
      fail();
    }
  });
}

/** Compatibility boundary: credentials, request bodies and mutations cannot enter IndexedDB. */
export async function queueOfflineMutation(
  url: string,
  method: string,
  headers: Record<string, string>,
  body: string | null,
  syncTag = "gikundiro-mutation-sync",
): Promise<void> {
  // Do not inspect or serialize private caller input, including header getters.
  void url; void method; void headers; void body; void syncTag;
  throw new OfflineRequestFailure("offline_queue_disabled", "not_sent");
}

async function inspectOrClear(clear: boolean): Promise<number> {
  const db = await openDB();
  try {
    return await new Promise<number>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, clear ? "readwrite" : "readonly");
      const store = tx.objectStore(STORE_NAME);
      let settled = false;
      const fail = () => {
        if (settled) return;
        settled = true; clearTimeout(timer); reject(unavailable());
      };
      const timer = setTimeout(() => {
        try { tx.abort(); } catch { /* The transaction may already be terminal. */ }
        fail();
      }, 5000);
      let count: number | undefined = clear ? 0 : undefined;
      const request = clear ? store.clear() : store.count();
      request.onsuccess = () => {
        if (!clear) count = request.result as number;
      };
      request.onerror = fail;
      tx.onerror = fail;
      tx.onabort = fail;
      tx.oncomplete = () => {
        if (settled) return;
        if (!Number.isSafeInteger(count) || count! < 0) { fail(); return; }
        settled = true; clearTimeout(timer);
        resolve(count!);
      };
    });
  } catch {
    throw unavailable();
  } finally {
    db.close();
  }
}

/** Count retained quarantined requests. Failure is not a verified empty queue. */
export async function getQueuedMutationCount(): Promise<number> {
  return inspectOrClear(false);
}

/** Explicit caller-requested deletion only; this operation does not submit requests. */
export async function clearOfflineQueue(): Promise<void> {
  try {
    await inspectOrClear(true);
  } catch {
    recordProductDiagnostic("offline_queue_clear_failed");
    throw unavailable();
  }
}

/** Exactly one attempt. A lost mutation response preserves an unknown server outcome. */
export async function fetchWithOfflineQueue(
  url: string,
  init: RequestInit = {},
): Promise<Response> {
  try {
    return await fetch(url, init);
  } catch {
    const method = typeof init.method === "string" ? init.method.toUpperCase() : "GET";
    const mutation = !["GET", "HEAD", "OPTIONS"].includes(method);
    if (mutation) recordProductDiagnostic("offline_mutation_outcome_unknown");
    throw new OfflineRequestFailure(
      mutation ? "mutation_outcome_unknown" : "read_unavailable",
      mutation ? "unknown" : "unavailable",
    );
  }
}
