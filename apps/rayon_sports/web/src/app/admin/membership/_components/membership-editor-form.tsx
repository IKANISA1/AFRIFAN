import { Dispatch, SetStateAction, useEffect, useRef, useState } from "react";
import { SupabaseClient } from "@supabase/supabase-js";
import { showAdminToast } from "@/components/admin/admin-toast";
import { saveAdminMembershipPackage } from "@/lib/data/admin/membership";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { AdminAccess, AdminMembershipPackage } from "@/lib/types";
import { emptyForm, type MembershipForm } from "./membership-state";

interface MembershipEditorFormProps {
  form: MembershipForm;
  setForm: Dispatch<SetStateAction<MembershipForm>>;
  currencyCode: string;
  client: SupabaseClient | null;
  access: AdminAccess;
  onSaved: () => Promise<void>;
  onConflict: () => Promise<void>;
}

export function MembershipEditorForm({
  form,
  setForm,
  currencyCode,
  client,
  access,
  onSaved,
  onConflict,
}: MembershipEditorFormProps) {
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const errorRef = useRef<HTMLDivElement>(null);
  const submittingRef = useRef(false);

  useEffect(() => {
    if (errorMessage != null) {
      errorRef.current?.focus();
    }
  }, [errorMessage]);

  async function submitForm(formData: FormData) {
    if (client == null || submittingRef.current) return;

    submittingRef.current = true;
    setSubmitting(true);
    setErrorMessage(null);
    showAdminToast(form.id ? "Saving tier..." : "Creating tier...", "info");
    try {
      await saveAdminMembershipPackage(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        tier: String(
          formData.get("tier") ?? "imena",
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
      if (isAdminMutationConflict(caught)) {
        await onConflict();
      }
      const message = caught instanceof Error
        ? caught.message
        : "Could not save tier.";
      setErrorMessage(message);
      showAdminToast(message, "error");
    } finally {
      submittingRef.current = false;
      setSubmitting(false);
    }
  }

  return (
    <form
      onSubmit={(event) => {
        event.preventDefault();
        void submitForm(new FormData(event.currentTarget));
      }}
      aria-labelledby="membership-form-title"
      aria-describedby={errorMessage ? "membership-form-error" : undefined}
      data-keyboard-safe-form="true"
      className="glass-panel grid gap-4 rounded-[32px] p-6 max-sm:max-h-[calc(100dvh-8rem)] max-sm:overflow-y-auto max-sm:overscroll-contain max-sm:scroll-pb-24"
    >
      <div className="flex items-center gap-3">
        <p
          id="membership-form-title"
          className="font-display text-3xl font-bold uppercase leading-none"
        >
          {form.id ? "Edit tier" : "New tier"}
        </p>
      </div>

      {errorMessage ? (
        <div
          ref={errorRef}
          id="membership-form-error"
          role="alert"
          tabIndex={-1}
          className="rounded-2xl border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200 outline-none focus-visible:ring-2 focus-visible:ring-rose-300"
        >
          {errorMessage}
        </div>
      ) : null}

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
            className="dashboard-input scroll-mb-24"
          >
            <option value="ingenzi-imanzi">Ingenzi / Imanzi</option>
            <option value="inyamibwa">Inyamibwa</option>
            <option value="imena">Imena</option>
            <option value="bronze">Bronze</option>
            <option value="silver">Silver</option>
            <option value="gold">Gold</option>
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
            className="dashboard-input scroll-mb-24"
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
          className="dashboard-input min-h-20 resize-y scroll-mb-24"
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
            className="dashboard-input scroll-mb-24"
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
            className="dashboard-input scroll-mb-24"
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
          className="dashboard-input min-h-28 resize-y scroll-mb-24"
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

      <div
        data-keyboard-safe-actions="true"
        className="grid gap-3 max-sm:sticky max-sm:bottom-0 max-sm:z-10 max-sm:-mx-2 max-sm:grid-cols-2 max-sm:rounded-2xl max-sm:border max-sm:border-border-soft max-sm:bg-slate-950/95 max-sm:p-2 max-sm:backdrop-blur"
      >
        {form.id ? (
          <button
            type="button"
            disabled={submitting}
            onClick={() => setForm(emptyForm)}
            className="rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-slate-100 transition hover:bg-white/8 disabled:cursor-not-allowed disabled:opacity-60"
          >
            Clear
          </button>
        ) : null}
        <button
          type="submit"
          disabled={submitting || client == null}
          aria-busy={submitting}
          className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:cursor-not-allowed disabled:opacity-60"
        >
          {submitting
            ? form.id
              ? "Saving tier..."
              : "Creating tier..."
            : form.id
              ? "Save tier"
              : "Create tier"}
        </button>
      </div>
    </form>
  );
}
