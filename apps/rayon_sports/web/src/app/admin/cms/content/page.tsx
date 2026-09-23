"use client";

import { useCallback, useState } from "react";
import { Edit3, Eye, EyeOff, Plus, Search, Trash2 } from "lucide-react";
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
  deleteAdminContentBlock,
  getAdminContentBlocks,
  getAdminContentTypes,
  normalizeAdminContentBlocks,
  normalizeAdminContentTypes,
  saveAdminContentBlock,
} from "@/lib/data/admin/cms-content";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { CmsContent, CmsContentType } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { cn } from "@/lib/utils";

type ContentForm = {
  id: string;
  expectedUpdatedAt: string;
  contentType: string;
  title: string;
  subtitle: string;
  body: string;
  rationale: string;
  iconEmoji: string;
  ctaAction: string;
  ctaLabel: string;
  sortOrder: number;
  isActive: boolean;
  distribution: CmsContent["distribution"];
};

type ContentBundle = {
  blocks: CmsContent[];
  contentTypes: CmsContentType[];
};

const emptyForm: ContentForm = {
  id: "",
  expectedUpdatedAt: "",
  contentType: "general",
  title: "",
  subtitle: "",
  body: "",
  rationale: "",
  iconEmoji: "",
  ctaAction: "",
  ctaLabel: "",
  sortOrder: 0,
  isActive: true,
  distribution: "both",
};

const emptyContentBundle: ContentBundle = {
  blocks: [],
  contentTypes: [],
};

const contentBundleIsEmpty = (value: ContentBundle) =>
  value.blocks.length === 0;

const normalizeContentBundle = (value: unknown): ContentBundle => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return emptyContentBundle;
  }
  const record = value as Record<string, unknown>;
  return {
    blocks: normalizeAdminContentBlocks(record.blocks),
    contentTypes: normalizeAdminContentTypes(record.contentTypes).filter(
      (type) => type.isActive,
    ),
  };
};

const contentStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading CMS content blocks",
    detail: "Waiting for the first authenticated content snapshot.",
  },
  ready: {
    label: "CMS content blocks confirmed",
    detail: "Approved content placements are current for this workspace.",
  },
  empty: {
    label: "No CMS content blocks in this scope",
    detail: "Use the editor to create the first governed content block.",
  },
  error: {
    label: "CMS content blocks unavailable",
    detail: "Confirmed blocks remain visible. Retry when service recovers.",
  },
  offline: {
    label: "CMS content workspace is offline",
    detail: "Confirmed blocks remain visible until connection returns.",
  },
  permission_denied: {
    label: "CMS content access denied",
    detail: "Previously loaded content and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing CMS content blocks",
    detail: "Confirmed blocks remain visible during refresh.",
  },
  conflict: {
    label: "CMS content records changed",
    detail: "Refresh before editing or deleting a content block.",
  },
  security_timeout: {
    label: "CMS content request timed out",
    detail: "No content operation or change was confirmed.",
  },
};

