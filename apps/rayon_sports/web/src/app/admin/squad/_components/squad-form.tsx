"use client";

import type { Dispatch, SetStateAction } from "react";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { saveAdminSquadPlayer } from "@/lib/data/admin/squad";
import { emptySquadForm, type SquadForm } from "./squad-form-state";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

interface SquadFormProps {
  form: SquadForm;
  setForm: Dispatch<SetStateAction<SquadForm>>;
  client: ReturnType<typeof useAdminPortal>["client"];
  access: ReturnType<typeof useAdminPortal>["access"];
  onSaved: () => Promise<void>;
  onConflict: () => Promise<void>;
}

export function SquadEditorForm({ form, setForm, client, access, onSaved, onConflict }: SquadFormProps) {
  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    showAdminToast(form.id ? "Saving player..." : "Adding player...", "info");

    try {
      await saveAdminSquadPlayer(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        name: String(formData.get("name") ?? ""),
        role: String(formData.get("role") ?? "Midfielder"),
        number: Number(formData.get("number") ?? 0),
        nationality: String(formData.get("nationality") ?? "Rwanda"),
        bio: String(formData.get("bio") ?? ""),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptySquadForm);
      await onSaved();
      showAdminToast("Player saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await onConflict();
      }
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save player.",
        "error",
      );
    }
  }

  return (
    <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          {form.id ? "Edit player" : "New player"}
        </p>
        {form.id ? (
          <button
            type="button"
            onClick={() => {
              setForm(emptySquadForm);
              showAdminToast("Form cleared.", "info");
            }}
            className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
          >
            Clear
          </button>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Player name
          <input
            name="name"
            required
            value={form.name}
            onChange={(e) => setForm((c) => ({ ...c, name: e.target.value }))}
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Shirt number
          <input
            type="number"
            name="number"
            required
            min={1}
            max={99}
            value={form.number}
            onChange={(e) => setForm((c) => ({ ...c, number: e.target.value }))}
            className="dashboard-input"
          />
        </label>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Position
          <select
            name="role"
            value={form.role}
            onChange={(e) => setForm((c) => ({ ...c, role: e.target.value }))}
            className="dashboard-input"
          >
            <option value="Goalkeeper">Goalkeeper</option>
            <option value="Defender">Defender</option>
            <option value="Midfielder">Midfielder</option>
            <option value="Forward">Forward</option>
          </select>
        </label>
        <label className="grid gap-2 text-sm">
          Nationality
          <input
            name="nationality"
            value={form.nationality}
            onChange={(e) => setForm((c) => ({ ...c, nationality: e.target.value }))}
            className="dashboard-input"
          />
        </label>
      </div>

      <AdminImageField
        label="Player image"
        name="imageUrl"
        value={form.imageUrl}
        onChange={(nextValue) => setForm((current) => ({ ...current, imageUrl: nextValue }))}
        mediaKind="squad_player"
        subject={form.name}
        previewAlt="Player preview"
        promptPlaceholder="Example: Clean player portrait in club colors, sharp lighting, premium media-day look, waist-up framing."
      />

      <label className="grid gap-2 text-sm">
        <div className="flex items-center justify-between">
          <span>Bio</span>
          <span className="font-mono text-[10px] text-slate-400">{form.bio.length} chars</span>
        </div>
        <textarea
          name="bio"
          rows={4}
          value={form.bio}
          onChange={(e) => setForm((c) => ({ ...c, bio: e.target.value }))}
          className="dashboard-input min-h-28 resize-y"
        />
      </label>

      <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
        <input
          type="checkbox"
          name="isActive"
          checked={form.isActive}
          onChange={(e) => setForm((c) => ({ ...c, isActive: e.target.checked }))}
        />
        Active in squad
      </label>

      <button
        type="submit"
        className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
      >
        {form.id ? "Save player" : "Add player"}
      </button>
    </form>
  );
}
