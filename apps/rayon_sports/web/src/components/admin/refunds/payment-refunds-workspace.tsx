"use client";
import { useState } from "react";
import { AdminPageHeader } from "../admin-page-header";
import { AdminSurface } from "../admin-surface";
import { AdminActionDrawer } from "../admin-action-drawer";
import { AdminStatusBadge } from "../admin-status-badge";
import { refundReasons, type PaymentRefund, type RefundApproval, type RefundReason, type RefundStatus } from "@/lib/data/admin/payment-refunds";
import { usePaymentRefunds } from "./use-payment-refunds";

const statusLabels: Record<RefundStatus, string> = {
  awaiting_review: "Awaiting a different reviewer", approved: "Approved · not issued", rejected: "Rejected",
  pending: "Provider confirmation pending", unknown: "Provider outcome unknown", failed: "Provider failure reported",
  partially_refunded: "Partially confirmed", refunded: "Requested refund confirmed",
};
const money = (amount: number, currency: string) => `${new Intl.NumberFormat("en").format(amount)} ${currency}`;
const reasonLabel = (reason: RefundReason) => reason.replaceAll("_", " ");
function Policy({ value }: { value: RefundApproval | null }) {
  if (!value) return <p>Provider capability and terms are awaiting acceptance. Issuing a refund is closed.</p>;
  return <dl className="grid gap-3 text-sm sm:grid-cols-2">
    <div><dt className="text-muted">Policy</dt><dd className="break-words">{value.policyVersion}</dd></div>
    <div><dt className="text-muted">Terms reference</dt><dd className="break-words">{value.termsReference}</dd></div>
    <div><dt className="text-muted">Source review</dt><dd className="break-words">{value.sourceReviewReference}</dd></div>
    <div><dt className="text-muted">Provider capability reference</dt><dd className="break-words">{value.providerAcceptanceReference}</dd></div>
    <div><dt className="text-muted">Full refund stock policy</dt><dd>{value.shopStockPolicy === "restore_unfulfilled" ? "Restore paid or confirmed orders once; retain packed or shipped stock history" : "Retain stock history"}</dd></div>
    <div><dt className="text-muted">Full refund ticket policy</dt><dd>{value.ticketPolicy === "revoke_unused" ? "Revoke unused tickets; retain admission history" : "Retain tickets"}</dd></div>
    <div><dt className="text-muted">Full refund membership policy</dt><dd>{value.membershipPolicy === "suspend_current" ? "Suspend current membership; preserve later paid renewal" : "Retain membership"}</dd></div>
  </dl>;
}
function RefundReview({ refund, userId, locked, run }: { refund: PaymentRefund; userId: string | null; locked: boolean; run: ReturnType<typeof usePaymentRefunds>["run"] }) {
  const [acknowledged, setAcknowledged] = useState(false);
  const differentReviewer = userId !== refund.makerId;
  const reviewable = ["awaiting_review", "approved"].includes(refund.status);
  const approvalChanged = JSON.stringify(refund.approval) !== JSON.stringify(refund.currentApproval);
  return <div className="space-y-5">
    <AdminStatusBadge label={statusLabels[refund.status]} tone={refund.status === "refunded" ? "success" : "neutral"} />
    <dl className="grid gap-4 text-sm sm:grid-cols-2">
      <div><dt className="text-muted">Requested return</dt><dd className="text-xl font-semibold">{money(refund.amount, refund.payment.currency)}</dd></div>
      <div><dt className="text-muted">Confirmed for this request</dt><dd>{money(refund.confirmedAmount, refund.payment.currency)}</dd></div>
      <div><dt className="text-muted">Original payment</dt><dd>{money(refund.payment.amount, refund.payment.currency)}</dd></div>
      <div><dt className="text-muted">Total original-payment returns</dt><dd>{money(refund.paymentConfirmedAmount, refund.payment.currency)}</dd></div>
      <div><dt className="text-muted">Original receiver</dt><dd className="break-all">{refund.payment.receiver} · {refund.payment.provider}</dd></div>
      <div><dt className="text-muted">Original provider transaction</dt><dd className="break-all">{refund.payment.providerTransactionId}</dd></div>
      <div><dt className="text-muted">Original settlement record</dt><dd className="break-all">{refund.payment.settlementRecordId}</dd></div>
      <div><dt className="text-muted">Reason</dt><dd>{reasonLabel(refund.reason)}</dd></div>
      <div><dt className="text-muted">Instruction reference</dt><dd className="break-all">{refund.instructionId}</dd></div>
      <div><dt className="text-muted">Request reference</dt><dd className="break-all">{refund.id}</dd></div>
    </dl>
    <p className="text-sm text-muted">The return is bound to the original provider transaction. Case closure, review and instruction issuance do not confirm a cash return. Partial returns retain stock and entitlements.</p>
    <div className="space-y-3 rounded-2xl border border-border-soft p-4">
      <h3 className="font-semibold">{refund.instruction ? "Approval frozen into this instruction" : "Current terms for review"}</h3>
      <Policy value={refund.instruction ? refund.approval : refund.currentApproval} />
    </div>
    {refund.consequence && <div className="space-y-2"><h3 className="font-semibold">Recorded full-refund consequences</h3>
      {Object.entries(refund.consequence).map(([kind, value]) => <p key={kind} className="text-sm">{kind}: {value.replaceAll("_", " ")}</p>)}
    </div>}
    {reviewable && <>
      {!differentReviewer && <p className="text-sm">A different current platform administrator must review this request.</p>}
      {approvalChanged && refund.status === "approved" && <p role="status">Current terms differ from the previous approval. Obtain a fresh review before issuing this instruction.</p>}
      <label className="flex items-start gap-3 text-sm"><input type="checkbox" checked={acknowledged} onChange={e => setAcknowledged(e.target.checked)} disabled={locked} />
        <span>I reviewed the original payment, requested amount, receiver and displayed terms.</span></label>
      <div className="flex flex-wrap gap-3">
        <button type="button" className="button-primary" disabled={locked || !differentReviewer || !refund.currentApproval || !acknowledged}
          onClick={() => void run({ action: "review", refundId: refund.id, revision: refund.revision, approve: true })}>Approve reviewed refund</button>
        <button type="button" className="button-secondary" disabled={locked || !differentReviewer}
          onClick={() => void run({ action: "review", refundId: refund.id, revision: refund.revision, approve: false })}>Reject request</button>
        {refund.status === "approved" && <button type="button" className="button-primary" disabled={locked || approvalChanged || !refund.approval || !acknowledged}
          onClick={() => void run({ action: "dispatch", refundId: refund.id })}>Issue original refund instruction</button>}
      </div>
    </>}
    {["pending", "unknown", "failed", "partially_refunded"].includes(refund.status) && <p role="status" className="text-sm">Keep this instruction reference. Unconfirmed amounts remain reserved; check status before taking another action.</p>}
  </div>;
}

