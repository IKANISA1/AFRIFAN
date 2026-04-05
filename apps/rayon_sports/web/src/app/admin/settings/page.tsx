"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Languages, Palette, Phone, ShieldCheck } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import { getAdminClubProfile, saveAdminClubProfile } from "@/lib/data/admin/settings";
import { formToProfile, profileToForm, type SettingsForm } from "./_components/settings-form-state";
import { IdentityForm } from "./_components/identity-form";
import { BrandPreview } from "./_components/brand-preview";

export default function AdminSettingsPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState<SettingsForm | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      const profile = await getAdminClubProfile(client, access);
      setForm(profileToForm(profile));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load club settings.",
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

  const enabledFlags = useMemo(
    () => (form == null ? 0 : Object.values(form.featureFlags).filter(Boolean).length),
    [form],
  );

  async function submitForm() {
    if (client == null || form == null) return;

    showAdminToast("Saving club settings...", "info");
    try {
      await saveAdminClubProfile(client, access, formToProfile(form));
      await load();
      showAdminToast("Club settings updated.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save club settings.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Settings"
        title="Club brand, contact, and feature flags."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Languages"
          value={
            loading || form == null
              ? "..."
              : form.supportedLanguagesText.split(",").map((i) => i.trim()).filter(Boolean).length.toString()
          }
          helper="Supported languages."
          icon={Languages}
        />
        <AdminStateCard label="Features" value={loading ? "..." : enabledFlags.toString()} helper="Enabled flags." icon={ShieldCheck} />
        <AdminStateCard label="Contact" value={loading || form == null ? "..." : "Live"} helper="Support channel." icon={Phone} />
        <AdminStateCard label="Brand" value={loading || form == null ? "..." : "Synced"} helper="Club colors." icon={Palette} />
      </div>

      <div className="grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
        <IdentityForm
          form={form}
          setForm={setForm}
          loading={loading}
          onReload={() => { load().catch(() => {}); }}
          onSave={() => { submitForm().catch(() => {}); }}
        />
        <BrandPreview form={form} setForm={setForm} loading={loading} />
      </div>
    </div>
  );
}
