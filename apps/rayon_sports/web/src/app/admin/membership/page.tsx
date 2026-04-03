"use client";

import { useCallback, useEffect, useState } from "react";
import { Crown } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { cn, formatCurrency } from "@/lib/utils";
import { getAdminMemberships, saveAdminMembership } from "@/lib/data/admin";
import type { AdminMembershipPackage } from "@/lib/data/admin";

const tierColors: Record<string, string> = {
  fan: "bg-white/8 text-slate-300 border-border-soft",
  bronze: "bg-amber-700/15 text-amber-300 border-amber-700/30",
  gold: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  platinum: "bg-violet-500/15 text-violet-400 border-violet-500/30",
};

const emptyForm = {
  id: "",
  tier: "fan",
  title: "",
  description: "",
  annualPrice: "",
  perks: "",
  sortOrder: "0",
  isActive: true,
};

export default function AdminMembershipPage() {
  const { access, client } = useAdminPortal();
  const [packages, setPackages] = useState<AdminMembershipPackage[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try { setPackages(await getAdminMemberships(client)); }
    catch (caught) { showAdminToast(caught instanceof Error ? caught.message : "Could not load membership tiers.", "error"); }
    finally { setLoading(false); }
  }, [client]);

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

  async function submitForm(formData: FormData) {
    if (client == null) return;
    showAdminToast(form.id ? "Saving tier..." : "Creating tier...", "info");
    try {
      await saveAdminMembership(client, access, {
        id: form.id || null,
        tier: String(formData.get("tier") ?? "fan"),
        title: String(formData.get("title") ?? ""),
        description: String(formData.get("description") ?? ""),
        annualPrice: Number(formData.get("annualPrice") ?? 0),
        perks: String(formData.get("perks") ?? "").split("\n").map((s) => s.trim()).filter(Boolean),
        sortOrder: Number(formData.get("sortOrder") ?? 0),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Membership tier saved.", "success");
    } catch (caught) {
      showAdminToast(caught instanceof Error ? caught.message : "Could not save tier.", "error");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Membership manager"
        title="Configure supporter tiers, pricing, and benefits."
        description="Changes update the public membership comparison page and the authenticated activation flow."
      />
      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard label="Tiers" value={loading ? "..." : packages.length.toString()} helper="Total membership tiers configured." icon={Crown} />
        <AdminStateCard label="Active" value={loading ? "..." : packages.filter((p) => p.isActive).length.toString()} helper="Published and visible to supporters." />
        <AdminStateCard label="Paid" value={loading ? "..." : packages.filter((p) => p.annualPrice > 0).length.toString()} helper="Tiers with annual pricing set." />
      </div>
      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">{form.id ? "Edit tier" : "New tier"}</p>
            {form.id ? <button type="button" onClick={() => setForm(emptyForm)} className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8">Clear</button> : null}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">Tier<select name="tier" value={form.tier} onChange={(e) => setForm((c) => ({ ...c, tier: e.target.value }))} className="dashboard-input"><option value="fan">Fan</option><option value="bronze">Bronze</option><option value="gold">Gold</option><option value="platinum">Platinum</option></select></label>
            <label className="grid gap-2 text-sm">Title<input name="title" required value={form.title} onChange={(e) => setForm((c) => ({ ...c, title: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <label className="grid gap-2 text-sm">Description<textarea name="description" rows={3} value={form.description} onChange={(e) => setForm((c) => ({ ...c, description: e.target.value }))} className="dashboard-input min-h-20 resize-y" /></label>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">Annual price (RWF)<input type="number" name="annualPrice" value={form.annualPrice} onChange={(e) => setForm((c) => ({ ...c, annualPrice: e.target.value }))} className="dashboard-input" /></label>
            <label className="grid gap-2 text-sm">Sort order<input type="number" name="sortOrder" value={form.sortOrder} onChange={(e) => setForm((c) => ({ ...c, sortOrder: e.target.value }))} className="dashboard-input" /></label>
          </div>
          <label className="grid gap-2 text-sm"><div className="flex items-center justify-between"><span>Perks (one per line)</span><span className="font-mono text-[10px] text-slate-400">{form.perks.split("\n").filter(Boolean).length} perks</span></div><textarea name="perks" rows={5} value={form.perks} onChange={(e) => setForm((c) => ({ ...c, perks: e.target.value }))} className="dashboard-input min-h-28 resize-y" /></label>
          <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm"><input type="checkbox" name="isActive" checked={form.isActive} onChange={(e) => setForm((c) => ({ ...c, isActive: e.target.checked }))} />Active and visible</label>
          <button type="submit" className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary">{form.id ? "Save tier" : "Create tier"}</button>
        </form>
        <section className="glass-panel rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">Tier cards</p>
          <div className="mt-5 space-y-3">
            {loading ? Array.from({ length: 4 }).map((_, i) => <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5"><Skeleton className="skeleton-text h-6 w-2/5" /><Skeleton className="skeleton-text mt-2 h-3 w-full" /></div>) : null}
            {!loading && packages.length === 0 ? <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">No membership tiers configured.</p> : null}
            {!loading && packages.map((pkg) => (
              <article key={pkg.id} className={cn("card-interactive rounded-[26px] border border-border-soft p-5 transition", pkg.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60")}>
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="flex items-center gap-3">
                      <p className="font-display text-2xl font-bold uppercase leading-none">{pkg.title}</p>
                      <span className={cn("rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]", tierColors[pkg.tier] ?? tierColors.fan)}>{pkg.tier}</span>
                    </div>
                    <p className="mt-2 text-sm text-slate-300">{pkg.description}</p>
                  </div>
                  <div className="text-right">
                    <p className="font-display text-2xl font-bold">{formatCurrency(pkg.annualPrice)}</p>
                    <p className="text-xs text-slate-400">/year</p>
                  </div>
                </div>
                {pkg.perks.length > 0 ? (
                  <div className="mt-4 flex flex-wrap gap-2">
                    {pkg.perks.map((perk) => <span key={perk} className="rounded-full border border-border-soft bg-white/5 px-3 py-1.5 text-xs text-slate-200">{perk}</span>)}
                  </div>
                ) : null}
                <button type="button" onClick={() => beginEdit(pkg)} className="mt-4 rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8">Edit</button>
              </article>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
