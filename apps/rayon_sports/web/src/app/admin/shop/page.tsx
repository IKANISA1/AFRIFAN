"use client";

import { useCallback, useEffect, useState } from "react";
import { ShoppingBag, Trash2 } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { fallbackClubProfile } from "@/lib/content";
import { cn, formatCurrency } from "@/lib/utils";
import {
  getAdminProducts,
  saveAdminProduct,
  deleteAdminProduct,
} from "@/lib/data/admin/shop";
import type { AdminShopProduct } from "@/lib/types";

const emptyForm = {
  id: "",
  name: "",
  subtitle: "",
  description: "",
  category: "Merch",
  price: "",
  imageUrl: "",
  sizes: "S, M, L, XL",
  isActive: true,
  collection: "",
  sortOrder: "0",
};

export default function AdminShopPage() {
  const { access, client } = useAdminPortal();
  const [products, setProducts] = useState<AdminShopProduct[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [filter, setFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setProducts(await getAdminProducts(client, access));
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not load products.", "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

  function beginEdit(product: AdminShopProduct) {
    setForm({
      id: product.id,
      name: product.name,
      subtitle: product.subtitle,
      description: product.description,
      category: product.category,
      price: String(product.price),
      imageUrl: product.imageUrl ?? "",
      sizes: product.sizes.join(", "),
      isActive: product.isActive,
      collection: product.collection ?? "",
      sortOrder: String(product.sortOrder),
    });
    showAdminToast(`Editing ${product.name}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) return;
    showAdminToast(form.id ? "Saving product..." : "Creating product...", "info");
    try {
      await saveAdminProduct(client, access, {
        id: form.id || null,
        name: String(formData.get("name") ?? ""),
        subtitle: String(formData.get("subtitle") ?? ""),
        description: String(formData.get("description") ?? ""),
        category: String(formData.get("category") ?? "Merch"),
        price: Number(formData.get("price") ?? 0),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        sizes: String(formData.get("sizes") ?? "").split(",").map((s) => s.trim()).filter(Boolean),
        isActive: formData.get("isActive") === "on",
        collection: String(formData.get("collection") ?? ""),
        sortOrder: Number(formData.get("sortOrder") ?? 0),
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Product saved.", "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not save product.", "error");
    }
  }

  async function removeProduct(product: AdminShopProduct) {
    if (client == null) return;
    try {
      await deleteAdminProduct(client, access, product.id);
      await load();
      showAdminToast(`${product.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not remove product.", "error");
    }
  }

  const categories = Array.from(new Set(products.map((p) => p.category)));
  const filtered = products.filter((p) => filter === "ALL" || p.category === filter);

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Shop"
        title="Manage products and catalogue."
      />
      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard label="Products" value={loading ? "..." : products.length.toString()} helper="In catalogue." icon={ShoppingBag} />
        <AdminStateCard label="Active" value={loading ? "..." : products.filter((p) => p.isActive).length.toString()} helper="Visible in shop." />
        <AdminStateCard label="Categories" value={loading ? "..." : categories.length.toString()} helper="Product groups." />
      </div>
      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">{form.id ? "Edit product" : "New product"}</p>
            {form.id ? <button type="button" onClick={() => setForm(emptyForm)} className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8">Clear</button> : null}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">Name<input name="name" required value={form.name} onChange={(e) => setForm((c) => ({ ...c, name: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Category<input name="category" value={form.category} onChange={(e) => setForm((c) => ({ ...c, category: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <label className="grid gap-2 text-sm">Subtitle<input name="subtitle" value={form.subtitle} onChange={(e) => setForm((c) => ({ ...c, subtitle: e.target.value }))} className="dashboard-input" /></label>
          <label className="grid gap-2 text-sm">Description<textarea name="description" rows={3} value={form.description} onChange={(e) => setForm((c) => ({ ...c, description: e.target.value }))} className="dashboard-input min-h-20 resize-y" /></label>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">Price ({fallbackClubProfile.currencyCode})<input type="number" name="price" value={form.price} onChange={(e) => setForm((c) => ({ ...c, price: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Sort order<input type="number" name="sortOrder" value={form.sortOrder} onChange={(e) => setForm((c) => ({ ...c, sortOrder: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Collection<input name="collection" value={form.collection} onChange={(e) => setForm((c) => ({ ...c, collection: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <label className="grid gap-2 text-sm">Sizes (comma separated)<input name="sizes" value={form.sizes} onChange={(e) => setForm((c) => ({ ...c, sizes: e.target.value }))} className="dashboard-input" /></label>
          <label className="grid gap-2 text-sm">Image URL<input name="imageUrl" value={form.imageUrl} onChange={(e) => setForm((c) => ({ ...c, imageUrl: e.target.value }))} className="dashboard-input" /></label>
          {form.imageUrl.trim() ? (
            <div className="overflow-hidden rounded-[22px] border border-border-soft">
              {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
              <img src={form.imageUrl} alt="Preview" className="h-32 w-full object-cover" />
            </div>
          ) : null}
          <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm"><input type="checkbox" name="isActive" checked={form.isActive} onChange={(e) => setForm((c) => ({ ...c, isActive: e.target.checked }))} />Active in shop</label>
          <button type="submit" className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary">{form.id ? "Save product" : "Add product"}</button>
        </form>
        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">Catalogue</p>
            <div className="flex flex-wrap gap-2">
              {["ALL", ...categories].map((item) => <button key={item} type="button" data-active={filter === item} onClick={() => setFilter(item)} className="dashboard-chip">{item}</button>)}
            </div>
          </div>
          <div className="mt-5 space-y-3">
            {loading ? Array.from({ length: 3 }).map((_, i) => <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5"><Skeleton className="skeleton-text h-5 w-2/5" /><Skeleton className="skeleton-text mt-2 h-3 w-full" /></div>) : null}
            {!loading && filtered.length === 0 ? <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">No products found.</p> : null}
            {!loading && filtered.map((product) => (
              <article key={product.id} className={cn("card-interactive flex items-start gap-4 rounded-[26px] border border-border-soft p-5 transition", product.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                {product.imageUrl ? (
                  <div className="hidden sm:block h-16 w-16 flex-shrink-0 overflow-hidden rounded-xl border border-border-soft">
                    {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
                    <img src={product.imageUrl} alt="" className="h-full w-full object-cover" />
                  </div>
                ) : null}
                <div className="flex-1 min-w-0">
                  <p className="font-display text-2xl font-bold uppercase leading-none">{product.name}</p>
                  <p className="mt-1 truncate text-sm text-slate-300">{product.subtitle}</p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">{formatCurrency(product.price)}</span>
                    <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-slate-300">{product.category}</span>
                    {product.sizes.map((s) => <span key={s} className="rounded-full border border-border-soft px-2 py-1 text-[10px] uppercase tracking-[0.16em] text-slate-400">{s}</span>)}
                  </div>
                </div>
                <div className="flex flex-shrink-0 gap-2">
                  <button type="button" onClick={() => beginEdit(product)} className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-white/8" title="Edit"><span className="text-xs">✏️</span></button>
                  <button type="button" onClick={() => { removeProduct(product).catch(() => {}); }} className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-rose-500/15 hover:border-rose-400/30 hover:text-rose-300" title="Remove"><Trash2 size={14} /></button>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
