"use client";

import { useCallback, useState, type FormEvent } from "react";
import { Pencil, Search, ShoppingBag, Trash2 } from "lucide-react";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { cn, formatCurrency } from "@/lib/utils";
import {
  getAdminProducts,
  normalizeAdminShopProducts,
  saveAdminProduct,
  deleteAdminProduct,
} from "@/lib/data/admin/shop";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import type { AdminShopProduct } from "@/lib/types";
import { useHydrated } from "@/lib/use-hydrated";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";

const emptyForm = {
  id: "",
  expectedUpdatedAt: "",
  name: "",
  subtitle: "",
  description: "",
  category: "Merch",
  price: "",
  imageUrl: "",
  sizes: "S, M, L, XL",
  isActive: true,
  collection: "",
  sortOrder: "0",
};

const emptyProducts: AdminShopProduct[] = [];
const productsAreEmpty = (products: AdminShopProduct[]) =>
  products.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading shop catalogue",
    detail: "Waiting for the first authenticated, club-scoped snapshot.",
  },
  ready: {
    label: "Shop catalogue confirmed",
    detail: "The latest bounded product catalogue is ready for review.",
  },
  empty: {
    label: "No products in this club",
    detail: "The club catalogue is confirmed and ready for its first product.",
  },
  error: {
    label: "Shop catalogue unavailable",
    detail:
      "Confirmed products remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Shop catalogue is offline",
    detail: "Confirmed products remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "Shop access denied",
    detail:
      "Products, filters, pagination, and editor content were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing shop catalogue",
    detail: "Confirmed products remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Shop catalogue changed",
    detail: "Review the retained snapshot, then refresh before making changes.",
  },
  security_timeout: {
    label: "Shop request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained catalogue.",
  },
};

