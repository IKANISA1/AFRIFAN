"use client";

import { useEffect, useRef, useState } from "react";
import type { AdminPartnerPredictionPool } from "@/lib/data/admin/partner-pools";
import { retainLegacyPredictOperation, settleAdminLegacyPredictForActor } from "@/lib/data/admin/predict-free";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { useAdminPortal } from "./admin-portal-provider";

export function AdminLegacyPartnerReconciliation({ pool, disabled, onConfirmed }: {
  pool: AdminPartnerPredictionPool;
  disabled: boolean;
  onConfirmed: () => Promise<void>;
}) {
  const { client, access } = useAdminPortal();
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState("");
  const inFlight = useRef(false);
  const mounted = useRef(true);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  if (!client || !access.isSuperAdmin || access.role !== "super_admin") return null;
  async function reconcile() {
    if (!client || disabled || inFlight.current || ["settled", "void", "cancelled"].includes(pool.status)) return;
    if (!confirmAdminDestructiveAction({
      action: "Reconcile historical partner pool", subject: pool.title,
      scope: `${access.clubId} · ${pool.partnerName} · ${pool.totalEntries} entries`,
      impact: "Historical rewards and refunds may be posted. This service command is attributed to your authenticated global account.",
      undo: "not_available",
    })) return;
    inFlight.current = true;
    setPending(true);
    let reference: string | null = null;
    try {
      reference = retainLegacyPredictOperation(access, "partner", pool.id, null);
      await settleAdminLegacyPredictForActor(client, client, access, { engine: "partner", poolId: pool.id, operationId: reference });
      if (!mounted.current) return;
      setNotice(`Historical reconciliation confirmed. Reference: ${reference}`);
      await onConfirmed();
    } catch {
      if (!mounted.current) return;
      setNotice(`Reconciliation was not confirmed. Refresh status before retrying the same command.${reference ? ` Original reference: ${reference}` : " The reference could not be retained; no command was sent."}`);
    } finally {
      inFlight.current = false;
      if (mounted.current) setPending(false);
    }
  }
  return <div className="space-y-2">
    <button type="button" className="ui-button ui-button-secondary min-h-12 min-w-12 max-w-full whitespace-normal disabled:opacity-60 motion-reduce:transition-none" disabled={disabled || pending || ["settled", "void", "cancelled"].includes(pool.status)} onClick={() => { void reconcile(); }}>
      {pending ? "Reconciling..." : "Reconcile historical partner pool"}
    </button>
    {notice ? <p role="status" className="text-sm text-[var(--admin-text-muted)]">{notice}</p> : null}
  </div>;
}
