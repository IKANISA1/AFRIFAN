"use client";
import type { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import { TeamSelect } from "@/components/team-select";
import { fixtureInitials } from "@/lib/team-identity";

import type { Dispatch, SetStateAction } from "react";
import type { MatchFormState } from "./match-form-state";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { showAdminToast } from "@/components/admin/admin-toast";
import type { SupabaseClient } from "@supabase/supabase-js";
import { saveAdminMatch } from "@/lib/data/admin/matches";
import type { AdminAccess } from "@/lib/types";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

interface MatchFormProps {
  draft: ReturnType<typeof useAdminMediaDraftScope>;
  form: MatchFormState;
  setForm: Dispatch<SetStateAction<MatchFormState>>;
  emptyForm: MatchFormState;
  client: SupabaseClient | null;
  access: AdminAccess;
  onSaved: () => Promise<void>;
  onConflict: () => Promise<void>;
  onFailure?: (error: unknown) => void;
  onCancel?: () => void;
}

export function MatchForm({
  form,
  draft,
  setForm,
  emptyForm,
  client,
  access,
  onSaved,
  onConflict,
  onFailure,
  onCancel,
}: MatchFormProps) {
  async function submitForm(formData: FormData) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    if (client == null) {
      return;
    }

    const saving = form.id ? "Saving fixture..." : "Creating fixture...";
    showAdminToast(saving, "info");

    try {
      await draft.runSave(() => saveAdminMatch(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        homeTeam: String(formData.get("homeTeam") ?? ""),
        awayTeam: String(formData.get("awayTeam") ?? ""),
        competition: String(formData.get("competition") ?? ""),
        venue: String(formData.get("venue") ?? ""),
        matchDate: String(formData.get("matchDate") ?? ""),
        kickoffTime: String(formData.get("kickoffTime") ?? "18:00"),
        isOnSale: formData.get("isOnSale") === "on",
        generalPrice: Number(formData.get("generalPrice") ?? 0),
        vipPrice: Number(formData.get("vipPrice") ?? 0),
        capacity: Number(formData.get("capacity") ?? 0),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        matchStatus: form.matchStatus,
        homeScore: Number(form.homeScore),
        awayScore: Number(form.awayScore),
        liveMinute: form.liveMinute.trim() ? Number(form.liveMinute) : null,
        matchSummary: String(formData.get("matchSummary") ?? ""),
        isFeatured: formData.get("isFeatured") === "on",
      }), form.id || undefined);
      if (!await draft.resetDraft(form.id || undefined)) { showAdminToast("Saved. Recover this composer before starting another draft.", "info"); return; }
      setForm(emptyForm);
      await onSaved();
      showAdminToast("Fixture saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await onConflict();
        return;
      }
      onFailure?.(caught);
      showAdminToast(
        "Could not confirm the fixture change.",
        "error",
      );
    }
  }

  const field = (name: keyof MatchFormState) => ({
    value: form[name] as string,
    onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
      setForm((current) => ({
        ...current,
        [name]: event.target.value,
      })),
  });

  return (
    <form action={submitForm} className="ui-panel grid gap-4 rounded-[32px] p-6">
      {draft.error ? <p role="alert">{draft.error}</p> : null}
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-medium normal-case leading-none">
          {form.id ? "Edit fixture" : "New fixture"}
        </p>
        <div className="flex items-center gap-2">
          {onCancel ? (
            <button
              type="button"
              onClick={onCancel}
              className="min-h-12 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
            >
              Close
            </button>
          ) : null}
          {form.id || draft.scopeKey ? (
            <button
              type="button"
              onClick={async () => { if (await draft.resetDraft(form.id || undefined)) setForm(emptyForm); }}
              className="min-h-12 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
            >
              Clear
            </button>
          ) : null}
        </div>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <TeamSelect name="homeTeam" value={form.homeTeam} onChange={value => setForm(current => ({...current, homeTeam: value}))} label="First team" />
        <TeamSelect name="awayTeam" value={form.awayTeam} onChange={value => setForm(current => ({...current, awayTeam: value}))} label="Second team" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Competition
          <input name="competition" {...field("competition")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          Venue
          <input name="venue" {...field("venue")} className="dashboard-input" />
        </label>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Match date
          <input type="date" name="matchDate" {...field("matchDate")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          Kickoff time
          <input type="time" name="kickoffTime" {...field("kickoffTime")} className="dashboard-input" />
        </label>
      </div>
      <div className="grid gap-4 sm:grid-cols-3">
        <label className="grid gap-2 text-sm">
          General price
          <input type="number" name="generalPrice" {...field("generalPrice")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          VIP price
          <input type="number" name="vipPrice" {...field("vipPrice")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          Capacity
          <input type="number" name="capacity" {...field("capacity")} className="dashboard-input" />
        </label>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <AdminImageField
          scopeKey={form.id || draft.scopeKey || "unavailable"}
          recoveryOnly={!form.id && draft.legacyUnbound}
          onRecoveryResolved={draft.refreshRecovery}
          disabled={!draft.ready && !draft.legacyUnbound}
          label="Hero image"
          name="imageUrl"
          value={form.imageUrl}
          onChange={(nextValue) =>
            setForm((current) => ({
              ...current,
              imageUrl: nextValue,
            }))
          }
          mediaKind="match"
          subject={fixtureInitials(form.homeTeam, form.awayTeam)}
          previewAlt="Fixture hero preview"
          promptPlaceholder="Matchday photograph under stadium lights."
          className="sm:col-span-2"
        />
      </div>
      <div className="rounded-2xl bg-[var(--admin-surface-muted)] p-4 text-sm">
        <p className="font-medium">Automatic match results</p>
        <p className="mt-2 text-[var(--admin-text-muted)]">
          Scores, match status and live minutes are managed by the LiveScore integration.
        </p>
        {form.id ? (
          <p className="mt-2">{form.matchStatus} · {form.homeScore}–{form.awayScore}</p>
        ) : null}
      </div>
      <label className="grid gap-2 text-sm">
        Match summary
        <textarea
          name="matchSummary"
          rows={4}
          {...field("matchSummary")}
          className="dashboard-input min-h-28 resize-y"
        />
      </label>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
          <input
            type="checkbox"
            name="isOnSale"
            checked={form.isOnSale as boolean}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                isOnSale: event.target.checked,
              }))
            }
          />
          Tickets on sale
        </label>
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
          <input
            type="checkbox"
            name="isFeatured"
            checked={form.isFeatured as boolean}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                isFeatured: event.target.checked,
              }))
            }
          />
          Feature on public surfaces
        </label>
      </div>
      <button
        type="submit"
        className="min-h-12 rounded-full bg-action-blue px-5 py-3 font-semibold text-white transition hover:bg-action-blue-hover"
      >
        {form.id ? "Save fixture" : "Create fixture"}
      </button>
    </form>
  );
}
