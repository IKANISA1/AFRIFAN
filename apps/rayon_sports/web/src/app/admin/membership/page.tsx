"use client";

import { useCallback, useState } from "react";
import { Crown, Plus, Search, Users } from "lucide-react";
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
import { handleAdminTabKeyDown } from "@/components/admin/admin-tab-keyboard";
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import {
  deleteAdminMembershipPackage,
  getAdminMembershipPackages,
  normalizeAdminMembershipPackages,
  canConfigureAdminMembership,
} from "@/lib/data/admin/membership";
import { getAdminPartnerOptions, normalizeAdminPartnerOptions, type AdminPartnerOption } from "@/lib/data/admin/partner-pools";
import {
  getAdminSupporterRegistry,
  normalizeAdminSupporters,
} from "@/lib/data/admin/membership-ops";
import type {
  AdminMembershipPackage,
  AdminSupporter,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import { cn } from "@/lib/utils";
import { MembershipEditorForm } from "./_components/membership-editor-form";
import { MembershipList } from "./_components/membership-list";
import {
  emptyForm,
  type MembershipForm,
} from "./_components/membership-state";

type MembershipTab = "tiers" | "registry";

type MembershipSnapshot = {
  packages: AdminMembershipPackage[];
  supporters: AdminSupporter[];
  partners: AdminPartnerOption[];
};

const emptyMembershipSnapshot: MembershipSnapshot = {
  packages: [],
  supporters: [],
  partners: [],
};

const membershipSnapshotIsEmpty = (snapshot: MembershipSnapshot) =>
  snapshot.packages.length === 0 &&
  snapshot.supporters.length === 0;

function normalizeMembershipSnapshot(value: unknown): MembershipSnapshot {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return emptyMembershipSnapshot;
  }
  const snapshot = value as Record<string, unknown>;
  return {
    packages: normalizeAdminMembershipPackages(snapshot.packages),
    supporters: normalizeAdminSupporters(snapshot.supporters),
    partners: normalizeAdminPartnerOptions(snapshot.partners),
  };
}

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading membership operations",
    detail: "Waiting for the first authenticated membership snapshot.",
  },
  ready: {
    label: "Membership operations confirmed",
    detail: "The bounded club-scoped membership workspace is current.",
  },
  empty: {
    label: "No membership records in this scope",
    detail: "Create a paid tier or wait for supporter activity.",
  },
  error: {
    label: "Membership operations unavailable",
    detail: "Confirmed records remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Membership workspace is offline",
    detail:
      "Confirmed records remain visible; mutations are locked until reconnect.",
  },
  permission_denied: {
    label: "Membership access denied",
    detail:
      "Records, filters, selections, details, and active drafts were cleared.",
  },
  syncing: {
    label: "Refreshing membership operations",
    detail: "Confirmed records remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Membership records changed",
    detail: "Review the current record before restarting the change.",
  },
  security_timeout: {
    label: "Membership request timed out",
    detail: "No membership change was confirmed.",
  },
};

export default function AdminMembershipPage() {
  const { access } = useAdminPortal();
  return <MembershipWorkspace key={`${access.userId}:${access.clubId}:${access.role}`} />;
}

