"use client";

import { useCallback, useState } from "react";
import { Edit3, Layout, Plus, Search, Trash2 } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminContentBlock,
  getAdminContentBlocks,
  normalizeAdminContentBlockFeatureOptions,
  normalizeAdminContentBlocks,
  saveAdminContentBlock,
  type AdminContentBlockFeatureOption,
} from "@/lib/data/admin/content-blocks";
import { getAdminFeatures } from "@/lib/data/admin/features";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { ContentBlock } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";

type ContentBlockBundle = {
  blocks: ContentBlock[];
  features: AdminContentBlockFeatureOption[];
};

type ContentBlockForm = {
  id: string;
  updatedAt: string;
  blockKey: string;
  blockType: string;
  targetChannel: ContentBlock["targetChannel"];
  placementKey: string;
  title: string;
  subtitle: string;
  featureId: string;
  isActive: boolean;
  sortOrder: number;
  contentJson: string;
  metadataJson: string;
};

const emptyBundle: ContentBlockBundle = { blocks: [], features: [] };
const bundleIsEmpty = (value: ContentBlockBundle) => value.blocks.length === 0;

const emptyForm: ContentBlockForm = {
  id: "",
  updatedAt: "",
  blockKey: "",
  blockType: "section",
  targetChannel: "both",
  placementKey: "home_mid",
  title: "",
  subtitle: "",
  featureId: "",
  isActive: true,
  sortOrder: 0,
  contentJson: "{}",
  metadataJson: "{}",
};

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading placement blocks",
    detail: "Waiting for the first authenticated composition snapshot.",
  },
  ready: {
    label: "Placement blocks confirmed",
    detail: "Governed UI composition is current for this workspace.",
  },
  empty: {
    label: "No placement blocks in this scope",
    detail: "Create the first governed placement block when authorized.",
  },
  error: {
    label: "Placement blocks unavailable",
    detail: "Confirmed blocks remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Placement workspace is offline",
    detail: "Confirmed blocks remain visible until connection returns.",
  },
  permission_denied: {
    label: "Placement access denied",
    detail:
      "Previously loaded blocks, filters, and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing placement blocks",
    detail: "Confirmed blocks remain visible during refresh.",
  },
  conflict: {
    label: "Placement records changed",
    detail: "Refresh before editing or deleting a placement block.",
  },
  security_timeout: {
    label: "Placement request timed out",
    detail: "No placement operation or change was confirmed.",
  },
};

function normalizeBundle(value: unknown): ContentBlockBundle {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return emptyBundle;
  }
  const record = value as Record<string, unknown>;
  return {
    blocks: normalizeAdminContentBlocks(record.blocks),
    features: normalizeAdminContentBlockFeatureOptions(record.features),
  };
}

function parseJsonObject(value: string) {
  const parsed = JSON.parse(value) as unknown;
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Expected a JSON object.");
  }
  return parsed as Record<string, unknown>;
}

function formatJson(value: Record<string, unknown>) {
  return JSON.stringify(value, null, 2);
}

