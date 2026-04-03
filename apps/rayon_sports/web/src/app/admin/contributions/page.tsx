"use client";

import { useCallback, useEffect, useState } from "react";
import { CircleDollarSign, Coins, Trash2, Users } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminContributionGroup,
  downloadContributionExcel,
  getAdminContributionSnapshot,
  saveAdminContributionGroup,
} from "@/lib/data/admin";
import { formatCurrency } from "@/lib/utils";
import type { AdminContributionGroup, AdminContributionSnapshot } from "@/lib/types";

const emptySnapshot: AdminContributionSnapshot = {
  groups: [],
  contributions: [],
  aliases: {},
  monthlyTotal: 0,
};

type GroupForm = {
  id: string;
  name: string;
  description: string;
  privacy: AdminContributionGroup["privacy"];
  groupType: AdminContributionGroup["groupType"];
  targetAmount: string;
  currentTotal: string;
  currency: string;
  memberCount: string;
  inviteCode: string;
  isClosed: boolean;
};

const emptyForm: GroupForm = {
  id: "",
  name: "",
  description: "",
  privacy: "public",
  groupType: "project",
  targetAmount: "0",
  currentTotal: "0",
  currency: "RWF",
  memberCount: "0",
  inviteCode: "",
  isClosed: false,
};

