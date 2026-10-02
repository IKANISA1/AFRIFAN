// @vitest-environment node
import { createHash } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { AdminImageGenerationPendingError, checkAdminImageGenerationStatus, generateAdminImage, readPendingAdminGeneration } from "./media";
const userId = "99969000-0000-4000-8000-000000000001";
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: false, userId,
  role: "club_admin", clubId: "24", availableClubIds: ["24"], assignmentCount: 1, canSelectClub: false };
const options = { kind: "shop_product" as const, prompt: "Private original image prompt", subject: "Private product", aspectRatio: "1:1", scopeKey: "draft:private-scope" };
let values: Map<string, string>, fail: boolean;
beforeEach(() => {
  values = new Map(); fail = false;
  vi.stubGlobal("localStorage", { getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { if (fail) throw new Error("QuotaExceededError"); values.set(key, value); }, removeItem: (key: string) => values.delete(key) });
  const queues = new Map<string, Promise<unknown>>();
  vi.stubGlobal("navigator", { locks: { request: (key: string, callback: () => unknown) => {
    const result = (queues.get(key) ?? Promise.resolve()).then(callback); queues.set(key, result.catch(() => undefined)); return result;
  } } });
});
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });
async function fixture() {
  const state = { loseResponse: false, status: "completed", submits: 0, statuses: 0, providerCalls: 0,
    override: {} as Record<string, unknown>, beforeVerifiedReturn: null as (() => void) | null };
  const rows = new Map<string, Record<string, unknown>>();
  const token = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url") + "." +
    Buffer.from(JSON.stringify({ sub: userId, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 3600 })).toString("base64url") + ".test";
  const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { "content-type": "application/json" } });
    const url = new URL(String(input));
    if (url.pathname === "/auth/v1/user") {
      state.beforeVerifiedReturn?.();
      return json({ id: userId, aud: "authenticated", role: "authenticated", app_metadata: {}, user_metadata: {}, created_at: "2026-10-02T00:00:00Z" });
    }
    expect(url.pathname).toBe("/functions/v1/generate-admin-image");
    expect(new Headers(init?.headers).get("authorization")).toBe(`Bearer ${token}`);
    const body = JSON.parse(String(init?.body));
    const original = [...values.values()].map(raw => JSON.parse(raw)).find(entry => entry.operationId === body.operation_id)!;
    expect(original).toBeDefined(); expect(body.clubId).toBe(24);
    if (body.mode === "status") {
      ++state.statuses; expect(Object.keys(body).sort()).toEqual(["clubId", "mode", "operation_id"]);
      if (!rows.has(body.operation_id)) return json({ error: "Not found" }, 404);
    } else {
      ++state.submits;
      const { operation_id: _id, clubId: _club, ...request } = body;
      const canonical = JSON.stringify(Object.fromEntries(Object.keys(request).sort().map(key => [key, request[key]])));
      expect(original.argumentsSha256).toBe(createHash("sha256").update(canonical).digest("hex"));
      if (!rows.has(body.operation_id)) ++state.providerCalls;
      const storagePath = "club-24/admin/shop_product/99969000-0000-4000-8000-000000000010.png";
      rows.set(body.operation_id, { operation_id: body.operation_id, actor_id: userId, club_id: 24, domain: "admin_image", kind: "shop_product",
        status: state.status, request, target_conflict: false,
        ...(state.status === "completed" ? { image_url: `https://generation.test/storage/v1/object/public/africlub-product-images/${storagePath}`,
          storage_path: storagePath, prompt_used: "Actual server-derived provider prompt", model: "server-model", aspect_ratio: "1:1", club: "Gikundiro", success: true } : {}) });
      if (state.loseResponse) throw new Error("Lost generation response");
    }
    return json({ ...rows.get(body.operation_id), ...state.override });
  });
  const client = createClient("https://generation.test", "test-key", { global: { fetch: fetcher }, auth: { persistSession: false, autoRefreshToken: false } });
  await client.auth.setSession({ access_token: token, refresh_token: "private-refresh" });
  return { state, rows, client };
}
describe("actual original generation SDK consumer", () => {
  test("retains only scope/request hashes before Edge and accepts exact configured Storage receipt", async () => {
    const f = await fixture(); const image = await generateAdminImage(f.client, access, options);
    expect(image.model).toBe("server-model"); expect(image.promptUsed).toBe("Actual server-derived provider prompt");
    expect(f.state.providerCalls).toBe(1); expect(await readPendingAdminGeneration(access, options.kind, options.scopeKey)).toBeNull();
    const persisted = [...values.entries()].flat().join(" ");
    for (const privateText of [options.prompt, options.subject, options.scopeKey, "private-refresh"]) expect(persisted).not.toContain(privateText);
  });
  test("lost completed reply recovers after reload without a new provider request", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(generateAdminImage(f.client, access, options)).rejects.toBeInstanceOf(AdminImageGenerationPendingError);
    const original = await readPendingAdminGeneration(access, options.kind, options.scopeKey); f.state.loseResponse = false;
    const receipt = await checkAdminImageGenerationStatus(f.client, access, options.kind, options);
    expect(receipt?.operationId).toBe(original?.operationId); expect(receipt?.image?.publicUrl).toContain("/africlub-product-images/");
    expect(f.state.submits).toBe(1); expect(f.state.providerCalls).toBe(1);
  });
  test("unknown generation only reads status on retry and retains its original", async () => {
    const f = await fixture(); f.state.status = "unknown";
    await expect(generateAdminImage(f.client, access, options)).rejects.toThrow();
    const first = await readPendingAdminGeneration(access, options.kind, options.scopeKey);
    await expect(generateAdminImage(f.client, access, options)).rejects.toThrow();
    expect(f.state.submits).toBe(1); expect(f.state.statuses).toBe(1); expect(f.state.providerCalls).toBe(1);
    expect(await readPendingAdminGeneration(access, options.kind, options.scopeKey)).toEqual(first);
  });
  test("missing admission remains read-only and retains the original reference", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(generateAdminImage(f.client, access, options)).rejects.toThrow();
    const original = await readPendingAdminGeneration(access, options.kind, options.scopeKey);
    f.rows.clear(); f.state.loseResponse = false;
    expect(await checkAdminImageGenerationStatus(f.client, access, options.kind, options)).toBeNull();
    expect(await readPendingAdminGeneration(access, options.kind, options.scopeKey)).toEqual(original); expect(f.state.submits).toBe(1);
  });
  test("changed original prompt refuses replacement and all provider calls", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(generateAdminImage(f.client, access, options)).rejects.toThrow();
    await expect(generateAdminImage(f.client, access, { ...options, prompt: "Different prompt" })).rejects.toThrow("original command");
    expect(f.state.submits).toBe(1); expect(f.state.statuses).toBe(0);
  });
  test.each(["actor_id", "club_id", "domain", "kind", "request", "image_url", "storage_path"])("foreign %s cannot clear or attach generation", async field => {
    const f = await fixture(); f.state.override = { [field]: field === "club_id" ? 25 : "foreign" };
    await expect(generateAdminImage(f.client, access, options)).rejects.toBeInstanceOf(AdminImageGenerationPendingError);
    expect(await readPendingAdminGeneration(access, options.kind, options.scopeKey)).not.toBeNull();
  });
  test("quota or owner transition before journal admission cannot invoke Edge", async () => {
    const f = await fixture(); fail = true;
    await expect(generateAdminImage(f.client, access, options)).rejects.toThrow(); expect(f.state.submits).toBe(0);
    fail = false; let current = true; f.state.beforeVerifiedReturn = () => { current = false; };
    await expect(generateAdminImage(f.client, access, { ...options, isCurrent: () => current })).rejects.toThrow(); expect(f.state.submits).toBe(0);
  });
});
