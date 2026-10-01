import type { AdminAccess } from "@/lib/types";
export const refundIds = {
  payment: "99967000-0000-4000-8000-000000000520", gateway: "99967000-0000-4000-8000-000000000500",
  ledger: "99967000-0000-4000-8000-000000000550", reconciliation: "99967000-0000-4000-8000-000000000551",
  subject: "99967000-0000-4000-8000-000000000003", maker: "99967000-0000-4000-8000-000000000001",
  checker: "99967000-0000-4000-8000-000000000002", receiver: "99967000-0000-4000-8000-000000000130",
  order: "99967000-0000-4000-8000-000000000201", refund: "99967000-0000-4000-8000-000000000600",
  instruction: "99967000-0000-4000-8000-000000000610", operation: "99967000-0000-4000-8000-000000000601",
};
export const refundAccess: AdminAccess = { hasAccess: true, isAuthenticated: true, isSuperAdmin: true, userId: refundIds.maker,
  role: "super_admin", clubId: "24", availableClubIds: ["24"], canSelectClub: true, assignmentCount: 1 };
export const refundPayment = { event_id: refundIds.payment, gateway_id: refundIds.gateway, ledger_id: refundIds.ledger,
  reconciliation_id: refundIds.reconciliation, subject_id: refundIds.subject, club_id: 24, target_kind: "shop", target_ids: [refundIds.order],
  receiver_account_id: refundIds.receiver, receiver: "12345", provider: "mtn_rwanda", country: "RW", currency: "RWF", amount: 2500,
  provider_transaction_id: "ORIGINAL-PAYMENT-201", settlement_record_id: "provider-statement-201", settlement_record_digest: "a".repeat(64), membership_id: null };
export const refundApproval = { gateway_id: refundIds.gateway, enabled: true, policy_version: "reviewed-v1",
  source_review_reference: "source-review-reference", provider_acceptance_reference: "provider-acceptance-reference", terms_reference: "terms-reference",
  shop_stock_policy: "restore_unfulfilled", ticket_policy: "revoke_unused", membership_policy: "suspend_current" };
export function refundReceipt(patch: Record<string, unknown> = {}) {
  const receipt = { id: refundIds.refund, instruction_id: refundIds.instruction, payment_event_id: refundIds.payment, club_id: 24,
    maker_id: refundIds.maker, checker_id: null as string | null, payment: refundPayment, amount: 2500, reason: "cancelled_order", status: "awaiting_review",
    revision: 1, confirmed_amount: 0, payment_confirmed_amount: 0, approval: null as typeof refundApproval | null,
    current_approval: refundApproval as typeof refundApproval | null, instruction: null as Record<string, unknown> | null,
    consequence: null, operation_id: refundIds.operation, created_at: "2026-10-01T10:00:00Z", updated_at: "2026-10-01T10:00:00Z", ...patch };
  if (["approved", "pending", "unknown", "failed", "partially_refunded", "refunded"].includes(receipt.status)) {
    receipt.checker_id = refundIds.checker; receipt.approval = refundApproval;
  }
  if (["pending", "unknown", "failed", "partially_refunded", "refunded"].includes(receipt.status)) receipt.instruction = {
    protocol: "africlub.provider-refund-instruction.v1", id: receipt.instruction_id, refund_id: receipt.id,
    original_payment: receipt.payment, amount: receipt.amount, currency: receipt.payment.currency,
    maker_id: receipt.maker_id, checker_id: receipt.checker_id, approval: receipt.approval,
  };
  return receipt;
}
