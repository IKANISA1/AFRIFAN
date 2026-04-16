"use client";

import { useCallback, useEffect, useState } from "react";
import { Settings2, ShieldCheck, Zap, Server } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { getAdminFeatures, updateAdminFeature } from "@/lib/data/admin/features";
import type { PlatformFeature } from "@/lib/types";

export default function AdminFeaturesPage() {
  const { access, client } = useAdminPortal();
  const [features, setFeatures] = useState<PlatformFeature[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [selectedFeature, setSelectedFeature] = useState<PlatformFeature | null>(null);

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setFeatures(await getAdminFeatures(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load features.";
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

  async function toggleFeatureEnabled(featureId: string, isEnabled: boolean) {
    if (!client) return;
    try {
      await updateAdminFeature(client, access, featureId, { isEnabled });
      showAdminToast(isEnabled ? "Feature enabled." : "Feature disabled.", "success");
      await load();
    } catch (e) {
      showAdminToast("Failed to toggle feature.", "error");
    }
  }

  function beginEdit(feature: PlatformFeature) {
    setSelectedFeature(feature);
    setDrawerOpen(true);
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Configuration"
        title="Feature flags"
        meta={
          <span className="admin-meta-chip">
            <Server size={12} className="inline mr-1" />
            Global Scope
          </span>
        }
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard
          label="Total Features"
          value={loading ? "..." : features.length.toString()}
          icon={Settings2}
        />
        <AdminStateCard
          label="Enabled"
          value={loading ? "..." : features.filter((f) => f.isEnabled).length.toString()}
          tone="success"
          icon={Zap}
        />
        <AdminStateCard
          label="Hidden / Disabled"
          value={loading ? "..." : features.filter((f) => !f.isEnabled || f.visibilityState !== "visible").length.toString()}
          tone={features.some((f) => !f.isEnabled) ? "warning" : "neutral"}
          icon={ShieldCheck}
        />
      </div>

      {loadError && !loading ? (
        <AdminErrorState
          title="Feature flags could not be loaded"
          description={loadError}
          onRetry={() => { load().catch(() => {}); }}
        />
      ) : (
        <div className="admin-surface">
          <AdminDataGrid
            columns={[
              { key: "feature", label: "Feature Module" },
              { key: "category", label: "Category" },
              { key: "status", label: "Global State" },
              { key: "mobile", label: "Mobile App", className: "text-center" },
              { key: "web", label: "Website", className: "text-center" },
              { key: "actions", label: "", className: "text-right" },
            ]}
          >
            {features.map((feature) => {
              const mobileChannel = feature.channels.find(c => c.channel === 'mobile' || c.channel === 'both');
              const webChannel = feature.channels.find(c => c.channel === 'web' || c.channel === 'both');
              
              return (
                <tr key={feature.id}>
                  <td>
                    <p className="admin-row-title">{feature.displayName}</p>
                    <p className="admin-row-meta">{feature.description || feature.featureKey}</p>
                  </td>
                  <td>
                    <AdminStatusBadge label={feature.category || 'core'} tone="neutral" />
                  </td>
                  <td>
                    <AdminStatusBadge
                      label={feature.isEnabled ? (feature.visibilityState === 'visible' ? 'Active' : 'Hidden') : 'Disabled'}
                      tone={feature.isEnabled ? (feature.visibilityState === 'visible' ? 'success' : 'warning') : 'danger'}
                    />
                  </td>
                  <td className="text-center">
                    {mobileChannel?.isEnabled ? <span className="text-emerald-400 font-bold">✓</span> : <span className="text-slate-500 font-bold">✗</span>}
                  </td>
                  <td className="text-center">
                    {webChannel?.isEnabled ? <span className="text-emerald-400 font-bold">✓</span> : <span className="text-slate-500 font-bold">✗</span>}
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => toggleFeatureEnabled(feature.id, !feature.isEnabled)}
                        className={`admin-action-button ${feature.isEnabled ? '!bg-rose-500/10 !text-rose-400' : '!bg-emerald-500/10 !text-emerald-400'}`}
                      >
                        {feature.isEnabled ? "Disable" : "Enable"}
                      </button>
                      <button onClick={() => beginEdit(feature)} className="admin-action-button">
                        Configure
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </AdminDataGrid>
        </div>
      )}

      {selectedFeature && (
        <AdminActionDrawer
          open={drawerOpen}
          onClose={() => setDrawerOpen(false)}
          title={`Configure ${selectedFeature.displayName}`}
        >
          <div className="space-y-6 p-4">
            <p className="text-sm text-[var(--admin-zinc-400)]">{selectedFeature.description}</p>
            {/* Extended configuration UI would go here for channels, rules, visibility */}
            <div className="glass-panel p-4 rounded-[20px] border border-[var(--admin-border)]">
              <p className="text-[10px] font-bold uppercase tracking-widest text-[var(--admin-zinc-500)] mb-4">Channel Settings</p>
              {selectedFeature.channels.map((channel) => (
                <div key={channel.id} className="flex items-center justify-between py-2 border-b border-[var(--admin-border)] last:border-0">
                  <span className="text-sm font-semibold text-white uppercase">{channel.channel}</span>
                  <div className="flex gap-4">
                    <label className="flex items-center gap-2">
                      <span className="text-xs text-[var(--admin-zinc-400)]">Enabled</span>
                      <input type="checkbox" checked={channel.isEnabled} readOnly className="accent-club-accent" />
                    </label>
                    <label className="flex items-center gap-2">
                      <span className="text-xs text-[var(--admin-zinc-400)]">Home</span>
                      <input type="checkbox" checked={channel.showOnHome} readOnly className="accent-club-accent" />
                    </label>
                    <label className="flex items-center gap-2">
                      <span className="text-xs text-[var(--admin-zinc-400)]">Nav</span>
                      <input type="checkbox" checked={channel.showInNavigation} readOnly className="accent-club-accent" />
                    </label>
                  </div>
                </div>
              ))}
            </div>
            
            <p className="text-xs text-[var(--admin-zinc-500)] text-center">Note: Full channel matrix editing is managed via the database or API directly in this version.</p>
          </div>
        </AdminActionDrawer>
      )}
    </div>
  );
}
