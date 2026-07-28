"use client";

import { useActionState } from "react";
import {
  initialVenueActionState,
  launchVenuePromotion,
  saveVenueMenuItem,
  updateVenueOrderStatus,
} from "../actions";
import type { VenueMenuItem } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";

export function OrderStatusForm({ orderId, currentStatus }: { orderId: string; currentStatus: string }) {
  const [state, action, pending] = useActionState(updateVenueOrderStatus, initialVenueActionState);
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
      <button className={ui.buttonPrimary} disabled={pending || available.length === 0}>
        {pending ? "Updating…" : "Update order"}
      </button>
      {state.message ? <p role="status" className={state.status === "error" ? "text-sm text-red-300" : "text-sm text-emerald-300"}>{state.message}</p> : null}
    </form>
  );
}

export function PromotionLaunchForm({ campaignId }: { campaignId: string }) {
  const [state, action, pending] = useActionState(launchVenuePromotion, initialVenueActionState);
  return (
    <form action={action} className="mt-5 border-t border-white/10 pt-4">
      <input type="hidden" name="campaignId" value={campaignId} />
      <button className={ui.buttonPrimary} disabled={pending}>{pending ? "Launching…" : "Launch approved promotion"}</button>
      {state.message ? <p role="status" className={state.status === "error" ? "mt-3 text-sm text-red-300" : "mt-3 text-sm text-emerald-300"}>{state.message}</p> : null}
    </form>
  );
}

export function MenuItemForm({ item }: { item?: VenueMenuItem }) {
  const [state, action, pending] = useActionState(saveVenueMenuItem, initialVenueActionState);
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
      <button className={ui.buttonPrimary} disabled={pending}>{pending ? "Saving…" : item ? "Save item" : "Add drink"}</button>
      {state.message ? <p role="status" className={state.status === "error" ? "text-sm text-red-300" : "text-sm text-emerald-300"}>{state.message}</p> : null}
    </form>
  );
}
