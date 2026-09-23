"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { DollarSign, Download, Plus, Search, Users } from "lucide-react";
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
  deleteAdminContributionGroup,
  downloadContributionExcel,
  getAdminContributionSnapshot,
  normalizeAdminContributionSnapshot,
} from "@/lib/data/admin/contributions";
import {
  deleteAdminFanClub,
  getAdminFanClubs,
  normalizeAdminFanClubs,
  saveAdminFanClub,
} from "@/lib/data/admin/fan-clubs";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type {
  AdminContributionGroup,
  AdminContributionSnapshot,
  AdminFanClub,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { cn, formatCurrency } from "@/lib/utils";
import { useHydrated } from "@/lib/use-hydrated";
import { ContributionGroupForm } from "./_components/group-form";
import {
  emptyGroupForm,
  groupToFormState,
} from "./_components/group-form-state";
import { CommunityContentEditor } from "./_components/community-content-editor";
import {
  emptyForm as emptyChapterForm,
  type CommunityForm,
} from "./_components/community-state";

type CommunityTab = "chapters" | "groups" | "contributions";

type CommunityBundle = {
  chapters: AdminFanClub[];
  snapshot: AdminContributionSnapshot;
};

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  monthlyTotal: 0,
};

const emptyCommunityBundle: CommunityBundle = {
  chapters: [],
  snapshot: emptySnapshot,
};

const communityBundleIsEmpty = (value: CommunityBundle) =>
  value.chapters.length === 0 &&
  value.snapshot.groups.length === 0 &&
  value.snapshot.contributions.length === 0;

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading community operations",
    detail: "Waiting for the first authenticated community snapshot.",
  },
  ready: {
    label: "Community snapshot confirmed",
    detail: "FanClubs, public groups, and contribution activity are current.",
  },
  empty: {
    label: "No community records in this scope",
    detail: "Create the first authorized FanClubs or public group.",
  },
  error: {
    label: "Community operations unavailable",
    detail: "Confirmed records remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Community workspace is offline",
    detail: "Confirmed records remain visible until connection returns.",
  },
  permission_denied: {
    label: "Community access denied",
    detail:
      "Previously loaded records, filters, selections, and drafts were cleared.",
  },
  syncing: {
    label: "Refreshing community operations",
    detail: "Confirmed records remain visible during refresh.",
  },
  conflict: {
    label: "Community records changed",
    detail: "Refresh and review the current record before changing it.",
  },
  security_timeout: {
    label: "Community request timed out",
    detail: "No community operation or change was confirmed.",
  },
};

export function normalizeCommunityBundle(value: unknown): CommunityBundle {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return emptyCommunityBundle;
  }
  const record = value as Record<string, unknown>;
  return {
    chapters: normalizeAdminFanClubs(record.chapters),
    snapshot: normalizeAdminContributionSnapshot(record.snapshot),
  };
}

function contributionStatusTone(status: string) {
  if (status === "confirmed" || status === "completed") return "success";
  if (status === "pending") return "warning";
  return "danger";
}

function fundingPercent(group: AdminContributionGroup) {
  if (group.targetAmount <= 0) return 0;
  return Math.min(
    Math.max(Math.round((group.currentTotal / group.targetAmount) * 100), 0),
    100,
  );
}

export default function AdminCommunityHubPage() {
  return <Suspense fallback={<section aria-label="Loading community operations" aria-busy="true" />}>
    <CommunityWorkspace />
  </Suspense>;
}

