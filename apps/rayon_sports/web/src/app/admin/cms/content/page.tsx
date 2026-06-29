"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Trash2, Edit3, Eye, EyeOff } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  getAdminContentBlocks,
  saveAdminContentBlock,
  deleteAdminContentBlock,
} from "@/lib/data/admin/cms-content";
import type { CmsContent } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useHydrated } from "@/lib/use-hydrated";

const CONTENT_TYPES = [
  "club_history",
  "privacy_policy",
  "terms",
  "contact_support",
  "section_heading",
  "portal_hero",
  "general",
] as const;

const emptyForm = {
  id: "" as string,
  contentType: "general" as string,
  title: "",
  subtitle: "",
  body: "",
  rationale: "",
  iconEmoji: "",
  ctaAction: "",
  ctaLabel: "",
  sortOrder: 0,
  isActive: true,
  distribution: "both" as "web" | "app" | "both",
};

export default function AdminContentBlocksPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [blocks, setBlocks] = useState<CmsContent[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);
  const [filterType, setFilterType] = useState("");
  const [loadError, setLoadError] = useState<string | null>(null);
  const formDisabled = !hydrated || client == null;

  const load = useCallback(async () => {
    if (!client) return;
    setLoading(true);
    try {
      setBlocks(await getAdminContentBlocks(client, access));
      setLoadError(null);
    } catch (e) {
      const message = e instanceof Error ? e.message : "Failed to load.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client && access.hasAccess) load().catch(() => { });
  }, [access.hasAccess, client, load]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!client) return;
    const formData = new FormData(e.currentTarget as HTMLFormElement);
    try {
      await saveAdminContentBlock(client, access, {
        id: form.id || null,
        contentType: String(formData.get("contentType") ?? form.contentType),
        title: String(formData.get("title") ?? form.title),
        subtitle: String(formData.get("subtitle") ?? form.subtitle),
        body: String(formData.get("body") ?? form.body),
        rationale: String(formData.get("rationale") ?? form.rationale),
        iconEmoji: String(formData.get("iconEmoji") ?? form.iconEmoji),
        ctaAction: String(formData.get("ctaAction") ?? form.ctaAction),
        ctaLabel: String(formData.get("ctaLabel") ?? form.ctaLabel),
        sortOrder: Number(formData.get("sortOrder") ?? form.sortOrder),
        isActive: formData.get("isActive") === "on",
        distribution:
          (String(formData.get("distribution") ?? form.distribution) as
            | "web"
            | "app"
            | "both"),
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Content saved.", "success");
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Save failed.", "error");
    }
  }

  async function remove(id: string) {
    if (!client) return;
    if (
      !confirmAdminDestructiveAction({
        subject: "this content block",
      })
    ) {
      return;
    }
    try {
      await deleteAdminContentBlock(client, access, id);
      await load();
      showAdminToast("Block removed.", "success");
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Delete failed.", "error");
    }
  }

  const filtered = filterType ? blocks.filter((b) => b.contentType === filterType) : blocks;

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="CMS"
        title="Content blocks"
      />

      <form onSubmit={submit} className="glass-panel rounded-[28px] p-6 grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Content type</span>
            <select name="contentType" value={form.contentType} onChange={(e) => setForm({ ...form, contentType: e.target.value })} className="admin-input">
              {CONTENT_TYPES.map((t) => <option key={t} value={t}>{t.replace(/_/g, " ")}</option>)}
            </select>
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Title</span>
            <input name="title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Distribution</span>
            <select name="distribution" value={form.distribution} onChange={(e) => setForm({ ...form, distribution: e.target.value as CmsContent["distribution"] })} className="admin-input">
              <option value="both">Both (Web & App)</option>
              <option value="web">Website only</option>
              <option value="app">Mobile App only</option>
            </select>
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Icon emoji</span>
            <input name="iconEmoji" value={form.iconEmoji} onChange={(e) => setForm({ ...form, iconEmoji: e.target.value })} className="admin-input" placeholder="📰" />
          </label>
          <label className="grid gap-1 sm:col-span-2">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Subtitle</span>
            <input name="subtitle" value={form.subtitle} onChange={(e) => setForm({ ...form, subtitle: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1 sm:col-span-2">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Body</span>
            <textarea name="body" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} rows={4} className="admin-input min-h-[100px]" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">CTA label</span>
            <input name="ctaLabel" value={form.ctaLabel} onChange={(e) => setForm({ ...form, ctaLabel: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">CTA action/route</span>
            <input name="ctaAction" value={form.ctaAction} onChange={(e) => setForm({ ...form, ctaAction: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Sort order</span>
            <input name="sortOrder" type="number" value={form.sortOrder} onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })} className="admin-input" />
          </label>
          <label className="flex items-center gap-3 self-end pb-2">
            <input name="isActive" type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} className="h-4 w-4 rounded accent-club-accent" />
            <span className="text-sm text-slate-200">Active</span>
          </label>
        </div>
        <div className="flex gap-3">
          <button
            type="submit"
            disabled={formDisabled}
            className="rounded-full bg-club-primary px-5 py-2.5 text-sm font-semibold text-white hover:bg-club-primary-light disabled:opacity-60"
          >
            <Plus size={16} className="inline mr-1" />{form.id ? "Update" : "Add"} block
          </button>
          {form.id ? (
            <button type="button" onClick={() => setForm(emptyForm)} className="rounded-full border border-border-soft px-4 py-2.5 text-sm text-slate-300 hover:bg-white/8">
              Cancel
            </button>
          ) : null}
        </div>
      </form>

      <div className="glass-panel rounded-[28px] p-6">
        <div className="mb-4 flex flex-wrap gap-2">
          <button onClick={() => setFilterType("")} className={`rounded-full px-3 py-1.5 text-[11px] uppercase tracking-wider font-semibold transition ${!filterType ? "bg-club-accent/20 text-club-accent" : "text-slate-400 hover:text-white"}`}>All</button>
          {CONTENT_TYPES.map((t) => (
            <button key={t} onClick={() => setFilterType(t)} className={`rounded-full px-3 py-1.5 text-[11px] uppercase tracking-wider font-semibold transition ${filterType === t ? "bg-club-accent/20 text-club-accent" : "text-slate-400 hover:text-white"}`}>{t.replace(/_/g, " ")}</button>
          ))}
        </div>

        {loading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : loadError ? (
          <AdminErrorState
            title="Content blocks could not be loaded"
            description={loadError}
            onRetry={() => {
              load().catch(() => { });
            }}
          />
        ) : filtered.length === 0 ? (
          <p className="text-sm text-slate-400">No content blocks. Add one above.</p>
        ) : (
          <div className="grid gap-3">
            {filtered.map((b) => (
              <div key={b.id} className="rounded-[20px] border border-border-soft bg-white/5 p-4">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      {b.isActive ? <Eye size={14} className="text-emerald-400" /> : <EyeOff size={14} className="text-slate-500" />}
                      <span className="rounded-full bg-club-primary/20 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-blue-200">{b.contentType.replace(/_/g, " ")}</span>
                      <span className={cn(
                        "rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider",
                        b.distribution === "both" ? "bg-slate-500/20 text-slate-300" :
                        b.distribution === "web" ? "bg-indigo-500/20 text-indigo-300" :
                        "bg-amber-500/20 text-amber-300"
                      )}>{b.distribution}</span>
                      <p className="font-semibold text-white truncate">{b.title}</p>
                    </div>
                    <p className="mt-1 text-xs text-slate-400 line-clamp-2">{b.body || "—"}</p>
                  </div>
                  <div className="flex shrink-0 gap-2">
                    <button
                      onClick={() =>
                        setForm({
                          id: b.id,
                          contentType: b.contentType,
                          title: b.title,
                          subtitle: b.subtitle,
                          body: b.body,
                          rationale: b.rationale,
                          iconEmoji: b.iconEmoji,
                          ctaAction: b.ctaAction,
                          ctaLabel: b.ctaLabel,
                          sortOrder: b.sortOrder,
                          isActive: b.isActive,
                          distribution: b.distribution,
                        })
                      }
                      aria-label={`Edit content block ${b.title || b.contentType}`}
                      className="rounded-full border border-border-soft p-2 text-slate-300 hover:bg-white/10"
                    >
                      <Edit3 size={14} />
                    </button>
                    <button
                      onClick={() => remove(b.id)}
                      aria-label={`Delete content block ${b.title || b.contentType}`}
                      className="rounded-full border border-red-500/30 p-2 text-red-400 hover:bg-red-500/10"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
