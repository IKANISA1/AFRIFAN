import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueOrders } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { OrderStatusForm } from "../_components/venue-forms";
import { VenueDataError, VenueEmptyState, VenuePageHeader } from "../_components/venue-shell";

export default async function VenueOrdersPage() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(() => getVenueOrders(result.client, result.access), "orders");
  if (!loaded.ok) return <main className="mx-auto max-w-7xl px-5 py-8"><VenueDataError correlationId={loaded.correlationId} /></main>;
  const orders = loaded.data;
  return <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader eyebrow="Live queue" title="Drinks orders" description="Oldest open orders appear first. Every status change uses the audited backend transition RPC." />
      {orders.length === 0 ? <VenueEmptyState title="Queue clear" body="No created, accepted, preparing, or ready orders exist for this venue." /> : (
        <section className="grid gap-4 lg:grid-cols-2">{orders.map((order) => <article key={order.id} className={`${ui.panel} rounded-lg p-5`}>
          <div className="flex items-start justify-between gap-4"><div><p className={ui.kicker}>Order {order.id.slice(0, 8)}</p><h2 className="mt-2 text-xl font-bold uppercase">{order.status}</h2></div><p className={ui.chip}>{order.totalAmount.toLocaleString()} {order.currencyCode}</p></div>
          <dl className="mt-4 grid grid-cols-2 gap-3 text-sm"><div><dt className="text-slate-400">Payment</dt><dd>{order.paymentStatus}</dd></div><div><dt className="text-slate-400">Age gate</dt><dd>{order.ageGateConfirmed ? "Confirmed" : "Not confirmed"}</dd></div></dl>
          {result.access.canOperateOrders ? <OrderStatusForm orderId={order.id} currentStatus={order.status} /> : <p className="mt-4 text-sm text-amber-200">Your reviewer role is read-only.</p>}
        </article>)}</section>
      )}
  </main>;
}
