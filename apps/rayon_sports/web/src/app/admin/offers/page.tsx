"use client";

import { useCallback, useEffect, useState } from "react";
import { Gift, Pencil, Search, Trash2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { cn } from "@/lib/utils";
import {
  getAdminOffers,
  saveAdminOffer,
  deleteAdminOffer,
} from "@/lib/data/admin/offers";
import type { AdminPartnerOffer } from "@/lib/data/admin/offers";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

const emptyForm = {
  id: "",
  expectedUpdatedAt: "",
  title: "",
  description: "",
  partnerName: "",
  fetCost: "0",
  originalValue: "",
  categoryTag: "reward",
  imageUrl: "",
  redeemUrl: "",
  totalStock: "",
  isActive: true,
  startsAt: "",
  expiresAt: "",
};

export default function AdminOffersPage() {
  const { access, client } = useAdminPortal();
  const [offers, setOffers] = useState<AdminPartnerOffer[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const offerCollection = useAdminCollection({
    records: offers,
    getId: (offer) => offer.id,
    getSearchValues: (offer) => [offer.title, offer.description, offer.partnerName, offer.categoryTag, offer.originalValue, offer.isActive ? "active" : "inactive"],
    getSortValue: (offer, key: "title" | "partner" | "cost" | "claimed" | "status") => {
      switch (key) {
        case "title": return offer.title;
        case "partner": return offer.partnerName;
        case "cost": return offer.fetCost;
        case "claimed": return offer.claimedCount;
        case "status": return offer.isActive;
      }
    },
    initialSortKey: "title" as const,
    pageSize: 20,
  });

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setOffers(await getAdminOffers(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load offers.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

  function beginEdit(offer: AdminPartnerOffer) {
    setForm({
      id: offer.id,
      expectedUpdatedAt: offer.updatedAt,
      title: offer.title,
      description: offer.description,
      partnerName: offer.partnerName,
      fetCost: String(offer.fetCost),
      originalValue: offer.originalValue,
      categoryTag: offer.categoryTag,
      imageUrl: offer.imageUrl ?? "",
      redeemUrl: offer.redeemUrl ?? "",
      totalStock: offer.totalStock == null ? "" : String(offer.totalStock),
      isActive: offer.isActive,
      startsAt: offer.startsAt ?? "",
      expiresAt: offer.expiresAt ?? "",
    });
    showAdminToast(`Editing ${offer.title}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) return;
    showAdminToast(form.id ? "Saving offer..." : "Creating offer...", "info");
    try {
      const stockValue = String(formData.get("totalStock") ?? "").trim();
      await saveAdminOffer(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        title: String(formData.get("title") ?? ""),
        description: String(formData.get("description") ?? ""),
        partnerName: String(formData.get("partnerName") ?? ""),
        fetCost: Number(formData.get("fetCost") ?? 0),
        originalValue: String(formData.get("originalValue") ?? ""),
        categoryTag: String(formData.get("categoryTag") ?? "reward"),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        redeemUrl: String(formData.get("redeemUrl") ?? ""),
        totalStock: stockValue ? Number(stockValue) : null,
        isActive: formData.get("isActive") === "on",
        startsAt: String(formData.get("startsAt") ?? "") || null,
        expiresAt: String(formData.get("expiresAt") ?? "") || null,
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Offer saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      showAdminToast(caught instanceof Error ? caught.message : "Could not save offer.", "error");
    }
  }

  async function removeOffer(offer: AdminPartnerOffer) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: offer.title,
        scope: "Platform partner-offer catalogue",
        impact: "The offer will be permanently removed from supporter redemption surfaces.",
        undo: "not_available",
      })
    ) {
      return;
    }
    try {
      await deleteAdminOffer(
        client,
        access,
        offer.id,
        offer.updatedAt,
      );
      await load();
      showAdminToast(`${offer.title} removed.`, "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await load();
      }
      showAdminToast(caught instanceof Error ? caught.message : "Could not remove offer.", "error");
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader eyebrow="Engagement" title="Partner Offers" />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard label="Total Offers" value={loading ? "..." : offers.length.toString()} helper="In catalogue." icon={Gift} />
        <AdminStateCard label="Active" value={loading ? "..." : offers.filter((o) => o.isActive).length.toString()} helper="Visible to fans." />
        <AdminStateCard label="Claimed" value={loading ? "..." : offers.reduce((sum, o) => sum + o.claimedCount, 0).toString()} helper="Total redemptions." />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        {/* Form */}
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">{form.id ? "Edit offer" : "New offer"}</p>
            {form.id ? <button type="button" onClick={() => setForm(emptyForm)} className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8">Clear</button> : null}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">Title<input name="title" required value={form.title} onChange={(e) => setForm((c) => ({ ...c, title: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Partner name<input name="partnerName" required value={form.partnerName} onChange={(e) => setForm((c) => ({ ...c, partnerName: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <label className="grid gap-2 text-sm">Description<textarea name="description" rows={3} value={form.description} onChange={(e) => setForm((c) => ({ ...c, description: e.target.value }))} className="dashboard-input min-h-20 resize-y" /></label>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">FET cost<input type="number" name="fetCost" value={form.fetCost} onChange={(e) => setForm((c) => ({ ...c, fetCost: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Original value<input name="originalValue" value={form.originalValue} onChange={(e) => setForm((c) => ({ ...c, originalValue: e.target.value }))} className="dashboard-input" placeholder="e.g. 5,000 RWF" /></label>
            <label className="grid gap-2 text-sm">Category<input name="categoryTag" value={form.categoryTag} onChange={(e) => setForm((c) => ({ ...c, categoryTag: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">Image URL<input name="imageUrl" value={form.imageUrl} onChange={(e) => setForm((c) => ({ ...c, imageUrl: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Redeem URL<input name="redeemUrl" value={form.redeemUrl} onChange={(e) => setForm((c) => ({ ...c, redeemUrl: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">Total stock<input type="number" name="totalStock" value={form.totalStock} onChange={(e) => setForm((c) => ({ ...c, totalStock: e.target.value }))} className="dashboard-input" placeholder="Unlimited if empty" /></label>
            <label className="grid gap-2 text-sm">Starts at<input type="date" name="startsAt" value={form.startsAt} onChange={(e) => setForm((c) => ({ ...c, startsAt: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Expires at<input type="date" name="expiresAt" value={form.expiresAt} onChange={(e) => setForm((c) => ({ ...c, expiresAt: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm"><input type="checkbox" name="isActive" checked={form.isActive} onChange={(e) => setForm((c) => ({ ...c, isActive: e.target.checked }))} />Active (visible to fans)</label>
          <button type="submit" className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary">{form.id ? "Save offer" : "Add offer"}</button>
        </form>

        {/* List */}
        <section className="glass-panel rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">Catalogue</p>
          <AdminFilterBar className="mt-5" actions={<div className="flex flex-wrap gap-2">{(["title", "partner", "cost", "claimed", "status"] as const).map((key) => <button key={key} type="button" data-active={offerCollection.sortKey === key} onClick={() => offerCollection.toggleSort(key)} className="dashboard-chip">Sort {key}</button>)}</div>}>
            <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search partner offers</span><input type="search" value={offerCollection.query} onChange={(event) => offerCollection.setQuery(event.target.value)} placeholder="Search offer, partner, category, or state" /></label>
          </AdminFilterBar>
          <div className="mt-5 space-y-3">
            {loading ? Array.from({ length: 3 }).map((_, i) => <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5"><Skeleton className="skeleton-text h-5 w-2/5" /><Skeleton className="skeleton-text mt-2 h-3 w-full" /></div>) : null}
            {!loading && loadError ? (
              <AdminErrorState title="Offers could not be loaded" description={loadError} onRetry={() => { load().catch(() => {}); }} />
            ) : null}
            {!loading && !loadError && offerCollection.pageResult.items.length === 0 ? <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">{offerCollection.query ? "No partner offers match the current search." : "No partner offers yet. Create one using the form."}</p> : null}
            {!loading && !loadError && offerCollection.pageResult.items.map((offer) => (
              <article key={offer.id} className={cn("card-interactive flex items-start gap-4 rounded-[26px] border border-border-soft p-5 transition", offer.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-border-soft bg-white/5">
                  <Gift size={20} className="text-club-accent" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-display text-2xl font-bold uppercase leading-none">{offer.title}</p>
                  <p className="mt-1 truncate text-sm text-slate-300">{offer.partnerName} · {offer.categoryTag}</p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">{offer.fetCost} pts</span>
                    {offer.originalValue ? <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-slate-300">{offer.originalValue}</span> : null}
                    <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-slate-400">{offer.claimedCount} claimed</span>
                  </div>
                </div>
                <div className="flex flex-shrink-0 gap-2">
                  <button type="button" onClick={() => beginEdit(offer)} className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-white/8" aria-label={`Edit ${offer.title}`}><Pencil size={14} aria-hidden="true" /></button>
                  <button type="button" onClick={() => { removeOffer(offer).catch(() => {}); }} className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-rose-500/15 hover:border-rose-400/30 hover:text-rose-300" aria-label={`Remove ${offer.title}`}><Trash2 size={14} aria-hidden="true" /></button>
                </div>
              </article>
            ))}
          </div>
          <AdminPagination page={offerCollection.pageResult} onPageChange={offerCollection.setPage} label="Partner offers" />
        </section>
      </div>
    </div>
  );
}
