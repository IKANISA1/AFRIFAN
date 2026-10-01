"use client";

import type { Dispatch, FormEvent, SetStateAction } from "react";
import type { GroupForm } from "./group-form-state";
import { showAdminToast } from "@/components/admin/admin-toast";
import { saveAdminContributionGroup } from "@/lib/data/admin/contributions";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
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
  onConflict: () => Promise<void>;
  disabled?: boolean;
  onFailure?: (error: unknown) => string;
}

export function ContributionGroupForm({
  form,
  setForm,
  emptyForm,
  defaultCurrencyCode,
  client,
  access,
  onSaved,
  onConflict,
  disabled = false,
  onFailure,
}: GroupFormProps) {
  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    showAdminToast(
      form.id ? "Saving initiative..." : "Creating initiative...",
      "info",
    );
    try {
      await saveAdminContributionGroup(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        name: String(formData.get("name") ?? ""),
        description: String(formData.get("description") ?? ""),
        groupType: String(
          formData.get("groupType") ?? "project",
        ) as AdminContributionGroup["groupType"],
        targetAmount: Number(formData.get("targetAmount") ?? 0),
        currentTotal: Number(formData.get("currentTotal") ?? 0),
        currency: String(formData.get("currency") ?? defaultCurrencyCode),
        memberCount: Number(formData.get("memberCount") ?? 0),
        isClosed: formData.get("isClosed") === "on",
      });
      setForm({ ...emptyForm, currency: defaultCurrencyCode });
      await onSaved();
      showAdminToast("Public initiative saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await onConflict();
      }
      showAdminToast(
        onFailure?.(caught) ??
          (caught instanceof Error
            ? caught.message
            : "Could not save initiative."),
        "error",
      );
    }
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    void submitForm(formData);
  }

  return (
    <form onSubmit={handleSubmit} className="grid gap-4 p-4">
      <fieldset disabled={disabled} className="contents">
        <div className="flex items-center justify-between gap-3">
          <p className="font-display text-3xl font-medium normal-case leading-none">
            {form.id ? "Edit Initiative" : "New Initiative"}
          </p>
          {form.id ? (
            <button
              type="button"
              onClick={() => setForm(emptyForm)}
              className="min-h-12 rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
            >
              Clear
            </button>
          ) : null}
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-2 text-sm">
            Initiative name
            <input
              name="name"
              required
              maxLength={160}
              autoComplete="off"
              value={form.name}
              onChange={(e) => setForm((c) => ({ ...c, name: e.target.value }))}
              className="dashboard-input"
            />
          </label>
          <div className="grid gap-2 text-sm">
            Visibility
            <div className="dashboard-input flex items-center text-[var(--admin-foreground)]">
              Public only
            </div>
          </div>
        </div>
        <label className="grid gap-2 text-sm">
          Description
          <textarea
            name="description"
            rows={3}
            maxLength={3000}
            value={form.description}
            onChange={(e) =>
              setForm((c) => ({ ...c, description: e.target.value }))
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
              onChange={(e) =>
                setForm((c) => ({
                  ...c,
                  groupType: e.target
                    .value as AdminContributionGroup["groupType"],
                }))
              }
              className="dashboard-input"
            >
              <option value="project">Team project</option>
              <option value="community">Community</option>
            </select>
          </label>
          <label className="grid gap-2 text-sm">
            Currency
            <input
              name="currency"
              required
              minLength={3}
              maxLength={3}
              pattern="[A-Za-z]{3}"
              autoComplete="off"
              value={form.currency || defaultCurrencyCode}
              onChange={(e) =>
                setForm((c) => ({
                  ...c,
                  currency: e.target.value.toUpperCase(),
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
              required
              min={0}
              max={1_000_000_000_000_000}
              step="0.01"
              value={form.targetAmount}
              onChange={(e) =>
                setForm((c) => ({ ...c, targetAmount: e.target.value }))
              }
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm">
            Confirmed ledger total
            <input
              type="number"
              name="currentTotal"
              readOnly
              aria-readonly="true"
              min={0}
              value={form.currentTotal}
              className="dashboard-input cursor-not-allowed opacity-80"
            />
            <span className="text-xs leading-5 text-[var(--admin-text-muted)]">
              Derived from confirmed contribution records.
            </span>
          </label>
          <label className="grid gap-2 text-sm">
            Participant count
            <input
              type="number"
              name="memberCount"
              readOnly
              aria-readonly="true"
              min={0}
              step={1}
              value={form.memberCount}
              className="dashboard-input cursor-not-allowed opacity-80"
            />
            <span className="text-xs leading-5 text-[var(--admin-text-muted)]">
              Derived from the scoped contribution ledger.
            </span>
          </label>
        </div>
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
          <input
            type="checkbox"
            name="isClosed"
            checked={form.isClosed}
            onChange={(e) =>
              setForm((c) => ({ ...c, isClosed: e.target.checked }))
            }
          />
          Closed to new supporter activity
        </label>
        <button
          type="submit"
          className="admin-action-button min-h-12 !bg-action-blue !text-white hover:!bg-action-blue-hover disabled:opacity-70"
        >
          {form.id ? "Save Initiative" : "Create Initiative"}
        </button>
      </fieldset>
    </form>
  );
}
