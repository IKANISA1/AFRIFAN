"use client";

import { useEffect, useState } from "react";
import { SectionHeading } from "@/components/section-heading";
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

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Membership"
        title="Activate and manage supporter tiers in the browser."
        description="The portal carries the same membership concept as the mobile app, while making tier comparison and renewal easier on larger screens."
      />
      <div className="grid gap-5 lg:grid-cols-3">
        {packages.map((membershipPackage) => (
          <article key={membershipPackage.id} className="glass-panel rounded-[32px] p-6">
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
              className="mt-6 rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
            >
              {membership?.tier === membershipPackage.tier
                ? "Current tier"
                : "Activate tier"}
            </button>
          </article>
        ))}
      </div>
      {status ? <p className="text-sm text-slate-300">{status}</p> : null}
    </div>
  );
}
