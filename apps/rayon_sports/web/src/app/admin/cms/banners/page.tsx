"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Trash2, Edit3, Eye, EyeOff, Search } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  getAdminBanners,
  saveAdminBanner,
  deleteAdminBanner,
} from "@/lib/data/admin/cms-content";
import type { HomeBanner } from "@/lib/types";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { cn } from "@/lib/utils";
import { useAdminCollection } from "@/lib/use-admin-collection";

const emptyForm = {
  id: "" as string,
  expectedUpdatedAt: "",
  title: "",
  subtitle: "",
  badgeLabel: "",
  ctaLabel: "",
  route: "/",
  imageUrl: "",
  sortOrder: 0,
  isActive: true,
  distribution: "both" as "web" | "app" | "both",
};

export default function AdminBannersPage() {
  const { access, client } = useAdminPortal();
  const [banners, setBanners] = useState<HomeBanner[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const bannerCollection = useAdminCollection({
    records: banners,
    getId: (banner) => banner.id,
    getSearchValues: (banner) => [banner.title, banner.subtitle, banner.badgeLabel, banner.ctaLabel, banner.route, banner.distribution, banner.isActive ? "active" : "inactive"],
    getSortValue: (banner, key: "title" | "distribution" | "status" | "order") => {
      switch (key) {
        case "title": return banner.title;
        case "distribution": return banner.distribution;
        case "status": return banner.isActive;
        case "order": return banner.sortOrder;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 20,
  });

  const load = useCallback(async () => {
    if (!client) return;
    setLoading(true);
    try {
      setBanners(await getAdminBanners(client, access));
      setLoadError(null);
    } catch (e) {
      const message =
        e instanceof Error ? e.message : "Failed to load banners.";
      setLoadError(message);
      showAdminToast(message, "error");
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
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        title: form.title,
        subtitle: form.subtitle,
        badgeLabel: form.badgeLabel,
        ctaLabel: form.ctaLabel,
        route: form.route,
        imageUrl: form.imageUrl,
        sortOrder: form.sortOrder,
        isActive: form.isActive,
        distribution: form.distribution,
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Banner saved.", "success");
    } catch (e) {
      if (isAdminMutationConflict(e)) {
        await load();
      }
      showAdminToast(e instanceof Error ? e.message : "Save failed.", "error");
    }
  }

  async function remove(banner: HomeBanner) {
    if (!client) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: "this banner",
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The banner will be removed from the club home experience.",
        undo: "not_available",
      })
    ) {
      return;
    }
    try {
      await deleteAdminBanner(
        client,
        access,
        banner.id,
        banner.updatedAt ?? "",
      );
      await load();
      showAdminToast("Banner removed.", "success");
    } catch (e) {
      if (isAdminMutationConflict(e)) {
        await load();
      }
      showAdminToast(
        e instanceof Error ? e.message : "Delete failed.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader eyebrow="CMS" title="Home banners" />

      <form
        onSubmit={submit}
        className="glass-panel rounded-[28px] p-6 grid gap-4"
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Title
            </span>
            <input
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              required
              className="admin-input"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Subtitle
            </span>
            <input
              value={form.subtitle}
              onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
              className="admin-input"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Distribution
            </span>
            <select
              value={form.distribution}
              onChange={(e) =>
                setForm({
                  ...form,
                  distribution: e.target.value as HomeBanner["distribution"],
                })
              }
              className="admin-input"
            >
              <option value="both">Both (Web & App)</option>
              <option value="web">Website only</option>
              <option value="app">Mobile App only</option>
            </select>
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Badge label
            </span>
            <input
              value={form.badgeLabel}
              onChange={(e) => setForm({ ...form, badgeLabel: e.target.value })}
              className="admin-input"
              placeholder="e.g. NEW, PROMO"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              CTA label
            </span>
            <input
              value={form.ctaLabel}
              onChange={(e) => setForm({ ...form, ctaLabel: e.target.value })}
              className="admin-input"
              placeholder="e.g. View details"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Route
            </span>
            <input
              value={form.route}
              onChange={(e) => setForm({ ...form, route: e.target.value })}
              className="admin-input"
              placeholder="/tickets"
            />
          </label>
          <AdminImageField
            label="Banner image"
            value={form.imageUrl}
            onChange={(nextValue) => setForm({ ...form, imageUrl: nextValue })}
            mediaKind="home_banner"
            subject={form.title}
            previewAlt="Banner preview"
            promptPlaceholder="Example: Homepage hero banner for an upcoming fixture or campaign, dramatic atmosphere, strong brand colors, clean focal point."
            className="sm:col-span-2"
          />
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Sort order
            </span>
            <input
              type="number"
              value={form.sortOrder}
              onChange={(e) =>
                setForm({ ...form, sortOrder: Number(e.target.value) })
              }
              className="admin-input"
            />
          </label>
          <label className="flex items-center gap-3 self-end pb-2">
            <input
              type="checkbox"
              checked={form.isActive}
              onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
              className="h-4 w-4 rounded accent-club-accent"
            />
            <span className="text-sm text-slate-200">Active</span>
          </label>
        </div>
        <div className="flex gap-3">
          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-2.5 text-sm font-semibold text-white hover:bg-club-primary-light"
          >
            <Plus size={16} className="inline mr-1" />
            {form.id ? "Update" : "Add"} banner
          </button>
          {form.id ? (
            <button
              type="button"
              onClick={() => setForm(emptyForm)}
              className="rounded-full border border-border-soft px-4 py-2.5 text-sm text-slate-300 hover:bg-white/8"
            >
              Cancel
            </button>
          ) : null}
        </div>
      </form>

      <div className="glass-panel rounded-[28px] p-6">
        <AdminFilterBar actions={<div className="flex flex-wrap gap-2">{(["order", "title", "distribution", "status"] as const).map((key) => <button key={key} type="button" data-active={bannerCollection.sortKey === key} onClick={() => bannerCollection.toggleSort(key)} className="dashboard-chip">Sort {key}</button>)}</div>}>
          <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search home banners</span><input type="search" value={bannerCollection.query} onChange={(event) => bannerCollection.setQuery(event.target.value)} placeholder="Search banner, route, channel, or state" /></label>
        </AdminFilterBar>
        {loading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : loadError ? (
          <AdminErrorState
            title="Banners could not be loaded"
            description={loadError}
            onRetry={() => {
              load().catch(() => {});
            }}
          />
        ) : bannerCollection.pageResult.items.length === 0 ? (
          <p className="text-sm text-slate-400">
            {bannerCollection.query ? "No banners match the current search." : "No banners yet. Add one above."}
          </p>
        ) : (
          <div className="grid gap-3">
            {bannerCollection.pageResult.items.map((b) => (
              <div
                key={b.id}
                className="flex items-center justify-between gap-4 rounded-[20px] border border-border-soft bg-white/5 p-4"
              >
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap mb-1">
                    {b.isActive ? (
                      <Eye size={14} className="text-emerald-400" />
                    ) : (
                      <EyeOff size={14} className="text-slate-500" />
                    )}
                    <p className="font-semibold text-white truncate">
                      {b.title}
                    </p>
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider",
                        b.distribution === "both"
                          ? "bg-slate-500/20 text-slate-300"
                          : b.distribution === "web"
                            ? "bg-indigo-500/20 text-indigo-300"
                            : "bg-amber-500/20 text-amber-300",
                      )}
                    >
                      {b.distribution}
                    </span>
                    {b.badgeLabel ? (
                      <span className="rounded-full bg-club-accent/15 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-club-accent">
                        {b.badgeLabel}
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1 text-xs text-slate-400 truncate">
                    {b.subtitle || "—"} · {b.route}
                  </p>
                </div>
                <div className="flex shrink-0 gap-2">
                  <button
                    onClick={() =>
                      setForm({
                        id: b.id,
                        expectedUpdatedAt: b.updatedAt ?? "",
                        title: b.title,
                        subtitle: b.subtitle,
                        badgeLabel: b.badgeLabel,
                        ctaLabel: b.ctaLabel,
                        route: b.route,
                        imageUrl: b.imageUrl ?? "",
                        sortOrder: b.sortOrder,
                        isActive: b.isActive,
                        distribution: b.distribution,
                      })
                    }
                    className="rounded-full border border-border-soft p-2 text-slate-300 hover:bg-white/10"
                    aria-label={`Edit ${b.title}`}
                  >
                    <Edit3 size={14} />
                  </button>
                  <button
                    onClick={() => remove(b)}
                    className="rounded-full border border-red-500/30 p-2 text-red-400 hover:bg-red-500/10"
                    aria-label={`Delete ${b.title}`}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
        <AdminPagination page={bannerCollection.pageResult} onPageChange={bannerCollection.setPage} label="Home banners" />
      </div>
    </div>
  );
}
