"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Languages, Palette, Phone, ShieldCheck, MessageSquare, Terminal, Building2, Cpu } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { getAdminClubProfile, saveAdminClubProfile } from "@/lib/data/admin/settings";
import { formToProfile, profileToForm, type SettingsForm } from "./_components/settings-form-state";
import { IdentityForm } from "./_components/identity-form";
import { BrandPreview } from "./_components/brand-preview";
import { cn } from "@/lib/utils";

type SettingsTab = "organization" | "infrastructure";

export default function AdminSettingsPage() {
  const { access, client } = useAdminPortal();
  const [activeTab, setActiveTab] = useState<SettingsTab>("organization");
  const [form, setForm] = useState<SettingsForm | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      const profile = await getAdminClubProfile(client, access);
      setForm(profileToForm(profile));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load club settings.";
      setLoadError(message);
      showAdminToast(message, "error");
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
      showAdminToast(caught instanceof Error ? caught.message : "Could not save club settings.", "error");
    }
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Configuration"
        title="Platform settings"
        meta={
          <span className="admin-meta-chip">
            {access.isSuperAdmin ? "Full control" : "Club admin scope"}
          </span>
        }
      />

      <div className="grid gap-4 md:grid-cols-4">
        <AdminStateCard
          label="Features"
          value={loading ? "..." : enabledFlags.toString()}
          icon={ShieldCheck}
        />
        <AdminStateCard
          label="WhatsApp API"
          value="Connected"
          tone="success"
          icon={MessageSquare}
        />
        <AdminStateCard
          label="Audit Logs"
          value="Enabled"
          icon={Terminal}
        />
        <AdminStateCard
          label="Languages"
          value={loading || form == null ? "..." : form.supportedLanguagesText.split(",").length.toString()}
          icon={Languages}
        />
      </div>

      <div className="flex items-center gap-1 border-b border-[var(--admin-border)] overflow-x-auto no-scrollbar">
        <button
          onClick={() => setActiveTab("organization")}
          className={cn(
            "px-6 py-3 text-xs font-bold uppercase tracking-widest transition-colors relative flex items-center gap-2",
            activeTab === "organization" ? "text-white" : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]"
          )}
        >
          <Building2 size={14} />
          Organization
          {activeTab === "organization" && (
            <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-club-accent" />
          )}
        </button>
        <button
          onClick={() => setActiveTab("infrastructure")}
          className={cn(
            "px-6 py-3 text-xs font-bold uppercase tracking-widest transition-colors relative flex items-center gap-2",
            activeTab === "infrastructure" ? "text-white" : "text-[var(--admin-zinc-500)] hover:text-[var(--admin-zinc-300)]"
          )}
        >
          <Cpu size={14} />
          Infrastructure
          {activeTab === "infrastructure" && (
            <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-club-accent" />
          )}
        </button>
      </div>

      {activeTab === "organization" && (
        <div className="grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
          <IdentityForm
            form={form}
            setForm={setForm}
            error={loadError}
            loading={loading}
            onReload={() => { load().catch(() => {}); }}
            onSave={() => { submitForm().catch(() => {}); }}
          />
          {!loadError && <BrandPreview form={form} setForm={setForm} loading={loading} />}
        </div>
      )}

      {activeTab === "infrastructure" && (
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="glass-panel p-6 rounded-[32px] space-y-6">
            <h3 className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--admin-zinc-400)]">Communication Engine</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 rounded-2xl bg-[var(--admin-zinc-950)] border border-[var(--admin-border)]">
                 <div>
                    <p className="font-bold text-white">WhatsApp Cloud API</p>
                    <p className="text-[10px] text-[var(--admin-zinc-500)] uppercase font-bold tracking-tighter mt-0.5">Meta Graph API v20.0</p>
                 </div>
                 <AdminStatusBadge label="Healthy" tone="success" />
              </div>
              <div className="flex items-center justify-between p-4 rounded-2xl bg-[var(--admin-zinc-950)] border border-[var(--admin-border)]">
                 <div>
                    <p className="font-bold text-white">SMS Broadcast Gateway</p>
                    <p className="text-[10px] text-[var(--admin-zinc-500)] uppercase font-bold tracking-tighter mt-0.5">Twilio / Local Telco</p>
                 </div>
                 <AdminStatusBadge label="Operational" tone="success" />
              </div>
            </div>
          </div>

          <div className="glass-panel p-6 rounded-[32px] space-y-6">
            <h3 className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--admin-zinc-400)]">Security & Governance</h3>
            <div className="space-y-4">
              <div className="p-4 rounded-2xl bg-[var(--admin-zinc-950)] border border-[var(--admin-border)] flex items-center justify-between">
                 <p className="font-bold text-white">Admin Audit Logging</p>
                 <AdminStatusBadge label="Active" tone="info" />
              </div>
              <div className="p-4 rounded-2xl bg-amber-500/5 border border-amber-500/20">
                 <p className="text-xs font-medium text-amber-200">Sensitive operations require high-level clearance. All system changes are recorded for audit compliance.</p>
              </div>
            </div>
          </div>
        </div>
      )}

      {loadError && !loading && (
        <AdminErrorState
          title="Settings could not be loaded"
          description={loadError}
          onRetry={() => { load().catch(() => {}); }}
        />
      )}
    </div>
  );
}
