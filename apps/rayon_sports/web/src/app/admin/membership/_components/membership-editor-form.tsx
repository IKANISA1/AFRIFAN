import { Dispatch, SetStateAction, useEffect, useRef, useState } from "react";
import { SupabaseClient } from "@supabase/supabase-js";
import { showAdminToast } from "@/components/admin/admin-toast";
import { canConfigureAdminMembership, saveAdminMembershipPackage } from "@/lib/data/admin/membership";
import type { AdminPartnerOption } from "@/lib/data/admin/partner-pools";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { AdminAccess, AdminMembershipPackage } from "@/lib/types";
import { emptyForm, type MembershipForm } from "./membership-state";

interface MembershipEditorFormProps {
  form: MembershipForm;
  setForm: Dispatch<SetStateAction<MembershipForm>>;
  currencyCode: string;
  client: SupabaseClient | null;
  access: AdminAccess;
  partners: AdminPartnerOption[];
  disabled?: boolean;
  onSaved: () => Promise<void>;
  onFailure?: (error: unknown) => void;
  onConflict: () => Promise<void>;
}

export function MembershipEditorForm({
  form,
  setForm,
  currencyCode,
  client,
  access,
  partners,
  disabled = false,
  onSaved,
  onFailure,
  onConflict,
}: MembershipEditorFormProps) {
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const errorRef = useRef<HTMLDivElement>(null);
  const submittingRef = useRef(false);
  const mountedRef = useRef(false);
  const locked = disabled || !canConfigureAdminMembership(access) || partners.length === 0;
  useEffect(() => { mountedRef.current = true; return () => { mountedRef.current = false; }; }, []);

  useEffect(() => {
    if (errorMessage != null) {
      errorRef.current?.focus();
    }
  }, [errorMessage]);

  async function submitForm(formData: FormData) {
    if (client == null || locked || submittingRef.current) return;

    submittingRef.current = true;
    setSubmitting(true);
    setErrorMessage(null);
    showAdminToast(form.id ? "Saving tier..." : "Creating tier...", "info");
    try {
      const title = String(formData.get("title") ?? "").trim();
      const subtitle = String(formData.get("subtitle") ?? "").trim();
      const partnerId = String(formData.get("partnerId") ?? "");
      const description = String(formData.get("description") ?? "").trim();
      const annualPrice = Number(formData.get("annualPrice") ?? 0);
      const sortOrder = Number(formData.get("sortOrder") ?? 0);
      const perks = String(formData.get("perks") ?? "")
        .split("\n")
        .map((item) => item.trim())
        .filter(Boolean);
      if (
        title.length === 0 ||
        title.length > 160 ||
        subtitle.length === 0 || subtitle.length > 240 ||
        !partners.some(partner => partner.id === partnerId) ||
        description.length === 0 ||
        description.length > 2_000 ||
        !Number.isInteger(annualPrice) ||
        annualPrice <= 0 ||
        annualPrice > 1_000_000_000 ||
        !Number.isInteger(sortOrder) ||
        sortOrder < 0 ||
        sortOrder > 1_000_000 ||
        perks.length > 20 ||
        perks.some((perk) => perk.length > 240)
      ) {
        throw new Error("invalid_membership_tier_input");
      }

      const creationId = form.id ? null : form.creationId || crypto.randomUUID();
      if (creationId && !form.creationId) setForm(current => ({ ...current, creationId }));
      await saveAdminMembershipPackage(client, access, {
        id: form.id || null,
        creationId,
        partnerId,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        tier: String(
          formData.get("tier") ?? "imena",
        ) as AdminMembershipPackage["tier"],
        title,
        subtitle,
        description,
        annualPrice,
        perks,
        sortOrder,
        isActive: formData.get("isActive") === "on",
      });
      if (!mountedRef.current) return;
      setForm(emptyForm);
      showAdminToast("Membership tier saved.", "success");
      await onSaved();
    } catch (caught) {
      if (!mountedRef.current) return;
      onFailure?.(caught);
      if (isAdminMutationConflict(caught)) {
        await onConflict();
      }
      if (!mountedRef.current) return;
      const message =
        caught instanceof Error &&
        caught.message === "invalid_membership_tier_input"
          ? "Review the tier fields and bounded values before retrying."
          : "Could not save the membership tier. Retry when service recovers.";
      setErrorMessage(message);
      showAdminToast(message, "error");
    } finally {
      submittingRef.current = false;
      if (mountedRef.current) setSubmitting(false);
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
      className="ui-panel grid gap-4 rounded-[32px] p-6 max-sm:max-h-[calc(100dvh-8rem)] max-sm:overflow-y-auto max-sm:overscroll-contain max-sm:scroll-pb-24"
    >
      <div className="flex items-center gap-3">
        <p
          id="membership-form-title"
          className="font-display text-3xl font-medium normal-case leading-none"
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
          className="rounded-2xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-[var(--admin-danger-text)] outline-none focus-visible:ring-2 focus-visible:ring-error"
        >
          {errorMessage}
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">Current club partner
          <select name="partnerId" required value={form.partnerId} disabled={locked || submitting}
            onChange={event => setForm(current => ({ ...current, partnerId: event.target.value }))} className="dashboard-input scroll-mb-24">
            <option value="">Select a configured partner</option>{partners.map(partner => <option key={partner.id} value={partner.id}>{partner.name}</option>)}
          </select>
        </label>
        <label className="grid gap-2 text-sm">
          Tier
          <select
            name="tier"
            disabled={locked || submitting}
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
            maxLength={160}
            disabled={locked || submitting}
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

      <label className="grid gap-2 text-sm">Subtitle
        <input name="subtitle" required maxLength={240} value={form.subtitle} disabled={locked || submitting}
          onChange={event => setForm(current => ({ ...current, subtitle: event.target.value }))} className="dashboard-input scroll-mb-24" />
      </label>
      {partners.length === 0 && <p role="status">No active partner is configured for this club. Configure the club partner before creating a membership tier.</p>}
      {form.creationId && <p className="break-all text-xs text-muted">Original creation reference: {form.creationId}. Keep this draft while recovering an unconfirmed save.</p>}
      <p className="text-sm text-muted">Visibility does not approve commercial classification or platform billing. New tiers retain the unclassified policy until separately reviewed.</p>

      <label className="grid gap-2 text-sm">
        Description
        <textarea
          name="description"
          required
          maxLength={2_000}
          disabled={locked || submitting}
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
            min={1}
            max={1_000_000_000}
            step="any"
            required
            disabled={locked || submitting}
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
            min={0}
            max={1_000_000}
            step={1}
            required
            disabled={locked || submitting}
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
          <span className="font-mono text-xs text-[var(--admin-text-muted)]">
            {form.perks.split("\n").filter(Boolean).length} perks
          </span>
        </div>
        <textarea
          name="perks"
          maxLength={4_800}
          disabled={locked || submitting}
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

      <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
        <input
          type="checkbox"
          name="isActive"
          disabled={locked || submitting}
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
        className="grid gap-3 max-sm:sticky max-sm:bottom-0 max-sm:z-10 max-sm:-mx-2 max-sm:grid-cols-2 max-sm:rounded-2xl max-sm:border max-sm:border-border-soft max-sm:bg-background/95 max-sm:p-2 max-sm:backdrop-blur"
      >
        {form.id ? (
          <button
            type="button"
            disabled={locked || submitting}
            onClick={() => setForm(emptyForm)}
            className="rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)] disabled:cursor-not-allowed disabled:opacity-60"
          >
            Clear
          </button>
        ) : null}
        <button
          type="submit"
          disabled={locked || submitting || client == null}
          aria-busy={submitting}
          className="rounded-full bg-action-blue px-5 py-3 font-semibold text-white transition hover:bg-action-blue-hover disabled:cursor-not-allowed disabled:opacity-60"
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
