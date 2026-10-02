import { webcrypto } from "node:crypto";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { acknowledgeAdminUpload, acknowledgeAdminUploadRelease, AdminUploadLegacyReferenceError, readPendingAdminUpload, retainAdminUpload, withAdminUploadJournal, withAdminUploadReleaseJournal } from "./media-upload-journal";
const owner = { userId: "99969000-0000-4000-8000-000000000001", clubId: "24" };
const scopeKey = "product:A private draft";
const binding = { mimeType: "image/png", byteLength: 9, contentSha256: "a".repeat(64) };
beforeEach(() => {
  vi.stubGlobal("crypto", webcrypto); localStorage.clear(); const queues = new Map<string, Promise<unknown>>();
  Object.defineProperty(navigator, "locks", { configurable: true, value: { request: (key: string, callback: () => unknown) => {
    const result = (queues.get(key) ?? Promise.resolve()).then(callback); queues.set(key, result.catch(() => undefined)); return result;
  } } });
});
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });
const keys = () => [...Array(localStorage.length)].map((_, i) => localStorage.key(i)!);
describe("retained upload metadata journal", () => {
  test("record scopes use only their hash in locks, pointers, originals and acknowledgements", async () => {
    const locks = vi.spyOn(navigator.locks, "request");
    const first = await withAdminUploadJournal(owner, "shop_product", scopeKey, async (_, hash) => retainAdminUpload(owner, "shop_product", hash, binding));
    const other = "product:B secret form";
    expect(await readPendingAdminUpload(owner, "shop_product", other)).toBeNull();
    const second = await withAdminUploadJournal(owner, "shop_product", other, async (_, hash) => retainAdminUpload(owner, "shop_product", hash, binding));
    expect(second.operationId).not.toBe(first.operationId); expect(second.scopeHash).not.toBe(first.scopeHash);
    await withAdminUploadJournal(owner, "shop_product", other, async entry => {
      acknowledgeAdminUpload(entry!, { publicUrl: "https://media.test/public/second.png", storagePath: "second.png" });
    });
    expect(await readPendingAdminUpload(owner, "shop_product", scopeKey)).toEqual(first);
    const persisted = keys().map(key => key + localStorage.getItem(key)).join(" ");
    expect(persisted).not.toContain(scopeKey); expect(persisted).not.toContain(other);
    expect(locks.mock.calls.map(call => call[0]).join(" ")).not.toContain(scopeKey);
    expect(locks.mock.calls.map(call => call[0]).join(" ")).toContain(first.scopeHash);
  });
  test("a valid recordless legacy reference is retained and isolated until explicitly acknowledged unused release", async () => {
    const entry = { version: 1, operationId: owner.userId, ...owner, kind: "shop_product", ...binding };
    const key = `africlub.admin-upload.v1:${owner.userId}:${owner.clubId}:shop_product`;
    localStorage.setItem(`${key}:${entry.operationId}`, JSON.stringify(entry)); localStorage.setItem(`${key}:pending`, JSON.stringify(entry));
    await expect(readPendingAdminUpload(owner, "shop_product", scopeKey)).rejects.toBeInstanceOf(AdminUploadLegacyReferenceError);
    await expect(withAdminUploadJournal(owner, "shop_product", scopeKey, async (_, hash) => retainAdminUpload(owner, "shop_product", hash, binding))).rejects.toBeInstanceOf(AdminUploadLegacyReferenceError);
    expect(await readPendingAdminUpload({ ...owner, clubId: "25" }, "shop_product", scopeKey)).toBeNull();
    await withAdminUploadReleaseJournal(owner, "shop_product", scopeKey, async original => {
      expect(original).toEqual(entry); acknowledgeAdminUploadRelease(original!);
    });
    expect(localStorage.getItem(`${key}:pending`)).toBeNull();
    expect(JSON.parse(localStorage.getItem(`${key}:${entry.operationId}:acknowledged`)!)).toEqual({ ...entry, released: true });
    expect(localStorage.getItem(`${key}:${entry.operationId}`)).toBe(JSON.stringify(entry));
  });
  test("corrupt or foreign legacy records do not advertise an unused release", async () => {
    const key = `africlub.admin-upload.v1:${owner.userId}:${owner.clubId}:shop_product:pending`;
    for (const raw of ["broken", JSON.stringify({ version: 1, operationId: owner.userId, ...owner, kind: "match", ...binding })]) {
      localStorage.setItem(key, raw);
      const error = await readPendingAdminUpload(owner, "shop_product", scopeKey).catch(error => error);
      expect(error).toBeInstanceOf(Error); expect(error).not.toBeInstanceOf(AdminUploadLegacyReferenceError);
      expect(localStorage.getItem(key)).toBe(raw);
    }
  });
  test("isolates owner, club and kind without disclosing another account's retained file binding", async () => {
    const original = await withAdminUploadJournal(owner, "shop_product", scopeKey, async (_, hash) => retainAdminUpload(owner, "shop_product", hash, binding));
    expect(await readPendingAdminUpload({ ...owner, userId: "99969000-0000-4000-8000-000000000002" }, "shop_product", scopeKey)).toBeNull();
    expect(await readPendingAdminUpload({ ...owner, clubId: "25" }, "shop_product", scopeKey)).toBeNull(); expect(await readPendingAdminUpload(owner, "match", scopeKey)).toBeNull();
    expect(await readPendingAdminUpload(owner, "shop_product", scopeKey)).toEqual(original);
  });
  test.each(["corrupt", "foreign", "extraBytes", "missingOriginal"])("%s pending metadata fails closed rather than minting a replacement key", async failure => {
    await withAdminUploadJournal(owner, "shop_product", scopeKey, async (_, hash) => retainAdminUpload(owner, "shop_product", hash, binding));
    const pendingKey = keys().find(k => k.endsWith(":pending"))!; const pending = localStorage.getItem(pendingKey)!;
    if (failure === "corrupt") localStorage.setItem(pendingKey, "{broken");
    if (failure === "foreign") localStorage.setItem(pendingKey, JSON.stringify({ ...JSON.parse(pending), clubId: "25" }));
    if (failure === "extraBytes") localStorage.setItem(pendingKey, JSON.stringify({ ...JSON.parse(pending), image_data_base64: "private-bytes" }));
    if (failure === "missingOriginal") localStorage.removeItem(keys().find(k => !k.endsWith(":pending"))!);
    const send = vi.fn(); await expect(withAdminUploadJournal(owner, "shop_product", scopeKey, send)).rejects.toThrow("needs recovery"); expect(send).not.toHaveBeenCalled();
  });
  test("acknowledges before clearing and never evicts prior original operation records", async () => {
    const first = await withAdminUploadJournal(owner, "shop_product", scopeKey, async (_, hash) => {
      const entry = retainAdminUpload(owner, "shop_product", hash, binding);
      acknowledgeAdminUpload(entry, { publicUrl: "https://media.test/public/first.png", storagePath: "first.png" }); return entry;
    });
    const second = await withAdminUploadJournal(owner, "shop_product", scopeKey, async (_, hash) => retainAdminUpload(owner, "shop_product", hash, binding));
    expect(second.operationId).not.toBe(first.operationId);
    expect(keys().some(k => k.endsWith(`:${first.operationId}`))).toBe(true);
    expect(keys().some(k => k.endsWith(`:${first.operationId}:acknowledged`))).toBe(true);
    expect((await readPendingAdminUpload(owner, "shop_product", scopeKey))?.operationId).toBe(second.operationId);
  });
  test("a missing storage API and denied access cannot send an upload", async () => {
    const send = vi.fn(); vi.stubGlobal("localStorage", undefined);
    try { await expect(withAdminUploadJournal(owner, "shop_product", scopeKey, send)).rejects.toThrow("could not be saved"); expect(send).not.toHaveBeenCalled(); }
    finally { vi.unstubAllGlobals(); }
  });
});