function MembershipWorkspace() {
  const { access, activeClub, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [activeTab, setActiveTab] = useState<MembershipTab>("tiers");
  const [form, setForm] = useState<MembershipForm>(emptyForm);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [detailSupporter, setDetailSupporter] =
    useState<AdminSupporter | null>(null);

  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadMembership = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyMembershipSnapshot;
      const [packages, supporters, partners] = await Promise.all([
        getAdminMembershipPackages(client, access, { signal }),
        getAdminSupporterRegistry(client, access, { signal }),
        getAdminPartnerOptions(client, access),
      ]);
      return { packages, supporters, partners };
    },
    [access, client],
  );

  const clearDeniedWorkspace = useCallback(() => {
    setActiveTab("tiers");
    setForm(emptyForm);
    setDrawerOpen(false);
    setDetailSupporter(null);
    setInteraction("idle");
  }, []);

  const {
    data: snapshot,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyMembershipSnapshot,
    isEmpty: membershipSnapshotIsEmpty,
    load: loadMembership,
    normalize: normalizeMembershipSnapshot,
    onPermissionDenied: clearDeniedWorkspace,
    resourceLabel: "membership operations",
  });

  const { packages, supporters, partners } = snapshot;

  const supporterCollection = useAdminCollection({
    records: supporters,
    getId: (supporter) => supporter.id,
    getSearchValues: (supporter) => [
      supporter.displayName,
      supporter.phone,
      supporter.membershipNumber,
      supporter.tier,
      supporter.status,
      supporter.chapter,
    ],
    getSortValue: (
      supporter,
      key: "supporter" | "tier" | "status" | "points" | "joinedAt",
    ) => {
      switch (key) {
        case "supporter":
          return supporter.displayName;
        case "tier":
          return supporter.tier;
        case "status":
          return supporter.status;
        case "points":
          return supporter.points;
        case "joinedAt":
          return new Date(supporter.joinedAt);
      }
    },
    initialSortKey: "joinedAt" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });



  const resourceLocked = status !== "ready" && status !== "empty";
  const mutationLocked = !canConfigureAdminMembership(access) || resourceLocked;
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  function beginEdit(pkg: AdminMembershipPackage) {
    if (mutationLocked) return;
    setForm({
      id: pkg.id,
      creationId: "",
      partnerId: pkg.partnerId ?? "",
      expectedUpdatedAt: pkg.updatedAt,
      tier: pkg.tier,
      title: pkg.title,
      subtitle: pkg.subtitle ?? "",
      description: pkg.description,
      annualPrice: String(pkg.annualPrice),
      perks: pkg.perks.join("\n"),
      sortOrder: String(pkg.sortOrder),
      isActive: pkg.isActive,
    });
    setInteraction("selected");
    setDrawerOpen(true);
  }



  return (
    <section
      className="admin-membership-state-surface section-grid min-w-0 max-w-full"
      data-admin-membership-status={status}
      data-admin-membership-interaction={interaction}
      data-admin-membership-refresh-disabled={busy}
      data-admin-membership-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Supporter programs"
        title="Membership operations"
        meta={
          <div className="flex flex-wrap items-center justify-end gap-2">
            <span className="admin-meta-chip">
              Bounded club-scoped membership records
            </span>
            <button
              type="button"
              onClick={() => {
                setForm(emptyForm);
                setInteraction("selected");
                setDrawerOpen(true);
              }}
              className="admin-membership-new-tier admin-action-button"
              disabled={mutationLocked || partners.length === 0}
            >
              <Plus size={16} aria-hidden="true" />
              New tier
            </button>
          </div>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh membership operations"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="admin-membership-metrics-grid">
        <AdminStateCard
          label="Total supporters"
          value={initialLoading ? "..." : supporters.length.toString()}
          helper="Strict registry window, capped at 500."
          icon={Users}
        />

        <AdminStateCard
          label="Active tiers"
          value={
            initialLoading
              ? "..."
              : packages
                  .filter((membershipPackage) => membershipPackage.isActive)
                  .length.toString()
          }
          helper="Strict catalogue window, capped at 100."
          icon={Crown}
        />
      </div>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry membership operations"
        />
      ) : initialLoading ? (
        <AdminSurface title="Membership workspace">
          <div className="space-y-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        </AdminSurface>
      ) : (
        <>
          <div
            className="admin-membership-tabs"
            role="tablist"
            aria-label="Membership workspaces"
          >
            {(["tiers", "registry"] as MembershipTab[]).map(
              (tab) => (
                <button
                  key={tab}
                  type="button"
                  role="tab"
                  id={`membership-tab-${tab}`}
                  aria-selected={activeTab === tab}
                  aria-controls="membership-panel"
                  tabIndex={activeTab === tab ? 0 : -1}
                  disabled={resourceLocked && status !== "error"}
                  onKeyDown={handleAdminTabKeyDown}
                  onClick={() => {
                    setActiveTab(tab);
                    setInteraction("selected");
                  }}
                  className={cn(
                    "admin-membership-tab",
                    activeTab === tab && "admin-membership-tab-active",
                  )}
                >
                  {tab}
                </button>
              ),
            )}
          </div>

          <div
            id="membership-panel"
            role="tabpanel"
            aria-labelledby={`membership-tab-${activeTab}`}
            tabIndex={0}
            className="min-w-0"
          >
          {activeTab === "tiers" ? (
            <MembershipList
              packages={packages}
              currencyCode={activeClub?.currencyCode ?? "USD"}
              loading={false}
              mutationDisabled={mutationLocked}
              onEdit={beginEdit}
              onDelete={async (pkg) => {
                if (
                  client == null ||
                  mutationLocked ||
                  !confirmAdminDestructiveAction({
                    action: "Delete",
                    subject: pkg.title,
                    scope: `Active club ${access.clubId ?? "not selected"}`,
                    impact:
                      "The membership tier will no longer be available to supporters.",
                    undo: "not_available",
                  })
                ) {
                  return;
                }
                showAdminToast("Removing membership tier...", "info");
                try {
                  await deleteAdminMembershipPackage(
                    client,
                    access,
                    pkg.id,
                    pkg.updatedAt,
                  );
                  await refresh();
                  showAdminToast("Membership tier removed.", "success");
                } catch (caught) {
                  applyFailure(caught);
                  if (isAdminMutationConflict(caught)) {
                    await refresh();
                  }
                  showAdminToast(
                    "Could not remove the membership tier.",
                    "error",
                  );
                }
              }}
            />
          ) : null}

          {activeTab === "registry" ? (
            <div className="admin-surface min-w-0">
              <AdminFilterBar>
                <label className="admin-search-field">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Search supporter registry</span>
                  <input
                    type="search"
                    value={supporterCollection.query}
                    onChange={(event) =>
                      supporterCollection.setQuery(event.target.value)
                    }
                    placeholder="Search supporter, membership, tier, or FanClubs"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="Supporter membership registry"
                onRowActivate={(rowId) => {
                  setDetailSupporter(
                    supporters.find((supporter) => supporter.id === rowId) ??
                      null,
                  );
                  setInteraction("selected");
                }}
                columns={[
                  { key: "supporter", label: "Supporter", priority: "primary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("supporter"), onSort: () => supporterCollection.toggleSort("supporter") },
                  { key: "tier", label: "Tier", priority: "primary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("tier"), onSort: () => supporterCollection.toggleSort("tier") },
                  { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("status"), onSort: () => supporterCollection.toggleSort("status") },
                  { key: "engagement", label: "Engagement", priority: "secondary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("points"), onSort: () => supporterCollection.toggleSort("points") },
                  { key: "joined", label: "Joined", priority: "secondary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("joinedAt"), onSort: () => supporterCollection.toggleSort("joinedAt") },
                ]}
              >
                {supporterCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="admin-membership-empty-cell">
                      {supporterCollection.query
                        ? "No supporters match the current search."
                        : "No supporters found."}
                    </td>
                  </tr>
                ) : (
                  supporterCollection.pageResult.items.map((supporter) => (
                    <tr key={supporter.id} data-row-id={supporter.id}>
                      <td>
                        <p className="admin-row-title">
                          {supporter.displayName}
                        </p>
                        <p className="admin-row-meta">
                          {supporter.phone ?? supporter.membershipNumber}
                        </p>
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={supporter.tier}
                          tone={
                            supporter.tier === "gold" ||
                            supporter.tier === "silver"
                              ? "accent"
                              : "neutral"
                          }
                        />
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={supporter.status}
                          tone={
                            supporter.status === "active"
                              ? "success"
                              : supporter.status === "suspended"
                                ? "danger"
                                : "warning"
                          }
                        />
                      </td>
                      <td>
                        <p className="admin-row-value">
                          {supporter.points} pts
                        </p>
                        <p className="admin-row-meta">{supporter.chapter}</p>
                      </td>
                      <td className="admin-row-meta">
                        {new Date(supporter.joinedAt).toLocaleDateString()}
                      </td>
                    </tr>
                  ))
                )}
              </AdminDataGrid>
              <AdminPagination
                page={supporterCollection.pageResult}
                onPageChange={supporterCollection.setPage}
                label="Supporter registry"
              />
            </div>
          ) : null}
          </div>

        </>
      )}

      <AdminActionDrawer
        open={drawerOpen}
        onClose={() => {
          setDrawerOpen(false);
          setInteraction("idle");
        }}
        title={form.id ? "Edit membership tier" : "Create new tier"}
      >
        <MembershipEditorForm
          form={form}
          setForm={setForm}
          currencyCode={activeClub?.currencyCode ?? "USD"}
          client={client}
          access={access}
          partners={partners}
          disabled={mutationLocked}
          onSaved={async () => {
            setDrawerOpen(false);
            await refresh();
          }}
          onFailure={applyFailure}
          onConflict={async () => {
            await refresh();
            showAdminToast(
              "Latest tiers loaded. Your draft is retained; review it before restarting the edit.",
              "info",
            );
          }}
        />
      </AdminActionDrawer>

      <AdminActionDrawer
        open={detailSupporter != null}
        onClose={() => {
          setDetailSupporter(null);
          setInteraction("idle");
        }}
        title="Supporter membership details"
      >
        {detailSupporter ? (
          <dl className="admin-membership-detail-list">
            <div>
              <dt>Supporter</dt>
              <dd>{detailSupporter.displayName}</dd>
            </div>
            <div>
              <dt>Membership</dt>
              <dd>{detailSupporter.membershipNumber}</dd>
            </div>
            <div>
              <dt>Tier and status</dt>
              <dd>
                {detailSupporter.tier} · {detailSupporter.status}
              </dd>
            </div>
            <div>
              <dt>Engagement</dt>
              <dd>
                {detailSupporter.points} points · {detailSupporter.chapter}
              </dd>
            </div>
            <div>
              <dt>Joined</dt>
              <dd>{new Date(detailSupporter.joinedAt).toLocaleString()}</dd>
            </div>
          </dl>
        ) : null}
      </AdminActionDrawer>


    </section>
  );
}