export default function AdminShopPage() {
  const { access, activeClub, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [form, setForm] = useState(emptyForm);
  const draft = useAdminMediaDraftScope(access, "shop_product");
  const [filter, setFilter] = useState("ALL");
  const [saving, setSaving] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const clearPrivateState = useCallback(() => {
    setForm(emptyForm);
    setFilter("ALL");
    setInteraction("idle");
  }, []);
  const loadProducts = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyProducts;
      return getAdminProducts(client, access, { signal });
    },
    [access, client],
  );
  const {
    data: products,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState<AdminShopProduct[]>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyProducts,
    isEmpty: productsAreEmpty,
    load: loadProducts,
    normalize: normalizeAdminShopProducts,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "shop catalogue",
  });

  const canEdit = access.isSuperAdmin || access.role === "club_admin";
  const mutationLocked =
    saving || busy || !canEdit || (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  async function beginEdit(product: AdminShopProduct) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    setForm({
      id: product.id,
      expectedUpdatedAt: product.updatedAt,
      name: product.name,
      subtitle: product.subtitle,
      description: product.description,
      category: product.category,
      price: String(product.price),
      imageUrl: product.imageUrl ?? "",
      sizes: product.sizes.join(", "),
      isActive: product.isActive,
      collection: product.collection ?? "",
      sortOrder: String(product.sortOrder),
    });
    showAdminToast(`Editing ${product.name}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    if (client == null || mutationLocked) return;
    setSaving(true);
    showAdminToast(
      form.id ? "Saving product..." : "Creating product...",
      "info",
    );
    try {
      await draft.runSave(() => saveAdminProduct(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        name: String(formData.get("name") ?? ""),
        subtitle: String(formData.get("subtitle") ?? ""),
        description: String(formData.get("description") ?? ""),
        category: String(formData.get("category") ?? "Merch"),
        price: Number(formData.get("price") ?? 0),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        sizes: String(formData.get("sizes") ?? "")
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean),
        isActive: formData.get("isActive") === "on",
        collection: String(formData.get("collection") ?? ""),
        sortOrder: Number(formData.get("sortOrder") ?? 0),
      }), form.id || undefined);
      if (!await draft.resetDraft(form.id || undefined)) { showAdminToast("Saved. Recover this composer before starting another draft.", "info"); return; }
      setForm(emptyForm);
      await refresh();
      showAdminToast("Product saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      const nextStatus = applyFailure(caught);
      showAdminToast(statusCopy[nextStatus].label, "error");
    } finally {
      setSaving(false);
    }
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    void submitForm(formData);
  }

  async function removeProduct(product: AdminShopProduct) {
    if (client == null || mutationLocked) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Remove",
        subject: product.name,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The product will be removed from the club catalogue.",
        undo: "not_available",
      })
    ) {
      return;
    }
    setSaving(true);
    try {
      await deleteAdminProduct(client, access, product.id, product.updatedAt);
      await refresh();
      showAdminToast(`${product.name} removed.`, "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      const nextStatus = applyFailure(caught);
      showAdminToast(statusCopy[nextStatus].label, "error");
    } finally {
      setSaving(false);
    }
  }

  const categories = Array.from(new Set(products.map((p) => p.category)));
  const filtered = products.filter(
    (p) => filter === "ALL" || p.category === filter,
  );
  const productCollection = useAdminCollection({
    records: filtered,
    getId: (product) => product.id,
    getSearchValues: (product) => [
      product.name,
      product.subtitle,
      product.description,
      product.category,
      product.collection,
      product.sizes.join(" "),
      product.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      product,
      key: "name" | "category" | "price" | "status" | "order",
    ) => {
      switch (key) {
        case "name":
          return product.name;
        case "category":
          return product.category;
        case "price":
          return product.price;
        case "status":
          return product.isActive;
        case "order":
          return product.sortOrder;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 20,
  });

  return (
    <div
      className="admin-shop-state-surface section-grid min-w-0 w-full max-w-full overflow-x-hidden"
      data-admin-shop-status={status}
      data-admin-shop-interaction={interaction}
    >
      <AdminPageHeader eyebrow="Retail" title="Shop" />
      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh catalogue"
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />
      <div className="admin-shop-metrics-grid grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Products"
          value={hasConfirmed ? products.length.toString() : "—"}
          helper={hasConfirmed ? "In catalogue." : "Awaiting confirmation."}
          icon={ShoppingBag}
        />
        <AdminStateCard
          label="Active"
          value={
            hasConfirmed
              ? products.filter((p) => p.isActive).length.toString()
              : "—"
          }
          helper={hasConfirmed ? "Visible in shop." : "Awaiting confirmation."}
        />
        <AdminStateCard
          label="Categories"
          value={hasConfirmed ? categories.length.toString() : "—"}
          helper={hasConfirmed ? "Product groups." : "Awaiting confirmation."}
        />
      </div>
      {initialLoading ? (
        <div
          className="grid gap-5 xl:grid-cols-2"
          role="group"
          aria-label="Loading shop workspace"
        >
          {Array.from({ length: 2 }).map((_, index) => (
            <div key={index} className="ui-panel rounded-[32px] p-6">
              <Skeleton className="skeleton-text h-7 w-2/5" />
              <Skeleton className="skeleton-text mt-5 h-52 w-full" />
            </div>
          ))}
        </div>
      ) : null}
      {!initialLoading && !unrecoveredFailure ? (
        <div
          className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]"
          data-admin-shop-state-surface
        >
          <form
            onSubmit={handleSubmit}
            className="ui-panel grid self-start content-start gap-4 rounded-[32px] p-6"
          >
            {draft.error ? <p role="alert">{draft.error}</p> : null}
            <fieldset disabled={mutationLocked} className="contents">
              <div className="flex items-center justify-between gap-3">
                <p className="font-display text-3xl font-medium normal-case leading-none">
                  {form.id ? "Edit product" : "New product"}
                </p>
                {form.id || draft.scopeKey ? (
                  <button
                    type="button"
                    onClick={async () => { if (await draft.resetDraft(form.id || undefined)) setForm(emptyForm); }}
                    className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
                  >
                    Clear
                  </button>
                ) : null}
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="grid gap-2 text-sm">
                  Name
                  <input
                    name="name"
                    required
                    value={form.name}
                    onChange={(e) =>
                      setForm((c) => ({ ...c, name: e.target.value }))
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Category
                  <input
                    name="category"
                    value={form.category}
                    onChange={(e) =>
                      setForm((c) => ({ ...c, category: e.target.value }))
                    }
                    className="dashboard-input"
                  />
                </label>
              </div>
              <label className="grid gap-2 text-sm">
                Subtitle
                <input
                  name="subtitle"
                  value={form.subtitle}
                  onChange={(e) =>
                    setForm((c) => ({ ...c, subtitle: e.target.value }))
                  }
                  className="dashboard-input"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Description
                <textarea
                  name="description"
                  rows={3}
                  value={form.description}
                  onChange={(e) =>
                    setForm((c) => ({ ...c, description: e.target.value }))
                  }
                  className="dashboard-input min-h-20 resize-y"
                />
              </label>
              <div className="grid gap-4 sm:grid-cols-3">
                <label className="grid gap-2 text-sm">
                  Price ({activeClub?.currencyCode ?? "USD"})
                  <input
                    type="number"
                    name="price"
                    value={form.price}
                    onChange={(e) =>
                      setForm((c) => ({ ...c, price: e.target.value }))
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Sort order
                  <input
                    type="number"
                    name="sortOrder"
                    value={form.sortOrder}
                    onChange={(e) =>
                      setForm((c) => ({ ...c, sortOrder: e.target.value }))
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Collection
                  <input
                    name="collection"
                    value={form.collection}
                    onChange={(e) =>
                      setForm((c) => ({ ...c, collection: e.target.value }))
                    }
                    className="dashboard-input"
                  />
                </label>
              </div>
              <label className="grid gap-2 text-sm">
                Sizes (comma separated)
                <input
                  name="sizes"
                  value={form.sizes}
                  onChange={(e) =>
                    setForm((c) => ({ ...c, sizes: e.target.value }))
                  }
                  className="dashboard-input"
                />
              </label>
              <AdminImageField
                scopeKey={form.id || draft.scopeKey || "unavailable"}
                  recoveryOnly={!form.id && draft.legacyUnbound}
                  onRecoveryResolved={draft.refreshRecovery}
                  disabled={!draft.ready && !draft.legacyUnbound}
                label="Product image"
                name="imageUrl"
                value={form.imageUrl}
                onChange={(nextValue) =>
                  setForm((current) => ({ ...current, imageUrl: nextValue }))
                }
                mediaKind="shop_product"
                subject={form.name}
                previewAlt="Product preview"
                promptPlaceholder="Example: Premium studio product shot of the new home jersey on a clean dark background, bold blue and white club colors, catalogue lighting."
              />
              <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
                <input
                  type="checkbox"
                  name="isActive"
                  checked={form.isActive}
                  onChange={(e) =>
                    setForm((c) => ({ ...c, isActive: e.target.checked }))
                  }
                />
                Active in shop
              </label>
              <button
                type="submit"
                disabled={mutationLocked}
                className="rounded-full bg-action-blue px-5 py-3 font-semibold text-white transition hover:bg-action-blue-hover disabled:opacity-60"
              >
                {saving ? "Saving…" : form.id ? "Save product" : "Add product"}
              </button>
            </fieldset>
          </form>
          <section className="ui-panel rounded-[32px] p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <p className="font-display text-3xl font-medium normal-case leading-none">
                Catalogue
              </p>
              <div className="flex flex-wrap gap-2">
                {["ALL", ...categories].map((item) => (
                  <button
                    key={item}
                    type="button"
                    data-active={filter === item}
                    onClick={() => setFilter(item)}
                    className="dashboard-chip"
                  >
                    {item}
                  </button>
                ))}
              </div>
            </div>
            <AdminFilterBar
              className="mt-5"
              actions={
                <div className="flex flex-wrap gap-2">
                  {(
                    ["order", "name", "category", "price", "status"] as const
                  ).map((key) => (
                    <button
                      key={key}
                      type="button"
                      data-active={productCollection.sortKey === key}
                      onClick={() => productCollection.toggleSort(key)}
                      className="dashboard-chip"
                    >
                      Sort {key}
                    </button>
                  ))}
                </div>
              }
            >
              <label className="admin-search-field">
                <Search size={16} aria-hidden="true" />
                <span className="sr-only">Search shop catalogue</span>
                <input
                  type="search"
                  value={productCollection.query}
                  onChange={(event) =>
                    productCollection.setQuery(event.target.value)
                  }
                  placeholder="Search product, category, collection, size, or state"
                />
              </label>
            </AdminFilterBar>
            <div className="mt-5 space-y-3">
              {productCollection.pageResult.items.length === 0 ? (
                <p className="rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-4 text-sm text-[var(--admin-text-muted)]">
                  {productCollection.query
                    ? "No products match the current search and category."
                    : "No products found."}
                </p>
              ) : null}
              {productCollection.pageResult.items.map((product) => (
                <article
                  key={product.id}
                  className={cn(
                    "card-interactive flex items-start gap-4 rounded-[26px] border border-border-soft p-5 transition",
                    product.isActive ? "bg-[var(--admin-surface-muted)]" : "bg-[var(--admin-surface-muted)]",
                  )}
                >
                  {product.imageUrl ? (
                    <div className="hidden sm:block h-16 w-16 flex-shrink-0 overflow-hidden rounded-xl border border-border-soft">
                      {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
                      <img
                        src={product.imageUrl}
                        alt=""
                        className="h-full w-full object-cover"
                      />
                    </div>
                  ) : null}
                  <div className="flex-1 min-w-0">
                    <p className="font-display text-2xl font-medium normal-case leading-none">
                      {product.name}
                    </p>
                    <p className="mt-1 truncate text-sm text-[var(--admin-text-muted)]">
                      {product.subtitle}
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      <AdminStatusBadge
                        label={product.isActive ? "Active" : "Inactive"}
                        tone={product.isActive ? "success" : "neutral"}
                      />
                      <span className="rounded-full bg-action-blue px-3 py-1.5 text-xs font-semibold normal-case tracking-normal text-white">
                        {formatCurrency(
                          product.price,
                          activeClub?.currencyCode,
                        )}
                      </span>
                      <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">
                        {product.category}
                      </span>
                      {product.sizes.map((s) => (
                        <span
                          key={s}
                          className="rounded-full border border-border-soft px-2 py-1 text-xs normal-case tracking-normal text-[var(--admin-text-muted)]"
                        >
                          {s}
                        </span>
                      ))}
                    </div>
                  </div>
                  <div className="flex flex-shrink-0 gap-2">
                    <button
                      type="button"
                      disabled={mutationLocked}
                      onClick={() => beginEdit(product)}
                      className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-border-soft text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed disabled:opacity-60"
                      aria-label={`Edit ${product.name}`}
                    >
                      <Pencil size={16} aria-hidden="true" />
                    </button>
                    <button
                      type="button"
                      disabled={mutationLocked}
                      onClick={() => {
                        removeProduct(product).catch(() => {});
                      }}
                      className="inline-flex min-h-12 min-w-12 items-center justify-center rounded-full border border-border-soft text-[var(--admin-text-strong)] transition hover:bg-error/15 hover:border-error/30 hover:text-error disabled:cursor-not-allowed disabled:opacity-60"
                      aria-label={`Remove ${product.name}`}
                    >
                      <Trash2 size={16} aria-hidden="true" />
                    </button>
                  </div>
                </article>
              ))}
            </div>
            <AdminPagination
              page={productCollection.pageResult}
              onPageChange={productCollection.setPage}
              label="Shop catalogue"
            />
          </section>
        </div>
      ) : null}
    </div>
  );
}
