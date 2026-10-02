"use client";

import { useCallback, useState } from "react";
import { Edit3, Eye, EyeOff, Plus, Search, Trash2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { showAdminToast } from "@/components/admin/admin-toast";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminBanner,
  getAdminBanners,
  normalizeAdminBanners,
  saveAdminBanner,
} from "@/lib/data/admin/cms-content";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { HomeBanner } from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { cn } from "@/lib/utils";

type BannerForm = {
  id: string;
  expectedUpdatedAt: string;
  title: string;
  subtitle: string;
  badgeLabel: string;
  ctaLabel: string;
  route: string;
  imageUrl: string;
  sortOrder: number;
  isActive: boolean;
  distribution: HomeBanner["distribution"];
};

const emptyForm: BannerForm = {
  id: "",
  expectedUpdatedAt: "",
  title: "",
  subtitle: "",
  badgeLabel: "",
  ctaLabel: "",
  route: "/",
  imageUrl: "",
  sortOrder: 0,
  isActive: true,
  distribution: "both",
};

const emptyBanners: HomeBanner[] = [];
const bannersAreEmpty = (banners: HomeBanner[]) => banners.length === 0;

const bannerStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading home banners",
    detail: "Waiting for the first authenticated banner snapshot.",
  },
  ready: {
    label: "Home banners confirmed",
    detail: "Banner order, distribution, and publication state are current.",
  },
  empty: {
    label: "No home banners in this scope",
    detail: "Use the editor to create the first controlled home banner.",
  },
  error: {
    label: "Home banners unavailable",
    detail: "Confirmed banners remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Banner workspace is offline",
    detail: "Confirmed banners remain visible until connection returns.",
  },
  permission_denied: {
    label: "Banner access denied",
    detail: "Previously loaded banner data and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing home banners",
    detail: "Confirmed banners remain visible during refresh.",
  },
  conflict: {
    label: "Banner records changed",
    detail: "Refresh before editing, publishing, reordering, or deleting.",
  },
  security_timeout: {
    label: "Banner request timed out",
    detail: "No banner operation or change was confirmed.",
  },
};

