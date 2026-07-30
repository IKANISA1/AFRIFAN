"use client";

import { useActionState, useRef } from "react";
import {
  initialVenueActionState,
  launchVenuePromotion,
  saveVenueMenuItem,
  updateVenueOrderStatus,
  type VenueActionState,
} from "../actions";
import type { VenueMenuItem } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { useVenueOnline } from "./venue-shell-client";

function ActionFeedback({ state }: { state: VenueActionState }) {
  if (!state.message) return null;
  const className =
    state.status === "success"
      ? "text-sm text-emerald-300"
      : state.status === "conflict" || state.status === "security_timeout"
        ? "text-sm text-amber-200"
        : "text-sm text-red-300";
  return (
    <p
      role={state.status === "success" ? "status" : "alert"}
      aria-live="polite"
      className={className}
    >
      {state.message}
    </p>
  );
}

export function OrderStatusForm({ orderId, currentStatus }: { orderId: string; currentStatus: string }) {
  const [state, action, pending] = useActionState(updateVenueOrderStatus, initialVenueActionState);
  const online = useVenueOnline();
  const uncertain =
    state.status === "conflict" || state.status === "security_timeout";
  const transitions: Record<string, string[]> = {
    created: ["accepted", "cancelled"],
    accepted: ["preparing", "cancelled"],
    preparing: ["ready", "cancelled"],
    ready: ["served", "cancelled"],
  };
  const available = transitions[currentStatus] ?? [];
  return (
    <form action={action} className="mt-4 grid gap-3 border-t border-white/10 pt-4">
      <input type="hidden" name="orderId" value={orderId} />
      <label className="grid gap-2 text-sm font-semibold">
        Next status
        <select name="nextStatus" className={ui.input} required defaultValue="">
          <option value="" disabled>Select status</option>
          {available.map((status) => <option key={status} value={status}>{status}</option>)}
        </select>
      </label>
      <label className="grid gap-2 text-sm font-semibold">
        Reason or handoff note
        <input name="reason" maxLength={240} className={ui.input} />
      </label>
      <label className="flex min-h-12 items-start gap-3 text-sm">
        <input
          type="checkbox"
          name="confirmConsequence"
          value="confirmed"
          required
          className="mt-1"
        />
        <span>
          I reviewed the order and understand this status change is recorded in
          the venue audit trail.
        </span>
      </label>
      <button className={ui.buttonPrimary} disabled={pending || !online || uncertain || available.length === 0}>
        {pending ? "Updating…" : "Update order"}
      </button>
      <ActionFeedback state={state} />
    </form>
  );
}

export function PromotionLaunchForm({ campaignId }: { campaignId: string }) {
  const [state, action, pending] = useActionState(launchVenuePromotion, initialVenueActionState);
  const idempotencyKey = useRef<HTMLInputElement>(null);
  const online = useVenueOnline();
  const uncertain =
    state.status === "conflict" || state.status === "security_timeout";
  return (
    <form
      action={action}
      className="mt-5 grid gap-4 border-t border-white/10 pt-4"
      onSubmit={() => {
        if (idempotencyKey.current && !idempotencyKey.current.value) {
          idempotencyKey.current.value = crypto.randomUUID();
        }
      }}
    >
      <input type="hidden" name="campaignId" value={campaignId} />
      <input ref={idempotencyKey} type="hidden" name="idempotencyKey" />
      <label className="flex min-h-12 items-start gap-3 text-sm">
        <input
          type="checkbox"
          name="confirmConsequence"
          value="confirmed"
          required
          className="mt-1"
        />
        <span>
          Launch the approved promotion for this venue. Budget and campaign
          rules cannot be changed here.
        </span>
      </label>
      <button className={ui.buttonPrimary} disabled={pending || !online || uncertain}>{pending ? "Launching…" : "Launch approved promotion"}</button>
      <ActionFeedback state={state} />
    </form>
  );
}

export function MenuItemForm({ item }: { item?: VenueMenuItem }) {
  const [state, action, pending] = useActionState(saveVenueMenuItem, initialVenueActionState);
  const online = useVenueOnline();
  const uncertain =
    state.status === "conflict" || state.status === "security_timeout";
  return (
    <form action={action} className={`${ui.panel} grid gap-4 rounded-lg p-5`}>
      <input type="hidden" name="itemId" value={item?.id ?? ""} />
      <label className="grid gap-2 text-sm font-semibold">Drink name<input className={ui.input} name="name" required minLength={2} maxLength={80} defaultValue={item?.name} /></label>
      <label className="grid gap-2 text-sm font-semibold">Description<input className={ui.input} name="description" maxLength={240} defaultValue={item?.description} /></label>
      <div className="grid gap-4 md:grid-cols-3">
        <label className="grid gap-2 text-sm font-semibold">Price<input className={ui.input} type="number" name="priceAmount" min={0} required defaultValue={item?.priceAmount ?? 0} /></label>
        <label className="grid gap-2 text-sm font-semibold">Currency<input className={ui.input} name="currencyCode" pattern="[A-Z]{3}" required defaultValue={item?.currencyCode ?? "RWF"} /></label>
        <label className="grid gap-2 text-sm font-semibold">Sort order<input className={ui.input} type="number" name="sortOrder" min={0} max={100} required defaultValue={item?.sortOrder ?? 0} /></label>
      </div>
      <div className="flex flex-wrap gap-5 text-sm">
        <label className="flex min-h-11 items-center gap-2"><input type="checkbox" name="isActive" defaultChecked={item?.isActive ?? true} /> Active</label>
        <label className="flex min-h-11 items-center gap-2"><input type="checkbox" name="isAlcohol" defaultChecked={item?.isAlcohol ?? false} /> Contains alcohol</label>
      </div>
      <button className={ui.buttonPrimary} disabled={pending || !online || uncertain}>{pending ? "Saving…" : item ? "Save item" : "Add drink"}</button>
      <ActionFeedback state={state} />
    </form>
  );
}
