"use client";

import { useCallback, useState } from "react";
import { Edit3, Plus, Search, Settings2, Trash2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { showAdminToast } from "@/components/admin/admin-toast";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminConfigEntry,
  getAdminAppConfig,
  normalizeAdminAppConfig,
  saveAdminConfigEntry,
} from "@/lib/data/admin/cms-content";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { AppConfigEntry } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { cn } from "@/lib/utils";

type ConfigForm = {
  id: string;
  expectedUpdatedAt: string;
  key: string;
  value: string;
  description: string;
  country: string;
  isEditing: boolean;
};

const emptyForm: ConfigForm = {
  id: "",
  expectedUpdatedAt: "",
  key: "",
  value: "",
  description: "",
  country: "",
  isEditing: false,
};

const emptyEntries: AppConfigEntry[] = [];
const entriesAreEmpty = (entries: AppConfigEntry[]) => entries.length === 0;

const configStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading application configuration",
    detail: "Waiting for the first authenticated configuration snapshot.",
  },
  ready: {
    label: "Application configuration confirmed",
    detail: "Scoped keys and values are current for this workspace.",
  },
  empty: {
    label: "No configuration in this scope",
    detail: "Use the editor to create the first controlled configuration key.",
  },
  error: {
    label: "Application configuration unavailable",
    detail: "Confirmed entries remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Configuration workspace is offline",
    detail: "Confirmed entries remain visible until connection returns.",
  },
  permission_denied: {
    label: "Configuration access denied",
    detail:
      "Previously loaded configuration and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing application configuration",
    detail: "Confirmed entries remain visible during refresh.",
  },
  conflict: {
    label: "Configuration records changed",
    detail: "Refresh before editing or deleting a scoped key.",
  },
  security_timeout: {
    label: "Configuration request timed out",
    detail: "No configuration operation or change was confirmed.",
  },
};

