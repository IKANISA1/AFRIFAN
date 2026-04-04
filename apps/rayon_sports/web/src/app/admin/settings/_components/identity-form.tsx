"use client";

import type { Dispatch, SetStateAction } from "react";
import { Skeleton } from "@/components/skeleton";
import type { SettingsForm } from "./settings-form-state";

interface IdentityFormProps {
  form: SettingsForm | null;
  setForm: Dispatch<SetStateAction<SettingsForm | null>>;
  loading: boolean;
  onReload: () => void;
  onSave: () => void;
}

export function IdentityForm({
  form,
  setForm,
  loading,
  onReload,
  onSave,
}: IdentityFormProps) {
  function updateField<K extends keyof SettingsForm>(field: K, value: SettingsForm[K]) {
    setForm((current) => (current ? { ...current, [field]: value } : current));
  }

  return (
    <section className="glass-panel grid gap-4 rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          Identity settings
        </p>
        <button
          type="button"
          onClick={onReload}
          className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
        >
          Reload
        </button>
      </div>

      {loading || form == null ? (
        <div className="space-y-4">
          {Array.from({ length: 7 }).map((_, index) => (
            <Skeleton key={index} className="h-14 rounded-[22px]" />
          ))}
        </div>
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Club name
              <input value={form.clubName} onChange={(e) => updateField("clubName", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Short name
              <input value={form.shortName} onChange={(e) => updateField("shortName", e.target.value)} className="dashboard-input" />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Nickname
              <input value={form.nickname} onChange={(e) => updateField("nickname", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Country code
              <input value={form.countryCode} onChange={(e) => updateField("countryCode", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Default language
              <input value={form.defaultLanguage} onChange={(e) => updateField("defaultLanguage", e.target.value)} className="dashboard-input" />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              League
              <input value={form.league} onChange={(e) => updateField("league", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Region
              <input value={form.region} onChange={(e) => updateField("region", e.target.value)} className="dashboard-input" />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Currency code
              <input value={form.currencyCode} onChange={(e) => updateField("currencyCode", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Currency symbol
              <input value={form.currencySymbol} onChange={(e) => updateField("currencySymbol", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Supported languages
              <input value={form.supportedLanguagesText} onChange={(e) => updateField("supportedLanguagesText", e.target.value)} className="dashboard-input" />
            </label>
          </div>
          <label className="grid gap-2 text-sm">
            Official contact
            <textarea rows={2} value={form.officialContact} onChange={(e) => updateField("officialContact", e.target.value)} className="dashboard-input min-h-20 resize-y" />
          </label>
          <label className="grid gap-2 text-sm">
            Official logo URL
            <input value={form.officialLogoUrl} onChange={(e) => updateField("officialLogoUrl", e.target.value)} className="dashboard-input" />
          </label>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Facebook URL
              <input value={form.facebookUrl} onChange={(e) => updateField("facebookUrl", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              X / Twitter URL
              <input value={form.xUrl} onChange={(e) => updateField("xUrl", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Instagram URL
              <input value={form.instagramUrl} onChange={(e) => updateField("instagramUrl", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              TikTok URL
              <input value={form.tiktokUrl} onChange={(e) => updateField("tiktokUrl", e.target.value)} className="dashboard-input" />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Primary color
              <input value={form.primaryColorHex} onChange={(e) => updateField("primaryColorHex", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Secondary color
              <input value={form.secondaryColorHex} onChange={(e) => updateField("secondaryColorHex", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Accent color
              <input value={form.accentColorHex} onChange={(e) => updateField("accentColorHex", e.target.value)} className="dashboard-input" />
            </label>
          </div>
          <button
            type="button"
            onClick={onSave}
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            Save settings
          </button>
        </>
      )}
    </section>
  );
}
