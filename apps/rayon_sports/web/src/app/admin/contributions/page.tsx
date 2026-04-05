"use client";

import { useCallback, useEffect, useState } from "react";
import { CircleDollarSign, Coins, Users } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminContributionGroup,
  downloadContributionExcel,
  getAdminContributionSnapshot,
} from "@/lib/data/admin/contributions";
import { formatCurrency } from "@/lib/utils";
import type { AdminContributionGroup, AdminContributionSnapshot } from "@/lib/types";
import { emptyGroupForm, groupToFormState } from "./_components/group-form-state";
import { ContributionGroupForm } from "./_components/group-form";
import { ContributionGroupList } from "./_components/group-list";

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  aliases: {},
  monthlyTotal: 0,
};

export default function AdminContributionsPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [form, setForm] = useState(emptyGroupForm);
  const [filter, setFilter] = useState("ALL");
  const [sortMode, setSortMode] = useState("RECENT");
  const [loading, setLoading] = useState(true);

  const loadMonitor = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminContributionSnapshot(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load contributions monitor.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadMonitor().catch(() => {});
  }, [access.hasAccess, client, loadMonitor]);

  function beginEdit(group: AdminContributionGroup) {
    setForm(groupToFormState(group));
    showAdminToast(`Editing ${group.name}.`, "info");
  }

  async function removeGroup(group: AdminContributionGroup) {
    if (client == null) {
      return;
    }

    try {
      await deleteAdminContributionGroup(client, access, group.id);
      await loadMonitor();
      showAdminToast(`${group.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove support circle.",
        "error",
      );
    }
  }

  async function exportExcel() {
    try {
      await downloadContributionExcel(snapshot);
      showAdminToast("Contribution report downloaded as Excel.", "success");
    } catch {
      showAdminToast("Could not generate Excel report.", "error");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Contributions manager"
        title="Operate supporter circles and watch funding momentum in one place."
        description="This surface now manages public circle metadata directly, while still giving the finance and operations team quick reporting and export controls."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Raised this month"
          value={loading ? "..." : formatCurrency(snapshot.monthlyTotal)}
          helper="Successful contribution volume in the current UTC month."
          icon={Coins}
        />
        <AdminStateCard
          label="Active circles"
          value={
            loading ? "..." : snapshot.groups.filter((g) => !g.isClosed).length.toString()
          }
          helper="Open groups currently visible to supporters."
          icon={CircleDollarSign}
        />
        <AdminStateCard
          label="Contributors"
          value={
            loading
              ? "..."
              : snapshot.groups.reduce((sum, g) => sum + g.memberCount, 0).toString()
          }
          helper="Total supporter participation across visible circles."
          icon={Users}
        />
        <AdminStateCard
          label="Recent contributions"
          value={loading ? "..." : snapshot.contributions.length.toString()}
          helper="Latest contribution rows tied to this club's circles."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.92fr_1.08fr]">
        <ContributionGroupForm
          form={form}
          setForm={setForm}
          emptyForm={emptyGroupForm}
          client={client}
          access={access}
          onSaved={loadMonitor}
        />
        <ContributionGroupList
          snapshot={snapshot}
          filter={filter}
          setFilter={setFilter}
          sortMode={sortMode}
          setSortMode={setSortMode}
          loading={loading}
          onEdit={beginEdit}
          onDelete={(group) => {
            removeGroup(group).catch(() => {});
          }}
          onExportExcel={() => {
            exportExcel().catch(() => {});
          }}
        />
      </div>
    </div>
  );
}
