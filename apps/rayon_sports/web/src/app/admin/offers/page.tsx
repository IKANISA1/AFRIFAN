"use client";

import { useCallback, useState } from "react";
import { Gift, Pencil, Search, ShieldCheck, Star, Trash2 } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminOffer,
  getAdminOffers,
  normalizeAdminOffersWorkspace,
  saveAdminOffer,
  type AdminOfferVerificationMode,
  type AdminOffersWorkspace,
  type AdminPartnerOffer,
} from "@/lib/data/admin/offers";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { cn } from "@/lib/utils";

const emptyWorkspace: AdminOffersWorkspace = {
  offers: [],
  catalog: [],
  partners: [],
};

const verificationOptions: Array<{
  value: AdminOfferVerificationMode;
  label: string;
}> = [
  { value: "manual_review", label: "Manual review" },
  { value: "api_confirmation", label: "API confirmation" },
  { value: "renewal_confirmation", label: "Renewal confirmation" },
  { value: "referral_conversion", label: "Referral conversion" },
  { value: "receipt_scan", label: "Receipt scan" },
  { value: "geo_checkin", label: "Location check-in" },
  { value: "social_share", label: "Social share" },
  { value: "community_savings", label: "Community savings" },
  { value: "ecommerce_confirmation", label: "Commerce confirmation" },
  { value: "mobility_confirmation", label: "Mobility confirmation" },
  { value: "event_qr", label: "Event QR" },
];

type OfferForm = {
  id: string;
  expectedUpdatedAt: string;
  catalogItemId: string;
  partnerId: string;
  subtitle: string;
  ctaLabel: string;
  verificationMode: AdminOfferVerificationMode;
  deeplinkRoute: string;
  externalUrl: string;
  isFeatured: boolean;
  isActive: boolean;
  sortOrder: string;
};

const emptyForm: OfferForm = {
  id: "",
  expectedUpdatedAt: "",
  catalogItemId: "",
  partnerId: "",
  subtitle: "",
  ctaLabel: "View details",
  verificationMode: "manual_review",
  deeplinkRoute: "",
  externalUrl: "",
  isFeatured: false,
  isActive: true,
  sortOrder: "0",
};

const workspaceIsEmpty = (value: AdminOffersWorkspace) =>
  value.offers.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading partner-offer catalogue",
    detail: "Waiting for the first authenticated club-scoped snapshot.",
  },
  ready: {
    label: "Partner-offer catalogue confirmed",
    detail: "The bounded catalogue and its approved source options are current.",
  },
  empty: {
    label: "No partner offers in this scope",
    detail: "Create an offer only from a confirmed FET item and active partner.",
  },
  error: {
    label: "Partner-offer catalogue unavailable",
    detail: "Confirmed offers remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Partner-offer workspace is offline",
    detail: "Confirmed offers remain visible; catalogue changes are locked.",
  },
  permission_denied: {
    label: "Partner-offer access denied",
    detail: "Offers, options, filters, selection, and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing partner-offer catalogue",
    detail: "Confirmed offers remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Partner-offer catalogue changed",
    detail: "Review the refreshed offer before restarting the change.",
  },
  security_timeout: {
    label: "Partner-offer request timed out",
    detail: "No catalogue change was confirmed.",
  },
};

function offerToForm(offer: AdminPartnerOffer): OfferForm {
  return {
    id: offer.id,
    expectedUpdatedAt: offer.updatedAt,
    catalogItemId: offer.catalogItemId,
    partnerId: offer.partnerId,
    subtitle: offer.subtitle,
    ctaLabel: offer.ctaLabel,
    verificationMode: offer.verificationMode,
    deeplinkRoute: offer.deeplinkRoute ?? "",
    externalUrl: offer.externalUrl ?? "",
    isFeatured: offer.isFeatured,
    isActive: offer.isActive,
    sortOrder: offer.sortOrder.toString(),
  };
}

