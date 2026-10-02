import { webcrypto } from "node:crypto";
import { StrictMode } from "react";
import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { useAdminMediaDraftScope } from "./use-admin-media-draft-scope";
import { acknowledgeAdminUploadRelease, readPendingAdminUpload, retainAdminUpload, withAdminUploadJournal } from "./data/admin/media-upload-journal";
import { acknowledgeStaffCommand, retainStaffCommand, staffCommandSha256, withStaffCommandJournal } from "./data/admin/staff-command-journal";
import type { AdminAccess } from "./types";

const access: AdminAccess = { userId: "99969000-0000-4000-8000-000000000001", clubId: "24", hasAccess: true,
  isAuthenticated: true, isSuperAdmin: false, role: "club_admin", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1 };
const binding = { mimeType: "image/png", byteLength: 8, contentSha256: "a".repeat(64) };
beforeEach(() => {
  vi.stubGlobal("crypto", webcrypto);
  localStorage.clear();
  const held = new Set<string>();
  const queues = new Map<string, Promise<unknown>>();
  Object.defineProperty(navigator, "locks", { configurable: true, value: { request: (key: string,
    options: { ifAvailable: boolean } | ((lock: object) => unknown), callback?: (lock: object | null) => unknown) => {
    if (typeof options !== "function") {
      if (held.has(key)) return Promise.resolve(callback!(null));
      held.add(key); return Promise.resolve(callback!({ name: key })).finally(() => held.delete(key));
    }
    const result = (queues.get(key) ?? Promise.resolve()).then(() => options({ name: key }));
    queues.set(key, result.catch(() => undefined)); return result;
  } } });
});
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
async function composer(owner = access) {
  const rendered = renderHook(({ owner }) => useAdminMediaDraftScope(owner, "shop_product"), { initialProps: { owner } });
  await waitFor(() => expect(rendered.result.current.ready || rendered.result.current.error).toBeTruthy());
  return rendered;
}
async function pending(scope: string) {
  return withAdminUploadJournal(access, "shop_product", scope, async (_, hash) => retainAdminUpload(access, "shop_product", hash, binding));
}
describe("actual retained media composer", () => {
  test("reload restores the original composer; explicit Clear then an identical blank draft has a different image scope", async () => {
    const first = await composer(); const original = first.result.current.scopeKey!;
    const upload = await pending(original); first.unmount();
    await act(async () => { await Promise.resolve(); });
    const reopened = await composer(); expect(reopened.result.current.scopeKey).toBe(original);
    await act(async () => { expect(await reopened.result.current.resetDraft()).toBe(false); });
    expect(reopened.result.current.scopeKey).toBe(original);
    expect((await readPendingAdminUpload(access, "shop_product", original))?.operationId).toBe(upload.operationId);
    await withAdminUploadJournal(access, "shop_product", original, async entry => acknowledgeAdminUploadRelease(entry!));
    await act(async () => { expect(await reopened.result.current.resetDraft()).toBe(true); });
    expect(reopened.result.current.scopeKey).not.toBe(original);
    const stored = [...Array(localStorage.length)].map((_, i) => localStorage.getItem(localStorage.key(i)!)).join(" ");
    expect(stored).not.toContain("private form"); expect(stored).not.toContain("image_data_base64");
    expect(localStorage.length).toBeGreaterThan(3); // Prior identity and command records remain.
  });
  test("Close/Edit/Save checks preserve unknown upload and known generation references", async () => {
    const view = await composer(); const original = view.result.current.scopeKey!;
    await pending(original);
    await act(async () => { expect(await view.result.current.canLeaveDraft()).toBe(false); });
    expect(view.result.current.error).toContain("Recover the original");
    await withAdminUploadJournal(access, "shop_product", original, async entry => acknowledgeAdminUploadRelease(entry!));
    const domain = `image-generation:shop_product:${await staffCommandSha256(original)}`;
    const command = await withStaffCommandJournal(access, domain, async () => retainStaffCommand(access, domain, "b".repeat(64)));
    await act(async () => { expect(await view.result.current.resetDraft()).toBe(false); });
    expect(view.result.current.scopeKey).toBe(original);
    await withStaffCommandJournal(access, domain, async () => acknowledgeStaffCommand(command, { state: "completed" }));
    await act(async () => { expect(await view.result.current.resetDraft()).toBe(true); });
  });
  test("a second mounted window cannot operate the shared draft or rotate its reference", async () => {
    const first = await composer(); const original = first.result.current.scopeKey;
    const second = await composer(); expect(second.result.current.ready).toBe(false); expect(second.result.current.scopeKey).toBeNull();
    await act(async () => { expect(await second.result.current.resetDraft()).toBe(false); });
    expect(first.result.current.scopeKey).toBe(original);
    first.unmount();
    await act(async () => { await Promise.resolve(); window.dispatchEvent(new Event("focus")); });
    await waitFor(() => expect(second.result.current.ready).toBe(true));
    expect(second.result.current.scopeKey).toBe(original);
  });
  test("StrictMode cleanup cannot strand a composer behind its own released lease", async () => {
    const view = renderHook(() => useAdminMediaDraftScope(access, "shop_product"), { wrapper: StrictMode });
    await waitFor(() => expect(view.result.current.ready).toBe(true));
    expect(view.result.current.scopeKey).toMatch(/^draft:/);
  });
  test("legacy new-scope upload is recovery-only; no UUID is attributed until confirmed acknowledgement", async () => {
    const original = await pending("new"); const view = await composer();
    expect(view.result.current.legacyUnbound).toBe(true); expect(view.result.current.scopeKey).toBe("new"); expect(view.result.current.ready).toBe(false);
    await act(async () => { expect(await view.result.current.resetDraft()).toBe(false); });
    expect((await readPendingAdminUpload(access, "shop_product", "new"))?.operationId).toBe(original.operationId);
    expect([...Array(localStorage.length)].map((_, i) => localStorage.key(i))).not.toContain(`africlub.admin-media-draft.v1:${access.userId}:24:shop_product`);
    await withAdminUploadJournal(access, "shop_product", "new", async entry => acknowledgeAdminUploadRelease(entry!));
    act(() => view.result.current.refreshRecovery());
    await waitFor(() => expect(view.result.current.ready).toBe(true));
    expect(view.result.current.scopeKey).toMatch(/^draft:/);
  });
  test("account/club switches never disclose the previous scope and returning restores its original command", async () => {
    const view = await composer(); const original = view.result.current.scopeKey!; await pending(original);
    view.rerender({ owner: { ...access, userId: "99969000-0000-4000-8000-000000000002" } });
    expect(view.result.current.scopeKey).toBeNull(); await waitFor(() => expect(view.result.current.ready).toBe(true));
    expect(view.result.current.scopeKey).not.toBe(original);
    view.rerender({ owner: { ...access, clubId: "25" } }); await waitFor(() => expect(view.result.current.ready).toBe(true));
    expect(view.result.current.scopeKey).not.toBe(original);
    view.rerender({ owner: access }); await waitFor(() => expect(view.result.current.scopeKey).toBe(original));
    expect((await readPendingAdminUpload(access, "shop_product", original))?.operationId).toBeTruthy();
  });
  test.each(["corrupt", "quota", "missingLocks"])("%s storage/window support fails closed without publishing a draft", async failure => {
    if (failure === "corrupt") localStorage.setItem(`africlub.admin-media-draft.v1:${access.userId}:24:shop_product`, "broken");
    if (failure === "quota") vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("quota"); });
    if (failure === "missingLocks") Object.defineProperty(navigator, "locks", { configurable: true, value: undefined });
    const view = await composer(); expect(view.result.current.ready).toBe(false); expect(view.result.current.scopeKey).toBeNull();
    await act(async () => { expect(await view.result.current.canLeaveDraft()).toBe(false); });
  });
  test("authoritative access loss denies reset while preserving same-owner recovery metadata", async () => {
    const view = await composer(); const original = view.result.current.scopeKey;
    view.rerender({ owner: { ...access, hasAccess: false } });
    expect(view.result.current.ready).toBe(false); await act(async () => { expect(await view.result.current.resetDraft()).toBe(false); });
    view.rerender({ owner: access }); expect(view.result.current.scopeKey).toBe(original);
  });
  test("actual Save owns the composer until its response; Clear and competing Save cannot rotate or write", async () => {
    const view = await composer(); const original = view.result.current.scopeKey;
    let resolve!: () => void;
    const response = new Promise<void>(done => { resolve = done; });
    const write = vi.fn(() => response);
    let save!: Promise<void>;
    await act(async () => { save = view.result.current.runSave(write); await Promise.resolve(); });
    await waitFor(() => expect(write).toHaveBeenCalledTimes(1));
    expect(view.result.current.ready).toBe(false);
    const competing = vi.fn();
    await act(async () => {
      expect(await view.result.current.resetDraft()).toBe(false);
      await expect(view.result.current.runSave(competing)).rejects.toThrow();
    });
    expect(competing).not.toHaveBeenCalled(); expect(view.result.current.scopeKey).toBe(original);
    await act(async () => { resolve(); await save; });
    await act(async () => { expect(await view.result.current.resetDraft()).toBe(true); });
    expect(view.result.current.scopeKey).not.toBe(original);
  });
});
