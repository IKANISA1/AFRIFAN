import type { GatewayProjection } from "../_shared/trusted_sms.ts";
import type { RefundGatewayProjection } from "../_shared/refund_gateway.ts";
export const evidence: GatewayProjection = {
  protocol: "africlub.receiver-settlement.v1",
  eventId: "99964000-0000-4000-8000-000000000001",
  checkoutReference: "order-99964000-0000-4000-8000-000000000002",
  providerTransactionId: "TX-99964001",
  receiver: "12345",
  provider: "mtn_rwanda",
  country: "RW",
  currency: "RWF",
  amount: 2500,
  settledAt: "2026-10-01T20:30:00Z",
  settlementStatus: "settled",
  payerAccountDigest:
    "1c0926b20c42ad64dbf0c8355f40ad8bd7546775f74183598cc5fb27a494c151",
  settlementRecordId: "receiver-statement:row-1",
  settlementRecordDigest: "a".repeat(64),
};
export const target = "https://qa.invalid/functions/v1/sms-ingest";
export const keyId = "99964000-0000-4000-8000-000000000010";
export const secret = btoa("a".repeat(32));
export const refundEvidence: RefundGatewayProjection = {
  protocol: "africlub.receiver-refund-settlement.v1",
  eventId: "99964000-0000-4000-8000-000000000101",
  refundId: "99964000-0000-4000-8000-000000000102",
  instructionId: "99964000-0000-4000-8000-000000000103",
  originalPaymentEventId: evidence.eventId,
  originalProviderTransactionId: evidence.providerTransactionId,
  originalSettlementRecordId: evidence.settlementRecordId,
  receiver: evidence.receiver,
  provider: evidence.provider,
  country: evidence.country,
  currency: evidence.currency,
  amount: 1000,
  providerRefundTransactionId: "RF-99964001",
  settlementRecordId: "receiver-refund:row-1",
  settlementRecordDigest: "b".repeat(64),
  settlementStatus: "settled",
  settledAt: "2026-10-01T20:35:00Z",
};