export default function AdminContentBlocksPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState<ContentForm>(emptyForm);
  const [filterType, setFilterType] = useState("");
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadContent = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) {
        return emptyContentBundle;
      }
      const [blocks, contentTypes] = await Promise.all([
        getAdminContentBlocks(client, access, { signal }),
        getAdminContentTypes(client, access, { signal }),
      ]);
      return { blocks, contentTypes };
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setForm(emptyForm);
    setFilterType("");
    setInteraction("idle");
  }, []);

  const {
    data,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptyContentBundle,
    isEmpty: contentBundleIsEmpty,
    load: loadContent,
    normalize: normalizeContentBundle,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "CMS content blocks",
  });

  const filtered = filterType
    ? data.blocks.filter((block) => block.contentType === filterType)
    : data.blocks;
  const blockCollection = useAdminCollection({
    records: filtered,
    getId: (block) => block.id,
    getSearchValues: (block) => [
      block.title,
      block.subtitle,
      block.body,
      block.contentType,
      block.distribution,
      block.ctaLabel,
      block.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      block,
      key: "title" | "type" | "distribution" | "status" | "order",
    ) => {
      switch (key) {
        case "title":
          return block.title;
        case "type":
          return block.contentType;
        case "distribution":
          return block.distribution;
        case "status":
          return block.isActive;
        case "order":
          return block.sortOrder;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 25,
  });

  const formContentTypes = data.contentTypes.some(
    (type) => type.contentType === form.contentType,
  )
    ? data.contentTypes
    : [
        ...data.contentTypes,
        {
          contentType: form.contentType,
          label: form.contentType.replace(/_/g, " "),
          description: null,
          defaultDistribution: "both" as const,
          sortOrder: 0,
          isActive: true,
        },
      ];

  const mutationLocked = status !== "ready" && status !== "empty";

  function beginEdit(block: CmsContent) {
    setForm({
      id: block.id,
      expectedUpdatedAt: block.updatedAt ?? "",
      contentType: block.contentType,
      title: block.title,
      subtitle: block.subtitle,
      body: block.body,
      rationale: block.rationale,
      iconEmoji: block.iconEmoji,
      ctaAction: block.ctaAction,
      ctaLabel: block.ctaLabel,
      sortOrder: block.sortOrder,
      isActive: block.isActive,
      distribution: block.distribution,
    });
    setInteraction("selected");
    showAdminToast(`Editing "${block.title}".`, "info");
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (client == null) return;

    showAdminToast(
      form.id ? "Saving content block..." : "Creating content block...",
      "info",
    );
    try {
      await saveAdminContentBlock(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
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
        distribution: form.distribution,
      });
      setForm(emptyForm);
      setInteraction("idle");
      await refresh();
      showAdminToast("Content block saved.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? contentStatusCopy.conflict.label
          : "Could not confirm the content change.",
        "error",
      );
    }
  }

  async function remove(block: CmsContent) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: block.title || block.contentType,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact:
          "The content block will be removed from its governed placement.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminContentBlock(
        client,
        access,
        block.id,
        block.updatedAt ?? "",
      );
      await refresh();
      showAdminToast(`Removed "${block.title}".`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? contentStatusCopy.conflict.label
          : "Could not confirm content deletion.",
        "error",
      );
    }
  }

  return (
    <section
      className="admin-cms-content-state-surface section-grid"
      data-admin-cms-content-status={status}
      data-admin-cms-content-interaction={interaction}
      data-admin-cms-content-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader eyebrow="CMS" title="Content blocks" />

      <AdminResourceStatusBanner
        status={status}
        label={contentStatusCopy[status].label}
        detail={contentStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh CMS content"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-cms-content-status"
      />

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={contentStatusCopy[status].label}
          description={contentStatusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <div className="grid grid-cols-[repeat(auto-fit,minmax(min(100%,34rem),1fr))] gap-5">
          <form
            onSubmit={submit}
            className="glass-panel grid min-w-0 gap-4 rounded-[28px] p-6"
          >
            <fieldset disabled={mutationLocked} className="contents">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <h2 className="font-display text-3xl font-medium normal-case leading-none text-[var(--admin-text-strong)]">
                  {form.id ? "Edit content block" : "New content block"}
                </h2>
                {form.id ? (
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
                  Content type
                  <select
                    value={form.contentType}
                    onChange={(event) =>
                      setForm({ ...form, contentType: event.target.value })
                    }
                    className="admin-input"
                  >
                    {formContentTypes.map((type) => (
                      <option key={type.contentType} value={type.contentType}>
                        {type.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Title
                  <input
                    value={form.title}
                    onChange={(event) =>
                      setForm({ ...form, title: event.target.value })
                    }
                    required
                    maxLength={200}
                    className="admin-input"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Distribution
                  <select
                    value={form.distribution}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        distribution: event.target
                          .value as CmsContent["distribution"],
                      })
                    }
                    className="admin-input"
                  >
                    <option value="both">Both web and app</option>
                    <option value="web">Website only</option>
                    <option value="app">Mobile app only</option>
                  </select>
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Icon emoji
                  <input
                    value={form.iconEmoji}
                    onChange={(event) =>
                      setForm({ ...form, iconEmoji: event.target.value })
                    }
                    maxLength={32}
                    className="admin-input"
                    placeholder="Optional"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)] sm:col-span-2">
                  Subtitle
                  <input
                    value={form.subtitle}
                    onChange={(event) =>
                      setForm({ ...form, subtitle: event.target.value })
                    }
                    maxLength={400}
                    className="admin-input"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)] sm:col-span-2">
                  Body
                  <textarea
                    value={form.body}
                    onChange={(event) =>
                      setForm({ ...form, body: event.target.value })
                    }
                    rows={5}
                    maxLength={12_000}
                    className="admin-input min-h-32"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)] sm:col-span-2">
                  Editorial rationale
                  <textarea
                    value={form.rationale}
                    onChange={(event) =>
                      setForm({ ...form, rationale: event.target.value })
                    }
                    rows={3}
                    maxLength={1_000}
                    className="admin-input min-h-24"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  CTA label
                  <input
                    value={form.ctaLabel}
                    onChange={(event) =>
                      setForm({ ...form, ctaLabel: event.target.value })
                    }
                    maxLength={80}
                    className="admin-input"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  CTA action or route
                  <input
                    value={form.ctaAction}
                    onChange={(event) =>
                      setForm({ ...form, ctaAction: event.target.value })
                    }
                    maxLength={512}
                    className="admin-input"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Sort order
                  <input
                    type="number"
                    min={-10_000}
                    max={10_000}
                    value={form.sortOrder}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        sortOrder: Number(event.target.value),
                      })
                    }
                    className="admin-input"
                  />
                </label>
                <label className="flex min-h-12 items-center gap-3 self-end text-sm text-[var(--admin-text-strong)]">
                  <input
                    type="checkbox"
                    checked={form.isActive}
                    onChange={(event) =>
                      setForm({ ...form, isActive: event.target.checked })
                    }
                    className="h-5 w-5 rounded accent-action-neutral"
                  />
                  Active placement
                </label>
              </div>

              <button
                type="submit"
                className="min-h-12 rounded-full bg-action-blue px-5 py-3 text-sm font-semibold text-white transition hover:bg-action-blue-hover disabled:cursor-not-allowed disabled:opacity-70"
              >
                <Plus size={16} className="mr-1 inline" aria-hidden="true" />
                {form.id ? "Update" : "Add"} content block
              </button>
            </fieldset>
          </form>

          <div className="glass-panel min-w-0 rounded-[28px] p-6">
            <AdminFilterBar
              actions={
                <div className="flex flex-wrap gap-2">
                  {(
                    [
                      "order",
                      "title",
                      "type",
                      "distribution",
                      "status",
                    ] as const
                  ).map((key) => (
                    <button
                      key={key}
                      type="button"
                      data-active={blockCollection.sortKey === key}
                      onClick={() => blockCollection.toggleSort(key)}
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
                <span className="sr-only">Search CMS content blocks</span>
                <input
                  type="search"
                  value={blockCollection.query}
                  onChange={(event) =>
                    blockCollection.setQuery(event.target.value)
                  }
                  placeholder="Search title, copy, type, distribution, or state"
                />
              </label>
            </AdminFilterBar>

            <div className="mb-4 flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => setFilterType("")}
                aria-pressed={!filterType}
                className="dashboard-chip min-h-12"
              >
                All types
              </button>
              {data.contentTypes.map((type) => (
                <button
                  key={type.contentType}
                  type="button"
                  onClick={() => setFilterType(type.contentType)}
                  aria-pressed={filterType === type.contentType}
                  className="dashboard-chip min-h-12"
                >
                  {type.label}
                </button>
              ))}
            </div>

            {initialLoading ? (
              <p className="text-sm text-[var(--admin-text-muted)]">
                Loading content…
              </p>
            ) : blockCollection.pageResult.items.length === 0 ? (
              <p className="text-sm text-[var(--admin-text-muted)]">
                {blockCollection.query || filterType
                  ? "No content blocks match the current filters."
                  : "No content blocks. Add one using the editor."}
              </p>
            ) : (
              <div className="grid gap-3">
                {blockCollection.pageResult.items.map((block) => (
                  <article
                    key={block.id}
                    data-row-id={block.id}
                    data-selected={form.id === block.id || undefined}
                    className={cn(
                      "rounded-[20px] border bg-[var(--admin-surface-muted)] p-4",
                      form.id === block.id
                        ? "border-[var(--admin-accent)]"
                        : "border-border-soft",
                    )}
                  >
                    <div className="flex flex-wrap items-start justify-between gap-4">
                      <div className="min-w-0 flex-1">
                        <div className="mb-1 flex flex-wrap items-center gap-2">
                          {block.isActive ? (
                            <Eye
                              size={16}
                              className="text-[var(--admin-text-strong)]"
                              aria-label="Active"
                            />
                          ) : (
                            <EyeOff
                              size={16}
                              className="text-[var(--admin-text-muted)]"
                              aria-label="Inactive"
                            />
                          )}
                          <span className="rounded-full border border-border-soft px-2 py-1 text-xs font-semibold normal-case tracking-normal text-[var(--admin-text-strong)]">
                            {block.contentType.replace(/_/g, " ")}
                          </span>
                          <span className="rounded-full border border-border-soft px-2 py-1 text-xs font-medium normal-case tracking-normal text-[var(--admin-text-strong)]">
                            {block.distribution}
                          </span>
                        </div>
                        <h3 className="break-words font-semibold text-[var(--admin-text-strong)]">
                          {block.title}
                        </h3>
                        <p className="mt-1 line-clamp-3 break-words text-xs text-[var(--admin-text-muted)]">
                          {block.body || "No body copy"}
                        </p>
                      </div>
                      <div className="flex shrink-0 gap-2">
                        <button
                          type="button"
                          onClick={() => beginEdit(block)}
                          disabled={mutationLocked}
                          aria-label={`Edit content block ${block.title}`}
                          className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-border-soft p-3 text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed disabled:opacity-70"
                        >
                          <Edit3 size={16} aria-hidden="true" />
                        </button>
                        <button
                          type="button"
                          onClick={() => void remove(block)}
                          disabled={mutationLocked}
                          aria-label={`Delete content block ${block.title}`}
                          className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-error/40 p-3 text-error transition hover:bg-error/10 disabled:cursor-not-allowed disabled:opacity-70"
                        >
                          <Trash2 size={16} aria-hidden="true" />
                        </button>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            )}

            <AdminPagination
              page={blockCollection.pageResult}
              onPageChange={blockCollection.setPage}
              label="CMS content blocks"
            />
          </div>
        </div>
      )}
    </section>
  );
}
