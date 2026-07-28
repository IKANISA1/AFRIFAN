"use client";

import type { Dispatch, SetStateAction } from "react";
import type { MatchFormState } from "./match-form-state";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { showAdminToast } from "@/components/admin/admin-toast";
import type { SupabaseClient } from "@supabase/supabase-js";
import { saveAdminMatch } from "@/lib/data/admin/matches";
import type { AdminAccess } from "@/lib/types";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

interface MatchFormProps {
  form: MatchFormState;
  setForm: Dispatch<SetStateAction<MatchFormState>>;
  emptyForm: MatchFormState;
  client: SupabaseClient | null;
  access: AdminAccess;
  onSaved: () => Promise<void>;
  onConflict: () => Promise<void>;
  onCancel?: () => void;
}

export function MatchForm({
  form,
  setForm,
  emptyForm,
  client,
  access,
  onSaved,
  onConflict,
  onCancel,
}: MatchFormProps) {
  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    const saving = form.id ? "Saving fixture..." : "Creating fixture...";
    showAdminToast(saving, "info");

    try {
      await saveAdminMatch(client, access, {
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
        matchStatus: String(formData.get("matchStatus") ?? "scheduled"),
        homeScore: Number(formData.get("homeScore") ?? 0),
        awayScore: Number(formData.get("awayScore") ?? 0),
        liveMinute: String(formData.get("liveMinute") ?? "").trim()
          ? Number(formData.get("liveMinute"))
          : null,
        matchSummary: String(formData.get("matchSummary") ?? ""),
        isFeatured: formData.get("isFeatured") === "on",
      });
      setForm(emptyForm);
      await onSaved();
      showAdminToast("Fixture saved.", "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await onConflict();
      }
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save match.",
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
    <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          {form.id ? "Edit fixture" : "New fixture"}
        </p>
        <div className="flex items-center gap-2">
          {onCancel ? (
            <button
              type="button"
              onClick={onCancel}
              className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
            >
              Close
            </button>
          ) : null}
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
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Home team
          <input name="homeTeam" {...field("homeTeam")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          Away team
          <input name="awayTeam" required {...field("awayTeam")} className="dashboard-input" />
        </label>
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
        <label className="grid gap-2 text-sm">
          Match status
          <select name="matchStatus" {...field("matchStatus")} className="dashboard-input">
            <option value="scheduled">Scheduled</option>
            <option value="live">Live</option>
            <option value="halftime">Half-time</option>
            <option value="fulltime">Full-time</option>
            <option value="postponed">Postponed</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </label>
        <AdminImageField
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
          subject={`${form.homeTeam || "Home"} vs ${form.awayTeam || "Away"}`}
          previewAlt="Fixture hero preview"
          promptPlaceholder="Example: Intense matchday hero image for Home vs Away under stadium lights, premium sports-poster energy, room for headline overlay."
          className="sm:col-span-2"
        />
      </div>
      <div className="grid gap-4 sm:grid-cols-3">
        <label className="grid gap-2 text-sm">
          Home score
          <input type="number" name="homeScore" {...field("homeScore")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          Away score
          <input type="number" name="awayScore" {...field("awayScore")} className="dashboard-input" />
        </label>
        <label className="grid gap-2 text-sm">
          Live minute
          <input type="number" name="liveMinute" {...field("liveMinute")} className="dashboard-input" />
        </label>
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
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
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
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
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
        className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
      >
        {form.id ? "Save fixture" : "Create fixture"}
      </button>
    </form>
  );
}
