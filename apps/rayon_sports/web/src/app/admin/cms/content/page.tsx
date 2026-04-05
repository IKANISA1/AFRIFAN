"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Trash2, Edit3, Eye, EyeOff } from "lucide-react";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  getAdminContentBlocks,
  saveAdminContentBlock,
  deleteAdminContentBlock,
} from "@/lib/data/admin/cms-content";
import type { CmsContent } from "@/lib/types";

const CONTENT_TYPES = [
  "club_history",
  "privacy_policy",
  "terms",
  "contact_support",
  "section_heading",
  "biopay_info",
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
};

export default function AdminContentBlocksPage() {
  const { access, client } = useAdminPortal();
  const [blocks, setBlocks] = useState<CmsContent[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);
  const [filterType, setFilterType] = useState("");

  const load = useCallback(async () => {
    if (!client) return;
    setLoading(true);
    try {
      setBlocks(await getAdminContentBlocks(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Failed to load.", "error");
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
      await saveAdminContentBlock(client, access, {
        id: form.id || null,
        contentType: form.contentType,
        title: form.title,
        subtitle: form.subtitle,
        body: form.body,
        rationale: form.rationale,
        iconEmoji: form.iconEmoji,
        ctaAction: form.ctaAction,
        ctaLabel: form.ctaLabel,
        sortOrder: form.sortOrder,
        isActive: form.isActive,
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
      <SectionHeading eyebrow="CMS" title="Manage content blocks." />

      <form onSubmit={submit} className="glass-panel rounded-[28px] p-6 grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Content type</span>
            <select value={form.contentType} onChange={(e) => setForm({ ...form, contentType: e.target.value })} className="admin-input">
              {CONTENT_TYPES.map((t) => <option key={t} value={t}>{t.replace(/_/g, " ")}</option>)}
            </select>
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Title</span>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Subtitle</span>
            <input value={form.subtitle} onChange={(e) => setForm({ ...form, subtitle: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Icon emoji</span>
            <input value={form.iconEmoji} onChange={(e) => setForm({ ...form, iconEmoji: e.target.value })} className="admin-input" placeholder="📰" />
          </label>
          <label className="grid gap-1 sm:col-span-2">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Body</span>
            <textarea value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} rows={4} className="admin-input min-h-[100px]" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">CTA label</span>
            <input value={form.ctaLabel} onChange={(e) => setForm({ ...form, ctaLabel: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">CTA action/route</span>
            <input value={form.ctaAction} onChange={(e) => setForm({ ...form, ctaAction: e.target.value })} className="admin-input" />
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
        ) : filtered.length === 0 ? (
          <p className="text-sm text-slate-400">No content blocks. Add one above.</p>
        ) : (
          <div className="grid gap-3">
            {filtered.map((b) => (
              <div key={b.id} className="rounded-[20px] border border-border-soft bg-white/5 p-4">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      {b.isActive ? <Eye size={14} className="text-emerald-400" /> : <EyeOff size={14} className="text-slate-500" />}
                      <span className="rounded-full bg-club-primary/20 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-blue-200">{b.contentType.replace(/_/g, " ")}</span>
                      <p className="font-semibold text-white truncate">{b.title}</p>
                    </div>
                    <p className="mt-1 text-xs text-slate-400 line-clamp-2">{b.body || "—"}</p>
                  </div>
                  <div className="flex shrink-0 gap-2">
                    <button onClick={() => setForm({ id: b.id, contentType: b.contentType, title: b.title, subtitle: b.subtitle, body: b.body, rationale: b.rationale, iconEmoji: b.iconEmoji, ctaAction: b.ctaAction, ctaLabel: b.ctaLabel, sortOrder: b.sortOrder, isActive: b.isActive })} className="rounded-full border border-border-soft p-2 text-slate-300 hover:bg-white/10">
                      <Edit3 size={14} />
                    </button>
                    <button onClick={() => remove(b.id)} className="rounded-full border border-red-500/30 p-2 text-red-400 hover:bg-red-500/10">
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
