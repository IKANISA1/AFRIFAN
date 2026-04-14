"use client";

import type { Dispatch, SetStateAction } from "react";
import type { GroupForm } from "./group-form-state";
import { showAdminToast } from "@/components/admin/admin-toast";
import { saveAdminContributionGroup } from "@/lib/data/admin/contributions";
import type { AdminAccess, AdminContributionGroup } from "@/lib/types";
import type { SupabaseClient } from "@supabase/supabase-js";

interface GroupFormProps {
  form: GroupForm;
  setForm: Dispatch<SetStateAction<GroupForm>>;
  emptyForm: GroupForm;
  defaultCurrencyCode: string;
  client: SupabaseClient | null;
  access: AdminAccess;
  onSaved: () => Promise<void>;
}

export function ContributionGroupForm({
  form,
  setForm,
  emptyForm,
  defaultCurrencyCode,
  client,
  access,
  onSaved,
}: GroupFormProps) {
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
        currency: String(
          formData.get("currency") ?? defaultCurrencyCode,
        ),
        memberCount: Number(formData.get("memberCount") ?? 0),
        inviteCode: String(formData.get("inviteCode") ?? ""),
        isClosed: formData.get("isClosed") === "on",
      });
      setForm({ ...emptyForm, currency: defaultCurrencyCode });
      await onSaved();
      showAdminToast("Support circle saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save circle.",
        "error",
      );
    }
  }

  return (
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
            onChange={(e) => setForm((c) => ({ ...c, name: e.target.value }))}
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Invite code
          <input
            name="inviteCode"
            value={form.inviteCode}
            onChange={(e) => setForm((c) => ({ ...c, inviteCode: e.target.value }))}
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
          onChange={(e) => setForm((c) => ({ ...c, description: e.target.value }))}
          className="dashboard-input min-h-24 resize-y"
        />
      </label>
      <div className="grid gap-4 sm:grid-cols-3">
        <label className="grid gap-2 text-sm">
          Type
          <select
            name="groupType"
            value={form.groupType}
            onChange={(e) => setForm((c) => ({ ...c, groupType: e.target.value as AdminContributionGroup["groupType"] }))}
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
            onChange={(e) => setForm((c) => ({ ...c, privacy: e.target.value as AdminContributionGroup["privacy"] }))}
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
            value={form.currency || defaultCurrencyCode}
            onChange={(e) => setForm((c) => ({ ...c, currency: e.target.value.toUpperCase() }))}
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
            onChange={(e) => setForm((c) => ({ ...c, targetAmount: e.target.value }))}
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Current total
          <input
            type="number"
            name="currentTotal"
            value={form.currentTotal}
            onChange={(e) => setForm((c) => ({ ...c, currentTotal: e.target.value }))}
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Member count
          <input
            type="number"
            name="memberCount"
            value={form.memberCount}
            onChange={(e) => setForm((c) => ({ ...c, memberCount: e.target.value }))}
            className="dashboard-input"
          />
        </label>
      </div>
      <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
        <input
          type="checkbox"
          name="isClosed"
          checked={form.isClosed}
          onChange={(e) => setForm((c) => ({ ...c, isClosed: e.target.checked }))}
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
  );
}