export default function AdminBannersPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState<BannerForm>(emptyForm);
  const draft = useAdminMediaDraftScope(access, "home_banner");
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadBanners = useCallback(
    (signal: AbortSignal) => {
      if (client == null) {
        return Promise.resolve([]);
      }
      return getAdminBanners(client, access, { signal });
    },
    [access, client],
  );
  const handlePermissionDenied = useCallback(() => {
    setForm(emptyForm);
    setInteraction("idle");
  }, []);

  const {
    data: banners,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptyBanners,
    isEmpty: bannersAreEmpty,
    load: loadBanners,
    normalize: normalizeAdminBanners,
    onPermissionDenied: handlePermissionDenied,
    resourceLabel: "Home banners",
  });

  const bannerCollection = useAdminCollection({
    records: banners,
    getId: (banner) => banner.id,
    getSearchValues: (banner) => [
      banner.title,
      banner.subtitle,
      banner.badgeLabel,
      banner.ctaLabel,
      banner.route,
      banner.distribution,
      banner.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      banner,
      key: "title" | "distribution" | "status" | "order",
    ) => {
      switch (key) {
        case "title":
          return banner.title;
        case "distribution":
          return banner.distribution;
        case "status":
          return banner.isActive;
        case "order":
          return banner.sortOrder;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 25,
  });

  async function beginEdit(banner: HomeBanner) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    setForm({
      id: banner.id,
      expectedUpdatedAt: banner.updatedAt ?? "",
      title: banner.title,
      subtitle: banner.subtitle,
      badgeLabel: banner.badgeLabel,
      ctaLabel: banner.ctaLabel,
      route: banner.route,
      imageUrl: banner.imageUrl ?? "",
      sortOrder: banner.sortOrder,
      isActive: banner.isActive,
      distribution: banner.distribution,
    });
    setInteraction("selected");
    showAdminToast(`Editing "${banner.title}".`, "info");
  }

  async function submit(event: React.FormEvent) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    event.preventDefault();
    if (client == null) return;

    showAdminToast(form.id ? "Saving banner..." : "Creating banner...", "info");
    try {
      await draft.runSave(() => saveAdminBanner(client, access, {
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
      }), form.id || undefined);
      if (!await draft.resetDraft(form.id || undefined)) { showAdminToast("Saved. Recover this composer before starting another draft.", "info"); return; }
      setForm(emptyForm);
      setInteraction("idle");
      await refresh();
      showAdminToast("Banner saved.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? bannerStatusCopy.conflict.label
          : "Could not confirm the banner change.",
        "error",
      );
    }
  }

  async function remove(banner: HomeBanner) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: banner.title,
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
      await refresh();
      showAdminToast(`Removed "${banner.title}".`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? bannerStatusCopy.conflict.label
          : "Could not confirm banner deletion.",
        "error",
      );
    }
  }

  const mutationLocked = status !== "ready" && status !== "empty";

  return (
    <section
      className="admin-cms-banners-state-surface section-grid"
      data-admin-cms-banners-status={status}
      data-admin-cms-banners-interaction={interaction}
      data-admin-cms-banners-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader eyebrow="CMS" title="Home banners" />

      <AdminResourceStatusBanner
        status={status}
        label={bannerStatusCopy[status].label}
        detail={bannerStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh home banners"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-cms-banners-status"
      />

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={bannerStatusCopy[status].label}
          description={bannerStatusCopy[status].detail}
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
            {draft.error ? <p role="alert">{draft.error}</p> : null}
            <fieldset disabled={mutationLocked} className="contents">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <p className="font-display text-3xl font-medium normal-case leading-none text-[var(--admin-text-strong)]">
                  {form.id ? "Edit banner" : "New banner"}
                </p>
                {form.id || draft.scopeKey ? (
                  <button
                    type="button"
                    onClick={() => {
                      void draft.resetDraft(form.id || undefined).then(ok => { if (ok) { setForm(emptyForm); setInteraction("idle"); } });
                    }}
                    className="min-h-12 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
                  >
                    {form.id ? "Cancel editing" : "Clear"}
                  </button>
                ) : null}
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
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
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Distribution
                  <select
                    value={form.distribution}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        distribution: event.target
                          .value as HomeBanner["distribution"],
                      })
                    }
                    className="admin-input"
                  >
                    <option value="both">Both (Web & App)</option>
                    <option value="web">Website only</option>
                    <option value="app">Mobile App only</option>
                  </select>
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Badge label
                  <input
                    value={form.badgeLabel}
                    onChange={(event) =>
                      setForm({ ...form, badgeLabel: event.target.value })
                    }
                    maxLength={40}
                    className="admin-input"
                    placeholder="e.g. NEW, PROMO"
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
                    placeholder="e.g. View details"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-text-strong)]">
                  Route
                  <input
                    value={form.route}
                    onChange={(event) =>
                      setForm({ ...form, route: event.target.value })
                    }
                    required
                    maxLength={512}
                    pattern="/(?!/).*"
                    className="admin-input"
                    placeholder="/tickets"
                  />
                </label>
                <AdminImageField
                  scopeKey={form.id || draft.scopeKey || "unavailable"}
                  recoveryOnly={!form.id && draft.legacyUnbound}
                  onRecoveryResolved={draft.refreshRecovery}
                  disabled={!draft.ready && !draft.legacyUnbound}
                  label="Banner image"
                  value={form.imageUrl}
                  onChange={(nextValue) =>
                    setForm({ ...form, imageUrl: nextValue })
                  }
                  mediaKind="home_banner"
                  subject={form.title}
                  previewAlt="Banner preview"
                  promptPlaceholder="Example: Homepage hero banner for an upcoming fixture or campaign, dramatic atmosphere, strong brand colors, clean focal point."
                  className="sm:col-span-2"
                />
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
                <label className="flex min-h-12 items-center gap-3 self-end rounded-[18px] border border-border-soft px-4 py-3 text-sm text-[var(--admin-text-strong)]">
                  <input
                    type="checkbox"
                    checked={form.isActive}
                    onChange={(event) =>
                      setForm({ ...form, isActive: event.target.checked })
                    }
                    className="h-5 w-5 rounded accent-action-neutral"
                  />
                  Active
                </label>
              </div>
              <button
                type="submit"
                className="min-h-12 rounded-full bg-action-blue px-5 py-3 text-sm font-semibold text-white transition hover:bg-action-blue-hover disabled:cursor-not-allowed disabled:opacity-70"
              >
                <Plus size={16} className="mr-1 inline" aria-hidden="true" />
                {form.id ? "Update" : "Add"} banner
              </button>
            </fieldset>
          </form>

          <div className="ui-panel min-w-0 rounded-[28px] p-6">
            <AdminFilterBar
              actions={
                <div className="flex flex-wrap gap-2">
                  {(["order", "title", "distribution", "status"] as const).map(
                    (key) => (
                      <button
                        key={key}
                        type="button"
                        data-active={bannerCollection.sortKey === key}
                        onClick={() => bannerCollection.toggleSort(key)}
                        className="dashboard-chip min-h-12"
                        aria-label={`Sort by ${key}`}
                      >
                        Sort {key}
                      </button>
                    ),
                  )}
                </div>
              }
            >
              <label className="admin-search-field min-h-12">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">Search home banners</span>
                <input
                  type="search"
                  value={bannerCollection.query}
                  onChange={(event) =>
                    bannerCollection.setQuery(event.target.value)
                  }
                  placeholder="Search banner, route, channel, or state"
                />
              </label>
            </AdminFilterBar>

            {initialLoading ? (
              <p className="text-sm text-[var(--admin-text-muted)]">
                Loading banners…
              </p>
            ) : bannerCollection.pageResult.items.length === 0 ? (
              <p className="text-sm text-[var(--admin-text-muted)]">
                {bannerCollection.query
                  ? "No banners match the current search."
                  : "No banners yet. Add one using the editor."}
              </p>
            ) : (
              <div className="grid gap-3">
                {bannerCollection.pageResult.items.map((banner) => (
                  <article
                    key={banner.id}
                    data-row-id={banner.id}
                    data-selected={form.id === banner.id || undefined}
                    className={cn(
                      "flex flex-wrap items-center justify-between gap-4 rounded-[20px] border bg-[var(--admin-surface-muted)] p-4",
                      form.id === banner.id
                        ? "border-[var(--admin-accent)]"
                        : "border-border-soft",
                    )}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="mb-1 flex flex-wrap items-center gap-2">
                        {banner.isActive ? (
                          <Eye
                            size={14}
                            className="text-success"
                            aria-hidden="true"
                          />
                        ) : (
                          <EyeOff
                            size={14}
                            className="text-[var(--admin-text-muted)]"
                            aria-hidden="true"
                          />
                        )}
                        <p className="break-words font-semibold text-[var(--admin-text-strong)]">
                          {banner.title}
                        </p>
                        <span className="rounded-full border border-border-soft px-2 py-1 text-xs font-medium normal-case tracking-normal text-[var(--admin-text-strong)]">
                          {banner.distribution}
                        </span>
                        {banner.badgeLabel ? (
                          <span className="rounded-full border border-[var(--admin-accent)]/40 bg-[var(--admin-accent)]/10 px-2 py-1 text-xs font-medium normal-case tracking-normal text-[var(--admin-text-strong)]">
                            {banner.badgeLabel}
                          </span>
                        ) : null}
                      </div>
                      <p className="break-words text-xs text-[var(--admin-text-muted)]">
                        {banner.subtitle || "No subtitle"} · {banner.route}
                      </p>
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <button
                        type="button"
                        onClick={() => beginEdit(banner)}
                        disabled={mutationLocked}
                        className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-border-soft p-3 text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed disabled:opacity-70"
                        aria-label={`Edit ${banner.title}`}
                      >
                        <Edit3 size={16} aria-hidden="true" />
                      </button>
                      <button
                        type="button"
                        onClick={() => void remove(banner)}
                        disabled={mutationLocked}
                        className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-error/40 p-3 text-error transition hover:bg-error/10 disabled:cursor-not-allowed disabled:opacity-70"
                        aria-label={`Delete ${banner.title}`}
                      >
                        <Trash2 size={16} aria-hidden="true" />
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            )}
            <AdminPagination
              page={bannerCollection.pageResult}
              onPageChange={bannerCollection.setPage}
              label="Home banners"
            />
          </div>
        </div>
      )}
    </section>
  );
}
