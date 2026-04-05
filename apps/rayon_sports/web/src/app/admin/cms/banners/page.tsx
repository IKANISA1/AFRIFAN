"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Trash2, Edit3, Eye, EyeOff } from "lucide-react";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  getAdminBanners,
  saveAdminBanner,
  deleteAdminBanner,
} from "@/lib/data/admin/cms-content";
import type { HomeBanner } from "@/lib/types";

const emptyForm = {
  id: "" as string,
  title: "",
  subtitle: "",
  badgeLabel: "",
  ctaLabel: "",
  route: "/",
  imageUrl: "",
  sortOrder: 0,
  isActive: true,
};

export default function AdminBannersPage() {
  const { access, client } = useAdminPortal();
  const [banners, setBanners] = useState<HomeBanner[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!client) return;
    setLoading(true);
    try {
      setBanners(await getAdminBanners(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Failed to load banners.", "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client && access.hasAccess) load().catch(() => {});
  }, [access.hasAccess, client, load]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!client) return;
    try {
      await saveAdminBanner(client, access, {
        id: form.id || null,
        title: form.title,
        subtitle: form.subtitle,
        badgeLabel: form.badgeLabel,
        ctaLabel: form.ctaLabel,
        route: form.route,
        imageUrl: form.imageUrl,
        sortOrder: form.sortOrder,
        isActive: form.isActive,
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Banner saved.", "success");
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Save failed.", "error");
    }
  }

  async function remove(id: string) {
    if (!client) return;
    try {
      await deleteAdminBanner(client, access, id);
      await load();
      showAdminToast("Banner removed.", "success");
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Delete failed.", "error");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading eyebrow="CMS" title="Manage home banners." />

      <form onSubmit={submit} className="glass-panel rounded-[28px] p-6 grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Title</span>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Subtitle</span>
            <input value={form.subtitle} onChange={(e) => setForm({ ...form, subtitle: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Badge label</span>
            <input value={form.badgeLabel} onChange={(e) => setForm({ ...form, badgeLabel: e.target.value })} className="admin-input" placeholder="e.g. NEW, PROMO" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">CTA label</span>
            <input value={form.ctaLabel} onChange={(e) => setForm({ ...form, ctaLabel: e.target.value })} className="admin-input" placeholder="e.g. View details" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Route</span>
            <input value={form.route} onChange={(e) => setForm({ ...form, route: e.target.value })} className="admin-input" placeholder="/tickets" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Image URL</span>
            <input value={form.imageUrl} onChange={(e) => setForm({ ...form, imageUrl: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Sort order</span>
            <input type="number" value={form.sortOrder} onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })} className="admin-input" />
          </label>
          <label className="flex items-center gap-3 self-end pb-2">
            <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} className="h-4 w-4 rounded accent-club-accent" />
            <span className="text-sm text-slate-200">Active</span>
          </label>
        </div>
        <div className="flex gap-3">
          <button type="submit" className="rounded-full bg-club-primary px-5 py-2.5 text-sm font-semibold text-white hover:bg-club-primary-light">
            <Plus size={16} className="inline mr-1" />{form.id ? "Update" : "Add"} banner
          </button>
          {form.id ? (
            <button type="button" onClick={() => setForm(emptyForm)} className="rounded-full border border-border-soft px-4 py-2.5 text-sm text-slate-300 hover:bg-white/8">
              Cancel
            </button>
          ) : null}
        </div>
      </form>

      <div className="glass-panel rounded-[28px] p-6">
        {loading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : banners.length === 0 ? (
          <p className="text-sm text-slate-400">No banners yet. Add one above.</p>
        ) : (
          <div className="grid gap-3">
            {banners.map((b) => (
              <div key={b.id} className="flex items-center justify-between gap-4 rounded-[20px] border border-border-soft bg-white/5 p-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    {b.isActive ? <Eye size={14} className="text-emerald-400" /> : <EyeOff size={14} className="text-slate-500" />}
                    <p className="font-semibold text-white truncate">{b.title}</p>
                    {b.badgeLabel ? <span className="rounded-full bg-club-accent/15 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-club-accent">{b.badgeLabel}</span> : null}
                  </div>
                  <p className="mt-1 text-xs text-slate-400 truncate">{b.subtitle || "—"} · {b.route}</p>
                </div>
                <div className="flex shrink-0 gap-2">
                  <button onClick={() => setForm({ id: b.id, title: b.title, subtitle: b.subtitle, badgeLabel: b.badgeLabel, ctaLabel: b.ctaLabel, route: b.route, imageUrl: b.imageUrl ?? "", sortOrder: b.sortOrder, isActive: b.isActive })} className="rounded-full border border-border-soft p-2 text-slate-300 hover:bg-white/10">
                    <Edit3 size={14} />
                  </button>
                  <button onClick={() => remove(b.id)} className="rounded-full border border-red-500/30 p-2 text-red-400 hover:bg-red-500/10">
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