export default function AdminContentBlocksPage() {
  const { access, client } = useAdminPortal();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [form, setForm] = useState<ContentBlockForm>(emptyForm);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadBundle = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyBundle;
      const [blocks, features] = await Promise.all([
        getAdminContentBlocks(client, access, { signal }),
        getAdminFeatures(client, access, { signal }),
      ]);
      return { blocks, features };
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setDrawerOpen(false);
    setForm(emptyForm);
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
    emptyValue: emptyBundle,
    isEmpty: bundleIsEmpty,
    load: loadBundle,
    normalize: normalizeBundle,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "placement blocks",
  });

  const blockCollection = useAdminCollection({
    records: data.blocks,
    getId: (block) => String(block.id),
    getSearchValues: (block) => [
      block.title,
      block.subtitle,
      block.blockKey,
      block.blockType,
      block.placementKey,
      block.targetChannel,
      block.isActive ? "active" : "disabled",
      data.features.find((feature) => feature.id === block.featureId)
        ?.displayName,
    ],
    getSortValue: (
      block,
      key: "block" | "placement" | "channel" | "status" | "order",
    ) => {
      switch (key) {
        case "block":
          return block.title || block.blockKey;
        case "placement":
          return block.placementKey;
        case "channel":
          return block.targetChannel;
        case "status":
          return block.isActive;
        case "order":
          return block.sortOrder ?? 0;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 25,
  });

  const mutationLocked = status !== "ready" && status !== "empty";

  function beginCreate() {
    setForm(emptyForm);
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function beginEdit(block: ContentBlock) {
    setForm({
      id: block.id ?? "",
      updatedAt: block.updatedAt ?? "",
      blockKey: block.blockKey,
      blockType: block.blockType,
      targetChannel: block.targetChannel,
      placementKey: block.placementKey,
      title: block.title ?? "",
      subtitle: block.subtitle ?? "",
      featureId: block.featureId ?? "",
      isActive: block.isActive,
      sortOrder: block.sortOrder ?? 0,
      contentJson: formatJson(block.content),
      metadataJson: formatJson(block.metadata),
    });
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function closeDrawer() {
    setDrawerOpen(false);
    setForm(emptyForm);
    setInteraction("idle");
  }

  async function handleSave(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (client == null) return;

    let content: Record<string, unknown>;
    let metadata: Record<string, unknown>;
    try {
      content = parseJsonObject(form.contentJson);
      metadata = parseJsonObject(form.metadataJson);
    } catch {
      showAdminToast(
        "Content and metadata must each be a valid JSON object.",
        "error",
      );
      return;
    }

    try {
      await saveAdminContentBlock(client, access, {
        id: form.id || undefined,
        updatedAt: form.updatedAt || undefined,
        blockKey: form.blockKey,
        blockType: form.blockType,
        title: form.title || null,
        subtitle: form.subtitle || null,
        content,
        targetChannel: form.targetChannel,
        placementKey: form.placementKey,
        featureId: form.featureId || null,
        isActive: form.isActive,
        sortOrder: form.sortOrder,
        metadata,
      });
      closeDrawer();
      await refresh();
      showAdminToast("Placement block saved.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? statusCopy.conflict.label
          : "Could not confirm the placement change.",
        "error",
      );
    }
  }

  async function handleDelete(block: ContentBlock) {
    if (
      client == null ||
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: block.title || block.blockKey,
        scope: access.isSuperAdmin
          ? "Selected platform or club content scope"
          : `Active club ${access.clubId ?? "not selected"}`,
        impact:
          "The governed placement will be removed or disabled for the active club.",
        undo: "manual_recovery",
      })
    ) {
      return;
    }

    try {
      await deleteAdminContentBlock(
        client,
        access,
        block.id ?? "",
        block.updatedAt ?? "",
      );
      await refresh();
      showAdminToast("Placement block deleted.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? statusCopy.conflict.label
          : "Could not confirm placement deletion.",
        "error",
      );
    }
  }

  return (
    <section
      className="admin-cms-content-blocks-state-surface section-grid"
      data-admin-cms-content-blocks-status={status}
      data-admin-cms-content-blocks-interaction={interaction}
      data-admin-cms-content-blocks-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="CMS"
        title="Placements & blocks"
        meta={
          <span className="admin-meta-chip">
            <Layout size={12} className="mr-1 inline" aria-hidden="true" />
            UI composition
          </span>
        }
        actions={
          <button
            type="button"
            onClick={beginCreate}
            disabled={mutationLocked}
            className="admin-action-button min-h-12 !bg-action-blue !text-white hover:!bg-action-blue-hover disabled:opacity-70"
          >
            <Plus size={16} aria-hidden="true" /> New block
          </button>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh placement blocks"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-cms-content-blocks-status"
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="Total blocks"
          value={initialLoading ? "…" : String(data.blocks.length)}
          icon={Layout}
        />
        <AdminStateCard
          label="Active"
          value={
            initialLoading
              ? "…"
              : String(data.blocks.filter((block) => block.isActive).length)
          }
          tone="success"
        />
        <AdminStateCard
          label="Placements"
          value={
            initialLoading
              ? "…"
              : String(
                  new Set(data.blocks.map((block) => block.placementKey)).size,
                )
          }
          tone="info"
        />
      </div>

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <div className="admin-surface min-w-0">
          <AdminFilterBar
            actions={
              <div className="flex flex-wrap gap-2">
                {(
                  ["order", "block", "placement", "channel", "status"] as const
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
              <span className="sr-only">Search placement blocks</span>
              <input
                type="search"
                value={blockCollection.query}
                onChange={(event) =>
                  blockCollection.setQuery(event.target.value)
                }
                placeholder="Search block, placement, channel, state, or feature"
              />
            </label>
          </AdminFilterBar>

          <AdminDataGrid
            caption="Content placement blocks"
            busy={busy}
            onRowActivate={(rowId) => {
              const block = data.blocks.find(
                (item) => String(item.id) === rowId,
              );
              if (block && !mutationLocked) beginEdit(block);
            }}
            columns={[
              {
                key: "block",
                label: "Block / type",
                priority: "primary",
              },
              {
                key: "placement",
                label: "Placement",
                priority: "primary",
              },
              {
                key: "channel",
                label: "Channel",
                priority: "secondary",
              },
              {
                key: "feature",
                label: "Linked feature",
                priority: "secondary",
              },
              { key: "status", label: "State", priority: "primary" },
              {
                key: "actions",
                label: "Actions",
                priority: "primary",
                className: "text-right",
              },
            ]}
          >
            {blockCollection.pageResult.items.length === 0 ? (
              <tr>
                <td
                  colSpan={6}
                  className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                >
                  {blockCollection.query
                    ? "No placement blocks match the current search."
                    : "No placement blocks in this scope."}
                </td>
              </tr>
            ) : (
              blockCollection.pageResult.items.map((block) => {
                const linkedFeature = data.features.find(
                  (feature) => feature.id === block.featureId,
                );
                return (
                  <tr
                    key={block.id}
                    data-row-id={String(block.id)}
                    data-selected={form.id === block.id || undefined}
                  >
                    <td>
                      <p className="admin-row-title">
                        {block.title || block.blockKey}
                      </p>
                      <p className="admin-row-meta">{block.blockType}</p>
                    </td>
                    <td>
                      <code className="break-all rounded bg-[var(--admin-surface-muted)] px-1.5 py-0.5 font-mono text-xs">
                        {block.placementKey}
                      </code>
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={block.targetChannel}
                        tone="neutral"
                      />
                    </td>
                    <td>
                      <span className="text-xs text-[var(--admin-text-muted)]">
                        {linkedFeature?.displayName ?? "Always show"}
                      </span>
                    </td>
                    <td>
                      <AdminStatusBadge
                        label={block.isActive ? "Active" : "Disabled"}
                        tone={block.isActive ? "success" : "danger"}
                      />
                    </td>
                    <td className="text-right">
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => beginEdit(block)}
                          disabled={mutationLocked}
                          aria-label={`Edit placement block ${
                            block.title || block.blockKey
                          }`}
                          className="admin-action-button min-h-12 min-w-12"
                        >
                          <Edit3 size={16} aria-hidden="true" />
                        </button>
                        <button
                          type="button"
                          onClick={() => void handleDelete(block)}
                          disabled={mutationLocked}
                          aria-label={`Delete placement block ${
                            block.title || block.blockKey
                          }`}
                          className="admin-action-button admin-action-button-danger min-h-12 min-w-12"
                        >
                          <Trash2 size={16} aria-hidden="true" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </AdminDataGrid>
          <AdminPagination
            page={blockCollection.pageResult}
            onPageChange={blockCollection.setPage}
            label="Placement blocks"
          />
        </div>
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={closeDrawer}
        title={form.id ? `Edit block: ${form.blockKey}` : "New content block"}
      >
        <form onSubmit={handleSave} className="space-y-6 p-4">
          <fieldset disabled={mutationLocked} className="contents">
            <div className="grid gap-4">
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Block key
                <input
                  required
                  maxLength={120}
                  value={form.blockKey}
                  onChange={(event) =>
                    setForm({ ...form, blockKey: event.target.value })
                  }
                  className="admin-input"
                  placeholder="home_hero_banner"
                />
              </label>
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                  Block type
                  <select
                    value={form.blockType}
                    onChange={(event) =>
                      setForm({ ...form, blockType: event.target.value })
                    }
                    className="admin-input"
                  >
                    <option value="section">Section</option>
                    <option value="banner">Banner</option>
                    <option value="action">Quick action</option>
                    <option value="html">HTML / raw</option>
                  </select>
                </label>
                <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                  Target channel
                  <select
                    value={form.targetChannel}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        targetChannel: event.target
                          .value as ContentBlock["targetChannel"],
                      })
                    }
                    className="admin-input"
                  >
                    <option value="both">Both</option>
                    <option value="web">Web only</option>
                    <option value="mobile">Mobile only</option>
                  </select>
                </label>
              </div>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Placement key
                <input
                  required
                  maxLength={120}
                  value={form.placementKey}
                  onChange={(event) =>
                    setForm({ ...form, placementKey: event.target.value })
                  }
                  className="admin-input"
                  placeholder="home_top, home_mid, sidebar"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Title
                <input
                  maxLength={160}
                  value={form.title}
                  onChange={(event) =>
                    setForm({ ...form, title: event.target.value })
                  }
                  className="admin-input"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Subtitle
                <input
                  maxLength={300}
                  value={form.subtitle}
                  onChange={(event) =>
                    setForm({ ...form, subtitle: event.target.value })
                  }
                  className="admin-input"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Linked feature
                <select
                  value={form.featureId}
                  onChange={(event) =>
                    setForm({ ...form, featureId: event.target.value })
                  }
                  className="admin-input"
                >
                  <option value="">None (always show)</option>
                  {data.features.map((feature) => (
                    <option key={feature.id} value={feature.id}>
                      {feature.displayName}
                    </option>
                  ))}
                </select>
              </label>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Content JSON
                <textarea
                  required
                  rows={7}
                  maxLength={12_000}
                  value={form.contentJson}
                  onChange={(event) =>
                    setForm({ ...form, contentJson: event.target.value })
                  }
                  className="admin-input min-h-40 font-mono text-xs"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                Metadata JSON
                <textarea
                  required
                  rows={4}
                  maxLength={4_000}
                  value={form.metadataJson}
                  onChange={(event) =>
                    setForm({ ...form, metadataJson: event.target.value })
                  }
                  className="admin-input min-h-28 font-mono text-xs"
                />
              </label>
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="flex min-h-12 items-center gap-3 text-sm font-semibold text-[var(--admin-text-strong)]">
                  <input
                    type="checkbox"
                    checked={form.isActive}
                    onChange={(event) =>
                      setForm({ ...form, isActive: event.target.checked })
                    }
                    className="h-5 w-5 accent-action-neutral"
                  />
                  Active placement
                </label>
                <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
                  Sort order
                  <input
                    type="number"
                    min={-100_000}
                    max={100_000}
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
              </div>
            </div>
            <div className="mt-6 flex flex-wrap gap-3 border-t border-[var(--admin-border)] pt-6">
              <button
                type="submit"
                className="admin-action-button min-h-12 flex-1 !bg-action-blue !text-white hover:!bg-action-blue-hover"
              >
                Save block
              </button>
              <button
                type="button"
                onClick={closeDrawer}
                className="admin-action-button min-h-12 flex-1"
              >
                Cancel
              </button>
            </div>
          </fieldset>
        </form>
      </AdminActionDrawer>
    </section>
  );
}