function CommunityWorkspace() {
  const query = useSearchParams();
  const requestedTab = query.get("tab");
  const initialTab: CommunityTab = requestedTab === "groups" || requestedTab === "contributions"
    ? requestedTab : "chapters";
  const { access, client, activeClub } = useAdminPortal();
  const hydrated = useHydrated();
  const [activeTab, setActiveTab] = useState<CommunityTab>(initialTab);
  useEffect(() => { setActiveTab(initialTab); }, [initialTab]);
  const [chapterForm, setChapterForm] =
    useState<CommunityForm>(emptyChapterForm);
  const [circleForm, setCircleForm] = useState(emptyGroupForm);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<"chapter" | "circle">("chapter");
  const [detailContributionId, setDetailContributionId] = useState<
    string | null
  >(null);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadCommunity = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyCommunityBundle;
      const [chapters, snapshot] = await Promise.all([
        getAdminFanClubs(client, access, { signal }),
        getAdminContributionSnapshot(client, access, { signal }),
      ]);
      return { chapters, snapshot };
    },
    [access, client],
  );

  const clearDeniedState = useCallback(() => {
    setActiveTab("chapters");
    setChapterForm(emptyChapterForm);
    setCircleForm(emptyGroupForm);
    setDrawerOpen(false);
    setDetailContributionId(null);
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
    emptyValue: emptyCommunityBundle,
    isEmpty: communityBundleIsEmpty,
    load: loadCommunity,
    normalize: normalizeCommunityBundle,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "community operations",
  });

  const chapterCollection = useAdminCollection({
    records: data.chapters,
    getId: (chapter) => chapter.id,
    getSearchValues: (chapter) => [
      chapter.name,
      chapter.description,
      chapter.region,
      chapter.isActive ? "active" : "hidden",
    ],
    getSortValue: (
      chapter,
      key: "name" | "region" | "status" | "members" | "rating",
    ) => {
      switch (key) {
        case "name":
          return chapter.name;
        case "region":
          return chapter.region;
        case "status":
          return chapter.isActive;
        case "members":
          return chapter.memberCount;
        case "rating":
          return chapter.rating;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });

  const groupCollection = useAdminCollection({
    records: data.snapshot.groups,
    getId: (group) => group.id,
    getSearchValues: (group) => [
      group.name,
      group.groupType,
      group.isClosed ? "closed" : "active",
      group.currency,
    ],
    getSortValue: (group, key: "name" | "type" | "funding" | "members") => {
      switch (key) {
        case "name":
          return group.name;
        case "type":
          return group.groupType;
        case "funding":
          return fundingPercent(group);
        case "members":
          return group.memberCount;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });

  const contributionCollection = useAdminCollection({
    records: data.snapshot.contributions,
    getId: (item) => item.id,
    getSearchValues: (item) => [
      item.userId,
      item.status,
      item.amount,
      data.snapshot.groups.find((group) => group.id === item.groupId)?.name,
    ],
    getSortValue: (
      item,
      key: "supporter" | "amount" | "group" | "status" | "date",
    ) => {
      switch (key) {
        case "supporter":
          return item.userId;
        case "amount":
          return item.amount;
        case "group":
          return (
            data.snapshot.groups.find((group) => group.id === item.groupId)
              ?.name ?? ""
          );
        case "status":
          return item.status;
        case "date":
          return new Date(item.createdAt);
      }
    },
    initialSortKey: "date" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  useEffect(() => {
    if (status !== "permission_denied") return;
    if (chapterCollection.query) chapterCollection.setQuery("");
    if (groupCollection.query) groupCollection.setQuery("");
    if (contributionCollection.query) contributionCollection.setQuery("");
  }, [chapterCollection, contributionCollection, groupCollection, status]);

  const mutationLocked =
    !hydrated || client == null || (status !== "ready" && status !== "empty");
  const detailContribution =
    data.snapshot.contributions.find(
      (item) => item.id === detailContributionId,
    ) ?? null;

  function beginChapterCreate() {
    setChapterForm(emptyChapterForm);
    setDrawerMode("chapter");
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function beginCircleCreate() {
    setCircleForm({
      ...emptyGroupForm,
      currency: activeClub?.currencyCode ?? "USD",
    });
    setDrawerMode("circle");
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function beginChapterEdit(chapter: AdminFanClub) {
    setChapterForm({
      id: chapter.id,
      expectedUpdatedAt: chapter.updatedAt,
      name: chapter.name,
      region: chapter.region,
      description: chapter.description,
      memberCount: String(chapter.memberCount),
      eventCount: String(chapter.eventCount),
      rating: String(chapter.rating),
      bannerImageUrl: chapter.bannerImageUrl ?? "",
      isActive: chapter.isActive,
    });
    setDrawerMode("chapter");
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function beginCircleEdit(group: AdminContributionGroup) {
    setCircleForm(groupToFormState(group));
    setDrawerMode("circle");
    setDrawerOpen(true);
    setInteraction("selected");
  }

  function closeEditor() {
    setDrawerOpen(false);
    setChapterForm(emptyChapterForm);
    setCircleForm(emptyGroupForm);
    setInteraction("idle");
  }

  function mutationFailureMessage(caught: unknown, fallback: string) {
    const nextStatus = applyFailure(caught);
    return nextStatus === "conflict" ? statusCopy.conflict.label : fallback;
  }

  async function saveChapter(formData: FormData) {
    if (client == null) return;
    try {
      await saveAdminFanClub(client, access, {
        id: chapterForm.id || null,
        expectedUpdatedAt: chapterForm.expectedUpdatedAt || null,
        name: String(formData.get("name") ?? ""),
        region: String(formData.get("region") ?? ""),
        description: String(formData.get("description") ?? ""),
        memberCount: Number(formData.get("memberCount") ?? 0),
        eventCount: Number(formData.get("eventCount") ?? 0),
        rating: Number(formData.get("rating") ?? 0),
        bannerImageUrl: String(formData.get("bannerImageUrl") ?? ""),
        isActive: formData.get("isActive") === "on",
      });
      closeEditor();
      await refresh();
      showAdminToast("Community FanClubs saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        mutationFailureMessage(caught, "Could not confirm the FanClubs change."),
        "error",
      );
    }
  }

  async function removeChapter(chapter: AdminFanClub) {
    if (
      client == null ||
      !confirmAdminDestructiveAction({
        action: "Remove",
        subject: chapter.name,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The supporter FanClubs and its admin listing will be removed.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminFanClub(client, access, chapter.id, chapter.updatedAt);
      await refresh();
      showAdminToast("Community FanClubs removed.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        mutationFailureMessage(caught, "Could not confirm FanClubs removal."),
        "error",
      );
    }
  }

  async function removeCircle(group: AdminContributionGroup) {
    if (
      client == null ||
      !confirmAdminDestructiveAction({
        action: "Remove",
        subject: group.name,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact:
          "The contribution group will no longer accept or display contributions.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminContributionGroup(
        client,
        access,
        group.id,
        group.updatedAt,
      );
      await refresh();
      showAdminToast("Public contribution group removed.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        mutationFailureMessage(
          caught,
          "Could not confirm contribution-group removal.",
        ),
        "error",
      );
    }
  }

  async function exportContributionReport() {
    try {
      await downloadContributionExcel(data.snapshot);
      showAdminToast("Contribution report prepared.", "success");
    } catch {
      showAdminToast("Could not prepare the contribution report.", "error");
    }
  }

  function selectTab(tab: CommunityTab) {
    setActiveTab(tab);
    setDetailContributionId(null);
    setInteraction(tab === "chapters" ? "idle" : "selected");
  }

  const totalMembers = data.chapters.reduce(
    (sum, chapter) => sum + chapter.memberCount,
    0,
  );

  return (
    <section
      className="admin-community-state-surface section-grid min-w-0 max-w-full"
      data-admin-community-status={status}
      data-admin-community-interaction={interaction}
      data-admin-community-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Ecosystem"
        title="Community hub"
        meta={
          <span className="admin-meta-chip">
            <Users size={12} className="mr-1 inline" aria-hidden="true" />
            FanClubs, groups & contributions
          </span>
        }
        actions={
          <>
            <button
              type="button"
              onClick={beginChapterCreate}
              disabled={mutationLocked}
              className="admin-action-button min-h-12 !bg-action-blue !text-white hover:!bg-action-blue-hover disabled:opacity-70"
            >
              <Plus size={16} aria-hidden="true" /> New FanClubs
            </button>
            <button
              type="button"
              onClick={beginCircleCreate}
              disabled={mutationLocked}
              className="admin-action-button min-h-12 disabled:opacity-70"
            >
              <Plus size={16} aria-hidden="true" /> New public group
            </button>
          </>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh community operations"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-community-status"
      />

      <div className="grid gap-4 [grid-template-columns:repeat(auto-fit,minmax(min(100%,14rem),1fr))]">
        <AdminStateCard
          label="Total FanClubs"
          value={initialLoading ? "…" : String(data.chapters.length)}
          icon={Users}
        />
        <AdminStateCard
          label="FanClubs members"
          value={initialLoading ? "…" : totalMembers.toLocaleString()}
          helper="Geographic reach"
        />
        <AdminStateCard
          label="Public groups"
          value={initialLoading ? "…" : String(data.snapshot.groups.length)}
          icon={DollarSign}
        />
        <AdminStateCard
          label="Monthly raised"
          value={
            initialLoading
              ? "…"
              : formatCurrency(
                  data.snapshot.monthlyTotal,
                  activeClub?.currencyCode,
                )
          }
          tone="success"
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
        <>
          <div
            className="flex min-w-0 items-center gap-1 overflow-x-auto border-b border-[var(--admin-border)] no-scrollbar"
            role="tablist"
            aria-label="Community operations"
          >
            {(["chapters", "groups", "contributions"] as CommunityTab[]).map(
              (tab) => (
                <button
                  key={tab === "chapters" ? "FanClubs" : tab}
                  type="button"
                  role="tab"
                  aria-selected={activeTab === tab}
                  onClick={() => selectTab(tab)}
                  className={cn(
                    "relative min-h-12 shrink-0 px-5 py-3 text-xs font-medium normal-case tracking-normal transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent motion-reduce:transition-none",
                    activeTab === tab
                      ? "text-[var(--admin-text-strong)]"
                      : "text-[var(--admin-text-muted)] hover:text-[var(--admin-text-strong)]",
                  )}
                >
                  {tab === "chapters" ? "FanClubs" : tab}
                  {activeTab === tab ? (
                    <span
                      aria-hidden="true"
                      className="absolute inset-x-0 bottom-0 h-0.5 bg-[var(--admin-accent)]"
                    />
                  ) : null}
                </button>
              ),
            )}
          </div>

          {activeTab === "chapters" ? (
            <div className="admin-surface min-w-0">
              <AdminFilterBar>
                <label className="admin-search-field min-h-12">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Search community FanClubs</span>
                  <input
                    type="search"
                    value={chapterCollection.query}
                    onChange={(event) =>
                      chapterCollection.setQuery(event.target.value)
                    }
                    placeholder="Search FanClubs, region, or state"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="Community FanClubs"
                busy={busy}
                onRowActivate={(rowId) => {
                  const chapter = data.chapters.find(
                    (item) => item.id === rowId,
                  );
                  if (chapter && !mutationLocked) beginChapterEdit(chapter);
                }}
                columns={[
                  {
                    key: "chapter",
                    label: "FanClubs name",
                    priority: "primary",
                    sortable: true,
                    sortDirection: chapterCollection.sortDirectionFor("name"),
                    onSort: () => chapterCollection.toggleSort("name"),
                  },
                  {
                    key: "region",
                    label: "Region",
                    priority: "primary",
                    sortable: true,
                    sortDirection: chapterCollection.sortDirectionFor("region"),
                    onSort: () => chapterCollection.toggleSort("region"),
                  },
                  {
                    key: "status",
                    label: "Status",
                    priority: "primary",
                    sortable: true,
                    sortDirection: chapterCollection.sortDirectionFor("status"),
                    onSort: () => chapterCollection.toggleSort("status"),
                  },
                  {
                    key: "members",
                    label: "Members",
                    priority: "secondary",
                    sortable: true,
                    sortDirection:
                      chapterCollection.sortDirectionFor("members"),
                    onSort: () => chapterCollection.toggleSort("members"),
                  },
                  {
                    key: "rating",
                    label: "Engagement",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: chapterCollection.sortDirectionFor("rating"),
                    onSort: () => chapterCollection.toggleSort("rating"),
                  },
                  {
                    key: "actions",
                    label: "Actions",
                    priority: "primary",
                    className: "text-right",
                  },
                ]}
              >
                {chapterCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td
                      colSpan={6}
                      className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                    >
                      {chapterCollection.query
                        ? "No FanClubs match the current search."
                        : "No community FanClubs in this scope."}
                    </td>
                  </tr>
                ) : (
                  chapterCollection.pageResult.items.map((chapter) => (
                    <tr
                      key={chapter.id}
                      data-row-id={chapter.id}
                      data-selected={chapterForm.id === chapter.id || undefined}
                    >
                      <td>
                        <p className="admin-row-title">{chapter.name}</p>
                        <p className="admin-row-meta line-clamp-1">
                          {chapter.description}
                        </p>
                      </td>
                      <td>
                        <AdminStatusBadge label={chapter.region} tone="info" />
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={chapter.isActive ? "Active" : "Hidden"}
                          tone={chapter.isActive ? "success" : "neutral"}
                        />
                      </td>
                      <td>
                        <p className="text-sm font-medium text-[var(--admin-text-strong)]">
                          {chapter.memberCount}
                        </p>
                        <p className="admin-row-meta">official fans</p>
                      </td>
                      <td>
                        <span className="text-xs font-medium text-[var(--admin-text-strong)]">
                          <span aria-hidden="true" className="text-warning">
                            ★
                          </span>{" "}
                          {chapter.rating.toFixed(1)}
                        </span>
                      </td>
                      <td className="text-right">
                        <div className="flex justify-end gap-2">
                          <button
                            type="button"
                            onClick={() => beginChapterEdit(chapter)}
                            disabled={mutationLocked}
                            aria-label={`Edit community FanClubs ${chapter.name}`}
                            className="admin-action-button min-h-12"
                          >
                            Edit
                          </button>
                          <button
                            type="button"
                            onClick={() => void removeChapter(chapter)}
                            disabled={mutationLocked}
                            aria-label={`Remove community FanClubs ${chapter.name}`}
                            className="admin-action-button admin-action-button-danger min-h-12"
                          >
                            Remove
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </AdminDataGrid>
              <AdminPagination
                page={chapterCollection.pageResult}
                onPageChange={chapterCollection.setPage}
                label="Community FanClubs"
              />
            </div>
          ) : null}

          {activeTab === "groups" ? (
            <div className="admin-surface min-w-0">
              <AdminFilterBar>
                <label className="admin-search-field min-h-12">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Search public groups</span>
                  <input
                    type="search"
                    value={groupCollection.query}
                    onChange={(event) =>
                      groupCollection.setQuery(event.target.value)
                    }
                    placeholder="Search group, type, state, or currency"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="Public contribution groups"
                busy={busy}
                onRowActivate={(rowId) => {
                  const group = data.snapshot.groups.find(
                    (item) => item.id === rowId,
                  );
                  if (group && !mutationLocked) beginCircleEdit(group);
                }}
                columns={[
                  {
                    key: "group",
                    label: "Public group",
                    priority: "primary",
                    sortable: true,
                    sortDirection: groupCollection.sortDirectionFor("name"),
                    onSort: () => groupCollection.toggleSort("name"),
                  },
                  {
                    key: "type",
                    label: "Type",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: groupCollection.sortDirectionFor("type"),
                    onSort: () => groupCollection.toggleSort("type"),
                  },
                  {
                    key: "funding",
                    label: "Funding status",
                    priority: "primary",
                    sortable: true,
                    sortDirection: groupCollection.sortDirectionFor("funding"),
                    onSort: () => groupCollection.toggleSort("funding"),
                  },
                  {
                    key: "members",
                    label: "Members",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: groupCollection.sortDirectionFor("members"),
                    onSort: () => groupCollection.toggleSort("members"),
                  },
                  {
                    key: "actions",
                    label: "Actions",
                    priority: "primary",
                    className: "text-right",
                  },
                ]}
              >
                {groupCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td
                      colSpan={5}
                      className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                    >
                      {groupCollection.query
                        ? "No public groups match the current search."
                        : "No public groups in this scope."}
                    </td>
                  </tr>
                ) : (
                  groupCollection.pageResult.items.map((group) => {
                    const percent = fundingPercent(group);
                    return (
                      <tr
                        key={group.id}
                        data-row-id={group.id}
                        data-selected={circleForm.id === group.id || undefined}
                      >
                        <td>
                          <p className="admin-row-title">{group.name}</p>
                          <p className="admin-row-meta">
                            {group.isClosed
                              ? "Closed to new activity"
                              : "Active fundraising"}
                          </p>
                        </td>
                        <td>
                          <AdminStatusBadge
                            label={group.groupType}
                            tone="neutral"
                          />
                        </td>
                        <td>
                          <div className="w-full max-w-40 space-y-1">
                            <div className="flex flex-wrap justify-between gap-2 text-xs font-medium normal-case tracking-normal text-[var(--admin-text-strong)]">
                              <span>{percent}%</span>
                              <span className="text-[var(--admin-text-muted)]">
                                {formatCurrency(
                                  group.targetAmount,
                                  group.currency,
                                )}
                              </span>
                            </div>
                            <div
                              className="h-1.5 w-full overflow-hidden rounded-full bg-[var(--admin-zinc-800)]"
                              role="progressbar"
                              aria-label={`${group.name} funding progress`}
                              aria-valuemin={0}
                              aria-valuemax={100}
                              aria-valuenow={percent}
                            >
                              <div
                                className="h-full bg-success"
                                style={{ width: `${percent}%` }}
                              />
                            </div>
                          </div>
                        </td>
                        <td>
                          <p className="text-sm font-medium text-[var(--admin-text-strong)]">
                            {group.memberCount}
                          </p>
                        </td>
                        <td className="text-right">
                          <div className="flex justify-end gap-2">
                            <button
                              type="button"
                              onClick={() => beginCircleEdit(group)}
                              disabled={mutationLocked}
                              aria-label={`Edit public group ${group.name}`}
                              className="admin-action-button min-h-12"
                            >
                              Edit
                            </button>
                            <button
                              type="button"
                              onClick={() => void removeCircle(group)}
                              disabled={mutationLocked}
                              aria-label={`Remove public group ${group.name}`}
                              className="admin-action-button admin-action-button-danger min-h-12"
                            >
                              Remove
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </AdminDataGrid>
              <AdminPagination
                page={groupCollection.pageResult}
                onPageChange={groupCollection.setPage}
                label="Public contribution groups"
              />
            </div>
          ) : null}

          {activeTab === "contributions" ? (
            <div className="admin-surface min-w-0">
              <AdminFilterBar
                actions={
                  <button
                    type="button"
                    onClick={() => void exportContributionReport()}
                    disabled={!hasConfirmed}
                    className="admin-action-button min-h-12 disabled:opacity-70"
                  >
                    <Download size={16} aria-hidden="true" /> Export report
                  </button>
                }
              >
                <label className="admin-search-field min-h-12">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Search contribution activity</span>
                  <input
                    type="search"
                    value={contributionCollection.query}
                    onChange={(event) =>
                      contributionCollection.setQuery(event.target.value)
                    }
                    placeholder="Search contributor, group, amount, or status"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="Contribution activity"
                busy={busy}
                onRowActivate={(rowId) => {
                  setDetailContributionId(rowId);
                  setInteraction("selected");
                }}
                columns={[
                  {
                    key: "supporter",
                    label: "Contributor",
                    priority: "primary",
                    sortable: true,
                    sortDirection:
                      contributionCollection.sortDirectionFor("supporter"),
                    onSort: () =>
                      contributionCollection.toggleSort("supporter"),
                  },
                  {
                    key: "amount",
                    label: "Amount",
                    priority: "primary",
                    sortable: true,
                    sortDirection:
                      contributionCollection.sortDirectionFor("amount"),
                    onSort: () => contributionCollection.toggleSort("amount"),
                  },
                  {
                    key: "group",
                    label: "Target group",
                    priority: "primary",
                    sortable: true,
                    sortDirection:
                      contributionCollection.sortDirectionFor("group"),
                    onSort: () => contributionCollection.toggleSort("group"),
                  },
                  {
                    key: "status",
                    label: "Status",
                    priority: "secondary",
                    sortable: true,
                    sortDirection:
                      contributionCollection.sortDirectionFor("status"),
                    onSort: () => contributionCollection.toggleSort("status"),
                  },
                  {
                    key: "date",
                    label: "Date",
                    priority: "secondary",
                    sortable: true,
                    sortDirection:
                      contributionCollection.sortDirectionFor("date"),
                    onSort: () => contributionCollection.toggleSort("date"),
                  },
                ]}
              >
                {contributionCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td
                      colSpan={5}
                      className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                    >
                      {contributionCollection.query
                        ? "No contributions match the current search."
                        : "No contribution activity in this scope."}
                    </td>
                  </tr>
                ) : (
                  contributionCollection.pageResult.items.map((item) => {
                    const group = data.snapshot.groups.find(
                      (candidate) => candidate.id === item.groupId,
                    );
                    const contributorLabel =
                      item.userId.length > 12
                        ? `${item.userId.slice(0, 12)}…`
                        : item.userId;
                    return (
                      <tr
                        key={item.id}
                        data-row-id={item.id}
                        data-selected={
                          detailContributionId === item.id || undefined
                        }
                      >
                        <td>
                          <p className="break-all text-sm font-medium text-[var(--admin-text-strong)]">
                            {contributorLabel}
                          </p>
                        </td>
                        <td>
                          <p className="text-sm font-medium text-success">
                            {formatCurrency(item.amount, group?.currency)}
                          </p>
                        </td>
                        <td>
                          <p className="text-sm text-[var(--admin-text-strong)]">
                            {group?.name ?? "Unavailable group"}
                          </p>
                        </td>
                        <td>
                          <AdminStatusBadge
                            label={item.status}
                            tone={contributionStatusTone(item.status)}
                          />
                        </td>
                        <td className="text-xs text-[var(--admin-text-muted)]">
                          {new Date(item.createdAt).toLocaleDateString()}
                        </td>
                      </tr>
                    );
                  })
                )}
              </AdminDataGrid>
              <AdminPagination
                page={contributionCollection.pageResult}
                onPageChange={contributionCollection.setPage}
                label="Contribution activity"
              />
            </div>
          ) : null}
        </>
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={closeEditor}
        title={
          drawerMode === "chapter"
            ? chapterForm.id
              ? "Edit FanClubs"
              : "New FanClubs"
            : circleForm.id
              ? "Edit public group"
              : "New public group"
        }
      >
        {drawerMode === "chapter" ? (
          <CommunityContentEditor
            form={chapterForm}
            setForm={setChapterForm}
            disabled={mutationLocked}
            onSubmit={(formData) => void saveChapter(formData)}
          />
        ) : (
          <ContributionGroupForm
            form={circleForm}
            setForm={setCircleForm}
            emptyForm={emptyGroupForm}
            defaultCurrencyCode={activeClub?.currencyCode ?? "USD"}
            client={client}
            access={access}
            disabled={mutationLocked}
            onSaved={async () => {
              closeEditor();
              await refresh();
            }}
            onConflict={refresh}
            onFailure={(caught) =>
              mutationFailureMessage(
                caught,
                "Could not confirm the public-group change.",
              )
            }
          />
        )}
      </AdminActionDrawer>

      <AdminActionDrawer
        isOpen={detailContribution != null}
        onClose={() => {
          setDetailContributionId(null);
          setInteraction("idle");
        }}
        title="Contribution details"
      >
        {detailContribution ? (
          <dl className="grid gap-4 p-4 text-sm">
            <div>
              <dt className="text-[var(--admin-text-muted)]">Contributor</dt>
              <dd className="mt-1 break-all text-[var(--admin-text-strong)]">
                {detailContribution.userId}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Amount</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {formatCurrency(
                  detailContribution.amount,
                  data.snapshot.groups.find(
                    (group) => group.id === detailContribution.groupId,
                  )?.currency,
                )}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Target group</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {data.snapshot.groups.find(
                  (group) => group.id === detailContribution.groupId,
                )?.name ?? "Unavailable group"}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Status</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailContribution.status}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Created</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {new Date(detailContribution.createdAt).toLocaleString()}
              </dd>
            </div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </section>
  );
}
