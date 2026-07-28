"use client";

import { useCallback, useEffect, useState } from "react";
import { Plus, Trash2, Edit3, Search, Settings2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  getAdminAppConfig,
  saveAdminConfigEntry,
  deleteAdminConfigEntry,
} from "@/lib/data/admin/cms-content";
import type { AppConfigEntry } from "@/lib/types";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

const emptyForm = {
  id: "",
  expectedUpdatedAt: "",
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
  const entryCollection = useAdminCollection({
    records: entries,
    getId: (entry) => entry.id ?? entry.key,
    getSearchValues: (entry) => [entry.key, entry.value, entry.description, entry.country || "global"],
    getSortValue: (entry, key: "key" | "value" | "country") => {
      switch (key) {
        case "key": return entry.key;
        case "value": return entry.value;
        case "country": return entry.country || "global";
      }
    },
    initialSortKey: "key" as const,
    pageSize: 25,
  });

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
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        key: form.key,
        value: form.value,
        description: form.description,
        country: form.country,
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Config saved.", "success");
    } catch (e) {
      if (isAdminMutationConflict(e)) {
        await load();
      }
      showAdminToast(e instanceof Error ? e.message : "Save failed.", "error");
    }
  }

  async function remove(entry: AppConfigEntry) {
    if (!client) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: entry.key,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact:
          "The configuration entry will be removed from the active club scope.",
        undo: "not_available",
      })
    ) {
      return;
    }
    try {
      await deleteAdminConfigEntry(
        client,
        access,
        entry.id ?? "",
        entry.updatedAt ?? "",
      );
      await load();
      showAdminToast("Config removed.", "success");
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
      <AdminPageHeader eyebrow="CMS" title="App configuration" />

      <form
        onSubmit={submit}
        className="glass-panel rounded-[28px] p-6 grid gap-4"
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Key
            </span>
            <input
              value={form.key}
              onChange={(e) => setForm({ ...form, key: e.target.value })}
              required
              disabled={form.isEditing}
              className="admin-input"
              placeholder="e.g. community_requests_enabled"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Value
            </span>
            <input
              value={form.value}
              onChange={(e) => setForm({ ...form, value: e.target.value })}
              required
              className="admin-input"
              placeholder="true / false / any string"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Description
            </span>
            <input
              value={form.description}
              onChange={(e) =>
                setForm({ ...form, description: e.target.value })
              }
              className="admin-input"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-300">
              Country
            </span>
            <input
              value={form.country}
              onChange={(e) => setForm({ ...form, country: e.target.value })}
              className="admin-input"
              placeholder="RW, MT, or blank for global"
            />
          </label>
        </div>
        <div className="flex gap-3">
          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-2.5 text-sm font-semibold text-white hover:bg-club-primary-light"
          >
            <Plus size={16} className="inline mr-1" />
            {form.isEditing ? "Update" : "Add"} config
          </button>
          {form.isEditing ? (
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
        <AdminFilterBar actions={<div className="flex gap-2">{(["key", "value", "country"] as const).map((key) => <button key={key} type="button" data-active={entryCollection.sortKey === key} onClick={() => entryCollection.toggleSort(key)} className="dashboard-chip">Sort {key}</button>)}</div>}>
          <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search application configuration</span><input type="search" value={entryCollection.query} onChange={(event) => entryCollection.setQuery(event.target.value)} placeholder="Search key, value, description, or country" /></label>
        </AdminFilterBar>
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
        ) : entryCollection.pageResult.items.length === 0 ? (
          <p className="text-sm text-slate-400">
            {entryCollection.query ? "No configuration entries match the current search." : "No config entries. Add one above."}
          </p>
        ) : (
          <div className="grid gap-3">
            {entryCollection.pageResult.items.map((entry) => (
              <div
                key={entry.key}
                className="flex items-center justify-between gap-4 rounded-[20px] border border-border-soft bg-white/5 p-4"
              >
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <Settings2
                      size={14}
                      className="text-club-accent shrink-0"
                    />
                    <p className="font-mono text-sm font-semibold text-white">
                      {entry.key}
                    </p>
                    {entry.country ? (
                      <span className="rounded-full bg-white/10 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-slate-300">
                        {entry.country}
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1 text-sm text-emerald-300 truncate">
                    {entry.value}
                  </p>
                  {entry.description ? (
                    <p className="mt-0.5 text-xs text-slate-400 truncate">
                      {entry.description}
                    </p>
                  ) : null}
                </div>
                <div className="flex shrink-0 gap-2">
                  <button
                    onClick={() =>
                      setForm({
                        id: entry.id ?? "",
                        expectedUpdatedAt: entry.updatedAt ?? "",
                        key: entry.key,
                        value: entry.value,
                        description: entry.description,
                        country: entry.country,
                        isEditing: true,
                      })
                    }
                    className="rounded-full border border-border-soft p-2 text-slate-300 hover:bg-white/10"
                    aria-label={`Edit ${entry.key}`}
                  >
                    <Edit3 size={14} />
                  </button>
                  <button
                    onClick={() => remove(entry)}
                    className="rounded-full border border-red-500/30 p-2 text-red-400 hover:bg-red-500/10"
                    aria-label={`Delete ${entry.key}`}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
        <AdminPagination page={entryCollection.pageResult} onPageChange={entryCollection.setPage} label="Application configuration" />
      </div>
    </div>
  );
}
