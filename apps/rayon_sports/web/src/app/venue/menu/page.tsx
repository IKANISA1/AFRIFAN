import { resolveVenueAccess } from "@/lib/data/venue-access";
import { captureVenueData, getVenueMenu } from "@/lib/data/venue-operations";
import { ui } from "@/ui-kit";
import { MenuItemForm } from "../_components/venue-forms";
import { VenueDataError, VenueEmptyState, VenuePageHeader } from "../_components/venue-shell";

export default async function VenueMenuPage() {
  const result = await resolveVenueAccess();
  if (result.status !== "ready") return null;
  const loaded = await captureVenueData(() => getVenueMenu(result.client, result.access), "menu");
  if (!loaded.ok) return <main className="mx-auto max-w-7xl px-5 py-8"><VenueDataError correlationId={loaded.correlationId} /></main>;
  const items = loaded.data;
  const activeCount = items.filter((item) => item.isActive).length;
  return <main className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8">
      <VenuePageHeader eyebrow={`${activeCount} of 10 active`} title="Drinks menu" description="Owners and managers can maintain drinks. The database rejects an eleventh active item." />
      {result.access.canManageMenu ? <MenuItemForm /> : <p className={`${ui.panel} rounded-lg p-5 text-amber-200`}>Your role can view the menu but cannot change it.</p>}
      {items.length === 0 ? <VenueEmptyState title="No drinks configured" body="An owner or manager can add the first approved drink above." /> : <section className="grid gap-4 lg:grid-cols-2">{items.map((item) => result.access.canManageMenu ? <MenuItemForm key={item.id} item={item} /> : <article key={item.id} className={`${ui.panel} rounded-lg p-5`}><h2 className="font-bold">{item.name}</h2><p className="mt-2 text-sm text-slate-300">{item.priceAmount.toLocaleString()} {item.currencyCode} · {item.isActive ? "Active" : "Inactive"}</p></article>)}</section>}
  </main>;
}
