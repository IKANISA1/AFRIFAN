"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { useAdminPortal } from "../admin-portal-provider";
import { fetchPaymentRefundDashboard, fetchPaymentRefundOperation, sendPaymentRefundCommand,
  type PaymentRefund, type PaymentRefundDashboard, type RefundDraftCommand } from "@/lib/data/admin/payment-refunds";
import { completeRefundOperation, readPendingRefundOperation, withRefundJournal, type RefundJournalEntry } from "./refund-operation-journal";

export function usePaymentRefunds() {
  const { access, accessUnavailable } = useAdminPortal();
  const [dashboard, setDashboard] = useState<PaymentRefundDashboard | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pending, setPending] = useState<RefundJournalEntry | null>(null);
  const [canRetry, setCanRetry] = useState(false);
  const mounted = useRef(false); const inFlight = useRef(false); const permitted = useRef(false);
  const allowed = !accessUnavailable && access.hasAccess && access.isAuthenticated && access.isSuperAdmin && !!access.userId && !!access.clubId;
  useEffect(() => { permitted.current = allowed; }, [allowed]);
  const readPending = useCallback(() => {
    if (access.userId && access.clubId && mounted.current) setPending(readPendingRefundOperation(access.userId, access.clubId));
  }, [access.userId, access.clubId]);
  const refresh = useCallback(async () => {
    if (!allowed || !access.clubId) return;
    const value = await fetchPaymentRefundDashboard(access.clubId);
    if (mounted.current && permitted.current) setDashboard(value);
  }, [allowed, access.clubId]);
  useEffect(() => {
    mounted.current = true;
    if (allowed) {
      setBusy(true);
      try { readPending(); } catch (failure) { setError((failure as Error).message); }
      void refresh().catch(failure => { if (mounted.current) setError(failure.message); })
        .finally(() => { if (mounted.current) setBusy(false); });
    }
    return () => { mounted.current = false; };
  }, [allowed, readPending, refresh]);
  const run = useCallback(async (command: RefundDraftCommand | RefundJournalEntry["command"]) => {
    if (!allowed || !access.userId || !access.clubId || inFlight.current) return;
    inFlight.current = true; setBusy(true); setError(null); setNotice(null); setCanRetry(false);
    try {
      const result = await withRefundJournal(access.userId, access.clubId, command, saved => {
        if (!mounted.current || !permitted.current) throw new Error("Current staff access could not be verified before this command was sent. Recover its saved reference after verification.");
        return sendPaymentRefundCommand(access.clubId!, saved);
      });
      if (!mounted.current || !permitted.current) return;
      setSelectedId(result.id);
      setNotice(result.status === "pending" ? "Original instruction issued. Provider refund is pending confirmation."
        : result.status === "approved" ? "The reviewed refund is approved. It has not been issued."
          : result.status === "rejected" ? "Refund request rejected. No refund was issued." : "Refund request retained for a different platform administrator to review.");
      readPending(); await refresh();
    } catch (failure) {
      if (mounted.current) {
        setError(`${(failure as Error).message} If the response was lost, check the saved operation before continuing.`);
        try { readPending(); } catch (storageFailure) { setError((storageFailure as Error).message); }
      }
    } finally { inFlight.current = false; if (mounted.current) setBusy(false); }
  }, [allowed, access.userId, access.clubId, readPending, refresh]);
  const recover = useCallback(async () => {
    if (!allowed || !pending || !access.userId || !access.clubId || inFlight.current) return;
    inFlight.current = true; setBusy(true); setError(null); setNotice(null);
    try {
      const result = await fetchPaymentRefundOperation(access.clubId, pending.command.operationId);
      if (!mounted.current || !permitted.current) return;
      if (result === null) {
        setCanRetry(true); setNotice("No committed result was found. You can retry the original command with the saved reference.");
      } else {
        completeRefundOperation(access.userId, access.clubId, pending.command.operationId);
        readPending(); setCanRetry(false); setSelectedId(result.id);
        setNotice("Original operation recovered. The list shows the latest refund status."); await refresh();
      }
    } catch (failure) { if (mounted.current) setError((failure as Error).message); }
    finally { inFlight.current = false; if (mounted.current) setBusy(false); }
  }, [allowed, pending, access.userId, access.clubId, readPending, refresh]);
  const selected: PaymentRefund | null = dashboard?.requests.find(r => r.id === selectedId) ?? null;
  return { access, accessUnavailable, allowed, dashboard, selected, setSelectedId, busy, error, notice, pending, canRetry, run, recover,
    refresh: async () => { if (inFlight.current) return; setBusy(true); setError(null); try { await refresh(); } catch (failure) { if (mounted.current) setError((failure as Error).message); } finally { if (mounted.current) setBusy(false); } } };
}
