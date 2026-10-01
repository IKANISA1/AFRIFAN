import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { AdminMutationConflictError } from "./helpers";
import { requestAdminApi } from "./http";

export const refundReasons = ["duplicate_payment", "cancelled_order", "unavailable_item", "cancelled_event", "membership_adjustment", "other_reviewed"] as const;
export type RefundReason = typeof refundReasons[number];
export type RefundStatus = "awaiting_review" | "approved" | "rejected" | "pending" | "unknown" | "failed" | "partially_refunded" | "refunded";
export interface RefundPayment {
  eventId: string; gatewayId: string; ledgerId: string; clubId: number;
  targetKind: "membership" | "shop" | "ticket"; targetIds: string[];
  receiver: string; provider: string; country: string; currency: string; amount: number;
  providerTransactionId: string; settlementRecordId: string; settlementRecordDigest: string;
  capabilityEnabled: boolean; reservedAmount: number;
}
export interface RefundApproval {
  policyVersion: string; sourceReviewReference: string; providerAcceptanceReference: string; termsReference: string;
  shopStockPolicy: "retain" | "restore_unfulfilled"; ticketPolicy: "retain" | "revoke_unused";
  membershipPolicy: "retain" | "suspend_current";
}
export interface PaymentRefund {
  id: string; instructionId: string; paymentEventId: string; clubId: number;
  makerId: string; checkerId: string | null; payment: RefundPayment;
  amount: number; reason: RefundReason; status: RefundStatus; revision: number;
  confirmedAmount: number; paymentConfirmedAmount: number; approval: RefundApproval | null;
  currentApproval: RefundApproval | null; instruction: Record<string, unknown> | null; consequence: Record<string, string> | null;
  createdAt: string; updatedAt: string; operationId: string | null;
}
export interface PaymentRefundDashboard { clubId: number; payments: RefundPayment[]; requests: PaymentRefund[] }
export type PaymentRefundCommand =
  | { action: "prepare"; paymentEventId: string; amount: number; reason: RefundReason; operationId: string }
  | { action: "review"; refundId: string; revision: number; approve: boolean; operationId: string }
  | { action: "dispatch"; refundId: string; operationId: string };
