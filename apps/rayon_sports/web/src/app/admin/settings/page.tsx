"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Languages, Palette, Phone, ShieldCheck } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import { getAdminClubProfile, saveAdminClubProfile } from "@/lib/data/admin";
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
      const profile = await getAdminClubProfile(client);
      setForm(profileToForm(profile));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load club settings.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

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
      await saveAdminClubProfile(client, formToProfile(form));
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
        eyebrow="Club settings"
        title="Control the brand, contact, language, and public feature switches."
        description="These values drive the public web experience and give the admin team one place to maintain core club identity in Supabase."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Languages"
          value={
            loading || form == null
              ? "..."
              : form.supportedLanguagesText.split(",").map((i) => i.trim()).filter(Boolean).length.toString()
          }
          helper="Languages exposed across the public shell."
          icon={Languages}
        />
        <AdminStateCard label="Features" value={loading ? "..." : enabledFlags.toString()} helper="Enabled public feature flags." icon={ShieldCheck} />
        <AdminStateCard label="Contact" value={loading || form == null ? "..." : "Live"} helper="Official support and matchday contact channel." icon={Phone} />
        <AdminStateCard label="Brand" value={loading || form == null ? "..." : "Synced"} helper="Primary, secondary, and accent club colors." icon={Palette} />
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
