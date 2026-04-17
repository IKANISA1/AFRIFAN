"use client";

import { useCallback, useEffect, useState } from "react";
import { Users, DollarSign, Plus, Download } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
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
import type { AdminFanClub, AdminContributionGroup, AdminContributionSnapshot } from "@/lib/types";
import { emptyForm as emptyChapterForm, type CommunityForm } from "./_components/community-state";
import { emptyGroupForm, groupToFormState } from "../contributions/_components/group-form-state";
import { CommunityContentEditor } from "./_components/community-content-editor";
import { ContributionGroupForm } from "../contributions/_components/group-form";
import { cn, formatCurrency } from "@/lib/utils";
import { useHydrated } from "@/lib/use-hydrated";

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
    if (confirmAdminDestructiveAction({ subject: club.name })) {
      await deleteAdminFanClub(client, access, club.id);
      await loadChapters();
    }
  }

  async function removeCircle(group: AdminContributionGroup) {
    if (!client) return;
    if (confirmAdminDestructiveAction({ subject: group.name })) {
      await deleteAdminContributionGroup(client, access, group.id);
      await loadCircles();
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
        <AdminDataGrid
          columns={[
            { key: "chapter", label: "Chapter Name" },
            { key: "region", label: "Region" },
            { key: "status", label: "Status" },
            { key: "members", label: "Members" },
            { key: "rating", label: "Engagement" },
            { key: "actions", label: "", className: "text-right" },
          ]}
        >
          {clubs.map((club) => (
            <tr key={club.id}>
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
      )}

      {activeTab === "groups" && (
        <AdminDataGrid
          columns={[
            { key: "circle", label: "Public Group" },
            { key: "type", label: "Type" },
            { key: "funding", label: "Funding Status" },
            { key: "members", label: "Members" },
            { key: "actions", label: "", className: "text-right" },
          ]}
        >
          {contributionSnapshot.groups.map((group) => (
            <tr key={group.id}>
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
      )}

      {activeTab === "contributions" && (
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <p className="text-xs font-bold uppercase tracking-widest text-[var(--admin-zinc-500)]">Recent funding activity</p>
            <button onClick={() => downloadContributionExcel(contributionSnapshot)} className="admin-action-button">
              <Download size={14} /> Export Report
            </button>
          </div>
          <AdminDataGrid
            columns={[
              { key: "supporter", label: "Contributor" },
              { key: "amount", label: "Amount" },
              { key: "circle", label: "Target Circle" },
              { key: "status", label: "Status" },
              { key: "date", label: "Date" },
            ]}
          >
            {contributionSnapshot.contributions.slice(0, 50).map((item) => {
               const group = contributionSnapshot.groups.find(g => g.id === item.groupId);
               return (
                <tr key={item.id}>
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
          />
        )}
      </AdminActionDrawer>
    </div>
  );
}
