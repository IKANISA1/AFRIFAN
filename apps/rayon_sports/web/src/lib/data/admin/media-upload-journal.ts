import type { AdminAccess } from "@/lib/types";
import type { AdminMediaKind, UploadedAdminImage } from "./media";

export interface AdminUploadJournalEntry {
  version: 2;
  operationId: string;
  userId: string;
  clubId: string;
  kind: AdminMediaKind;
  mimeType: string;
  byteLength: number;
  contentSha256: string;
  scopeHash: string;
}
type LegacyUploadJournalEntry = Omit<AdminUploadJournalEntry, "version" | "scopeHash"> & { version: 1 };
type ReleaseJournalEntry = AdminUploadJournalEntry | LegacyUploadJournalEntry;
export type AdminUploadFileBinding = Pick<AdminUploadJournalEntry, "mimeType" | "byteLength" | "contentSha256">;
const legacyPrefix = "africlub.admin-upload.v1";
const prefix = "africlub.admin-upload.v2";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const kinds = new Set(["shop_product", "news_article", "home_banner", "fan_club", "match", "squad_player", "notification"]);
const mimes = new Set(["image/jpeg", "image/png", "image/webp"]);
const unavailable = "The original upload reference could not be saved. No new upload was sent.";

function ownerScope(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind) {
  if (!access.userId || !/^[0-9a-f-]{36}$/i.test(access.userId) || !access.clubId
    || !/^[1-9]\d*$/.test(access.clubId) || !Number.isSafeInteger(Number(access.clubId)) || !kinds.has(kind)) {
    throw new Error("Choose a verified staff account and club before recovering an upload.");
  }
  return `${access.userId}:${access.clubId}:${kind}`;
}
async function hashScope(scopeKey: string) {
  if (typeof scopeKey !== "string" || !scopeKey.length || scopeKey.length > 16384) {
    throw new Error("A bounded record scope is required before recovering an upload.");
  }
  const bytes = new TextEncoder().encode(scopeKey);
  if (bytes.length > 65536) throw new Error("A bounded record scope is required before recovering an upload.");
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))].map(b => b.toString(16).padStart(2, "0")).join("");
}
function scope(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind, scopeHash: string) {
  if (!/^[0-9a-f]{64}$/.test(scopeHash)) throw new Error("The saved upload reference needs recovery. No new upload was sent.");
  return `${prefix}:${ownerScope(access, kind)}:${scopeHash}`;
}
function store() {
  try { if (typeof localStorage !== "undefined") return localStorage; } catch { /* Fail closed below. */ }
  throw new Error(unavailable);
}
function get(key: string) {
  try { return store().getItem(key); } catch { throw new Error(unavailable); }
}
function persist(key: string, value: string) {
  try { store().setItem(key, value); if (store().getItem(key) === value) return; } catch { /* Keep any original records. */ }
  throw new Error(unavailable);
}
function parse(raw: string, access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind,
  scopeHash: string | null): ReleaseJournalEntry {
  try {
    const value = JSON.parse(raw) as AdminUploadJournalEntry;
    const fields = scopeHash === null ? "byteLength,clubId,contentSha256,kind,mimeType,operationId,userId,version"
      : "byteLength,clubId,contentSha256,kind,mimeType,operationId,scopeHash,userId,version";
    if (Object.keys(value).sort().join(",") !== fields
      || value.version !== (scopeHash === null ? 1 : 2) || (scopeHash !== null && value.scopeHash !== scopeHash)
      || value.userId !== access.userId || value.clubId !== access.clubId || value.kind !== kind
      || !uuid.test(value.operationId) || !mimes.has(value.mimeType) || !Number.isSafeInteger(value.byteLength)
      || value.byteLength <= 0 || value.byteLength > 5 * 1024 * 1024 || !/^[0-9a-f]{64}$/.test(value.contentSha256)) throw new Error();
    return value;
  } catch { throw new Error("The saved upload reference needs recovery. No new upload was sent."); }
}
export class AdminUploadLegacyReferenceError extends Error {
  readonly code = "ADMIN_UPLOAD_LEGACY_REFERENCE";
  constructor(readonly operationId: string) {
    super("A saved upload has no record binding. Only its confirmed unused-reference release can clear it.");
    this.name = "AdminUploadLegacyReferenceError";
  }
}
function readAt(key: string, access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind, scopeHash: string | null) {
  const raw = get(`${key}:pending`);
  if (raw === null) return null;
  const entry = parse(raw, access, kind, scopeHash);
  if (get(`${key}:${entry.operationId}`) !== raw) throw new Error("The saved upload reference needs recovery. No new upload was sent.");
  return entry;
}
function readLegacy(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind) {
  return readAt(`${legacyPrefix}:${ownerScope(access, kind)}`, access, kind, null);
}
function readScoped(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind, scopeHash: string) {
  return readAt(scope(access, kind, scopeHash), access, kind, scopeHash) as AdminUploadJournalEntry | null;
}
function rejectLegacy(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind) {
  const legacy = readLegacy(access, kind);
  if (legacy) throw new AdminUploadLegacyReferenceError(legacy.operationId);
}
export async function readPendingAdminUpload(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind,
  scopeKey: string): Promise<AdminUploadJournalEntry | null> {
  if (!access.userId || !access.clubId) return null;
  const scopeHash = await hashScope(scopeKey);
  rejectLegacy(access, kind);
  return readScoped(access, kind, scopeHash);
}