export type RefundDraftCommand = PaymentRefundCommand extends infer C ? C extends PaymentRefundCommand ? Omit<C, "operationId"> : never : never;
export class PaymentRefundValidationError extends Error {
  constructor(message: string, readonly code = "REFUND_INVALID_REQUEST") { super(message); }
}
export class PaymentRefundAuthorizationError extends Error {
  constructor(message: string, readonly code = "ADMIN_ACCESS_DENIED") { super(message); }
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const statuses: RefundStatus[] = ["awaiting_review", "approved", "rejected", "pending", "unknown", "failed", "partially_refunded", "refunded"];
const integer = (v: unknown, min = 0): v is number => typeof v === "number" && Number.isSafeInteger(v) && v >= min && v <= 2_147_483_647;
const text = (v: unknown, max = 200): v is string => typeof v === "string" && v.trim().length > 0 && v.length <= max;
const isUuid = (v: unknown): v is string => typeof v === "string" && uuid.test(v);
function row(v: unknown): Record<string, unknown> {
  if (v == null || typeof v !== "object" || Array.isArray(v)) throw new Error("Refund data could not be confirmed.");
  return v as Record<string, unknown>;
}
function timestamp(v: unknown): string {
  if (!text(v, 64) || !Number.isFinite(Date.parse(v))) throw new Error("Refund date could not be confirmed.");
  return v;
}
export function normalizeRefundPayment(value: unknown, clubId: number): RefundPayment {
  const p = row(value);
  if (![p.event_id, p.gateway_id, p.ledger_id, p.reconciliation_id, p.subject_id, p.receiver_account_id].every(isUuid)
    || p.club_id !== clubId || !integer(p.amount, 1)
    || !["membership", "shop", "ticket"].includes(String(p.target_kind))
    || !Array.isArray(p.target_ids) || p.target_ids.length < 1 || p.target_ids.length > 1000
    || !p.target_ids.every(isUuid) || new Set(p.target_ids).size !== p.target_ids.length
    || !text(p.receiver, 160) || !text(p.provider, 40) || !text(p.country, 2) || !/^[A-Z]{2}$/.test(p.country)
    || !text(p.currency, 3) || !/^[A-Z]{3}$/.test(p.currency)
    || !text(p.provider_transaction_id, 160) || !text(p.settlement_record_id, 160)
    || !text(p.settlement_record_digest, 64) || !/^[a-f0-9]{64}$/.test(p.settlement_record_digest)
    || (p.reserved_amount !== undefined && (!integer(p.reserved_amount) || p.reserved_amount > p.amount))
    || (p.capability_enabled !== undefined && typeof p.capability_enabled !== "boolean")) throw new Error("Original payment binding could not be confirmed.");
  return { eventId: p.event_id as string, gatewayId: p.gateway_id as string, ledgerId: p.ledger_id as string, clubId,
    targetKind: p.target_kind as RefundPayment["targetKind"], targetIds: p.target_ids as string[], receiver: p.receiver,
    provider: p.provider, country: p.country, currency: p.currency, amount: p.amount,
    providerTransactionId: p.provider_transaction_id, settlementRecordId: p.settlement_record_id,
    settlementRecordDigest: p.settlement_record_digest, capabilityEnabled: p.capability_enabled === true,
    reservedAmount: p.reserved_amount === undefined ? 0 : p.reserved_amount as number };
}
function normalizeApproval(value: unknown): RefundApproval | null {
  if (value === null) return null;
  const a = row(value);
  if (a.enabled !== true || !text(a.policy_version, 80) || !text(a.source_review_reference)
    || !text(a.provider_acceptance_reference) || !text(a.terms_reference)
    || !["retain", "restore_unfulfilled"].includes(String(a.shop_stock_policy))
    || !["retain", "revoke_unused"].includes(String(a.ticket_policy))
    || !["retain", "suspend_current"].includes(String(a.membership_policy))) throw new Error("Refund approval could not be confirmed.");
  return { policyVersion: a.policy_version, sourceReviewReference: a.source_review_reference,
    providerAcceptanceReference: a.provider_acceptance_reference, termsReference: a.terms_reference,
    shopStockPolicy: a.shop_stock_policy as RefundApproval["shopStockPolicy"], ticketPolicy: a.ticket_policy as RefundApproval["ticketPolicy"],
    membershipPolicy: a.membership_policy as RefundApproval["membershipPolicy"] };
}
export function normalizePaymentRefund(value: unknown, clubId: number): PaymentRefund {
  const r = row(value); const payment = normalizeRefundPayment(r.payment, clubId);
  if (![r.id, r.instruction_id, r.payment_event_id, r.maker_id].every(isUuid) || r.club_id !== clubId
    || !(r.checker_id === null || isUuid(r.checker_id)) || r.checker_id === r.maker_id
    || r.payment_event_id !== payment.eventId || !integer(r.amount, 1) || r.amount > payment.amount
    || !integer(r.confirmed_amount) || r.confirmed_amount > r.amount
    || !integer(r.payment_confirmed_amount) || r.payment_confirmed_amount < r.confirmed_amount || r.payment_confirmed_amount > payment.amount
    || !integer(r.revision, 1) || !refundReasons.includes(r.reason as RefundReason) || !statuses.includes(r.status as RefundStatus)
    || (r.operation_id != null && !isUuid(r.operation_id))) throw new Error("Refund receipt could not be confirmed.");
  const approval = normalizeApproval(r.approval);
  const issued = !["awaiting_review", "approved", "rejected"].includes(String(r.status));
  const instruction = r.instruction === null ? null : row(r.instruction);
  if ((issued && (!instruction || !approval || !r.checker_id)) || (!issued && instruction !== null)
    || (r.status === "refunded" && r.confirmed_amount !== r.amount)
    || (r.status === "partially_refunded" && (r.confirmed_amount === 0 || r.confirmed_amount >= r.amount))
    || (!["partially_refunded", "refunded"].includes(String(r.status)) && r.confirmed_amount !== 0)
    || (r.status === "approved" && (!approval || !r.checker_id))) throw new Error("Refund outcome could not be confirmed.");
  if (instruction) {
    const original = normalizeRefundPayment(instruction.original_payment, clubId);
    if (instruction.protocol !== "africlub.provider-refund-instruction.v1" || instruction.id !== r.instruction_id
      || instruction.refund_id !== r.id || instruction.amount !== r.amount || instruction.currency !== payment.currency
      || instruction.maker_id !== r.maker_id || instruction.checker_id !== r.checker_id
      || JSON.stringify(original) !== JSON.stringify(payment)
      || JSON.stringify(normalizeApproval(instruction.approval)) !== JSON.stringify(approval)) throw new Error("Issued refund instruction differs from its reviewed receipt.");
  }
  let consequence: Record<string, string> | null = null;
  if (r.consequence !== null) {
    const c = row(r.consequence);
    if (Object.keys(c).some(k => !["stock", "tickets", "membership"].includes(k)) || Object.values(c).some(v => !text(v, 80))) throw new Error("Refund consequences could not be confirmed.");
    consequence = c as Record<string, string>;
  }
  return { id: r.id as string, instructionId: r.instruction_id as string, paymentEventId: payment.eventId, clubId,
    makerId: r.maker_id as string, checkerId: r.checker_id as string | null, payment, amount: r.amount, reason: r.reason as RefundReason,
    status: r.status as RefundStatus, revision: r.revision, confirmedAmount: r.confirmed_amount,
    paymentConfirmedAmount: r.payment_confirmed_amount, approval, currentApproval: normalizeApproval(r.current_approval ?? null), instruction, consequence,
    createdAt: timestamp(r.created_at), updatedAt: timestamp(r.updated_at), operationId: r.operation_id as string | null ?? null };
}
export function normalizePaymentRefundDashboard(value: unknown, clubId: number): PaymentRefundDashboard {
  const d = row(value);
  if (d.club_id !== clubId || !Array.isArray(d.payments) || !Array.isArray(d.requests) || d.payments.length > 1000 || d.requests.length > 1000) throw new Error("Refund dashboard could not be confirmed.");
  const payments = d.payments.map(v => normalizeRefundPayment(v, clubId));
  const requests = d.requests.map(v => normalizePaymentRefund(v, clubId));
  if (new Set(payments.map(p => p.eventId)).size !== payments.length || new Set(requests.map(r => r.id)).size !== requests.length) throw new Error("Duplicate refund records could not be confirmed.");
  return { clubId, payments, requests };
}
export function parsePaymentRefundCommand(value: unknown): PaymentRefundCommand {
  let c: Record<string, unknown>;
  try { c = row(value); } catch { throw new PaymentRefundValidationError("Review the refund command fields."); }
  const keys = Object.keys(c).sort().join(",");
  if (!isUuid(c.operationId)) throw new PaymentRefundValidationError("The original operation reference is required.");
  if (c.action === "prepare" && keys === "action,amount,operationId,paymentEventId,reason" && isUuid(c.paymentEventId)
    && integer(c.amount, 1) && refundReasons.includes(c.reason as RefundReason)) return c as PaymentRefundCommand;
  if (c.action === "review" && keys === "action,approve,operationId,refundId,revision" && isUuid(c.refundId)
    && integer(c.revision, 1) && typeof c.approve === "boolean") return c as PaymentRefundCommand;
  if (c.action === "dispatch" && keys === "action,operationId,refundId" && isUuid(c.refundId)) return c as PaymentRefundCommand;
  throw new PaymentRefundValidationError("Review the refund command fields.");
}
function club(access: AdminAccess): number {
  const id = Number(access.clubId);
  if (!access.hasAccess || !access.isAuthenticated || !access.isSuperAdmin || !access.userId || !integer(id, 1)) throw new PaymentRefundAuthorizationError("Platform admin access is required.");
  return id;
}
async function rpc(client: SupabaseClient, name: string, args: Record<string, unknown>): Promise<unknown> {
  const { data, error } = await client.rpc(name, args);
  if (error) {
    if (error.code === "42501") throw new PaymentRefundAuthorizationError(error.message, error.message);
    if (error.message === "REFUND_REVIEW_CHANGED") throw new AdminMutationConflictError();
    if (error.message.startsWith("REFUND_")) throw new PaymentRefundValidationError(refundErrorCopy(error.message), error.message);
    throw new Error("Refund operation could not be confirmed.");
  }
  return data;
}
export function refundErrorCopy(code: string): string {
  const messages: Record<string, string> = {
    REFUND_CAPABILITY_CLOSED: "Refund execution is closed until provider capability and terms are accepted.",
    REFUND_APPROVAL_CHANGED: "Provider approval changed. Obtain a fresh review before issuing the same instruction.",
    REFUND_AMOUNT_RESERVED: "This amount is already reserved by another refund request. Check its status.",
    REFUND_DISTINCT_CHECKER_REQUIRED: "A different current platform administrator must review this request.",
    REFUND_REVIEW_CLOSED: "This request has already left review. Check its current status.",
    REFUND_OPERATION_BINDING_MISMATCH: "The original operation reference belongs to different command details.",
  };
  return messages[code] ?? "The refund was not confirmed. Review current payment and request details.";
}
export async function getPaymentRefundDashboard(client: SupabaseClient, access: AdminAccess) {
  const id = club(access);
  return normalizePaymentRefundDashboard(await rpc(client, "admin_payment_refund_dashboard", { p_club_id: id }), id);
}
export async function executePaymentRefundCommand(client: SupabaseClient, access: AdminAccess, command: PaymentRefundCommand) {
  const id = club(access); const c = parsePaymentRefundCommand(command);
  const args = c.action === "prepare" ? { p_club_id: id, p_payment_event_id: c.paymentEventId, p_amount: c.amount, p_reason: c.reason, p_operation_id: c.operationId }
    : c.action === "review" ? { p_refund_id: c.refundId, p_expected_club_id: id, p_expected_revision: c.revision, p_approve: c.approve, p_operation_id: c.operationId }
      : { p_refund_id: c.refundId, p_expected_club_id: id, p_operation_id: c.operationId };
  const result = normalizePaymentRefund(await rpc(client, `admin_${c.action === "prepare" ? "prepare" : c.action === "review" ? "review" : "dispatch"}_payment_refund`, args), id);
  if (result.operationId !== c.operationId || (c.action === "prepare" && (result.paymentEventId !== c.paymentEventId || result.amount !== c.amount || result.reason !== c.reason))
    || (c.action !== "prepare" && result.id !== c.refundId)) throw new Error("Refund response differs from the original command.");
  return result;
}
export async function recoverPaymentRefundOperation(client: SupabaseClient, access: AdminAccess, operationId: string) {
  const id = club(access);
  if (!isUuid(operationId)) throw new PaymentRefundValidationError("The original operation reference is required.");
  const data = await rpc(client, "admin_recover_payment_refund_operation", { p_club_id: id, p_operation_id: operationId });
  if (data === null) return null;
  const result = normalizePaymentRefund(data, id);
  if (result.operationId !== operationId) throw new Error("Recovered refund operation differs from its original reference.");
  return result;
}

export const fetchPaymentRefundDashboard = (clubId: string) => requestAdminApi<PaymentRefundDashboard>("refunds", { query: { club: clubId } });
function confirmedBrowserReceipt(value: PaymentRefund, clubId: string, operationId: string) {
  if (!value || value.clubId !== Number(clubId) || value.operationId !== operationId || !isUuid(value.id)
    || !isUuid(value.instructionId) || !isUuid(value.paymentEventId) || !integer(value.amount, 1)
    || !integer(value.confirmedAmount) || value.confirmedAmount > value.amount || !statuses.includes(value.status)) {
    throw new Error("Refund response could not be bound to the saved operation. Recover its original reference.");
  }
  return value;
}
export async function sendPaymentRefundCommand(clubId: string, command: PaymentRefundCommand) {
  const value = confirmedBrowserReceipt(await requestAdminApi<PaymentRefund>("refunds", { method: "POST", query: { club: clubId }, body: command }), clubId, command.operationId);
  if ((command.action === "prepare" && (value.paymentEventId !== command.paymentEventId || value.amount !== command.amount || value.reason !== command.reason))
    || (command.action !== "prepare" && value.id !== command.refundId)) throw new Error("Refund response differs from the saved command. Recover its original reference.");
  return value;
}
export async function fetchPaymentRefundOperation(clubId: string, operationId: string) {
  const value = await requestAdminApi<PaymentRefund | null>("refunds", { query: { club: clubId, operation_id: operationId } });
  return value === null ? null : confirmedBrowserReceipt(value, clubId, operationId);
}