export function PaymentRefundsWorkspace() {
  const state = usePaymentRefunds();
  const [paymentId, setPaymentId] = useState(""); const [amount, setAmount] = useState("");
  const [reason, setReason] = useState<RefundReason>("cancelled_order");
  const payment = state.dashboard?.payments.find(p => p.eventId === paymentId);
  const parsedAmount = Number(amount); const remaining = payment ? payment.amount - payment.reservedAmount : 0;
  const valid = !!payment && Number.isSafeInteger(parsedAmount) && parsedAmount > 0 && parsedAmount <= remaining;
  const locked = !state.allowed || state.busy || !!state.pending;
  const accessNotice = <AdminSurface title="Refund access"><p>Current platform administrator access and fresh authenticator verification are required.</p></AdminSurface>;
  if (!state.allowed && !(state.accessUnavailable && state.dashboard)) return accessNotice;
  return <>{!state.allowed && accessNotice}<div hidden={!state.allowed} inert={!state.allowed || undefined} className="section-grid min-w-0 max-w-full" aria-busy={state.busy || undefined}>
    <AdminPageHeader eyebrow="Payment operations" title="Refunds" actions={<button className="button-secondary" disabled={!state.allowed || state.busy} onClick={() => void state.refresh()}>Check latest refund status</button>} />
    {state.error && <p role="alert" className="rounded-2xl border border-border-soft p-4">{state.error}</p>}
    {state.notice && <p role="status" className="rounded-2xl border border-border-soft p-4">{state.notice}</p>}
    {state.pending && <AdminSurface title="Recover original operation"><div className="space-y-3">
      <p>A refund command has an unconfirmed response. Check its original reference before starting another command.</p>
      <p className="break-all text-sm">{state.pending.command.operationId}</p>
      <div className="flex flex-wrap gap-3"><button className="button-primary" disabled={!state.allowed || state.busy} onClick={() => void state.recover()}>Recover original operation</button>
        {state.canRetry && <button className="button-secondary" disabled={!state.allowed || state.busy} onClick={() => void state.run(state.pending!.command)}>Retry original command</button>}</div>
    </div></AdminSurface>}
    <AdminSurface title="Request a reviewed refund"><form className="grid gap-4 sm:grid-cols-2" onSubmit={e => { e.preventDefault(); if (valid && !locked) void state.run({ action: "prepare", paymentEventId: payment!.eventId, amount: parsedAmount, reason }); }}>
      <label className="space-y-2 text-sm"><span>Original confirmed payment</span><select className="input-field w-full" value={paymentId} disabled={locked} onChange={e => { setPaymentId(e.target.value); setAmount(""); }}>
        <option value="">Select an original payment</option>{state.dashboard?.payments.map(p => <option key={p.eventId} value={p.eventId}>{p.providerTransactionId} · {money(p.amount, p.currency)}</option>)}</select></label>
      <label className="space-y-2 text-sm"><span>Requested return amount{payment ? ` (${payment.currency})` : ""}</span><input className="input-field w-full" type="number" inputMode="numeric" min="1" step="1" max={remaining || undefined} value={amount} disabled={locked || !payment} onChange={e => setAmount(e.target.value)} aria-describedby="refund-available-amount" /></label>
      <label className="space-y-2 text-sm"><span>Reason</span><select className="input-field w-full" value={reason} disabled={locked} onChange={e => setReason(e.target.value as RefundReason)}>{refundReasons.map(r => <option value={r} key={r}>{reasonLabel(r)}</option>)}</select></label>
      <div className="space-y-2 self-end"><p id="refund-available-amount" className="text-sm text-muted">{payment ? `${money(remaining, payment.currency)} remains unreserved.` : "Choose the exact original provider transaction."}</p>
        <button className="button-primary" disabled={locked || !valid}>Retain request for separate review</button></div>
      {payment && <p className="text-sm sm:col-span-2">Original receiver: {payment.receiver} · {payment.provider}. {payment.capabilityEnabled ? "Review is required before the original instruction can be issued." : "Provider refund capability is closed; this request cannot be issued until capability and terms are accepted."}</p>}
    </form></AdminSurface>
    <AdminSurface title="Requests and provider outcomes"><div className="space-y-3">
      {!state.dashboard && <p role="status">Loading current refund records…</p>}
      {state.dashboard && state.dashboard.requests.length === 0 && <p>No refund requests in this club.</p>}
      {state.dashboard?.requests.map(r => <button key={r.id} type="button" className="flex w-full flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-soft p-4 text-left" onClick={() => state.setSelectedId(r.id)}>
        <span className="min-w-0"><span className="block font-semibold">{money(r.amount, r.payment.currency)}</span><span className="block break-all text-sm text-muted">{r.payment.providerTransactionId}</span></span>
        <span><AdminStatusBadge label={statusLabels[r.status]} /><span className="mt-1 block text-sm">{money(r.confirmedAmount, r.payment.currency)} confirmed</span></span>
      </button>)}
    </div></AdminSurface>
    <AdminActionDrawer open={state.allowed && !!state.selected} onClose={() => state.setSelectedId(null)} title="Review original refund">
      {state.selected && <RefundReview key={`${state.selected.id}:${state.selected.revision}`} refund={state.selected} userId={state.access.userId ?? null} locked={locked} run={state.run} />}
      {state.error && <p role="alert" className="mt-4">{state.error}</p>}{state.notice && <p role="status" className="mt-4">{state.notice}</p>}
      {state.pending && <div className="mt-4 space-y-2"><p className="break-all text-sm">Saved operation: {state.pending.command.operationId}</p>
        <button className="button-secondary" disabled={!state.allowed || state.busy} onClick={() => void state.recover()}>Recover original operation</button>
        {state.canRetry && <button className="button-secondary" disabled={!state.allowed || state.busy} onClick={() => void state.run(state.pending!.command)}>Retry original command</button>}</div>}
    </AdminActionDrawer>
  </div></>;
}
