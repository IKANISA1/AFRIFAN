import { TeamSelect } from "@/components/team-select";
import type { Dispatch, SetStateAction } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { showAdminToast } from "@/components/admin/admin-toast";
import { saveAdminStandingRow } from "@/lib/data/admin/standings";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { AdminAccess } from "@/lib/types";
import { emptyForm, type StandingForm } from "./standing-state";

interface StandingEditorFormProps {
  form: StandingForm;
  setForm: Dispatch<SetStateAction<StandingForm>>;
  client: SupabaseClient | null;
  access: AdminAccess;
  onSaved: () => Promise<void>;
  onConflict: () => Promise<void>;
  onFailure?: (error: unknown) => void;
  onCancel?: () => void;
}

export function StandingEditorForm({
  form,
  setForm,
  client,
  access,
  onSaved,
  onConflict,
  onFailure,
  onCancel,
}: StandingEditorFormProps) {
  async function submitForm(formData: FormData) {
    if (client == null) return;

    showAdminToast(form.id ? "Saving row..." : "Adding row...", "info");
    try {
      await saveAdminStandingRow(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        position: Number(formData.get("position") ?? 0),
        club: String(formData.get("club") ?? ""),
        clubSlug: String(formData.get("clubSlug") ?? "").trim() || null,
        played: Number(formData.get("played") ?? 0),
        goalDifference: Number(formData.get("goalDifference") ?? 0),
        points: Number(formData.get("points") ?? 0),
        form: String(formData.get("form") ?? "")
          .split(",")
          .map((item) => item.trim().toUpperCase())
          .filter(Boolean)
          .slice(0, 5),
      });
      setForm(emptyForm);
      await onSaved();
      showAdminToast("Standing row saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await onConflict();
        return;
      }
      onFailure?.(caught);
      showAdminToast(
        "Could not confirm the standings change.",
        "error",
      );
    }
  }

  return (
    <form action={submitForm} className="ui-panel grid gap-4 rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-medium normal-case leading-none">
          {form.id ? "Edit row" : "New row"}
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
          {form.id ? (
            <button
              type="button"
              onClick={() => {
                setForm(emptyForm);
                showAdminToast("Form cleared.", "info");
              }}
              className="min-h-12 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
            >
              Clear
            </button>
          ) : null}
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Position
          <input
            type="number"
            name="position"
            required
            min={1}
            value={form.position}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                position: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <TeamSelect name="club" value={form.club} onChange={value => setForm(current => ({...current, club: value}))} />
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <label className="grid gap-2 text-sm">
          Played
          <input
            type="number"
            name="played"
            value={form.played}
            onChange={(event) =>
              setForm((current) => ({ ...current, played: event.target.value }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Goal diff
          <input
            type="number"
            name="goalDifference"
            value={form.goalDifference}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                goalDifference: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Points
          <input
            type="number"
            name="points"
            value={form.points}
            onChange={(event) =>
              setForm((current) => ({ ...current, points: event.target.value }))
            }
            className="dashboard-input"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm">
        Club slug (optional)
        <input
          name="clubSlug"
          value={form.clubSlug}
          onChange={(event) =>
            setForm((current) => ({ ...current, clubSlug: event.target.value }))
          }
          placeholder="club_slug"
          className="dashboard-input"
        />
      </label>

      <label className="grid gap-2 text-sm">
        Form (W, D, L comma separated)
        <input
          name="form"
          value={form.form}
          onChange={(event) =>
            setForm((current) => ({ ...current, form: event.target.value }))
          }
          placeholder="W, W, D, L, W"
          className="dashboard-input"
        />
      </label>

      <button
        type="submit"
        className="min-h-12 rounded-full bg-action-blue px-5 py-3 font-semibold text-white transition hover:bg-action-blue-hover"
      >
        {form.id ? "Save row" : "Add row"}
      </button>
    </form>
  );
}
