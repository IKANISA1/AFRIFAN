// @vitest-environment node
import { createHash } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { AdminImageUploadPendingError, AdminUploadLegacyReferenceError, buildAdminMediaStoragePath, checkAdminImageUploadStatus,
  defaultAspectRatioForAdminMediaKind, readPendingAdminUpload, releaseUnadmittedAdminImageUpload, uploadAdminImage } from "./media";

const userId = "99969000-0000-4000-8000-000000000001";
const scopeKey = "product:A private draft";
const otherUser = "99969000-0000-4000-8000-000000000002";
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: false, userId,
  role: "club_admin", clubId: "24", availableClubIds: ["24"], assignmentCount: 1, canSelectClub: false };
class MemoryStorage {
  values = new Map<string, string>(); fail = false; loseReadback = false; failAcknowledgement = false;
  getItem(key: string) { return this.loseReadback ? null : this.values.get(key) ?? null; }
  setItem(key: string, value: string) { if (this.fail || this.failAcknowledgement && key.endsWith(":acknowledged")) throw new Error("QuotaExceededError"); this.values.set(key, value); }
  removeItem(key: string) { this.values.delete(key); }
}
let storage: MemoryStorage;
beforeEach(() => {
  storage = new MemoryStorage(); vi.stubGlobal("localStorage", storage);
  const queues = new Map<string, Promise<unknown>>();
  vi.stubGlobal("navigator", { locks: { request: (key: string, callback: () => unknown) => {
    const result = (queues.get(key) ?? Promise.resolve()).then(callback); queues.set(key, result.catch(() => undefined)); return result;
  } } });
});
afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks(); });
const image = (suffix = 0, name = "image.png") => new File([new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, suffix])], name, { type: "image/png" });
async function fixture() {
  const state = { ownerId: userId, loseResponse: false, denyStatus: false, objects: 0, uploads: 0, statuses: 0,
    rejectBeforeAdmission: false, releases: [] as string[], loseReleaseResponse: false,
    releaseOverride: {} as Record<string, unknown>, beforeRelease: null as (() => Promise<void>) | null,
    status: "completed", override: {} as Record<string, unknown>, beforeUpload: null as (() => Promise<void>) | null,
    verifiedReads: 0, beforeVerifiedReturn: null as ((count: number) => Promise<void>) | null };
  const rows = new Map<string, Record<string, unknown>>();
  const token = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url") + "." +
    Buffer.from(JSON.stringify({ sub: userId, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 3600 })).toString("base64url") + ".test";
  const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    if (url.pathname === "/auth/v1/user") {
      const id = state.ownerId; state.verifiedReads++;
      if (state.beforeVerifiedReturn) await state.beforeVerifiedReturn(state.verifiedReads);
      return json({ id, aud: "authenticated", role: "authenticated", app_metadata: {}, user_metadata: {}, created_at: "2026-10-02T00:00:00Z" });
    }
    expect(url.pathname).toBe("/functions/v1/admin-upload-image"); expect(init?.method).toBe("POST");
    expect(new Headers(init?.headers).get("authorization")).toBe(`Bearer ${token}`);
    const body = JSON.parse(String(init?.body));
    if (body.mode === "status") {
      state.statuses++; expect(Object.keys(body).sort()).toEqual(["mode", "operation_id"]);
      return state.denyStatus || !rows.has(body.operation_id) ? json({ error: "Not found" }, 404) : json({ ...rows.get(body.operation_id), ...state.override });
    }
    if (body.mode === "release") {
      expect(Object.keys(body).sort()).toEqual(["club_id", "mode", "operation_id"]);
      expect(body.club_id).toBe(24);
      if (state.beforeRelease) await state.beforeRelease();
      if (rows.has(body.operation_id)) return json({ error: "Already admitted" }, 409);
      state.releases.push(body.operation_id);
      if (state.loseReleaseResponse) throw new Error("Release acknowledgement lost");
      return json({ operation_id: body.operation_id, actor_id: userId, club_id: 24, released: true, ...state.releaseOverride });
    }
    state.uploads++; if (state.beforeUpload) await state.beforeUpload();
    if (state.rejectBeforeAdmission) return json({ error: "Admission rejected" }, 400);
    expect(Object.keys(body).sort()).toEqual(["club_id", "image_data_base64", "kind", "mime_type", "operation_id"]);
    const pending = [...storage.values.entries()].filter(([key]) => key.endsWith(":pending")).map(([, value]) => JSON.parse(value)).find(value => value.operationId === body.operation_id)!;
    expect(pending.operationId).toBe(body.operation_id); expect(pending.clubId).toBe(String(body.club_id));
    const bytes = Buffer.from(body.image_data_base64, "base64");
    expect(pending.contentSha256).toBe(createHash("sha256").update(bytes).digest("hex")); expect(pending.byteLength).toBe(bytes.length);
    const path = `club-24/admin/shop_product/${body.operation_id}.png`;
    if (!rows.has(body.operation_id)) state.objects++;
    const receipt = { operation_id: body.operation_id, actor_id: userId, club_id: 24, kind: body.kind, mime_type: body.mime_type,
      byte_length: bytes.length, content_sha256: pending.contentSha256, bucket: "africlub-product-images", storage_path: path,
      status: state.status, ...(state.status === "completed" ? { image_url: `https://media.test/storage/v1/object/public/africlub-product-images/${path}` } : {}) };
    rows.set(body.operation_id, receipt);
    if (state.loseResponse) throw new Error("Committed upload response lost");
    return json({ ...receipt, ...state.override });
  });
  const client = createClient("https://media.test", "test-key", { global: { fetch: fetcher }, auth: { persistSession: false, autoRefreshToken: false } });
  await client.auth.setSession({ access_token: token, refresh_token: "test-refresh" });
  return { state, rows, client, fetcher };
}
describe("actual governed media upload consumer", () => {
  test("derives deterministic original UUID paths from MIME and preserves aspect ratios", () => {
    expect(buildAdminMediaStoragePath({ clubId: 24, kind: "shop_product", fileName: "wrong.jpg", mimeType: "image/png", operationId: userId }))
      .toBe(`club-24/admin/shop_product/${userId}.png`);
    expect(defaultAspectRatioForAdminMediaKind("shop_product")).toBe("1:1");
    expect(defaultAspectRatioForAdminMediaKind("squad_player")).toBe("3:4"); expect(defaultAspectRatioForAdminMediaKind("news_article")).toBe("16:9");
  });
  test("persists bound metadata before the actual caller SDK invokes Edge, then acknowledges exact configured Storage URL", async () => {
    const f = await fixture(); const result = await uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey });
    expect(result.publicUrl).toBe(`https://media.test/storage/v1/object/public/africlub-product-images/${result.storagePath}`);
    expect(f.state.objects).toBe(1); expect(f.state.uploads).toBe(1); expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).toBeNull();
    const archived = [...storage.values.values()].join(" "); expect(archived).toContain("completed");
    expect(archived).not.toContain("image_data_base64"); expect(archived).not.toContain("test-refresh"); expect(archived).not.toContain("image.png");
  });
  test("lost committed response survives reload and reselecting identical renamed bytes recovers without another upload", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const original = (await readPendingAdminUpload(access, "shop_product", scopeKey))!; f.state.loseResponse = false;
    const result = await uploadAdminImage(f.client, { ...access }, { file: image(0, "reselected.jpg"), kind: "shop_product", scopeKey });
    expect(result.storagePath).toContain(original.operationId); expect(f.state.uploads).toBe(1); expect(f.state.objects).toBe(1);
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).toBeNull();
  });
  test("record B cannot query or attach record A's unknown operation; returning to A recovers its original", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const original = await readPendingAdminUpload(access, "shop_product", scopeKey);
    const otherScope = "product:B other private draft";
    expect(await readPendingAdminUpload(access, "shop_product", otherScope)).toBeNull();
    expect(await checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey: otherScope })).toBeNull();
    expect(f.state.statuses).toBe(0);
    f.state.loseResponse = false;
    expect(await checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).toMatchObject({ operationId: original!.operationId, status: "completed" });
    expect(f.state.uploads).toBe(1);
    const persisted = [...storage.values.keys(), ...storage.values.values()].join(" ");
    expect(persisted).not.toContain(scopeKey); expect(persisted).not.toContain(otherScope);
    expect(original!.scopeHash).toBe(createHash("sha256").update(scopeKey).digest("hex"));
  });
  test.each(["image/png", "image/jpeg", "image/webp"])("invalid %s magic sends no HTTP request and retains no journal", async type => {
    const f = await fixture(); f.fetcher.mockClear();
    await expect(uploadAdminImage(f.client, access, { file: new File(["not an image"], "image", { type }), kind: "shop_product", scopeKey })).rejects.toThrow("image bytes");
    expect(f.fetcher).not.toHaveBeenCalled(); expect(storage.values.size).toBe(0);
  });
  test("lost unused-release acknowledgement keeps the original key and retries only that release before a new file", async () => {
    const f = await fixture(); f.state.rejectBeforeAdmission = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const entry = await readPendingAdminUpload(access, "shop_product", scopeKey);
    f.state.loseReleaseResponse = true;
    await expect(releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))!.operationId).toBe(entry!.operationId);
    await expect(uploadAdminImage(f.client, access, { file: image(1), kind: "shop_product", scopeKey })).rejects.toThrow("different image");
    f.state.loseReleaseResponse = false;
    expect(await releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).toEqual({ operationId: entry!.operationId, actorId: userId, clubId: 24, released: true });
    expect(f.state.releases).toEqual([entry!.operationId, entry!.operationId]);
    expect(await readPendingAdminUpload(access, "shop_product", scopeKey)).toBeNull();
    expect([...storage.values.values()].some(value => JSON.parse(value).released === true)).toBe(true);
    f.state.rejectBeforeAdmission = false;
    await uploadAdminImage(f.client, access, { file: image(1), kind: "shop_product", scopeKey });
    expect([...f.rows.keys()][0]).not.toBe(entry!.operationId);
  });
  test.each([{ actor_id: otherUser }, { club_id: 25 }, { operation_id: otherUser }, { released: false }, { image_url: "https://wrong.test" }])("invalid release binding %j preserves the original", async override => {
    const f = await fixture(); f.state.rejectBeforeAdmission = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const entry = await readPendingAdminUpload(access, "shop_product", scopeKey);
    f.state.releaseOverride = override;
    await expect(releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))!.operationId).toBe(entry!.operationId);
  });
  test("admitted release refusal, acknowledgement storage failure and account change retain original metadata", async () => {
    const f = await fixture(); f.state.status = "unknown";
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const entry = await readPendingAdminUpload(access, "shop_product", scopeKey);
    await expect(releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    expect(f.state.releases).toEqual([]); f.rows.clear(); storage.failAcknowledgement = true;
    await expect(releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).rejects.toThrow("could not be saved");
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))!.operationId).toBe(entry!.operationId);
    storage.failAcknowledgement = false; f.state.beforeRelease = async () => { f.state.ownerId = otherUser; };
    await expect(releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).rejects.toThrow("no longer owns");
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))!.operationId).toBe(entry!.operationId);
  });
  test("two windows release only the original unadmitted operation and another account cannot release it", async () => {
    const f = await fixture(); f.state.rejectBeforeAdmission = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const entry = await readPendingAdminUpload(access, "shop_product", scopeKey);
    f.state.ownerId = otherUser;
    await expect(releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).rejects.toThrow("no longer owns");
    expect(await releaseUnadmittedAdminImageUpload(f.client, { ...access, userId: otherUser }, "shop_product", { scopeKey })).toBeNull();
    expect(f.state.releases).toEqual([]); f.state.ownerId = userId;
    const result = await Promise.all([releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey }),
      releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })]);
    expect(result.filter(Boolean)).toEqual([{ operationId: entry!.operationId, actorId: userId, clubId: 24, released: true }]);
    expect(f.state.releases).toEqual([entry!.operationId]);
  });
  test("a legacy recordless reference never queries status or attaches, but can explicitly release the original unused command", async () => {
    const f = await fixture(); const key = `africlub.admin-upload.v1:${userId}:24:shop_product`;
    const entry = { version: 1, operationId: userId, userId, clubId: "24", kind: "shop_product", mimeType: "image/png", byteLength: 9, contentSha256: "a".repeat(64) };
    storage.setItem(`${key}:${userId}`, JSON.stringify(entry)); storage.setItem(`${key}:pending`, JSON.stringify(entry));
    await expect(readPendingAdminUpload(access, "shop_product", scopeKey)).rejects.toBeInstanceOf(AdminUploadLegacyReferenceError);
    await expect(checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).rejects.toBeInstanceOf(AdminUploadLegacyReferenceError);
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminUploadLegacyReferenceError);
    expect(f.state.statuses).toBe(0); expect(f.state.uploads).toBe(0);
    expect(await releaseUnadmittedAdminImageUpload(f.client, access, "shop_product", { scopeKey })).toEqual({ operationId: userId, actorId: userId, clubId: 24, released: true });
    expect(storage.getItem(`${key}:pending`)).toBeNull(); expect(storage.getItem(`${key}:${userId}`)).toBe(JSON.stringify(entry));
    expect(JSON.parse(storage.getItem(`${key}:${userId}:acknowledged`)!)).toEqual({ ...entry, released: true });
  });
  test("status recovery sends no bytes and preserves unadmitted original reference", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const original = (await readPendingAdminUpload(access, "shop_product", scopeKey))!; f.state.denyStatus = true;
    expect(await checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).toBeNull();
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))?.operationId).toBe(original.operationId); f.state.denyStatus = false;
    expect(await checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).toMatchObject({ status: "completed", operationId: original.operationId });
    expect(f.state.uploads).toBe(1);
  });
  test.each(["pending", "uploading", "unknown", "staged", "failed"])("%s never attaches an image or loses its original reference", async status => {
    const f = await fixture(); f.state.status = status;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toMatchObject({ status, code: "ADMIN_UPLOAD_UNCONFIRMED" });
    const entry = (await readPendingAdminUpload(access, "shop_product", scopeKey))!;
    expect(await checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).toMatchObject({ operationId: entry.operationId, status });
    await expect(uploadAdminImage(f.client, access, { file: image(1), kind: "shop_product", scopeKey })).rejects.toThrow("different image"); expect(f.state.uploads).toBe(1);
  });
  test.each([
    { actor_id: otherUser }, { club_id: 25 }, { kind: "match" }, { mime_type: "image/jpeg" }, { byte_length: 900 },
    { content_sha256: "f".repeat(64) }, { bucket: "other" }, { storage_path: "club-25/admin/shop_product/wrong.png" },
    { image_url: "https://attacker.test/wrong.png" }, { operation_id: otherUser }, { status: "staged", image_url: "https://media.test/image.png" },
  ])("rejects a response with changed original binding %j", async override => {
    const f = await fixture(); f.state.override = override;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).not.toBeNull();
    await expect(checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
  });
  test("actual provider account switch denies writes and another account cannot read the retained reference", async () => {
    const f = await fixture(); f.state.ownerId = otherUser;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toThrow("no longer owns");
    expect(f.state.uploads).toBe(0); expect(storage.values.size).toBe(0); f.state.ownerId = userId; f.state.loseResponse = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    expect((await readPendingAdminUpload({ ...access, userId: otherUser }, "shop_product", scopeKey))).toBeNull(); f.state.ownerId = otherUser;
    await expect(checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).rejects.toThrow("no longer owns"); expect(f.state.statuses).toBe(0);
  });
  test("stale ownership after file reading stops before retention or mutation", async () => {
    const f = await fixture(); let current = true; const file = image(); const arrayBuffer = file.arrayBuffer.bind(file);
    vi.spyOn(file, "arrayBuffer").mockImplementation(async () => { const bytes = await arrayBuffer(); current = false; return bytes; });
    await expect(uploadAdminImage(f.client, access, { file, kind: "shop_product", scopeKey, isCurrent: () => current })).rejects.toThrow("Current staff permission");
    expect(storage.values.size).toBe(0); expect(f.state.uploads).toBe(0);
  });
  test("old owner completion remains pending and cannot attach after actual asynchronous account change", async () => {
    const f = await fixture(); f.state.beforeUpload = async () => { f.state.ownerId = otherUser; };
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toThrow("no longer owns");
    expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).not.toBeNull();
  });
  test("pins the provider-verified token when the SDK session switches before actual function token retrieval", async () => {
    const f = await fixture();
    f.state.beforeVerifiedReturn = async count => {
      if (count !== 3) return;
      f.state.beforeVerifiedReturn = null; f.state.ownerId = otherUser;
      const switchedToken = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url") + "." +
        Buffer.from(JSON.stringify({ sub: otherUser, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 3600 })).toString("base64url") + ".other";
      await f.client.auth.setSession({ access_token: switchedToken, refresh_token: "other-refresh" });
    };
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toThrow("no longer owns");
    // The HTTP fixture asserts the original verified Authorization token. The
    // new SDK session cannot attribute this original operation to another user.
    expect(f.state.uploads).toBe(1); expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).not.toBeNull();
    expect([...storage.values.values()].join(" ")).not.toContain("other-refresh");
  });
  test("two windows serialize one unknown original operation and never create a second key", async () => {
    const f = await fixture(); f.state.status = "uploading";
    const results = await Promise.allSettled([uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey }),
      uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })]);
    expect(results.every(r => r.status === "rejected")).toBe(true); expect(f.state.objects).toBe(1);
    expect(f.rows.size).toBe(1); expect((await readPendingAdminUpload(access, "shop_product", scopeKey))?.operationId).toBe([...f.rows.keys()][0]);
  });
  test("a queued old-owner callback cannot mint an operation after another window releases the lock", async () => {
    const f = await fixture(); let release = () => {}; let arrived = () => {};
    const blocked = new Promise<void>(resolve => { release = resolve; });
    const entered = new Promise<void>(resolve => { arrived = resolve; });
    f.state.beforeUpload = async () => { arrived(); await blocked; };
    const first = uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey }); await entered;
    let current = true; const file = image(1); const arrayBuffer = file.arrayBuffer.bind(file); let read = () => {};
    const readFinished = new Promise<void>(resolve => { read = resolve; });
    vi.spyOn(file, "arrayBuffer").mockImplementation(async () => { const bytes = await arrayBuffer(); read(); return bytes; });
    const second = uploadAdminImage(f.client, access, { file, kind: "shop_product", scopeKey, isCurrent: () => current });
    const denied = expect(second).rejects.toThrow("Current staff permission"); await readFinished;
    current = false; release(); await first; await denied;
    expect(f.state.uploads).toBe(1); expect(f.rows.size).toBe(1); expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).toBeNull();
  });
  test.each(["quota", "readback", "unsupported"])("%s persistence fails closed before Edge writes", async mode => {
    const f = await fixture(); storage.fail = mode === "quota"; storage.loseReadback = mode === "readback"; if (mode === "unsupported") vi.stubGlobal("navigator", {});
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toThrow(); expect(f.state.uploads).toBe(0);
  });
  test("full acknowledgement storage retains the reference until status recovery can durably acknowledge", async () => {
    const f = await fixture(); storage.failAcknowledgement = true;
    await expect(uploadAdminImage(f.client, access, { file: image(), kind: "shop_product", scopeKey })).rejects.toBeInstanceOf(AdminImageUploadPendingError);
    const entry = (await readPendingAdminUpload(access, "shop_product", scopeKey))!; storage.failAcknowledgement = false;
    expect(await checkAdminImageUploadStatus(f.client, access, "shop_product", { scopeKey })).toMatchObject({ status: "completed", operationId: entry.operationId });
    expect(f.state.uploads).toBe(1); expect((await readPendingAdminUpload(access, "shop_product", scopeKey))).toBeNull();
  });
});
