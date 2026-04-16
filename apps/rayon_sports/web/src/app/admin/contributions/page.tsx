"use client";

import { useCallback, useEffect, useState } from "react";
import { GroupDollarSign, Coins, Users } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
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
  : { },
monthlyTotal: 0,
};

export default function AdminContributionsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [form, setForm] = useState(emptyGroupForm);
  const [filter, setFilter] = useState("ALL");
  const [sortMode, setSortMode] = useState("RECENT");
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const loadMonitor = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminContributionSnapshot(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load contributions monitor.";
      setLoadError(message);
      showAdminToast(
        message,
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
    loadMonitor().catch(() => { });
  }, [access.hasAccess, client, loadMonitor]);

  function beginEdit(group: AdminContributionGroup) {
    setForm(groupToFormState(group));
    showAdminToast(`Editing ${group.name}.`, "info");
  }

  async function removeGroup(group: AdminContributionGroup) {
    if (client == null) {
      return;
    }
    if (
      !confirmAdminDestructiveAction({
        subject: group.name,
        detail: "The contribution group and its operational definition will be removed.",
      })
    ) {
      return;
    }

    try {
      await deleteAdminContributionGroup(client, access, group.id);
      await loadMonitor();
      showAdminToast(`${group.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove support Group.",
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
      <AdminPageHeader
        eyebrow="Funding"
        title="Contributions"
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Raised this month"
          value={loading ? "..." : formatCurrency(snapshot.monthlyTotal, activeClub?.currencyCode)}
          helper="This month (UTC)."
          icon={Coins}
        />
        <AdminStateCard
          label="Active Groups"
          value={
            loading ? "..." : snapshot.groups.filter((g) => !g.isClosed).length.toString()
          }
          helper="Currently visible."
          icon={GroupDollarSign}
        />
        <AdminStateCard
          label="Contributors"
          value={
            loading
              ? "..."
              : snapshot.groups.reduce((sum, g) => sum + g.memberCount, 0).toString()
          }
          helper="Total participation."
          icon={Users}
        />
        <AdminStateCard
          label="Recent contributions"
          value={loading ? "..." : snapshot.contributions.length.toString()}
          helper="Latest entries."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.92fr_1.08fr]">
        <ContributionGroupForm
          form={form}
          setForm={setForm}
          emptyForm={emptyGroupForm}
          defaultCurrencyCode={activeClub?.currencyCode ?? "USD"}
          client={client}
          access={access}
          onSaved={loadMonitor}
        />
        {loadError && !loading ? (
          <AdminErrorState
            title="Contribution monitoring could not be loaded"
            description={loadError}
            onRetry={() => {
              loadMonitor().catch(() => { });
            }}
          />
        ) : (
          <ContributionGroupList
            snapshot={snapshot}
            currencyCode={activeClub?.currencyCode ?? "USD"}
            filter={filter}
            setFilter={setFilter}
            sortMode={sortMode}
            setSortMode={setSortMode}
            loading={loading}
            onEdit={beginEdit}
            onDelete={(group) => {
              removeGroup(group).catch(() => { });
            }}
            onExportExcel={() => {
              exportExcel().catch(() => { });
            }}
          />
        )}
      </div>
    </div>
  );
}
