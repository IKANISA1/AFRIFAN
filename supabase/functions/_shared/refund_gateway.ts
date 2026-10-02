import { HttpError } from "./http_error.ts";
import { refundGatewayProtocol, uuid } from "./trusted_sms.ts";

/** Syntax only: SQL25 owns approval, original-payment binding and compensation. */
export type RefundGatewayProjection = {
  protocol: typeof refundGatewayProtocol;
  eventId: string;
  refundId: string;
  instructionId: string;
  originalPaymentEventId: string;
  originalProviderTransactionId: string;
  originalSettlementRecordId: string;
  receiver: string;
  provider: string;
  country: string;
  currency: string;
  amount: number;
  providerRefundTransactionId: string;
  settlementRecordId: string;
  settlementRecordDigest: string;
  settlementStatus: "settled" | "failed" | "unknown";
  settledAt: string;
};
export const refundGatewayFields = [
  "protocol",
  "eventId",
  "refundId",
  "instructionId",
  "originalPaymentEventId",
  "originalProviderTransactionId",
  "originalSettlementRecordId",
  "receiver",
  "provider",
  "country",
  "currency",
  "amount",
  "providerRefundTransactionId",
  "settlementRecordId",
  "settlementRecordDigest",
  "settlementStatus",
  "settledAt",
] as const;
export function validateRefundProjection(
  value: unknown,
): RefundGatewayProjection {
  if (
    !value || typeof value !== "object" || Array.isArray(value) ||
    Object.keys(value).sort().join() !== [...refundGatewayFields].sort().join()
  ) throw new HttpError(400, "Unsupported refund evidence fields.");
  const p = value as RefundGatewayProjection;
  if (
    refundGatewayFields.some((field) =>
      field !== "amount" &&
      typeof (value as Record<string, unknown>)[field] !== "string"
    ) || p.protocol !== refundGatewayProtocol ||
    ![p.eventId, p.refundId, p.instructionId, p.originalPaymentEventId].every(
      (id) => uuid.test(id),
    ) || !["settled", "failed", "unknown"].includes(p.settlementStatus) ||
    !Number.isSafeInteger(p.amount) || p.amount > 2_000_000_000 ||
    (p.settlementStatus === "settled" ? p.amount <= 0 : p.amount !== 0) ||
    !/^\d{3,20}$/.test(p.receiver) ||
    !/^[a-z][a-z0-9_]{1,39}$/.test(p.provider) ||
    !/^[A-Z]{2}$/.test(p.country) || !/^[A-Z]{3}$/.test(p.currency) ||
    ![
      p.originalProviderTransactionId,
      p.originalSettlementRecordId,
      p.providerRefundTransactionId,
      p.settlementRecordId,
    ].every((id) => /^[A-Za-z0-9_.:/-]{1,160}$/.test(id)) ||
    !/^[0-9a-f]{64}$/.test(p.settlementRecordDigest) ||
    !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{3})?Z$/.test(p.settledAt) ||
    !Number.isFinite(Date.parse(p.settledAt))
  ) throw new HttpError(400, "Invalid refund settlement evidence.");
  return p;
}
export function validateRefundReceipt(
  value: unknown,
  evidence: RefundGatewayProjection,
): {
  status: string;
  confirmedAmount: number;
  compensationId: string | null;
  replay: boolean;
} {
  const p = value as Record<string, unknown> | null;
  if (
    !p || typeof p !== "object" || Array.isArray(p) ||
    p.event_id !== evidence.eventId ||
    p.refund_id !== evidence.refundId ||
    p.instruction_id !== evidence.instructionId ||
    p.currency !== evidence.currency ||
    typeof p.status !== "string" ||
    !["pending", "unknown", "failed", "partially_refunded", "refunded"]
      .includes(p.status) ||
    !Number.isSafeInteger(p.confirmed_amount) ||
    Number(p.confirmed_amount) < 0 ||
    Number(p.confirmed_amount) > 2_000_000_000 ||
    typeof p.replay !== "boolean" ||
    (p.compensation_id !== null &&
      (typeof p.compensation_id !== "string" ||
        !uuid.test(p.compensation_id))) ||
    (evidence.settlementStatus !== "settled" && p.compensation_id !== null) ||
    (evidence.settlementStatus === "settled" &&
      (!p.compensation_id || Number(p.confirmed_amount) < evidence.amount ||
        !["partially_refunded", "refunded"].includes(String(p.status)))) ||
    (["partially_refunded", "refunded"].includes(String(p.status)) &&
      Number(p.confirmed_amount) <= 0) ||
    (!["partially_refunded", "refunded"].includes(String(p.status)) &&
      Number(p.confirmed_amount) !== 0)
  ) throw new Error("Refund processing acknowledgement could not be verified.");
  return {
    status: String(p.status),
    confirmedAmount: Number(p.confirmed_amount),
    compensationId: p.compensation_id as string | null,
    replay: p.replay,
  };
}
