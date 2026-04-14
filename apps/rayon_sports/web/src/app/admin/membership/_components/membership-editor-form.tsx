import { Dispatch, SetStateAction } from "react";
import { SupabaseClient } from "@supabase/supabase-js";
import { showAdminToast } from "@/components/admin/admin-toast";
import { saveAdminMembershipPackage } from "@/lib/data/admin/membership";
import type { AdminAccess, AdminMembershipPackage } from "@/lib/types";
import { emptyForm, type MembershipForm } from "./membership-state";

interface MembershipEditorFormProps {
  form: MembershipForm;
  setForm: Dispatch<SetStateAction<MembershipForm>>;
  currencyCode: string;
  client: SupabaseClient | null;
  access: AdminAccess;
  onSaved: () => Promise<void>;
}

export function MembershipEditorForm({
  form,
  setForm,
  currencyCode,
  client,
  access,
  onSaved,
}: MembershipEditorFormProps) {
  async function submitForm(formData: FormData) {
    if (client == null) return;

    showAdminToast(form.id ? "Saving tier..." : "Creating tier...", "info");
    try {
      await saveAdminMembershipPackage(client, access, {
        id: form.id || null,
        tier: String(
          formData.get("tier") ?? "fan",
        ) as AdminMembershipPackage["tier"],
        title: String(formData.get("title") ?? ""),
        description: String(formData.get("description") ?? ""),
        annualPrice: Number(formData.get("annualPrice") ?? 0),
        perks: String(formData.get("perks") ?? "")
          .split("\n")
          .map((item) => item.trim())
          .filter(Boolean),
        sortOrder: Number(formData.get("sortOrder") ?? 0),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptyForm);
      await onSaved();
      showAdminToast("Membership tier saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save tier.",
        "error",
      );
    }
  }

  return (
    <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          {form.id ? "Edit tier" : "New tier"}
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
          Tier
          <select
            name="tier"
            value={form.tier}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                tier: event.target.value as AdminMembershipPackage["tier"],
              }))
            }
            className="dashboard-input"
          >
            <option value="fan">Fan</option>
            <option value="bronze">Bronze</option>
            <option value="gold">Gold</option>
            <option value="platinum">Platinum</option>
          </select>
        </label>
        <label className="grid gap-2 text-sm">
          Title
          <input
            name="title"
            required
            value={form.title}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                title: event.target.value,
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
          className="dashboard-input min-h-20 resize-y"
        />
      </label>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Annual price ({currencyCode})
          <input
            type="number"
            name="annualPrice"
            value={form.annualPrice}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                annualPrice: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Sort order
          <input
            type="number"
            name="sortOrder"
            value={form.sortOrder}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                sortOrder: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm">
        <div className="flex items-center justify-between">
          <span>Perks (one per line)</span>
          <span className="font-mono text-[10px] text-slate-400">
            {form.perks.split("\n").filter(Boolean).length} perks
          </span>
        </div>
        <textarea
          name="perks"
          rows={5}
          value={form.perks}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              perks: event.target.value,
            }))
          }
          className="dashboard-input min-h-28 resize-y"
        />
      </label>

      <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
        <input
          type="checkbox"
          name="isActive"
          checked={form.isActive}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              isActive: event.target.checked,
            }))
          }
        />
        Active and visible
      </label>

      <button
        type="submit"
        className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
      >
        {form.id ? "Save tier" : "Create tier"}
      </button>
    </form>
  );
}
