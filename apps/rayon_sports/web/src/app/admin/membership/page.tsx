"use client";

import { useCallback, useEffect, useState } from "react";
import { Crown, Users, ClipboardCheck, Plus, Search } from "lucide-react";
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
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminCollection } from "@/lib/use-admin-collection";

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
  const [detailSupporter, setDetailSupporter] = useState<AdminSupporter | null>(null);
  const [detailApplication, setDetailApplication] =
    useState<AdminMembershipApplication | null>(null);

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
        case "supporter": return supporter.displayName;
        case "tier": return supporter.tier;
        case "status": return supporter.status;
        case "points": return supporter.points;
        case "joinedAt": return new Date(supporter.joinedAt);
      }
    },
    initialSortKey: "joinedAt" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  const applicationCollection = useAdminCollection({
    records: applications,
    getId: (application) => application.id,
    getSearchValues: (application) => [
      application.userName,
      application.userPhone,
      application.tier,
      application.status,
      application.paymentStatus,
    ],
    getSortValue: (
      application,
      key: "applicant" | "tier" | "status" | "payment" | "date",
    ) => {
      switch (key) {
        case "applicant": return application.userName;
        case "tier": return application.tier;
        case "status": return application.status;
        case "payment": return application.paymentStatus;
        case "date": return new Date(application.applicationDate);
      }
    },
    initialSortKey: "date" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

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
      expectedUpdatedAt: pkg.updatedAt,
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

  async function handleReview(
    application: AdminMembershipApplication,
    decision: "approved" | "rejected",
  ) {
    if (!client) return;
    try {
      await reviewMembershipApplication(
        client,
        access,
        application.id,
        application.updatedAt,
        decision,
      );
      showAdminToast(`Application ${decision}.`, "success");
      await loadAll();
    } catch (e) {
      if (isAdminMutationConflict(e)) {
        await loadApplications();
      }
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
             if (confirmAdminDestructiveAction({
               action: "Delete",
               subject: pkg.title,
               scope: `Active club ${access.clubId ?? "not selected"}`,
               impact: "The membership tier will no longer be available to supporters.",
               undo: "not_available",
             })) {
               try {
                 await deleteAdminMembershipPackage(
                   client!,
                   access,
                   pkg.id,
                   pkg.updatedAt,
                 );
                 await loadTiers();
               } catch (caught) {
                 if (isAdminMutationConflict(caught)) {
                   await loadTiers();
                 }
                 throw caught;
               }
             }
          }}
        />
      )}

      {activeTab === "registry" && (
        <div className="admin-surface">
          <AdminFilterBar><label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search supporter registry</span><input type="search" value={supporterCollection.query} onChange={(event) => supporterCollection.setQuery(event.target.value)} placeholder="Search supporter, membership, tier, or chapter" /></label></AdminFilterBar>
          <AdminDataGrid
            caption="Supporter membership registry"
            busy={loading}
            onRowActivate={(rowId) => setDetailSupporter(supporters.find((supporter) => supporter.id === rowId) ?? null)}
            columns={[
              { key: "supporter", label: "Supporter", priority: "primary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("supporter"), onSort: () => supporterCollection.toggleSort("supporter") },
              { key: "tier", label: "Tier", priority: "primary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("tier"), onSort: () => supporterCollection.toggleSort("tier") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("status"), onSort: () => supporterCollection.toggleSort("status") },
              { key: "engagement", label: "Engagement", priority: "secondary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("points"), onSort: () => supporterCollection.toggleSort("points") },
              { key: "joined", label: "Joined", priority: "secondary", sortable: true, sortDirection: supporterCollection.sortDirectionFor("joinedAt"), onSort: () => supporterCollection.toggleSort("joinedAt") },
            ]}
          >
          {supporterCollection.pageResult.items.length === 0 ? (
            <tr><td colSpan={5} className="py-8 text-center text-sm text-slate-400">{supporterCollection.query ? "No supporters match the current search." : "No supporters found."}</td></tr>
          ) : supporterCollection.pageResult.items.map((s) => (
            <tr key={s.id} data-row-id={s.id}>
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
          <AdminPagination page={supporterCollection.pageResult} onPageChange={supporterCollection.setPage} label="Supporter registry" />
        </div>
      )}

      {activeTab === "applications" && (
        <div className="admin-surface">
          <AdminFilterBar><label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search membership applications</span><input type="search" value={applicationCollection.query} onChange={(event) => applicationCollection.setQuery(event.target.value)} placeholder="Search applicant, tier, status, or payment" /></label></AdminFilterBar>
          <AdminDataGrid
            caption="Membership applications"
            busy={loading}
            onRowActivate={(rowId) => setDetailApplication(applications.find((application) => application.id === rowId) ?? null)}
            columns={[
              { key: "applicant", label: "Applicant", priority: "primary", sortable: true, sortDirection: applicationCollection.sortDirectionFor("applicant"), onSort: () => applicationCollection.toggleSort("applicant") },
              { key: "request", label: "Requested Tier", priority: "primary", sortable: true, sortDirection: applicationCollection.sortDirectionFor("tier"), onSort: () => applicationCollection.toggleSort("tier") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: applicationCollection.sortDirectionFor("status"), onSort: () => applicationCollection.toggleSort("status") },
              { key: "payment", label: "Payment", priority: "secondary", sortable: true, sortDirection: applicationCollection.sortDirectionFor("payment"), onSort: () => applicationCollection.toggleSort("payment") },
              { key: "date", label: "Applied Date", priority: "secondary", sortable: true, sortDirection: applicationCollection.sortDirectionFor("date"), onSort: () => applicationCollection.toggleSort("date") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
          {applicationCollection.pageResult.items.length === 0 ? (
            <tr><td colSpan={6} className="py-8 text-center text-sm text-slate-400">{applicationCollection.query ? "No applications match the current search." : "No membership applications found."}</td></tr>
          ) : applicationCollection.pageResult.items.map((app) => (
            <tr key={app.id} data-row-id={app.id}>
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
                      onClick={() => handleReview(app, "approved")}
                      className="admin-action-button !bg-emerald-500/10 !text-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
                      disabled={app.paymentStatus !== "paid"}
                      title={app.paymentStatus === "paid" ? "Approve application" : "Payment must be marked paid before approval"}
                    >
                      Approve
                    </button>
                    <button onClick={() => handleReview(app, "rejected")} className="admin-action-button !bg-rose-500/10 !text-rose-400">Reject</button>
                  </div>
                )}
              </td>
            </tr>
          ))}
          </AdminDataGrid>
          <AdminPagination page={applicationCollection.pageResult} onPageChange={applicationCollection.setPage} label="Membership applications" />
        </div>
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
          onConflict={async () => {
            await loadTiers();
            showAdminToast(
              "Latest tiers loaded. Your draft is retained; review it before restarting the edit.",
              "info",
            );
          }}
        />
      </AdminActionDrawer>
      <AdminActionDrawer open={detailSupporter != null} onClose={() => setDetailSupporter(null)} title="Supporter membership details">
        {detailSupporter ? <dl className="grid gap-4 text-sm"><div><dt className="text-slate-500">Supporter</dt><dd className="mt-1 text-slate-100">{detailSupporter.displayName}</dd></div><div><dt className="text-slate-500">Membership</dt><dd className="mt-1 text-slate-100">{detailSupporter.membershipNumber}</dd></div><div><dt className="text-slate-500">Tier and status</dt><dd className="mt-1 text-slate-100">{detailSupporter.tier} · {detailSupporter.status}</dd></div><div><dt className="text-slate-500">Engagement</dt><dd className="mt-1 text-slate-100">{detailSupporter.points} points · {detailSupporter.chapter}</dd></div><div><dt className="text-slate-500">Joined</dt><dd className="mt-1 text-slate-100">{new Date(detailSupporter.joinedAt).toLocaleString()}</dd></div></dl> : null}
      </AdminActionDrawer>
      <AdminActionDrawer open={detailApplication != null} onClose={() => setDetailApplication(null)} title="Membership application details">
        {detailApplication ? <dl className="grid gap-4 text-sm"><div><dt className="text-slate-500">Applicant</dt><dd className="mt-1 text-slate-100">{detailApplication.userName}</dd></div><div><dt className="text-slate-500">Requested tier</dt><dd className="mt-1 text-slate-100">{detailApplication.tier}</dd></div><div><dt className="text-slate-500">Status</dt><dd className="mt-1 text-slate-100">{detailApplication.status}</dd></div><div><dt className="text-slate-500">Payment</dt><dd className="mt-1 text-slate-100">{detailApplication.paymentStatus}</dd></div><div><dt className="text-slate-500">Applied</dt><dd className="mt-1 text-slate-100">{new Date(detailApplication.applicationDate).toLocaleString()}</dd></div></dl> : null}
      </AdminActionDrawer>
    </div>
  );
}
