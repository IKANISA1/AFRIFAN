"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Trash2, Edit3, Settings2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  getAdminAppConfig,
  saveAdminConfigEntry,
  deleteAdminConfigEntry,
} from "@/lib/data/admin/cms-content";
import type { AppConfigEntry } from "@/lib/types";

const emptyForm = {
  key: "",
  value: "",
  description: "",
  country: "",
  isEditing: false,
};

export default function AdminConfigPage() {
  const { access, client } = useAdminPortal();
  const [entries, setEntries] = useState<AppConfigEntry[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!client) return;
    setLoading(true);
    try {
      setEntries(await getAdminAppConfig(client, access));
      setLoadError(null);
    } catch (e) {
      const message = e instanceof Error ? e.message : "Failed to load config.";
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
      await saveAdminConfigEntry(client, access, {
        key: form.key,
        value: form.value,
        description: form.description,
        country: form.country,
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Config saved.", "success");
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Save failed.", "error");
    }
  }

  async function remove(key: string) {
    if (!client) return;
    if (
      !confirmAdminDestructiveAction({
        subject: key,
        detail: "The configuration entry will be removed from the active club scope.",
      })
    ) {
      return;
    }
    try {
      await deleteAdminConfigEntry(client, access, key);
      await load();
      showAdminToast("Config removed.", "success");
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Delete failed.", "error");
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="CMS"
        title="App configuration"
        description="Manage feature and experience flags that apply to the active club scope."
      />

      <form onSubmit={submit} className="glass-panel rounded-[28px] p-6 grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Key</span>
            <input value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} required disabled={form.isEditing} className="admin-input" placeholder="e.g. biopay_face_enabled" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Value</span>
            <input value={form.value} onChange={(e) => setForm({ ...form, value: e.target.value })} required className="admin-input" placeholder="true / false / any string" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Description</span>
            <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className="admin-input" />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">Country</span>
            <input value={form.country} onChange={(e) => setForm({ ...form, country: e.target.value })} className="admin-input" placeholder="RW, MT, or blank for global" />
          </label>
        </div>
        <div className="flex gap-3">
          <button type="submit" className="rounded-full bg-club-primary px-5 py-2.5 text-sm font-semibold text-white hover:bg-club-primary-light">
            <Plus size={16} className="inline mr-1" />{form.isEditing ? "Update" : "Add"} config
          </button>
          {form.isEditing ? (
            <button type="button" onClick={() => setForm(emptyForm)} className="rounded-full border border-border-soft px-4 py-2.5 text-sm text-slate-300 hover:bg-white/8">
              Cancel
            </button>
          ) : null}
        </div>
      </form>

      <div className="glass-panel rounded-[28px] p-6">
        {loading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : loadError ? (
          <AdminErrorState
            title="Configuration could not be loaded"
            description={loadError}
            onRetry={() => {
              load().catch(() => {});
            }}
          />
        ) : entries.length === 0 ? (
          <p className="text-sm text-slate-400">No config entries. Add one above.</p>
        ) : (
          <div className="grid gap-3">
            {entries.map((entry) => (
              <div key={entry.key} className="flex items-center justify-between gap-4 rounded-[20px] border border-border-soft bg-white/5 p-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <Settings2 size={14} className="text-club-accent shrink-0" />
                    <p className="font-mono text-sm font-semibold text-white">{entry.key}</p>
                    {entry.country ? <span className="rounded-full bg-white/10 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-slate-300">{entry.country}</span> : null}
                  </div>
                  <p className="mt-1 text-sm text-emerald-300 truncate">{entry.value}</p>
                  {entry.description ? <p className="mt-0.5 text-xs text-slate-400 truncate">{entry.description}</p> : null}
                </div>
                <div className="flex shrink-0 gap-2">
                  <button onClick={() => setForm({ key: entry.key, value: entry.value, description: entry.description, country: entry.country, isEditing: true })} className="rounded-full border border-border-soft p-2 text-slate-300 hover:bg-white/10">
                    <Edit3 size={14} />
                  </button>
                  <button onClick={() => remove(entry.key)} className="rounded-full border border-red-500/30 p-2 text-red-400 hover:bg-red-500/10">
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