async function withScopedLocks<T>(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind,
  scopeKey: string, action: (scopeHash: string) => Promise<T>): Promise<T> {
  if (typeof navigator === "undefined" || !navigator.locks?.request) {
    throw new Error("This browser cannot safely retain an upload. Use a browser with secure operation locking.");
  }
  const scopeHash = await hashScope(scopeKey);
  // Every new record scope takes the legacy lock first. An explicit legacy
  // release cannot race admission from a different record/window.
  return navigator.locks.request(`${legacyPrefix}:${ownerScope(access, kind)}`, () =>
    navigator.locks.request(scope(access, kind, scopeHash), () => action(scopeHash)));
}
export async function withAdminUploadJournal<T>(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind,
  scopeKey: string, action: (entry: AdminUploadJournalEntry | null, scopeHash: string) => Promise<T>): Promise<T> {
  return withScopedLocks(access, kind, scopeKey, async scopeHash => {
    rejectLegacy(access, kind);
    return action(readScoped(access, kind, scopeHash), scopeHash);
  });
}
export async function withAdminUploadReleaseJournal<T>(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind,
  scopeKey: string, action: (entry: ReleaseJournalEntry | null) => Promise<T>): Promise<T> {
  return withScopedLocks(access, kind, scopeKey, async scopeHash => action(readLegacy(access, kind) ?? readScoped(access, kind, scopeHash)));
}

// Called only under the scoped Web Lock, after current owner verification.
export function retainAdminUpload(access: Pick<AdminAccess, "userId" | "clubId">, kind: AdminMediaKind,
  scopeHash: string, binding: AdminUploadFileBinding): AdminUploadJournalEntry {
  rejectLegacy(access, kind);
  const key = scope(access, kind, scopeHash);
  const prior = readScoped(access, kind, scopeHash);
  if (prior) {
    if (prior.mimeType !== binding.mimeType || prior.byteLength !== binding.byteLength || prior.contentSha256 !== binding.contentSha256) {
      throw new Error("Check the saved upload before selecting a different image. Reselect the original file to retry its reference.");
    }
    return prior;
  }
  const entry = parse(JSON.stringify({ version: 2, operationId: crypto.randomUUID(), userId: access.userId,
    clubId: access.clubId, kind, scopeHash, ...binding }), access, kind, scopeHash) as AdminUploadJournalEntry;
  const serialized = JSON.stringify(entry);
  // Original metadata is retained without eviction. Neither bytes nor tokens
  // enter Storage; the pending pointer must read back before the Edge mutation.
  persist(`${key}:${entry.operationId}`, serialized);
  persist(`${key}:pending`, serialized);
  return entry;
}

export function acknowledgeAdminUpload(entry: AdminUploadJournalEntry, image: UploadedAdminImage) {
  const access = { userId: entry.userId, clubId: entry.clubId };
  const key = scope(access, entry.kind, entry.scopeHash);
  if (readScoped(access, entry.kind, entry.scopeHash)?.operationId !== entry.operationId) throw new Error("The original upload reference changed. Check its status.");
  persist(`${key}:${entry.operationId}:acknowledged`, JSON.stringify({ ...entry, status: "completed", ...image }));
  try { store().removeItem(`${key}:pending`); if (store().getItem(`${key}:pending`) === null) return; } catch { /* Retain original metadata. */ }
  throw new Error("Upload was confirmed; recover its original reference before continuing.");
}
export function acknowledgeAdminUploadRelease(entry: ReleaseJournalEntry) {
  const access = { userId: entry.userId, clubId: entry.clubId };
  const key = entry.version === 1 ? `${legacyPrefix}:${ownerScope(access, entry.kind)}` : scope(access, entry.kind, entry.scopeHash);
  if (readAt(key, access, entry.kind, entry.version === 1 ? null : entry.scopeHash)?.operationId !== entry.operationId) {
    throw new Error("The original upload reference changed. Check its status.");
  }
  persist(`${key}:${entry.operationId}:acknowledged`, JSON.stringify({ ...entry, released: true }));
  try { store().removeItem(`${key}:pending`); if (store().getItem(`${key}:pending`) === null) return; } catch { /* Keep the original. */ }
  throw new Error("Unused reference was released; recover its original acknowledgement before continuing.");
}