export default function AdminContributionsPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [form, setForm] = useState<GroupForm>(emptyForm);
  const [filter, setFilter] = useState("ALL");
  const [sortMode, setSortMode] = useState("RECENT");
  const [loading, setLoading] = useState(true);

  const loadMonitor = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setSnapshot(await getAdminContributionSnapshot(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load contributions monitor.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadMonitor().catch(() => {});
  }, [access.hasAccess, client, loadMonitor]);

  function beginEdit(group: AdminContributionGroup) {
    setForm({
      id: group.id,
      name: group.name,
      description: group.description,
      privacy: group.privacy,
      groupType: group.groupType,
      targetAmount: String(group.targetAmount),
      currentTotal: String(group.currentTotal),
      currency: group.currency,
      memberCount: String(group.memberCount),
      inviteCode: group.inviteCode ?? "",
      isClosed: group.isClosed,
    });
    showAdminToast(`Editing ${group.name}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    showAdminToast(form.id ? "Saving circle..." : "Creating circle...", "info");
    try {
      await saveAdminContributionGroup(client, access, {
        id: form.id || null,
        name: String(formData.get("name") ?? ""),
        description: String(formData.get("description") ?? ""),
        privacy: String(formData.get("privacy") ?? "public") as AdminContributionGroup["privacy"],
        groupType: String(formData.get("groupType") ?? "project") as AdminContributionGroup["groupType"],
        targetAmount: Number(formData.get("targetAmount") ?? 0),
        currentTotal: Number(formData.get("currentTotal") ?? 0),
        currency: String(formData.get("currency") ?? "RWF"),
        memberCount: Number(formData.get("memberCount") ?? 0),
        inviteCode: String(formData.get("inviteCode") ?? ""),
        isClosed: formData.get("isClosed") === "on",
      });
      setForm(emptyForm);
      await loadMonitor();
      showAdminToast("Support circle saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save circle.",
        "error",
      );
    }
  }

  async function removeGroup(group: AdminContributionGroup) {
    if (client == null) {
      return;
    }

    try {
      await deleteAdminContributionGroup(client, group.id);
      await loadMonitor();
      showAdminToast(`${group.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not remove support circle.",
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

  const filteredGroups = snapshot.groups
    .filter((group) => {
      switch (filter) {
        case "CLUB PROJECTS":
          return group.groupType === "project";
        case "COMMUNITY":
          return group.groupType === "general";
        case "SAVINGS":
          return group.groupType === "savings";
        case "CLOSED":
          return group.isClosed;
        default:
          return true;
      }
    })
    .sort((left, right) => {
      if (sortMode === "TOTAL") {
        return right.currentTotal - left.currentTotal;
      }
      if (sortMode === "MEMBERS") {
        return right.memberCount - left.memberCount;
      }
      return right.createdAt.localeCompare(left.createdAt);
    });

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Contributions manager"
        title="Operate supporter circles and watch funding momentum in one place."
        description="This surface now manages public circle metadata directly, while still giving the finance and operations team quick reporting and export controls."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Raised this month"
          value={loading ? "..." : formatCurrency(snapshot.monthlyTotal)}
          helper="Successful contribution volume in the current UTC month."
          icon={Coins}
        />
        <AdminStateCard
          label="Active circles"
          value={
            loading
              ? "..."
              : snapshot.groups.filter((group) => !group.isClosed).length.toString()
          }
          helper="Open groups currently visible to supporters."
          icon={CircleDollarSign}
        />
        <AdminStateCard
          label="Contributors"
          value={
            loading
              ? "..."
              : snapshot.groups
                  .reduce((sum, group) => sum + group.memberCount, 0)
                  .toString()
          }
          helper="Total supporter participation across visible circles."
          icon={Users}
        />
        <AdminStateCard
          label="Recent contributions"
          value={loading ? "..." : snapshot.contributions.length.toString()}
          helper="Latest contribution rows tied to this club's circles."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.92fr_1.08fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              {form.id ? "Edit circle" : "New circle"}
            </p>
            {form.id ? (
              <button
                type="button"
                onClick={() => setForm(emptyForm)}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
              >
                Clear
              </button>
            ) : null}
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Circle name
              <input
                name="name"
                required
                value={form.name}
                onChange={(event) =>
                  setForm((current) => ({ ...current, name: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Invite code
              <input
                name="inviteCode"
                value={form.inviteCode}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    inviteCode: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="grid gap-2 text-sm">
            Description
            <textarea
              name="description"
              rows={3}
              value={form.description}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  description: event.target.value,
                }))
              }
              className="dashboard-input min-h-24 resize-y"
            />
          </label>

          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Type
              <select
                name="groupType"
                value={form.groupType}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    groupType: event.target.value as AdminContributionGroup["groupType"],
                  }))
                }
                className="dashboard-input"
              >
                <option value="project">Project</option>
                <option value="general">General</option>
                <option value="savings">Savings</option>
                <option value="emergency">Emergency</option>
              </select>
            </label>
            <label className="grid gap-2 text-sm">
              Privacy
              <select
                name="privacy"
                value={form.privacy}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    privacy: event.target.value as AdminContributionGroup["privacy"],
                  }))
                }
                className="dashboard-input"
              >
                <option value="public">Public</option>
                <option value="private">Private</option>
              </select>
            </label>
            <label className="grid gap-2 text-sm">
              Currency
              <input
                name="currency"
                value={form.currency}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    currency: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Target amount
              <input
                type="number"
                name="targetAmount"
                value={form.targetAmount}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    targetAmount: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Current total
              <input
                type="number"
                name="currentTotal"
                value={form.currentTotal}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    currentTotal: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Member count
              <input
                type="number"
                name="memberCount"
                value={form.memberCount}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    memberCount: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
            <input
              type="checkbox"
              name="isClosed"
              checked={form.isClosed}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  isClosed: event.target.checked,
                }))
              }
            />
            Closed to new supporter activity
          </label>

          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {form.id ? "Save circle" : "Create circle"}
          </button>
        </form>

        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex flex-wrap gap-2">
              {["ALL", "CLUB PROJECTS", "COMMUNITY", "SAVINGS", "CLOSED"].map(
                (item) => (
                  <button
                    key={item}
                    type="button"
                    data-active={filter === item}
                    onClick={() => setFilter(item)}
                    className="dashboard-chip"
                  >
                    {item}
                  </button>
                ),
              )}
              {["RECENT", "TOTAL", "MEMBERS"].map((item) => (
                <button
                  key={item}
                  type="button"
                  data-active={sortMode === item}
                  onClick={() => setSortMode(item)}
                  className="dashboard-chip"
                >
                  Sort {item}
                </button>
              ))}
            </div>
            <button
              type="button"
              onClick={() => {
                exportExcel().catch(() => {});
              }}
              className="rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-club-secondary"
            >
              Export Excel
            </button>
          </div>

          <div className="mt-5 space-y-3">
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, index) => (
                  <div
                    key={index}
                    className="rounded-[26px] border border-border-soft bg-white/5 p-5"
                  >
                    <Skeleton className="skeleton-text h-6 w-2/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                    <Skeleton className="mt-4 h-3 w-full rounded-full" />
                  </div>
                ))}
              </div>
            ) : null}
            {!loading && filteredGroups.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No contribution groups match the current view.
              </p>
            ) : null}
            {!loading &&
              filteredGroups.map((group) => {
                const creatorAlias = group.creatorId
                  ? snapshot.aliases[group.creatorId] ?? "000000"
                  : "000000";

                return (
                  <article
                    key={group.id}
                    className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="font-display text-2xl font-bold uppercase leading-none">
                            {group.name}
                          </p>
                          <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">
                            {group.groupType}
                          </span>
                          <span
                            className={`rounded-full border px-3 py-1.5 text-xs uppercase tracking-[0.18em] ${
                              group.isClosed
                                ? "border-rose-400/30 text-rose-300"
                                : "border-emerald-500/30 text-emerald-400"
                            }`}
                          >
                            {group.isClosed ? "Closed" : "Active"}
                          </span>
                        </div>
                        <p className="mt-2 text-sm leading-6 text-slate-300">
                          {group.description}
                        </p>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          onClick={() => beginEdit(group)}
                          className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            removeGroup(group).catch(() => {});
                          }}
                          className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                        >
                          <span className="inline-flex items-center gap-1.5">
                            <Trash2 size={12} />
                            Delete
                          </span>
                        </button>
                      </div>
                    </div>
                    <div className="mt-4">
                      <ProgressBar
                        value={group.currentTotal}
                        max={group.targetAmount}
                        label="Funding progress"
                        compact
                      />
                    </div>
                    <div className="mt-4 grid gap-3 sm:grid-cols-4">
                      <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                        <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                          Total
                        </p>
                        <p className="mt-2 text-sm text-slate-200">
                          {formatCurrency(group.currentTotal)}
                        </p>
                      </div>
                      <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                        <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                          Target
                        </p>
                        <p className="mt-2 text-sm text-slate-200">
                          {formatCurrency(group.targetAmount)}
                        </p>
                      </div>
                      <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                        <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                          Members
                        </p>
                        <p className="mt-2 text-sm text-slate-200">
                          {group.memberCount}
                        </p>
                      </div>
                      <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                        <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                          Creator
                        </p>
                        <p className="mt-2 text-sm text-slate-200">
                          {creatorAlias}
                        </p>
                      </div>
                    </div>
                  </article>
                );
              })}
          </div>
        </section>
      </div>
    </div>
  );
}
