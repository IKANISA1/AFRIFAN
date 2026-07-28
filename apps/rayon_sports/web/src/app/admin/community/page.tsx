"use client";

import { useCallback, useEffect, useState } from "react";
import { Users, DollarSign, Plus, Download, Search } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminFanClub,
  getAdminFanClubs,
  saveAdminFanClub,
} from "@/lib/data/admin/fan-clubs";
import {
  deleteAdminContributionGroup,
  downloadContributionExcel,
  getAdminContributionSnapshot,
} from "@/lib/data/admin/contributions";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { AdminFanClub, AdminContributionGroup, AdminContributionSnapshot } from "@/lib/types";
import { emptyForm as emptyChapterForm, type CommunityForm } from "./_components/community-state";
import { emptyGroupForm, groupToFormState } from "../contributions/_components/group-form-state";
import { CommunityContentEditor } from "./_components/community-content-editor";
import { ContributionGroupForm } from "../contributions/_components/group-form";
import { cn, formatCurrency } from "@/lib/utils";
import { useHydrated } from "@/lib/use-hydrated";
import { useAdminCollection } from "@/lib/use-admin-collection";

type CommunityTab = "chapters" | "groups" | "contributions";

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  monthlyTotal: 0,
};

export default function AdminCommunityHubPage() {
  const { access, client, activeClub } = useAdminPortal();
  const hydrated = useHydrated();
  const [activeTab, setActiveTab] = useState<CommunityTab>("chapters");
  const [clubs, setClubs] = useState<AdminFanClub[]>([]);
  const [contributionSnapshot, setSnapshot] = useState<AdminContributionSnapshot>(emptySnapshot);
  const [chapterForm, setChapterForm] = useState<CommunityForm>(emptyChapterForm);
  const [circleForm, setCircleForm] = useState(emptyGroupForm);
  const [loading, setLoading] = useState(true);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<"chapter" | "circle">("chapter");
  const controlsDisabled = !hydrated || client == null || loading;
  const [detailContributionId, setDetailContributionId] = useState<string | null>(null);

  const chapterCollection = useAdminCollection({
    records: clubs,
    getId: (club) => club.id,
    getSearchValues: (club) => [club.name, club.description, club.region, club.isActive ? "active" : "hidden"],
    getSortValue: (club, key: "name" | "region" | "status" | "members" | "rating") => {
      switch (key) {
        case "name": return club.name;
        case "region": return club.region;
        case "status": return club.isActive;
        case "members": return club.memberCount;
        case "rating": return club.rating;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });
  const groupCollection = useAdminCollection({
    records: contributionSnapshot.groups,
    getId: (group) => group.id,
    getSearchValues: (group) => [group.name, group.groupType, group.isClosed ? "closed" : "active", group.currency],
    getSortValue: (group, key: "name" | "type" | "funding" | "members") => {
      switch (key) {
        case "name": return group.name;
        case "type": return group.groupType;
        case "funding": return group.targetAmount === 0 ? 0 : group.currentTotal / group.targetAmount;
        case "members": return group.memberCount;
      }
    },
    initialSortKey: "name" as const,
    pageSize: 25,
  });
  const contributionCollection = useAdminCollection({
    records: contributionSnapshot.contributions,
    getId: (item) => item.id,
    getSearchValues: (item) => [
      item.userId,
      item.status,
      item.amount,
      contributionSnapshot.groups.find((group) => group.id === item.groupId)?.name,
    ],
    getSortValue: (item, key: "supporter" | "amount" | "circle" | "status" | "date") => {
      switch (key) {
        case "supporter": return item.userId;
        case "amount": return item.amount;
        case "circle": return contributionSnapshot.groups.find((group) => group.id === item.groupId)?.name ?? "";
        case "status": return item.status;
        case "date": return new Date(item.createdAt);
      }
    },
    initialSortKey: "date" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });
  const detailContribution = contributionSnapshot.contributions.find((item) => item.id === detailContributionId) ?? null;

  const loadChapters = useCallback(async () => {
    if (!client) return;
    try {
      setClubs(await getAdminFanClubs(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Error loading chapters", "error");
    }
  }, [access, client]);

  const loadCircles = useCallback(async () => {
    if (!client) return;
    try {
      setSnapshot(await getAdminContributionSnapshot(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Error loading circles", "error");
    }
  }, [access, client]);

  const loadAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([loadChapters(), loadCircles()]);
    setLoading(false);
  }, [loadChapters, loadCircles]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    queueMicrotask(() => {
      loadAll().catch(() => {});
    });
  }, [access.hasAccess, client, loadAll]);

  function beginChapterEdit(club: AdminFanClub) {
    setChapterForm({
      id: club.id,
      expectedUpdatedAt: club.updatedAt,
      name: club.name,
      region: club.region,
      description: club.description,
      memberCount: String(club.memberCount),
      eventCount: String(club.eventCount),
      rating: String(club.rating),
      bannerImageUrl: club.bannerImageUrl ?? "",
      isActive: club.isActive,
    });
    setDrawerMode("chapter");
    setDrawerOpen(true);
  }

  function beginCircleEdit(group: AdminContributionGroup) {
    setCircleForm(groupToFormState(group));
    setDrawerMode("circle");
    setDrawerOpen(true);
  }

  async function removeChapter(club: AdminFanClub) {
    if (!client) return;
    if (confirmAdminDestructiveAction({
      action: "Remove",
      subject: club.name,
      scope: `Active club ${access.clubId ?? "not selected"}`,
      impact: "The supporter chapter and its admin listing will be removed.",
      undo: "not_available",
    })) {
      try {
        await deleteAdminFanClub(
          client,
          access,
          club.id,
          club.updatedAt,
        );
        await loadChapters();
      } catch (caught) {
        if (isAdminMutationConflict(caught)) {
          await loadChapters();
        }
        throw caught;
      }
    }
  }

  async function removeCircle(group: AdminContributionGroup) {
    if (!client) return;
    if (confirmAdminDestructiveAction({
      action: "Remove",
      subject: group.name,
      scope: `Active club ${access.clubId ?? "not selected"}`,
      impact: "The contribution group will no longer accept or display contributions.",
      undo: "not_available",
    })) {
      try {
        await deleteAdminContributionGroup(
          client,
          access,
          group.id,
          group.updatedAt,
        );
        await loadCircles();
      } catch (caught) {
        if (isAdminMutationConflict(caught)) {
          await loadCircles();
        }
        throw caught;
      }
    }
  }

  const totalMembers = clubs.reduce((sum, club) => sum + club.memberCount, 0);
  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Ecosystem"
        title="Community hub"
        meta={
          <div className="flex gap-2">
            <button
              onClick={() => { setChapterForm(emptyChapterForm); setDrawerMode("chapter"); setDrawerOpen(true); }}
              disabled={controlsDisabled}
              className="admin-action-button !bg-club-accent !text-white disabled:opacity-60"
            >
              <Plus size={14} /> New Chapter
            </button>
            <button
              onClick={() => { setCircleForm(emptyGroupForm); setDrawerMode("circle"); setDrawerOpen(true); }}
              disabled={controlsDisabled}
              className="admin-action-button !bg-[var(--admin-zinc-800)] !text-white disabled:opacity-60"
            >
              <Plus size={14} /> New Public Group
            </button>
          </div>
        }
      />

      <div className="grid gap-4 md:grid-cols-4">
        <AdminStateCard
          label="Total Chapters"
          value={loading ? "..." : clubs.length.toString()}
          icon={Users}
        />
        <AdminStateCard
          label="Chapter Members"
          value={loading ? "..." : totalMembers.toLocaleString()}
          helper="Geographic reach"
        />
        <AdminStateCard
          label="Public Groups"
          value={loading ? "..." : contributionSnapshot.groups.length.toString()}
          icon={DollarSign}
        />
        <AdminStateCard
          label="Monthly Raised"
          value={loading ? "..." : formatCurrency(contributionSnapshot.monthlyTotal, activeClub?.currencyCode)}
          tone="success"
        />
      </div>

      <div className="flex items-center gap-1 border-b border-[var(--admin-border)] overflow-x-auto no-scrollbar">
        {(["chapters", "groups", "contributions"] as CommunityTab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={cn(
              "px-6 py-3 text-xs font-bold uppercase tracking-widest transition-colors relative",
              activeTab === tab ? "text-white" : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]"
            )}
          >
            {tab}
            {activeTab === tab && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-club-accent" />
            )}
          </button>
        ))}
      </div>

      {activeTab === "chapters" && (
        <div className="admin-surface">
          <AdminFilterBar><label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search community chapters</span><input type="search" value={chapterCollection.query} onChange={(event) => chapterCollection.setQuery(event.target.value)} placeholder="Search chapter, region, or state" /></label></AdminFilterBar>
          <AdminDataGrid
            caption="Community chapters"
            busy={loading}
            onRowActivate={(rowId) => {
              const club = clubs.find((item) => item.id === rowId);
              if (club) beginChapterEdit(club);
            }}
            columns={[
              { key: "chapter", label: "Chapter Name", priority: "primary", sortable: true, sortDirection: chapterCollection.sortDirectionFor("name"), onSort: () => chapterCollection.toggleSort("name") },
              { key: "region", label: "Region", priority: "primary", sortable: true, sortDirection: chapterCollection.sortDirectionFor("region"), onSort: () => chapterCollection.toggleSort("region") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: chapterCollection.sortDirectionFor("status"), onSort: () => chapterCollection.toggleSort("status") },
              { key: "members", label: "Members", priority: "secondary", sortable: true, sortDirection: chapterCollection.sortDirectionFor("members"), onSort: () => chapterCollection.toggleSort("members") },
              { key: "rating", label: "Engagement", priority: "secondary", sortable: true, sortDirection: chapterCollection.sortDirectionFor("rating"), onSort: () => chapterCollection.toggleSort("rating") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
          {chapterCollection.pageResult.items.length === 0 ? (
            <tr><td colSpan={6} className="py-8 text-center text-sm text-slate-400">{chapterCollection.query ? "No chapters match the current search." : "No community chapters found."}</td></tr>
          ) : chapterCollection.pageResult.items.map((club) => (
            <tr key={club.id} data-row-id={club.id}>
              <td>
                <p className="admin-row-title">{club.name}</p>
                <p className="admin-row-meta line-clamp-1">{club.description}</p>
              </td>
              <td>
                <AdminStatusBadge label={club.region} tone="info" />
              </td>
              <td>
                <AdminStatusBadge label={club.isActive ? "Active" : "Hidden"} tone={club.isActive ? "success" : "neutral"} />
              </td>
              <td>
                <p className="text-sm font-medium text-white">{club.memberCount}</p>
                <p className="admin-row-meta">official fans</p>
              </td>
              <td>
                <div className="flex items-center gap-1">
                  <span className="text-xs font-bold text-amber-400">★ {club.rating}</span>
                </div>
              </td>
              <td className="text-right">
                 <div className="flex justify-end gap-2">
                    <button onClick={() => beginChapterEdit(club)} className="admin-action-button">Edit</button>
                    <button onClick={() => removeChapter(club)} className="admin-action-button admin-action-button-danger">Remove</button>
                 </div>
              </td>
            </tr>
          ))}
          </AdminDataGrid>
          <AdminPagination page={chapterCollection.pageResult} onPageChange={chapterCollection.setPage} label="Community chapters" />
        </div>
      )}

      {activeTab === "groups" && (
        <div className="admin-surface">
          <AdminFilterBar><label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search public groups</span><input type="search" value={groupCollection.query} onChange={(event) => groupCollection.setQuery(event.target.value)} placeholder="Search group, type, state, or currency" /></label></AdminFilterBar>
          <AdminDataGrid
            caption="Public contribution groups"
            busy={loading}
            onRowActivate={(rowId) => {
              const group = contributionSnapshot.groups.find((item) => item.id === rowId);
              if (group) beginCircleEdit(group);
            }}
            columns={[
              { key: "circle", label: "Public Group", priority: "primary", sortable: true, sortDirection: groupCollection.sortDirectionFor("name"), onSort: () => groupCollection.toggleSort("name") },
              { key: "type", label: "Type", priority: "secondary", sortable: true, sortDirection: groupCollection.sortDirectionFor("type"), onSort: () => groupCollection.toggleSort("type") },
              { key: "funding", label: "Funding Status", priority: "primary", sortable: true, sortDirection: groupCollection.sortDirectionFor("funding"), onSort: () => groupCollection.toggleSort("funding") },
              { key: "members", label: "Members", priority: "secondary", sortable: true, sortDirection: groupCollection.sortDirectionFor("members"), onSort: () => groupCollection.toggleSort("members") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
          {groupCollection.pageResult.items.length === 0 ? (
            <tr><td colSpan={5} className="py-8 text-center text-sm text-slate-400">{groupCollection.query ? "No public groups match the current search." : "No public groups found."}</td></tr>
          ) : groupCollection.pageResult.items.map((group) => (
            <tr key={group.id} data-row-id={group.id}>
              <td>
                <p className="admin-row-title">{group.name}</p>
                <p className="admin-row-meta">{group.isClosed ? "Operational closed" : "Active fundraising"}</p>
              </td>
              <td>
                <AdminStatusBadge label={group.groupType} tone="neutral" />
              </td>
              <td>
                <div className="w-full max-w-[120px] space-y-1">
                  <div className="flex justify-between text-[9px] font-bold uppercase tracking-wider">
                     <span>{Math.round((group.currentTotal / group.targetAmount) * 100)}%</span>
                     <span className="text-[var(--admin-zinc-500)]">{formatCurrency(group.targetAmount, group.currency)}</span>
                  </div>
                  <div className="h-1 w-full rounded-full bg-[var(--admin-zinc-800)] overflow-hidden">
                     <div className="h-full bg-emerald-500" style={{ width: `${Math.min((group.currentTotal / group.targetAmount) * 100, 100)}%` }} />
                  </div>
                </div>
              </td>
              <td>
                <p className="text-sm font-medium text-white">{group.memberCount}</p>
              </td>
              <td className="text-right">
                 <div className="flex justify-end gap-2">
                    <button onClick={() => beginCircleEdit(group)} className="admin-action-button">Edit</button>
                    <button onClick={() => removeCircle(group)} className="admin-action-button admin-action-button-danger">Remove</button>
                 </div>
              </td>
            </tr>
          ))}
          </AdminDataGrid>
          <AdminPagination page={groupCollection.pageResult} onPageChange={groupCollection.setPage} label="Public contribution groups" />
        </div>
      )}

      {activeTab === "contributions" && (
        <div className="space-y-4">
          <AdminFilterBar actions={<button onClick={() => downloadContributionExcel(contributionSnapshot)} className="admin-action-button"><Download size={14} /> Export Report</button>}>
            <label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search contribution activity</span><input type="search" value={contributionCollection.query} onChange={(event) => contributionCollection.setQuery(event.target.value)} placeholder="Search contributor, group, amount, or status" /></label>
          </AdminFilterBar>
          <div className="flex justify-between items-center">
            <p className="text-xs font-bold uppercase tracking-widest text-[var(--admin-zinc-500)]">Recent funding activity</p>
          </div>
          <AdminDataGrid
            caption="Contribution activity"
            busy={loading}
            onRowActivate={setDetailContributionId}
            columns={[
              { key: "supporter", label: "Contributor", priority: "primary", sortable: true, sortDirection: contributionCollection.sortDirectionFor("supporter"), onSort: () => contributionCollection.toggleSort("supporter") },
              { key: "amount", label: "Amount", priority: "primary", sortable: true, sortDirection: contributionCollection.sortDirectionFor("amount"), onSort: () => contributionCollection.toggleSort("amount") },
              { key: "circle", label: "Target Circle", priority: "primary", sortable: true, sortDirection: contributionCollection.sortDirectionFor("circle"), onSort: () => contributionCollection.toggleSort("circle") },
              { key: "status", label: "Status", priority: "secondary", sortable: true, sortDirection: contributionCollection.sortDirectionFor("status"), onSort: () => contributionCollection.toggleSort("status") },
              { key: "date", label: "Date", priority: "secondary", sortable: true, sortDirection: contributionCollection.sortDirectionFor("date"), onSort: () => contributionCollection.toggleSort("date") },
            ]}
          >
            {contributionCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={5} className="py-8 text-center text-sm text-slate-400">{contributionCollection.query ? "No contributions match the current search." : "No contribution activity found."}</td></tr>
            ) : contributionCollection.pageResult.items.map((item) => {
               const group = contributionSnapshot.groups.find(g => g.id === item.groupId);
               return (
                <tr key={item.id} data-row-id={item.id}>
                  <td>
                    <p className="text-sm font-medium text-white">{item.userId.slice(0, 8)}...</p>
                  </td>
                  <td>
                    <p className="text-sm font-bold text-emerald-400">{formatCurrency(item.amount, group?.currency)}</p>
                  </td>
                  <td>
                    <p className="text-sm text-[var(--admin-zinc-300)]">{group?.name || "Unknown Group"}</p>
                  </td>
                  <td>
                    <AdminStatusBadge label={item.status} tone={item.status === "confirmed" ? "success" : item.status === "pending" ? "warning" : "danger"} />
                  </td>
                  <td className="text-xs text-[var(--admin-zinc-500)]">
                    {new Date(item.createdAt).toLocaleDateString()}
                  </td>
                </tr>
               );
            })}
          </AdminDataGrid>
          <AdminPagination page={contributionCollection.pageResult} onPageChange={contributionCollection.setPage} label="Contribution activity" />
        </div>
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={drawerMode === "chapter" ? (chapterForm.id ? "Edit Chapter" : "New Chapter") : (circleForm.id ? "Edit Public Group" : "New Public Group")}
      >
        {drawerMode === "chapter" ? (
          <CommunityContentEditor
            form={chapterForm}
            setForm={setChapterForm}
            onSubmit={async (formData) => {
               await saveAdminFanClub(client!, access, {
                 id: chapterForm.id || null,
                 expectedUpdatedAt: chapterForm.expectedUpdatedAt || null,
                 name: String(formData.get("name")),
                 region: String(formData.get("region")),
                 description: String(formData.get("description")),
                 memberCount: Number(formData.get("memberCount")),
                 eventCount: Number(formData.get("eventCount")),
                 rating: Number(formData.get("rating")),
                 isActive: formData.get("isActive") === "on",
               });
               setDrawerOpen(false);
               await loadChapters();
            }}
          />
        ) : (
          <ContributionGroupForm
            form={circleForm}
            setForm={setCircleForm}
            emptyForm={emptyGroupForm}
            defaultCurrencyCode={activeClub?.currencyCode ?? "USD"}
            client={client}
            access={access}
            onSaved={async () => { setDrawerOpen(false); await loadCircles(); }}
            onConflict={async () => {
              await loadCircles();
              showAdminToast(
                "The latest group list is loaded. Your draft is retained; review it before restarting the edit.",
                "info",
              );
            }}
          />
        )}
      </AdminActionDrawer>
      <AdminActionDrawer open={detailContribution != null} onClose={() => setDetailContributionId(null)} title="Contribution details">
        {detailContribution ? (
          <dl className="grid gap-4 text-sm">
            <div><dt className="text-slate-500">Contributor</dt><dd className="mt-1 break-all text-slate-100">{detailContribution.userId}</dd></div>
            <div><dt className="text-slate-500">Amount</dt><dd className="mt-1 text-slate-100">{formatCurrency(detailContribution.amount, contributionSnapshot.groups.find((group) => group.id === detailContribution.groupId)?.currency)}</dd></div>
            <div><dt className="text-slate-500">Target group</dt><dd className="mt-1 text-slate-100">{contributionSnapshot.groups.find((group) => group.id === detailContribution.groupId)?.name ?? "Unknown group"}</dd></div>
            <div><dt className="text-slate-500">Status</dt><dd className="mt-1 text-slate-100">{detailContribution.status}</dd></div>
            <div><dt className="text-slate-500">Created</dt><dd className="mt-1 text-slate-100">{new Date(detailContribution.createdAt).toLocaleString()}</dd></div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}
