// @vitest-environment node
import { createClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { executePaymentRefundCommand, getPaymentRefundDashboard, normalizePaymentRefund, normalizePaymentRefundDashboard,
  parsePaymentRefundCommand, recoverPaymentRefundOperation } from "./payment-refunds";
import { refundAccess, refundIds, refundPayment, refundReceipt } from "./payment-refunds.test-fixtures";

function caller(handle: (name: string, args: Record<string, unknown>) => unknown) {
  const fetch = vi.fn(async (input: RequestInfo | URL, options?: RequestInit) => {
    expect(new Headers(options?.headers).get("authorization")).toBe("Bearer actual-caller-jwt");
    const value = handle(String(input).split("/").at(-1)!, JSON.parse(String(options?.body)));
    return new Response(JSON.stringify(value), { status: 200, headers: { "content-type": "application/json" } });
  });
  return { fetch, value: createClient("http://127.0.0.1:54321", "test-anon", { global: { fetch, headers: { Authorization: "Bearer actual-caller-jwt" } }, auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } }) };
}
describe("actual caller-bound refund consumer", () => {
  it("retains exact original settlement and separate default-closed current approval", () => {
    const value = normalizePaymentRefund(refundReceipt({ current_approval: null }), 24);
    expect(value.currentApproval).toBeNull(); expect(value.approval).toBeNull();
    expect(value.payment.providerTransactionId).toBe("ORIGINAL-PAYMENT-201");
    expect(value.instruction).toBeNull(); expect(value.confirmedAmount).toBe(0);
  });
  it.each([{ confirmed_amount: 1 }, { amount: 2501 }, { club_id: 25 }, { checker_id: refundIds.maker },
    { payment_event_id: refundIds.order }, { status: "refunded", confirmed_amount: 1000, payment_confirmed_amount: 1000 },
    { status: "partially_refunded", confirmed_amount: 0 }, { payment_confirmed_amount: 2501 }])("rejects unconfirmed or inconsistent money receipt %j", patch => {
    expect(() => normalizePaymentRefund(refundReceipt(patch), 24)).toThrow();
  });
  it("rejects a changed receiver/amount/source inside the issued instruction", () => {
    for (const patch of [{ amount: 1 }, { currency: "USD" }, { original_payment: { ...refundPayment, receiver: "67890" } }, { original_payment: { ...refundPayment, provider_transaction_id: "FOREIGN" } }]) {
      const receipt = refundReceipt({ status: "pending" }); receipt.instruction = { ...receipt.instruction, ...patch };
      expect(() => normalizePaymentRefund(receipt, 24)).toThrow("instruction");
    }
  });
  it("keeps partial provider returns explicit without full consequence", () => {
    const value = normalizePaymentRefund(refundReceipt({ status: "partially_refunded", confirmed_amount: 1000, payment_confirmed_amount: 1000 }), 24);
    expect(value.confirmedAmount).toBe(1000); expect(value.consequence).toBeNull();
  });
  it("rejects foreign/duplicate original rows in authoritative status", () => {
    const value = { club_id: 24, payments: [refundPayment], requests: [refundReceipt()] };
    expect(normalizePaymentRefundDashboard(value, 24).requests).toHaveLength(1);
    expect(() => normalizePaymentRefundDashboard({ ...value, payments: [refundPayment, refundPayment] }, 24)).toThrow();
    expect(() => normalizePaymentRefundDashboard({ ...value, club_id: 25 }, 24)).toThrow();
  });
  it("sends exact preparation named arguments with current caller JWT and server-resolved club", async () => {
    const c = caller((name, args) => { expect(name).toBe("admin_prepare_payment_refund");
      expect(args).toEqual({ p_club_id: 24, p_payment_event_id: refundIds.payment, p_amount: 2500, p_reason: "cancelled_order", p_operation_id: refundIds.operation }); return refundReceipt(); });
    const command = { action: "prepare" as const, paymentEventId: refundIds.payment, amount: 2500, reason: "cancelled_order" as const, operationId: refundIds.operation };
    expect((await executePaymentRefundCommand(c.value, refundAccess, command)).instructionId).toBe(refundIds.instruction);
    await executePaymentRefundCommand(c.value, refundAccess, command);
    expect(c.fetch).toHaveBeenCalledTimes(2);
  });
  it("uses revision and original review/issue keys; never accepts a caller-selected actor", async () => {
    const c = caller((name, args) => { if (name === "admin_review_payment_refund") {
      expect(args).toEqual({ p_refund_id: refundIds.refund, p_expected_club_id: 24, p_expected_revision: 1, p_approve: true, p_operation_id: refundIds.operation }); return refundReceipt({ status: "approved", revision: 2 }); }
      expect(args).toEqual({ p_refund_id: refundIds.refund, p_expected_club_id: 24, p_operation_id: refundIds.operation }); return refundReceipt({ status: "pending", revision: 3 }); });
    await executePaymentRefundCommand(c.value, refundAccess, { action: "review", refundId: refundIds.refund, revision: 1, approve: true, operationId: refundIds.operation });
    expect((await executePaymentRefundCommand(c.value, refundAccess, { action: "dispatch", refundId: refundIds.refund, operationId: refundIds.operation })).status).toBe("pending");
    expect(() => parsePaymentRefundCommand({ action: "dispatch", refundId: refundIds.refund, operationId: refundIds.operation, actorId: refundIds.checker })).toThrow();
  });
  it("recovers committed original operation and rejects a wrong operation response", async () => {
    const c = caller((name, args) => { expect(name).toBe("admin_recover_payment_refund_operation"); expect(args).toEqual({ p_club_id: 24, p_operation_id: refundIds.operation }); return refundReceipt(); });
    expect((await recoverPaymentRefundOperation(c.value, refundAccess, refundIds.operation))?.id).toBe(refundIds.refund);
    const changed = caller(() => refundReceipt({ operation_id: refundIds.order }));
    await expect(recoverPaymentRefundOperation(changed.value, refundAccess, refundIds.operation)).rejects.toThrow("original reference");
  });
  it("denies normal club admins before any RPC and reads actual global status", async () => {
    const c = caller(() => ({ club_id: 24, payments: [], requests: [] }));
    await expect(getPaymentRefundDashboard(c.value, { ...refundAccess, role: "club_admin", isSuperAdmin: false })).rejects.toThrow("Platform admin");
    expect(c.fetch).not.toHaveBeenCalled(); expect((await getPaymentRefundDashboard(c.value, refundAccess)).payments).toEqual([]);
  });
});
