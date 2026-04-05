"use client";

import { useCallback, useEffect, useState } from "react";
import { Crown } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminMembershipPackage,
  getAdminMembershipPackages,
} from "@/lib/data/admin/membership";
import type { AdminMembershipPackage } from "@/lib/types";
import { emptyForm, type MembershipForm } from "./_components/membership-state";
import { MembershipEditorForm } from "./_components/membership-editor-form";
import { MembershipList } from "./_components/membership-list";

export default function AdminMembershipPage() {
  const { access, client } = useAdminPortal();
  const [packages, setPackages] = useState<AdminMembershipPackage[]>([]);
  const [form, setForm] = useState<MembershipForm>(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setPackages(await getAdminMembershipPackages(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load membership tiers.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

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
    showAdminToast(`Editing ${pkg.title}.`, "info");
  }

  async function removeTier(pkg: AdminMembershipPackage) {
    if (client == null) return;

    showAdminToast(`Removing ${pkg.title}...`, "info");
    try {
      await deleteAdminMembershipPackage(client, access, pkg.id);
      await load();
      showAdminToast(`${pkg.title} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove tier.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Membership manager"
        title="Configure supporter tiers, pricing, and benefit ladders."
        description="Changes update the public membership comparison page and the authenticated activation journey."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Tiers"
          value={loading ? "..." : packages.length.toString()}
          helper="Total membership tiers configured."
          icon={Crown}
        />
        <AdminStateCard
          label="Active"
          value={
            loading
              ? "..."
              : packages.filter((pkg) => pkg.isActive).length.toString()
          }
          helper="Published and visible to supporters."
        />
        <AdminStateCard
          label="Paid"
          value={
            loading
              ? "..."
              : packages.filter((pkg) => pkg.annualPrice > 0).length.toString()
          }
          helper="Tiers with annual pricing set."
        />
        <AdminStateCard
          label="Free"
          value={
            loading
              ? "..."
              : packages.filter((pkg) => pkg.annualPrice === 0).length.toString()
          }
          helper="Identity or onboarding tiers without annual cost."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <MembershipEditorForm
          form={form}
          setForm={setForm}
          client={client}
          access={access}
          onSaved={load}
        />
        <MembershipList
          packages={packages}
          loading={loading}
          onEdit={beginEdit}
          onDelete={removeTier}
        />
      </div>
    </div>
  );
}