export default function AdminConfigPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState<ConfigForm>(emptyForm);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadEntries = useCallback(
    (signal: AbortSignal) => {
      if (client == null) {
        return Promise.resolve([]);
      }
      return getAdminAppConfig(client, access, { signal });
    },
    [access, client],
  );
  const handlePermissionDenied = useCallback(() => {
    setForm(emptyForm);
    setInteraction("idle");
  }, []);

  const {
    data: entries,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptyEntries,
    isEmpty: entriesAreEmpty,
    load: loadEntries,
    normalize: normalizeAdminAppConfig,
    onPermissionDenied: handlePermissionDenied,
    resourceLabel: "Application configuration",
  });

  const entryCollection = useAdminCollection({
    records: entries,
    getId: (entry) => entry.id ?? entry.key,
    getSearchValues: (entry) => [
      entry.key,
      entry.value,
      entry.description,
      entry.country || "global",
    ],
    getSortValue: (entry, key: "key" | "value" | "country") => {
      switch (key) {
        case "key":
          return entry.key;
        case "value":
          return entry.value;
        case "country":
          return entry.country || "global";
      }
    },
    initialSortKey: "key" as const,
    pageSize: 25,
  });

  function beginEdit(entry: AppConfigEntry) {
    setForm({
      id: entry.id ?? "",
      expectedUpdatedAt: entry.updatedAt ?? "",
      key: entry.key,
      value: entry.value,
      description: entry.description,
      country: entry.country,
      isEditing: true,
    });
    setInteraction("selected");
    showAdminToast(`Editing "${entry.key}".`, "info");
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (client == null) return;

    showAdminToast(
      form.isEditing ? "Saving configuration..." : "Creating configuration...",
      "info",
    );
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
      setInteraction("idle");
      await refresh();
      showAdminToast("Configuration saved.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? configStatusCopy.conflict.label
          : "Could not confirm the configuration change.",
        "error",
      );
    }
  }

  async function remove(entry: AppConfigEntry) {
    if (client == null || entry.id == null) return;
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
        entry.id,
        entry.updatedAt ?? "",
      );
      await refresh();
      showAdminToast(`Removed "${entry.key}".`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? configStatusCopy.conflict.label
          : "Could not confirm configuration deletion.",
        "error",
      );
    }
  }

  const mutationLocked = status !== "ready" && status !== "empty";

  return (
    <section
      className="admin-cms-config-state-surface section-grid"
      data-admin-cms-config-status={status}
      data-admin-cms-config-interaction={interaction}
      data-admin-cms-config-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader eyebrow="CMS" title="App configuration" />

      <AdminResourceStatusBanner
        status={status}
        label={configStatusCopy[status].label}
        detail={configStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh configuration"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-cms-config-status"
      />

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={configStatusCopy[status].label}
          description={configStatusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <div className="grid grid-cols-[repeat(auto-fit,minmax(min(100%,32rem),1fr))] gap-5">
          <form
            onSubmit={submit}
            className="ui-panel grid gap-4 rounded-[28px] p-6"
          >
            <fieldset disabled={mutationLocked} className="contents">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <p className="font-display text-3xl font-medium normal-case leading-none text-[var(--admin-text-strong)]">
                  {form.isEditing ? "Edit configuration" : "New configuration"}
                </p>
                {form.isEditing ? (
                  <button
                    type="button"
                    onClick={() => {
                      setForm(emptyForm);
                      setInteraction("idle");
                    }}
                    className="min-h-12 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
                  >
                    Cancel editing
                  </button>
                ) : null}
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Key
                  <input
                    value={form.key}
                    onChange={(event) =>
                      setForm({ ...form, key: event.target.value })
                    }
                    required
                    disabled={form.isEditing}
                    maxLength={160}
                    className="admin-input"
                    placeholder="e.g. community_requests_enabled"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Value
                  <input
                    value={form.value}
                    onChange={(event) =>
                      setForm({ ...form, value: event.target.value })
                    }
                    maxLength={4_000}
                    className="admin-input"
                    placeholder="true / false / any string"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Description
                  <input
                    value={form.description}
                    onChange={(event) =>
                      setForm({ ...form, description: event.target.value })
                    }
                    maxLength={500}
                    className="admin-input"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Country
                  <input
                    value={form.country}
                    onChange={(event) =>
                      setForm({ ...form, country: event.target.value })
                    }
                    maxLength={32}
                    className="admin-input"
                    placeholder="RW, MT, or blank for global"
                  />
                </label>
              </div>
              <button
                type="submit"
                className="min-h-12 rounded-full bg-action-blue px-5 py-3 text-sm font-semibold text-white transition hover:bg-action-blue-hover disabled:cursor-not-allowed disabled:opacity-70"
              >
                <Plus size={16} className="mr-1 inline" aria-hidden="true" />
                {form.isEditing ? "Update" : "Add"} configuration
              </button>
            </fieldset>
          </form>

          <div className="ui-panel min-w-0 rounded-[28px] p-6">
            <AdminFilterBar
              actions={
                <div className="flex flex-wrap gap-2">
                  {(["key", "value", "country"] as const).map((key) => (
                    <button
                      key={key}
                      type="button"
                      data-active={entryCollection.sortKey === key}
                      onClick={() => entryCollection.toggleSort(key)}
                      className="dashboard-chip min-h-12"
                      aria-label={`Sort by ${key}`}
                    >
                      Sort {key}
                    </button>
                  ))}
                </div>
              }
            >
              <label className="admin-search-field min-h-12">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">
                  Search application configuration
                </span>
                <input
                  type="search"
                  value={entryCollection.query}
                  onChange={(event) =>
                    entryCollection.setQuery(event.target.value)
                  }
                  placeholder="Search key, value, description, or country"
                />
              </label>
            </AdminFilterBar>

            {initialLoading ? (
              <p className="text-sm text-[var(--admin-text-muted)]">
                Loading configuration…
              </p>
            ) : entryCollection.pageResult.items.length === 0 ? (
              <p className="text-sm text-[var(--admin-text-muted)]">
                {entryCollection.query
                  ? "No configuration entries match the current search."
                  : "No configuration entries. Add one using the editor."}
              </p>
            ) : (
              <div className="grid gap-3">
                {entryCollection.pageResult.items.map((entry) => (
                  <article
                    key={entry.id ?? entry.key}
                    data-row-id={entry.id}
                    data-selected={form.id === entry.id || undefined}
                    className={cn(
                      "flex flex-wrap items-center justify-between gap-4 rounded-[20px] border bg-[var(--admin-surface-muted)] p-4",
                      form.id === entry.id
                        ? "border-[var(--admin-accent)]"
                        : "border-border-soft",
                    )}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <Settings2
                          size={16}
                          className="shrink-0 text-[var(--admin-accent)]"
                          aria-hidden="true"
                        />
                        <p className="break-all font-mono text-sm font-semibold text-[var(--admin-text-strong)]">
                          {entry.key}
                        </p>
                        {entry.country ? (
                          <span className="rounded-full border border-border-soft px-2 py-1 text-xs font-medium normal-case tracking-normal text-[var(--admin-text-strong)]">
                            {entry.country}
                          </span>
                        ) : null}
                      </div>
                      <p className="mt-1 break-all text-sm font-semibold text-[var(--admin-text-strong)]">
                        {entry.value || "Empty value"}
                      </p>
                      {entry.description ? (
                        <p className="mt-1 break-words text-xs text-[var(--admin-text-muted)]">
                          {entry.description}
                        </p>
                      ) : null}
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <button
                        type="button"
                        onClick={() => beginEdit(entry)}
                        disabled={mutationLocked}
                        className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-border-soft p-3 text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed disabled:opacity-70"
                        aria-label={`Edit ${entry.key}`}
                      >
                        <Edit3 size={16} aria-hidden="true" />
                      </button>
                      <button
                        type="button"
                        onClick={() => void remove(entry)}
                        disabled={mutationLocked || entry.id == null}
                        className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-error/40 p-3 text-error transition hover:bg-error/10 disabled:cursor-not-allowed disabled:opacity-70"
                        aria-label={`Delete ${entry.key}`}
                      >
                        <Trash2 size={16} aria-hidden="true" />
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            )}
            <AdminPagination
              page={entryCollection.pageResult}
              onPageChange={entryCollection.setPage}
              label="Application configuration"
            />
          </div>
        </div>
      )}
    </section>
  );
}
