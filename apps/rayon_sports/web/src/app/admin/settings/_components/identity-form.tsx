"use client";

import type { Dispatch, SetStateAction } from "react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { Skeleton } from "@/components/skeleton";
import type { SettingsForm } from "./settings-form-state";

interface IdentityFormProps {
  form: SettingsForm | null;
  setForm: Dispatch<SetStateAction<SettingsForm | null>>;
  error: string | null;
  loading: boolean;
  onReload: () => void;
  onSave: () => void;
}

function normalizeLanguageList(value: string) {
  return value
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function isValidUrl(value: string) {
  if (!value.trim()) {
    return true;
  }

  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function isValidHexColor(value: string) {
  return /^#(?:[0-9a-fA-F]{3}){1,2}$/.test(value.trim());
}

function resolveColorValue(value: string) {
  return isValidHexColor(value) ? value : "#1A7A4E";
}

export function IdentityForm({
  form,
  setForm,
  error,
  loading,
  onReload,
  onSave,
}: IdentityFormProps) {
  function updateField<K extends keyof SettingsForm>(field: K, value: SettingsForm[K]) {
    setForm((current) => (current ? { ...current, [field]: value } : current));
  }

  const supportedLanguages = form ? normalizeLanguageList(form.supportedLanguagesText) : [];
  const defaultLanguage = form?.defaultLanguage.trim().toLowerCase() ?? "";
  const defaultLanguageOptions = form == null
    ? []
    : Array.from(new Set([defaultLanguage, ...supportedLanguages].filter(Boolean)));
  const urlErrors = form == null
    ? {}
    : {
        officialLogoUrl: isValidUrl(form.officialLogoUrl) ? null : "Enter a valid https:// URL.",
        facebookUrl: isValidUrl(form.facebookUrl) ? null : "Enter a valid https:// URL.",
        xUrl: isValidUrl(form.xUrl) ? null : "Enter a valid https:// URL.",
        instagramUrl: isValidUrl(form.instagramUrl) ? null : "Enter a valid https:// URL.",
        tiktokUrl: isValidUrl(form.tiktokUrl) ? null : "Enter a valid https:// URL.",
      };
  const colorErrors = form == null
    ? {}
    : {
        primaryColorHex: isValidHexColor(form.primaryColorHex) ? null : "Use a valid hex color like #1A7A4E.",
        secondaryColorHex: isValidHexColor(form.secondaryColorHex) ? null : "Use a valid hex color like #0E2B55.",
        accentColorHex: isValidHexColor(form.accentColorHex) ? null : "Use a valid hex color like #F7B500.",
      };
  const validationErrors = form == null
    ? []
    : [
        supportedLanguages.length === 0 ? "Add at least one supported language." : null,
        defaultLanguage && !supportedLanguages.includes(defaultLanguage)
          ? "Default language must appear in the supported languages list."
          : null,
        supportedLanguages.some((item) => item.length < 2 || item.length > 5)
          ? "Supported language codes should be 2-5 characters each."
          : null,
        form.countryCode.trim().length !== 2
          ? "Country code must be a 2-letter ISO code."
          : null,
        form.currencyCode.trim().length !== 3
          ? "Currency code must be a 3-letter ISO code."
          : null,
        ...Object.values(urlErrors),
        ...Object.values(colorErrors),
      ].filter((value): value is string => value != null);
  const isValid = validationErrors.length === 0;

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
        error && !loading ? (
          <AdminErrorState
            title="Settings could not be loaded"
            description={error}
            onRetry={onReload}
          />
        ) : (
        <div className="space-y-4">
          {Array.from({ length: 7 }).map((_, index) => (
            <Skeleton key={index} className="h-14 rounded-[22px]" />
          ))}
        </div>
        )
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
              <input
                value={form.countryCode}
                onChange={(e) =>
                  updateField("countryCode", e.target.value.toUpperCase().slice(0, 2))
                }
                maxLength={2}
                className="dashboard-input uppercase"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Default language
              <select
                value={defaultLanguage}
                onChange={(e) => updateField("defaultLanguage", e.target.value)}
                className="dashboard-input"
              >
                {defaultLanguageOptions.map((language) => (
                  <option key={language} value={language}>
                    {language}
                  </option>
                ))}
              </select>
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
              <input
                value={form.currencyCode}
                onChange={(e) =>
                  updateField("currencyCode", e.target.value.toUpperCase().slice(0, 3))
                }
                maxLength={3}
                className="dashboard-input uppercase"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Currency symbol
              <input value={form.currencySymbol} onChange={(e) => updateField("currencySymbol", e.target.value)} className="dashboard-input" />
            </label>
            <label className="grid gap-2 text-sm">
              Supported languages
              <input
                value={form.supportedLanguagesText}
                onChange={(e) => updateField("supportedLanguagesText", e.target.value)}
                className="dashboard-input"
                placeholder="rw, en, fr"
              />
            </label>
          </div>
          <label className="grid gap-2 text-sm">
            Official contact
            <textarea rows={2} value={form.officialContact} onChange={(e) => updateField("officialContact", e.target.value)} className="dashboard-input min-h-20 resize-y" />
          </label>
          <label className="grid gap-2 text-sm">
            Official logo URL
            <input type="url" value={form.officialLogoUrl} onChange={(e) => updateField("officialLogoUrl", e.target.value)} className="dashboard-input" />
            {urlErrors.officialLogoUrl ? <span className="text-xs text-rose-300">{urlErrors.officialLogoUrl}</span> : null}
          </label>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Facebook URL
              <input type="url" value={form.facebookUrl} onChange={(e) => updateField("facebookUrl", e.target.value)} className="dashboard-input" />
              {urlErrors.facebookUrl ? <span className="text-xs text-rose-300">{urlErrors.facebookUrl}</span> : null}
            </label>
            <label className="grid gap-2 text-sm">
              X / Twitter URL
              <input type="url" value={form.xUrl} onChange={(e) => updateField("xUrl", e.target.value)} className="dashboard-input" />
              {urlErrors.xUrl ? <span className="text-xs text-rose-300">{urlErrors.xUrl}</span> : null}
            </label>
            <label className="grid gap-2 text-sm">
              Instagram URL
              <input type="url" value={form.instagramUrl} onChange={(e) => updateField("instagramUrl", e.target.value)} className="dashboard-input" />
              {urlErrors.instagramUrl ? <span className="text-xs text-rose-300">{urlErrors.instagramUrl}</span> : null}
            </label>
            <label className="grid gap-2 text-sm">
              TikTok URL
              <input type="url" value={form.tiktokUrl} onChange={(e) => updateField("tiktokUrl", e.target.value)} className="dashboard-input" />
              {urlErrors.tiktokUrl ? <span className="text-xs text-rose-300">{urlErrors.tiktokUrl}</span> : null}
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Primary color
              <div className="flex items-center gap-3">
                <input type="color" value={resolveColorValue(form.primaryColorHex)} onChange={(e) => updateField("primaryColorHex", e.target.value)} className="h-12 w-12 rounded-2xl border border-border-soft bg-transparent" />
                <input value={form.primaryColorHex} onChange={(e) => updateField("primaryColorHex", e.target.value)} className="dashboard-input" />
              </div>
              {colorErrors.primaryColorHex ? <span className="text-xs text-rose-300">{colorErrors.primaryColorHex}</span> : null}
            </label>
            <label className="grid gap-2 text-sm">
              Secondary color
              <div className="flex items-center gap-3">
                <input type="color" value={resolveColorValue(form.secondaryColorHex)} onChange={(e) => updateField("secondaryColorHex", e.target.value)} className="h-12 w-12 rounded-2xl border border-border-soft bg-transparent" />
                <input value={form.secondaryColorHex} onChange={(e) => updateField("secondaryColorHex", e.target.value)} className="dashboard-input" />
              </div>
              {colorErrors.secondaryColorHex ? <span className="text-xs text-rose-300">{colorErrors.secondaryColorHex}</span> : null}
            </label>
            <label className="grid gap-2 text-sm">
              Accent color
              <div className="flex items-center gap-3">
                <input type="color" value={resolveColorValue(form.accentColorHex)} onChange={(e) => updateField("accentColorHex", e.target.value)} className="h-12 w-12 rounded-2xl border border-border-soft bg-transparent" />
                <input value={form.accentColorHex} onChange={(e) => updateField("accentColorHex", e.target.value)} className="dashboard-input" />
              </div>
              {colorErrors.accentColorHex ? <span className="text-xs text-rose-300">{colorErrors.accentColorHex}</span> : null}
            </label>
          </div>
          {validationErrors.length > 0 ? (
            <div className="rounded-[22px] border border-amber-400/20 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
              {validationErrors[0]}
            </div>
          ) : null}
          <button
            type="button"
            onClick={onSave}
            disabled={!isValid}
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            Save settings
          </button>
        </>
      )}
    </section>
  );
}
