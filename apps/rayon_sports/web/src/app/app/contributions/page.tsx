"use client";

import { useEffect, useState } from "react";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";
import { fallbackContributionGroups } from "@/lib/content";
import { rayonClub } from "@/lib/config";
import type { ContributionGroup } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export default function FanContributionsPage() {
  const { client, user } = useFanPortal();
  const [groups, setGroups] = useState<ContributionGroup[]>(
    fallbackContributionGroups,
  );
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (client == null) return;
    const activeClient = client;

    async function loadGroups() {
      const { data } = await activeClient
        .from("contribution_groups")
        .select("*")
        .eq("club_id", rayonClub.numericId)
        .eq("is_active", true)
        .order("created_at", { ascending: false });

      if (data && data.length > 0) {
        setGroups(
          data.map((row) => ({
            id: String(row.id),
            name: String(row.name),
            description: String(row.description ?? "Support circle"),
            privacy: String(row.privacy) === "public" ? "public" : "private",
            groupType:
              String(row.group_type) === "project" ||
              String(row.group_type) === "savings" ||
              String(row.group_type) === "emergency"
                ? (String(row.group_type) as ContributionGroup["groupType"])
                : "general",
            targetAmount: Number(row.target_amount ?? 0),
            currentTotal: Number(row.current_total ?? 0),
            currency: String(row.currency ?? "RWF"),
            memberCount: Number(row.member_count ?? 0),
            inviteCode: row.invite_code ? String(row.invite_code) : null,
            isActive: row.is_active !== false,
          })),
        );
      }
    }

    loadGroups().catch(() => {});
  }, [client]);

  async function createGroup(formData: FormData) {
    if (client == null) return;
    const activeClient = client;
    setStatus("Creating contribution group...");

    try {
      await activeClient.rpc("create_group_atomic", {
        p_name: String(formData.get("name") ?? ""),
        p_description: String(formData.get("description") ?? ""),
        p_privacy: String(formData.get("privacy") ?? "public"),
        p_group_type: String(formData.get("groupType") ?? "general"),
        p_target_amount: Number(formData.get("targetAmount") ?? "0"),
        p_currency: "RWF",
        p_cycle_days: 30,
        p_country_code: "RW",
      });

      setStatus("Contribution group created.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Creation failed.");
    }
  }

  async function supportGroup(formData: FormData) {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;
    setStatus("Recording contribution...");

    try {
      await activeClient.from("contributions").insert({
        group_id: String(formData.get("groupId") ?? ""),
        user_id: activeUser.id,
        club_id: rayonClub.numericId,
        amount: Number(formData.get("amount") ?? "0"),
        currency: "RWF",
        status: "pending",
        payment_method: "momo",
        external_ref: `WEB-CONTRIB-${Date.now()}`,
        note: "Portal contribution",
      });

      setStatus("Contribution recorded as pending payment confirmation.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Contribution failed.");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Support circles"
        title="Create and support club contribution groups."
        description="This brings one of the most community-heavy mobile features into a browser workflow that is easier to understand and promote."
      />
      <div className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <div className="grid gap-6">
          <form action={createGroup} className="glass-panel grid gap-4 rounded-[32px] p-6">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Create group
            </p>
            <input
              name="name"
              placeholder="Blue Wall Travel Fund"
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
            />
            <textarea
              name="description"
              rows={4}
              placeholder="Purpose, target, and supporter context."
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
            />
            <div className="grid gap-4 md:grid-cols-3">
              <select
                name="privacy"
                defaultValue="public"
                className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
              >
                <option value="public">Public</option>
                <option value="private">Private</option>
              </select>
              <select
                name="groupType"
                defaultValue="project"
                className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
              >
                <option value="general">General</option>
                <option value="project">Project</option>
                <option value="savings">Savings</option>
                <option value="emergency">Emergency</option>
              </select>
              <input
                name="targetAmount"
                type="number"
                min="0"
                defaultValue="100000"
                className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
              />
            </div>
            <button
              type="submit"
              className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
            >
              Create support circle
            </button>
          </form>

          <form action={supportGroup} className="glass-panel grid gap-4 rounded-[32px] p-6">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Support a group
            </p>
            <select
              name="groupId"
              defaultValue={groups[0]?.id}
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
            >
              {groups.map((group) => (
                <option key={group.id} value={group.id}>
                  {group.name}
                </option>
              ))}
            </select>
            <input
              name="amount"
              type="number"
              min="100"
              defaultValue="5000"
              className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3"
            />
            <button
              type="submit"
              className="rounded-full border border-border-soft px-5 py-3 font-semibold text-white transition hover:bg-white/8"
            >
              Record contribution
            </button>
          </form>
          {status ? <p className="text-sm text-slate-300">{status}</p> : null}
        </div>

        <div className="grid gap-5">
          {groups.map((group) => (
            <article key={group.id} className="glass-panel rounded-[30px] p-5">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-display text-3xl font-bold uppercase leading-none">
                    {group.name}
                  </p>
                  <p className="mt-2 text-sm leading-7 text-slate-300">
                    {group.description}
                  </p>
                </div>
                <span className="rounded-full bg-club-accent/15 px-3 py-1.5 text-xs uppercase tracking-[0.2em] text-club-accent">
                  {group.groupType}
                </span>
              </div>
              <div className="mt-5 grid gap-3 sm:grid-cols-3">
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">
                    Raised
                  </p>
                  <p className="mt-2 font-display text-2xl font-bold uppercase">
                    {formatCurrency(group.currentTotal)}
                  </p>
                </div>
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">
                    Target
                  </p>
                  <p className="mt-2 font-display text-2xl font-bold uppercase">
                    {formatCurrency(group.targetAmount)}
                  </p>
                </div>
                <div className="rounded-[20px] bg-black/20 p-4">
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-400">
                    Invite code
                  </p>
                  <p className="mt-2 font-display text-2xl font-bold uppercase">
                    {group.inviteCode ?? "Hidden"}
                  </p>
                </div>
              </div>
            </article>
          ))}
        </div>
      </div>
    </div>
  );
}
