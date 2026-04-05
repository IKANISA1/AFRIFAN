"use client";

import { useEffect, useState } from "react";
import { ArrowRight, ShieldCheck } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackMembershipPackages } from "@/lib/content";
import { rayonClub } from "@/lib/config";
import type { MembershipPackage } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export default function FanMembershipPage() {
  const { client, user, membership, refresh } = useFanPortal();
  const [packages, setPackages] = useState<MembershipPackage[]>(
    fallbackMembershipPackages,
  );
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (client == null) return;
    const activeClient = client;

    async function loadPackages() {
      const { data } = await activeClient
        .from("membership_packages")
        .select("*")
        .eq("club_id", rayonClub.numericId)
        .eq("is_active", true)
        .order("sort_order", { ascending: true });

      if (data && data.length > 0) {
        setPackages(
          data.map((row) => ({
            id: String(row.id),
            tier:
              String(row.tier).toLowerCase() == "gold"
                ? "gold"
                : String(row.tier).toLowerCase() == "platinum"
                  ? "platinum"
                  : String(row.tier).toLowerCase() == "bronze"
                    ? "bronze"
                    : "fan",
            title: String(row.title ?? "Membership tier"),
            description: String(row.description ?? "Supporter benefits"),
            sortOrder: Number(row.sort_order ?? 0),
            annualPrice: Number(row.annual_price ?? row.price ?? 0),
            perks: String(row.description ?? "Supporter benefits")
              .split(/[.;]/)
              .map((item) => item.trim())
              .filter((item) => item.length > 2)
              .slice(0, 4),
          })),
        );
      }
    }

    loadPackages().catch(() => {});
  }, [client]);

  async function activatePackage(nextPackage: MembershipPackage) {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    setStatus(`Activating ${nextPackage.title}...`);

    try {
      await activeClient.from("fan_memberships").upsert(
        {
          user_id: activeUser.id,
          club_id: rayonClub.numericId,
          partner_id: rayonClub.numericId.toString(),
          tier: nextPackage.tier,
          points:
            nextPackage.tier == "platinum"
              ? 5000
              : nextPackage.tier == "gold"
                ? 2500
                : nextPackage.tier == "bronze"
                  ? 1000
                  : 0,
          chapter: "Main",
          renewed_at: new Date().toISOString(),
        },
        { onConflict: "user_id,club_id" },
      );
      await refresh();
      setStatus(`${nextPackage.title} is now active.`);
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Activation failed.");
    }
  }

  const tierLabel = (membership?.tier ?? "fan").toUpperCase();
  const xpPoints = membership?.points ?? 0;
  const featuredTier =
    packages.find((pkg) => pkg.tier !== (membership?.tier ?? "fan")) ??
    packages[packages.length - 1];

  return (
    <div className="section-grid">
      <PageHero
        eyebrow="Membership"
        title="Your tier, your perks, your matchday."
        description="Upgrade anytime and unlock ticket priority, shop discounts, and exclusive supporter access across every fixture."
        stats={[
          { label: "Current tier", value: tierLabel },
          { label: "XP earned", value: xpPoints.toString() },
          { label: "Tiers available", value: packages.length.toString() },
        ]}
        actions={
          <>
            <a
              href="#tier-grid"
              className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
            >
              Compare tiers <ShieldCheck size={18} />
            </a>
          </>
        }
        media={
          featuredTier ? (
            <article className="rounded-[28px] border border-border-soft bg-black/20 p-5">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-club-accent">
                {featuredTier.tier === "platinum" ? "Top tier" : "Upgrade option"}
              </p>
              <p className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
                {featuredTier.title}
              </p>
              <p className="mt-3 text-sm leading-6 text-slate-300">
                {featuredTier.description}
              </p>
              <p className="mt-5 font-display text-3xl font-bold uppercase text-white">
                {formatCurrency(featuredTier.annualPrice)}
                <span className="ml-2 text-sm font-normal normal-case tracking-normal text-slate-300">
                  per year
                </span>
              </p>
              <ul className="mt-4 space-y-2">
                {featuredTier.perks.slice(0, 3).map((perk) => (
                  <li key={perk} className="flex items-center gap-2 text-sm text-slate-200">
                    <ArrowRight size={14} className="text-club-accent" />
                    {perk}
                  </li>
                ))}
              </ul>
            </article>
          ) : null
        }
      />

      <div id="tier-grid" className="grid gap-5 lg:grid-cols-3">
        {packages.map((membershipPackage) => {
          const isCurrent = membership?.tier === membershipPackage.tier;

          return (
            <article
              key={membershipPackage.id}
              className={`glass-panel relative overflow-hidden rounded-[32px] p-6 ${
                isCurrent ? "ring-2 ring-club-accent/40" : ""
              }`}
            >
              {isCurrent ? (
                <span className="absolute top-5 right-5 rounded-full border border-club-accent/30 bg-club-accent/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-club-accent">
                  Active
                </span>
              ) : null}
              <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
                {membershipPackage.tier}
              </p>
              <p className="mt-4 font-display text-4xl font-bold uppercase leading-none">
                {membershipPackage.title}
              </p>
              <p className="mt-4 text-sm leading-7 text-slate-300">
                {membershipPackage.description}
              </p>
              <p className="mt-5 font-display text-3xl font-bold uppercase">
                {formatCurrency(membershipPackage.annualPrice)}
              </p>
              <ul className="mt-5 space-y-3 text-sm text-slate-200">
                {membershipPackage.perks.map((perk) => (
                  <li key={perk} className="rounded-[20px] border border-border-soft bg-white/6 px-4 py-3">
                    {perk}
                  </li>
                ))}
              </ul>
              <button
                type="button"
                onClick={() => activatePackage(membershipPackage)}
                disabled={isCurrent}
                className="mt-6 w-full rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-50"
              >
                {isCurrent ? "Current tier" : "Activate tier"}
              </button>
            </article>
          );
        })}
      </div>
      {status ? (
        <p className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3 text-sm text-slate-200">
          {status}
        </p>
      ) : null}
    </div>
  );
}