function OffersWorkspace({
  workspace,
  status,
  onStatusFailure,
  onRefresh,
  onInteractionChange,
}: {
  workspace: AdminOffersWorkspace;
  status: AdminResourceStatus;
  onStatusFailure: (error: unknown) => AdminResourceStatus;
  onRefresh: () => Promise<void>;
  onInteractionChange: (interaction: AdminResourceInteraction) => void;
}) {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState<OfferForm>(emptyForm);
  const [submitting, setSubmitting] = useState(false);
  const offerCollection = useAdminCollection({
    records: workspace.offers,
    getId: (offer) => offer.id,
    getSearchValues: (offer) => [
      offer.code,
      offer.title,
      offer.partnerName,
      offer.partnerCategory,
      offer.verificationMode,
      offer.isFeatured ? "featured" : "",
      offer.isActive ? "active" : "inactive",
    ],
    getSortValue: (
      offer,
      key: "title" | "partner" | "points" | "order" | "status",
    ) => {
      switch (key) {
        case "title":
          return offer.title;
        case "partner":
          return offer.partnerName;
        case "points":
          return offer.fetValue;
        case "order":
          return offer.sortOrder;
        case "status":
          return offer.isActive;
      }
    },
    initialSortKey: "order" as const,
    pageSize: 25,
  });

  const mutationLocked =
    submitting || (status !== "ready" && status !== "empty");
  const sourceOptionsAvailable =
    workspace.catalog.length > 0 && workspace.partners.length > 0;

  function selectOffer(offer: AdminPartnerOffer) {
    setForm(offerToForm(offer));
    onInteractionChange("selected");
    showAdminToast("Partner offer selected for review.", "info");
  }

  function clearForm() {
    setForm(emptyForm);
    onInteractionChange("idle");
  }

  async function submitOffer() {
    if (client == null || mutationLocked || !sourceOptionsAvailable) return;
    const sortOrder = Number(form.sortOrder);
    if (
      !form.catalogItemId ||
      !form.partnerId ||
      !form.ctaLabel.trim() ||
      !Number.isInteger(sortOrder) ||
      sortOrder < 0
    ) {
      showAdminToast(
        "Choose a FET item and partner, add an action label, and use a valid whole-number order.",
        "error",
      );
      return;
    }

    setSubmitting(true);
    showAdminToast(
      form.id ? "Saving partner offer..." : "Creating partner offer...",
      "info",
    );
    try {
      await saveAdminOffer(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        catalogItemId: form.catalogItemId,
        partnerId: form.partnerId,
        subtitle: form.subtitle,
        ctaLabel: form.ctaLabel,
        verificationMode: form.verificationMode,
        deeplinkRoute: form.deeplinkRoute || null,
        externalUrl: form.externalUrl || null,
        isFeatured: form.isFeatured,
        isActive: form.isActive,
        sortOrder,
      });
      await onRefresh();
      clearForm();
      showAdminToast("Partner offer saved.", "success");
    } catch (caught) {
      onStatusFailure(caught);
      if (isAdminMutationConflict(caught)) await onRefresh();
      showAdminToast("Could not confirm the partner-offer change.", "error");
    } finally {
      setSubmitting(false);
    }
  }

  async function removeOffer(offer: AdminPartnerOffer) {
    if (client == null || mutationLocked) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: offer.title,
        scope: `${offer.partnerName} · active club ${access.clubId ?? "not selected"}`,
        impact:
          "The linked offer will be permanently removed from supporter partner journeys.",
        undo: "not_available",
      })
    ) {
      return;
    }

    setSubmitting(true);
    showAdminToast("Removing partner offer...", "info");
    try {
      await deleteAdminOffer(client, access, offer.id, offer.updatedAt);
      await onRefresh();
      if (form.id === offer.id) clearForm();
      showAdminToast("Partner offer removed.", "success");
    } catch (caught) {
      onStatusFailure(caught);
      if (isAdminMutationConflict(caught)) await onRefresh();
      showAdminToast("Could not confirm partner-offer removal.", "error");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="admin-offers-content-grid">
      <AdminSurface
        title={form.id ? "Review partner offer" : "Create partner offer"}
      >
        <p className="text-sm leading-6 text-[var(--admin-zinc-400)]">
          Link one confirmed FET item to one active partner. Reward definitions
          remain governed in the FET catalogue.
        </p>
        {!sourceOptionsAvailable ? (
          <p className="admin-offers-source-warning" role="status">
            An active FET catalogue item and partner are required before an
            offer can be created.
          </p>
        ) : null}
        <form
          className="mt-5 grid min-w-0 gap-4"
          onSubmit={(event) => {
            event.preventDefault();
            void submitOffer();
          }}
        >
          <div className="grid min-w-0 gap-4 md:grid-cols-2">
            <label className="grid gap-2 text-sm font-semibold">
              FET catalogue item
              <select
                required
                value={form.catalogItemId}
                disabled={mutationLocked}
                onChange={(event) => {
                  setForm((current) => ({
                    ...current,
                    catalogItemId: event.target.value,
                  }));
                  onInteractionChange("selected");
                }}
                className="dashboard-input"
              >
                <option value="">Choose an approved FET item</option>
                {workspace.catalog.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.code} · {item.itemName} · {item.fetValue} pts
                  </option>
                ))}
              </select>
            </label>
            <label className="grid gap-2 text-sm font-semibold">
              Active partner
              <select
                required
                value={form.partnerId}
                disabled={mutationLocked}
                onChange={(event) => {
                  setForm((current) => ({
                    ...current,
                    partnerId: event.target.value,
                  }));
                  onInteractionChange("selected");
                }}
                className="dashboard-input"
              >
                <option value="">Choose an active partner</option>
                {workspace.partners.map((partner) => (
                  <option key={partner.id} value={partner.id}>
                    {partner.name} · {partner.category}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <label className="grid gap-2 text-sm font-semibold">
            Supporter-facing subtitle
            <textarea
              value={form.subtitle}
              maxLength={500}
              rows={3}
              disabled={mutationLocked}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  subtitle: event.target.value,
                }))
              }
              className="dashboard-input min-h-24 resize-y"
            />
          </label>

          <div className="grid min-w-0 gap-4 md:grid-cols-2">
            <label className="grid gap-2 text-sm font-semibold">
              Action label
              <input
                required
                value={form.ctaLabel}
                maxLength={80}
                disabled={mutationLocked}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    ctaLabel: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm font-semibold">
              Verification mode
              <select
                value={form.verificationMode}
                disabled={mutationLocked}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    verificationMode: event.target
                      .value as AdminOfferVerificationMode,
                  }))
                }
                className="dashboard-input"
              >
                {verificationOptions.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="grid min-w-0 gap-4 md:grid-cols-2">
            <label className="grid gap-2 text-sm font-semibold">
              Internal deep link
              <input
                value={form.deeplinkRoute}
                maxLength={512}
                placeholder="/predict?section=wallet"
                disabled={mutationLocked}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    deeplinkRoute: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm font-semibold">
              External HTTPS URL
              <input
                type="url"
                value={form.externalUrl}
                maxLength={2048}
                placeholder="https://partner.example/offer"
                disabled={mutationLocked}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    externalUrl: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="grid gap-2 text-sm font-semibold">
            Catalogue order
            <input
              type="number"
              min={0}
              max={1_000_000}
              step={1}
              value={form.sortOrder}
              disabled={mutationLocked}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  sortOrder: event.target.value,
                }))
              }
              className="dashboard-input"
            />
          </label>

          <div className="grid gap-3 sm:grid-cols-2">
            <label className="admin-offers-check">
              <input
                type="checkbox"
                checked={form.isFeatured}
                disabled={mutationLocked}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    isFeatured: event.target.checked,
                  }))
                }
              />
              Featured placement
            </label>
            <label className="admin-offers-check">
              <input
                type="checkbox"
                checked={form.isActive}
                disabled={mutationLocked}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    isActive: event.target.checked,
                  }))
                }
              />
              Active for supporters
            </label>
          </div>

          <div className="flex flex-wrap gap-3">
            <button
              type="submit"
              disabled={mutationLocked || !sourceOptionsAvailable}
              className="admin-offers-primary"
            >
              {submitting
                ? "Saving…"
                : form.id
                  ? "Save partner offer"
                  : "Create partner offer"}
            </button>
            {form.id ? (
              <button
                type="button"
                disabled={mutationLocked}
                onClick={clearForm}
                className="admin-offers-secondary"
              >
                Clear selection
              </button>
            ) : null}
          </div>
        </form>
      </AdminSurface>

      <AdminSurface
        title="Partner-offer catalogue"
      >
        <p className="text-sm leading-6 text-[var(--admin-zinc-400)]">
          Strict source-owned reward values and partner identities; no
          synthetic stock or claim totals.
        </p>
        <AdminFilterBar
          className="mt-5"
          actions={
            <div className="flex flex-wrap gap-2">
              {(
                ["title", "partner", "points", "order", "status"] as const
              ).map((key) => (
                <button
                  key={key}
                  type="button"
                  disabled={mutationLocked}
                  data-active={offerCollection.sortKey === key}
                  onClick={() => offerCollection.toggleSort(key)}
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
            <span className="sr-only">Search partner offers</span>
            <input
              type="search"
              value={offerCollection.query}
              disabled={mutationLocked}
              onChange={(event) =>
                offerCollection.setQuery(event.target.value)
              }
              placeholder="Search offer, partner, verification, or status"
            />
          </label>
        </AdminFilterBar>

        <div className="mt-5 space-y-3">
          {offerCollection.pageResult.items.length === 0 ? (
            <p className="admin-offers-empty">
              {offerCollection.query
                ? "No partner offers match the current search."
                : "No partner offers are currently confirmed for this club."}
            </p>
          ) : (
            offerCollection.pageResult.items.map((offer) => (
              <article
                key={offer.id}
                className={cn(
                  "admin-offer-card",
                  form.id === offer.id && "admin-offer-card-selected",
                )}
              >
                <div className="admin-offer-icon" aria-hidden="true">
                  <Gift size={20} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex min-w-0 flex-wrap items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="admin-offer-code">{offer.code}</p>
                      <h3 className="admin-offer-title">{offer.title}</h3>
                    </div>
                    <span
                      className={cn(
                        "admin-offer-status",
                        offer.isActive
                          ? "admin-offer-status-active"
                          : "admin-offer-status-inactive",
                      )}
                    >
                      {offer.isActive ? "Active" : "Inactive"}
                    </span>
                  </div>
                  <p className="admin-offer-partner">
                    {offer.partnerName} · {offer.partnerCategory}
                  </p>
                  {offer.subtitle ? (
                    <p className="admin-offer-subtitle">{offer.subtitle}</p>
                  ) : null}
                  <dl className="admin-offer-facts">
                    <div>
                      <dt>Reward</dt>
                      <dd>{offer.fetValue} FET</dd>
                    </div>
                    <div>
                      <dt>Verification</dt>
                      <dd>{offer.verificationMode.replaceAll("_", " ")}</dd>
                    </div>
                    <div>
                      <dt>Order</dt>
                      <dd>{offer.sortOrder}</dd>
                    </div>
                  </dl>
                  {offer.isFeatured ? (
                    <p className="admin-offer-featured">
                      <Star size={16} aria-hidden="true" />
                      Featured placement
                    </p>
                  ) : null}
                </div>
                <div className="admin-offer-actions">
                  <button
                    type="button"
                    disabled={mutationLocked}
                    onClick={() => selectOffer(offer)}
                    className="admin-offer-action"
                    aria-label={`Edit ${offer.title}`}
                    title={`Edit ${offer.title}`}
                  >
                    <Pencil size={17} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    disabled={mutationLocked}
                    onClick={() => void removeOffer(offer)}
                    className="admin-offer-action admin-offer-action-danger"
                    aria-label={`Delete ${offer.title}`}
                    title={`Delete ${offer.title}`}
                  >
                    <Trash2 size={17} aria-hidden="true" />
                  </button>
                </div>
              </article>
            ))
          )}
        </div>

        <AdminPagination
          page={offerCollection.pageResult}
          onPageChange={offerCollection.setPage}
          label="Partner offers"
        />
      </AdminSurface>
    </div>
  );
}

export default function AdminOffersPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadWorkspace = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyWorkspace;
      return getAdminOffers(client, access, { signal });
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setInteraction("idle");
  }, []);

  const {
    data: workspace,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyWorkspace,
    isEmpty: workspaceIsEmpty,
    load: loadWorkspace,
    normalize: normalizeAdminOffersWorkspace,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "partner-offer catalogue",
  });

  const mutationLocked = status !== "ready" && status !== "empty";
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");
  const featuredCount = workspace.offers.filter(
    (offer) => offer.isFeatured,
  ).length;

  return (
    <section
      className="admin-offers-state-surface section-grid min-w-0 max-w-full"
      data-admin-offers-status={status}
      data-admin-offers-interaction={interaction}
      data-admin-offers-refresh-disabled={busy}
      data-admin-offers-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Engagement"
        title="Partner offers"
        meta={
          <span className="admin-meta-chip">
            Club-scoped FET and partner links
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh partner-offer catalogue"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="admin-offers-metrics-grid">
        <AdminStateCard
          label="Catalogue links"
          value={initialLoading ? "..." : workspace.offers.length.toString()}
          helper="Strict club-scoped window, capped at 500."
          icon={Gift}
        />
        <AdminStateCard
          label="Active"
          value={
            initialLoading
              ? "..."
              : workspace.offers
                  .filter((offer) => offer.isActive)
                  .length.toString()
          }
          helper="Currently available to supporter journeys."
          icon={ShieldCheck}
        />
        <AdminStateCard
          label="Featured"
          value={initialLoading ? "..." : featuredCount.toString()}
          helper="Approved priority placements."
          icon={Star}
        />
      </div>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry partner-offer catalogue"
        />
      ) : initialLoading ? (
        <AdminSurface title="Partner-offer workspace">
          <div className="grid gap-4 xl:grid-cols-2">
            {Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-zinc-900)] p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-3 h-24 w-full" />
              </div>
            ))}
          </div>
        </AdminSurface>
      ) : (
        <OffersWorkspace
          workspace={workspace}
          status={status}
          onStatusFailure={applyFailure}
          onRefresh={refresh}
          onInteractionChange={setInteraction}
        />
      )}
    </section>
  );
}
