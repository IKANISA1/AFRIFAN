import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { readPendingRefundOperation, withRefundJournal } from "./refund-operation-journal";
import { refundIds } from "@/lib/data/admin/payment-refunds.test-fixtures";

const draft = { action: "prepare" as const, paymentEventId: refundIds.payment, amount: 1000, reason: "cancelled_order" as const };
beforeEach(() => {
  localStorage.clear();
  let queue = Promise.resolve<unknown>(undefined);
  Object.defineProperty(navigator, "locks", { configurable: true, value: { request: (_key: string, callback: () => unknown) => {
    const result = queue.then(callback); queue = result.catch(() => undefined); return result;
  } } });
});
afterEach(() => vi.restoreAllMocks());
describe("durable original operation journal", () => {
  it("serializes separate windows and refuses another fresh key after a lost response", async () => {
    let release: () => void = () => {};
    const arrived = new Promise<void>(resolve => { release = resolve; });
    const send = vi.fn(async () => { await arrived; throw new Error("Lost committed response"); });
    const first = withRefundJournal(refundIds.maker, "24", draft, send);
    const firstFailure = expect(first).rejects.toThrow("Lost committed response");
    const second = withRefundJournal(refundIds.maker, "24", draft, send);
    const secondFailure = expect(second).rejects.toThrow("Check the saved operation");
    release(); await firstFailure; await secondFailure; expect(send).toHaveBeenCalledTimes(1);
    const retained = readPendingRefundOperation(refundIds.maker, "24")!;
    expect(retained.command.operationId).toBeTruthy();
    const retry = vi.fn(async command => command.operationId);
    expect(await withRefundJournal(refundIds.maker, "24", retained.command, retry)).toBe(retained.command.operationId);
    expect(readPendingRefundOperation(refundIds.maker, "24")).toBeNull();
    expect(localStorage.length).toBe(2);
  });
  it("never evicts completed original keys when an explicit subsequent request is started", async () => {
    const send = vi.fn(async command => command.operationId);
    const first = await withRefundJournal(refundIds.maker, "24", draft, send);
    const second = await withRefundJournal(refundIds.maker, "24", draft, send);
    expect(first).not.toBe(second); expect(localStorage.length).toBe(4);
    expect([...Array(localStorage.length)].map((_, i) => localStorage.key(i)).filter(k => k?.endsWith(":confirmed"))).toHaveLength(2);
  });
  it("isolates user and club and fails closed for unsupported locking/corrupt stored reference", async () => {
    const send = vi.fn(async () => { throw new Error("Unknown"); });
    await expect(withRefundJournal(refundIds.maker, "24", draft, send)).rejects.toThrow("Unknown");
    expect(readPendingRefundOperation(refundIds.checker, "24")).toBeNull(); expect(readPendingRefundOperation(refundIds.maker, "25")).toBeNull();
    const pendingKey = [...Array(localStorage.length)].map((_, i) => localStorage.key(i)).find(k => k?.endsWith(":pending"))!;
    localStorage.setItem(pendingKey, "{broken"); expect(() => readPendingRefundOperation(refundIds.maker, "24")).toThrow("needs recovery");
    Object.defineProperty(navigator, "locks", { configurable: true, value: undefined });
    await expect(withRefundJournal(refundIds.checker, "24", draft, send)).rejects.toThrow("secure operation locking"); expect(send).toHaveBeenCalledTimes(1);
  });
});
