// @vitest-environment node
import { createHash } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import type { AdminAccess } from "@/lib/types";
import { AdminNotificationPendingError, checkAdminNotificationStatus, readPendingAdminNotification, sendAdminNotification } from "./notification-command";

const userId = "99969000-0000-4000-8000-000000000001";
const access: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: true, userId,
  role: "super_admin", clubId: "24", availableClubIds: ["24", "25"], assignmentCount: 1, canSelectClub: true };
const payload = { title: "Private original title", body: "Private original message", audience: "all_fans" as const, deliveryMode: "send_now" as const };
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
  vi.stubGlobal("navigator", { locks: { request: (key: string, action: () => unknown) => {
    const result = (queues.get(key) ?? Promise.resolve()).then(action); queues.set(key, result.catch(() => undefined)); return result;
  } } });
});
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });
async function fixture() {
  const state = { ownerId: userId, loseResponse: false, rejectAdmission: false, state: "completed", submits: 0, statuses: 0,
    verified: 0, beforeVerifiedReturn: null as ((count: number) => Promise<void>) | null,
    overrideCommand: {} as Record<string, unknown>, overrideDelivery: {} as Record<string, unknown> };
  const rows = new Map<string, Record<string, unknown>>();
  const token = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url") + "." +
    Buffer.from(JSON.stringify({ sub: userId, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 3600 })).toString("base64url") + ".test";
  const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    if (url.pathname === "/auth/v1/user") {
      const id = state.ownerId; ++state.verified;
      if (state.beforeVerifiedReturn) await state.beforeVerifiedReturn(state.verified);
      return json({ id, aud: "authenticated", role: "authenticated", app_metadata: {}, user_metadata: {}, created_at: "2026-10-02T00:00:00Z" });
    }
    expect(url.pathname).toBe("/functions/v1/admin-send-notification");
    expect(new Headers(init?.headers).get("authorization")).toBe(`Bearer ${token}`);
    const body = JSON.parse(String(init?.body));
    const original = [...storage.values.values()].map(raw => JSON.parse(raw)).find(entry => entry.operationId === body.operation_id)!;
    expect(original.userId).toBe(userId); expect(body.club_id).toBe(24);
    if (body.action === "status") {
      ++state.statuses; expect(Object.keys(body).sort()).toEqual(["action", "club_id", "operation_id"]);
      if (!rows.has(body.operation_id)) return json({ success: true, data: { command: { version: 1, operation_id: body.operation_id,
        club_id: 24, actor_id: null, arguments_sha256: null, notification_id: null, delivery_mode: null, state: "not_admitted" }, notification: null, delivery: null } });
    } else {
      ++state.submits;
      if (state.rejectAdmission) return json({ error: "Rejected before admission" }, 400);
      const { action: _action, operation_id: _operation, club_id: _club, ...args } = body;
      const canonical = JSON.stringify(Object.fromEntries(Object.keys(args).sort().map(key => [key, args[key]])));
      expect(original.argumentsSha256).toBe(createHash("sha256").update(canonical).digest("hex"));
      const id = "99969000-0000-4000-8000-000000000010";
      rows.set(body.operation_id, { command: { version: 1, operation_id: body.operation_id, actor_id: userId, club_id: 24,
        arguments_sha256: original.argumentsSha256, notification_id: id, delivery_mode: body.delivery_mode, state: state.state },
        notification: { id, title: body.title, body: body.body }, delivery: { status: state.state === "completed" ? "sent" : "unknown",
          requested_recipient_count: 1, successful_user_count: state.state === "completed" ? 1 : 0, failed_user_count: 0,
          sent_count: state.state === "completed" ? 1 : 0, failed_count: 0, cleaned_tokens: 0,
          unknown_count: state.state === "completed" ? 0 : 1, pending_count: 0, scheduled_at: null }, dispatch_proof_id: "private-provider-proof" });
      if (state.loseResponse) throw new Error("Lost committed response");
    }
    const row = rows.get(body.operation_id)!;
    return json({ success: true, data: { ...row, command: { ...(row.command as object), ...state.overrideCommand },
      delivery: { ...(row.delivery as object), ...state.overrideDelivery } } });
  });
  const client = createClient("https://notifications.test", "test-key", { global: { fetch: fetcher }, auth: { persistSession: false, autoRefreshToken: false } });
  await client.auth.setSession({ access_token: token, refresh_token: "private-refresh" });
  return { client, state, rows, fetcher };
}
describe("actual original notification SDK consumer", () => {
  test("retains metadata before Edge, pins the verified bearer and strips private provider proof", async () => {
    const f = await fixture(); const result = await sendAdminNotification(f.client, payload, access);
    expect(result.command.state).toBe("completed"); expect(result).not.toHaveProperty("dispatch_proof_id");
    expect(readPendingAdminNotification(access)).toBeNull();
    const persisted = [...storage.values.values()].join(" ");
    expect(persisted).not.toContain(payload.title); expect(persisted).not.toContain(payload.body);
    expect(persisted).not.toContain("private-provider-proof"); expect(persisted).not.toContain("private-refresh");
  });
  test("lost completed reply is recovered after reload without another submit", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toBeInstanceOf(AdminNotificationPendingError);
    const original = readPendingAdminNotification(access)!;
    expect(original).not.toBeNull(); f.state.loseResponse = false;
    const recovered = await checkAdminNotificationStatus(f.client, access);
    expect(recovered?.command.operation_id).toBe(original.operationId); expect(f.state.submits).toBe(1); expect(f.state.statuses).toBe(1);
    expect(readPendingAdminNotification(access)).toBeNull();
  });
  test("overlapping calls share one original command and one submit", async () => {
    const f = await fixture();
    const receipts = await Promise.all([sendAdminNotification(f.client, payload, access), sendAdminNotification(f.client, payload, access)]);
    expect(receipts[0].command.operation_id).toBe(receipts[1].command.operation_id);
    expect(f.state.submits).toBe(1);
  });
  test("unknown is retained and a repeated send only reads status", async () => {
    const f = await fixture(); f.state.state = "unknown";
    const first = await sendAdminNotification(f.client, payload, access);
    const second = await sendAdminNotification(f.client, payload, access);
    expect(second.command.operation_id).toBe(first.command.operation_id); expect(second.command.state).toBe("unknown");
    expect(f.state.submits).toBe(1); expect(f.state.statuses).toBe(1); expect(readPendingAdminNotification(access)?.operationId).toBe(first.command.operation_id);
  });
  test("not-admitted status is read-only and explicit identical retry keeps the original key", async () => {
    const f = await fixture(); f.state.rejectAdmission = true;
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toBeInstanceOf(AdminNotificationPendingError);
    const first = readPendingAdminNotification(access)!;
    expect((await checkAdminNotificationStatus(f.client, access))?.command.state).toBe("not_admitted");
    expect(f.state.submits).toBe(1); expect(readPendingAdminNotification(access)).toEqual(first);
    f.state.rejectAdmission = false;
    expect((await sendAdminNotification(f.client, payload, access)).command.operation_id).toBe(first.operationId);
    expect(f.state.submits).toBe(2);
  });
  test("changed contents refuse all provider calls and preserve the original reference", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toThrow();
    const first = readPendingAdminNotification(access); f.state.loseResponse = false;
    await expect(sendAdminNotification(f.client, { ...payload, body: "Different contents" }, access)).rejects.toThrow("original command");
    expect(f.state.submits).toBe(1); expect(f.state.statuses).toBe(0); expect(readPendingAdminNotification(access)).toEqual(first);
  });
  test.each(["actor_id", "club_id", "arguments_sha256", "operation_id", "notification_id"])("foreign %s acknowledgement never clears the original", async field => {
    const f = await fixture(); f.state.overrideCommand = { [field]: field === "club_id" ? 25 : "foreign" };
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toBeInstanceOf(AdminNotificationPendingError);
    expect(readPendingAdminNotification(access)).not.toBeNull();
  });
  test("false completed with an unknown device never acknowledges success", async () => {
    const f = await fixture(); f.state.overrideDelivery = { unknown_count: 1 };
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toThrow("acknowledgement");
    expect(readPendingAdminNotification(access)).not.toBeNull();
  });
  test.each(["quota", "readback", "locks"])("%s failure prevents Edge invocation", async failure => {
    const f = await fixture();
    if (failure === "quota") storage.fail = true;
    if (failure === "readback") storage.loseReadback = true;
    if (failure === "locks") vi.stubGlobal("navigator", {});
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toThrow(); expect(f.state.submits).toBe(0);
  });
  test("acknowledgement quota failure keeps original metadata for status recovery", async () => {
    const f = await fixture(); storage.failAcknowledgement = true;
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toThrow("retained");
    const original = readPendingAdminNotification(access)!; storage.failAcknowledgement = false;
    expect((await checkAdminNotificationStatus(f.client, access))?.command.operation_id).toBe(original.operationId);
    expect(f.state.submits).toBe(1);
  });
  test("account transition during verified lookup prevents the first submit", async () => {
    const f = await fixture(); let current = true;
    f.state.beforeVerifiedReturn = async () => { current = false; };
    await expect(sendAdminNotification(f.client, payload, access, { isCurrent: () => current })).rejects.toThrow();
    expect(f.state.submits).toBe(0); expect(readPendingAdminNotification(access)).toBeNull();
  });
  test("changed account and club cannot read another account's pending command", async () => {
    const f = await fixture(); f.state.loseResponse = true;
    await expect(sendAdminNotification(f.client, payload, access)).rejects.toThrow();
    expect(readPendingAdminNotification({ userId: "99969000-0000-4000-8000-000000000002", clubId: "24" })).toBeNull();
    expect(readPendingAdminNotification({ userId, clubId: "25" })).toBeNull();
  });
});
