"use client";

import { useCallback, useEffect, useState } from "react";
import { Crown, Users, ClipboardCheck, Plus } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminMembershipPackage,
  getAdminMembershipPackages,
} from "@/lib/data/admin/membership";
import {
  getAdminSupporterRegistry,
  getAdminMembershipApplications,
  reviewMembershipApplication,
} from "@/lib/data/admin/membership-ops";
import type { AdminMembershipPackage, AdminSupporter, AdminMembershipApplication } from "@/lib/types";
import { emptyForm, type MembershipForm } from "./_components/membership-state";
import { MembershipEditorForm } from "./_components/membership-editor-form";
import { MembershipList } from "./_components/membership-list";
import { cn } from "@/lib/utils";

type MembershipTab = "tiers" | "registry" | "applications";

export default function AdminMembershipPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [activeTab, setActiveTab] = useState<MembershipTab>("tiers");
  const [packages, setPackages] = useState<AdminMembershipPackage[]>([]);
  const [supporters, setSupporters] = useState<AdminSupporter[]>([]);
  const [applications, setApplications] = useState<AdminMembershipApplication[]>([]);
  const [form, setForm] = useState<MembershipForm>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const loadTiers = useCallback(async () => {
    if (client == null) return;
    try {
      setPackages(await getAdminMembershipPackages(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Error loading tiers", "error");
    }
  }, [access, client]);

  const loadRegistry = useCallback(async () => {
    if (client == null) return;
    try {
      setSupporters(await getAdminSupporterRegistry(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Error loading registry", "error");
    }
  }, [access, client]);

  const loadApplications = useCallback(async () => {
    if (client == null) return;
    try {
      setApplications(await getAdminMembershipApplications(client, access));
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Error loading applications", "error");
    }
  }, [access, client]);

  const loadAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([loadTiers(), loadRegistry(), loadApplications()]);
    setLoading(false);
  }, [loadApplications, loadRegistry, loadTiers]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    queueMicrotask(() => {
      loadAll().catch(() => {});
    });
  }, [access.hasAccess, client, loadAll]);

  function beginEdit(pkg: AdminMembershipPackage) {
    setForm({
      id: pkg.id,
      tier: pkg.tier,
      title: pkg.title,
      description: pkg.description,
      annualPrice: String(pkg.annualPrice),
      perks: pkg.perks.join("\n"),
      sortOrder: String(pkg.sortOrder),
      isActive: pkg.isActive,
    });
    setDrawerOpen(true);
  }

  async function handleReview(appId: string, decision: "approved" | "rejected") {
    if (!client) return;
    try {
      await reviewMembershipApplication(client, access, appId, decision);
      showAdminToast(`Application ${decision}.`, "success");
      await loadAll();
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Review failed", "error");
    }
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Supporter programs"
        title="Membership operations"
        meta={
          <div className="flex gap-2">
            <button
              onClick={() => { setForm(emptyForm); setDrawerOpen(true); }}
              className="admin-action-button !bg-club-accent !text-white"
            >
              <Plus size={14} /> New Tier
            </button>
          </div>
        }
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="Total Supporters"
          value={loading ? "..." : supporters.length.toString()}
          icon={Users}
        />
        <AdminStateCard
          label="Pending Applications"
          value={loading ? "..." : applications.filter(a => a.status === "pending").length.toString()}
          tone={applications.some(a => a.status === "pending") ? "warning" : "neutral"}
          icon={ClipboardCheck}
        />
        <AdminStateCard
          label="Active Tiers"
          value={loading ? "..." : packages.filter(p => p.isActive).length.toString()}
          icon={Crown}
        />
      </div>

      <div className="flex items-center gap-1 border-b border-[var(--admin-border)] overflow-x-auto no-scrollbar">
        {(["tiers", "registry", "applications"] as MembershipTab[]).map((tab) => (
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

      {activeTab === "tiers" && (
        <MembershipList
          packages={packages}
          currencyCode={activeClub?.currencyCode ?? "USD"}
          loading={loading}
          onEdit={beginEdit}
          onDelete={async (pkg) => {
             if (confirmAdminDestructiveAction({ subject: pkg.title })) {
               await deleteAdminMembershipPackage(client!, access, pkg.id);
               await loadTiers();
             }
          }}
        />
      )}

      {activeTab === "registry" && (
        <AdminDataGrid
          columns={[
            { key: "supporter", label: "Supporter" },
            { key: "tier", label: "Tier" },
            { key: "status", label: "Status" },
            { key: "engagement", label: "Engagement" },
            { key: "joined", label: "Joined" },
          ]}
        >
          {supporters.map((s) => (
            <tr key={s.id}>
              <td>
                <p className="admin-row-title">{s.displayName}</p>
                <p className="admin-row-meta">{s.phone || s.membershipNumber}</p>
              </td>
              <td>
                <AdminStatusBadge label={s.tier} tone={s.tier === "gold" || s.tier === "silver" ? "accent" : "neutral"} />
              </td>
              <td>
                <AdminStatusBadge label={s.status} tone={s.status === "active" ? "success" : s.status === "suspended" ? "danger" : "warning"} />
              </td>
              <td>
                <p className="text-sm font-medium text-white">{s.points} pts</p>
                <p className="admin-row-meta">{s.chapter}</p>
              </td>
              <td className="text-xs text-[var(--admin-zinc-500)]">
                {new Date(s.joinedAt).toLocaleDateString()}
              </td>
            </tr>
          ))}
        </AdminDataGrid>
      )}

      {activeTab === "applications" && (
        <AdminDataGrid
          columns={[
            { key: "applicant", label: "Applicant" },
            { key: "request", label: "Requested Tier" },
            { key: "status", label: "Status" },
            { key: "payment", label: "Payment" },
            { key: "date", label: "Applied Date" },
            { key: "actions", label: "", className: "text-right" },
          ]}
        >
          {applications.map((app) => (
            <tr key={app.id}>
              <td>
                <p className="admin-row-title">{app.userName}</p>
                <p className="admin-row-meta">{app.userPhone}</p>
              </td>
              <td>
                <AdminStatusBadge label={app.tier} tone="info" />
              </td>
              <td>
                <AdminStatusBadge label={app.status} tone={app.status === "approved" ? "success" : app.status === "rejected" ? "danger" : "warning"} />
              </td>
              <td>
                <AdminStatusBadge label={app.paymentStatus} tone={app.paymentStatus === "paid" ? "success" : "neutral"} />
              </td>
              <td className="text-xs text-[var(--admin-zinc-500)]">
                {new Date(app.applicationDate).toLocaleDateString()}
              </td>
              <td className="text-right">
                {app.status === "pending" && (
                  <div className="flex justify-end gap-2">
                    <button
                      onClick={() => handleReview(app.id, "approved")}
                      className="admin-action-button !bg-emerald-500/10 !text-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
                      disabled={app.paymentStatus !== "paid"}
                      title={app.paymentStatus === "paid" ? "Approve application" : "Payment must be marked paid before approval"}
                    >
                      Approve
                    </button>
                    <button onClick={() => handleReview(app.id, "rejected")} className="admin-action-button !bg-rose-500/10 !text-rose-400">Reject</button>
                  </div>
                )}
              </td>
            </tr>
          ))}
        </AdminDataGrid>
      )}

      <AdminActionDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={form.id ? "Edit membership tier" : "Create new tier"}
      >
        <MembershipEditorForm
          form={form}
          setForm={setForm}
          currencyCode={activeClub?.currencyCode ?? "USD"}
          client={client}
          access={access}
          onSaved={async () => { setDrawerOpen(false); await loadTiers(); }}
        />
      </AdminActionDrawer>
    </div>
  );
}
