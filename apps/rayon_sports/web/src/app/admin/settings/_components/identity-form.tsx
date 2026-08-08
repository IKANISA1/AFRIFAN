"use client";

import type { Dispatch, SetStateAction } from "react";
import { Skeleton } from "@/components/skeleton";
import {
  isValidHexColor,
  normalizeHexColorInput,
  sanitizeHexColorDraft,
} from "@/lib/utils";
import type { SettingsForm } from "./settings-form-state";

interface IdentityFormProps {
  form: SettingsForm | null;
  setForm: Dispatch<SetStateAction<SettingsForm | null>>;
  loading: boolean;
  canSave: boolean;
  saving: boolean;
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
    return (
      url.protocol === "https:" &&
      url.username === "" &&
      url.password === "" &&
      url.hash === ""
    );
  } catch {
    return false;
  }
}

function resolveColorValue(value: string) {
  const normalized = normalizeHexColorInput(value);
  return /^#[0-9A-F]{6}$/.test(normalized) ? normalized : "#1A7A4E";
}

export function IdentityForm({
  form,
  setForm,
  loading,
  canSave,
  saving,
  onSave,
}: IdentityFormProps) {
  function updateField<K extends keyof SettingsForm>(
    field: K,
    value: SettingsForm[K],
  ) {
    setForm((current) => (current ? { ...current, [field]: value } : current));
  }

  function updateColorField(
    field: "primaryColorHex" | "secondaryColorHex" | "accentColorHex",
    value: string,
    finalize = false,
  ) {
    const nextValue = finalize
      ? normalizeHexColorInput(value)
      : sanitizeHexColorDraft(value);
    updateField(field, nextValue as SettingsForm[typeof field]);
  }

  const supportedLanguages = form
    ? normalizeLanguageList(form.supportedLanguagesText)
    : [];
  const defaultLanguage = form?.defaultLanguage.trim().toLowerCase() ?? "";
  const defaultLanguageOptions =
    form == null
      ? []
      : Array.from(
          new Set([defaultLanguage, ...supportedLanguages].filter(Boolean)),
        );
  const urlErrors =
    form == null
      ? {}
      : {
          officialLogoUrl: isValidUrl(form.officialLogoUrl)
            ? null
            : "Enter a valid https:// URL.",
          facebookUrl: isValidUrl(form.facebookUrl)
            ? null
            : "Enter a valid https:// URL.",
          xUrl: isValidUrl(form.xUrl) ? null : "Enter a valid https:// URL.",
          instagramUrl: isValidUrl(form.instagramUrl)
            ? null
            : "Enter a valid https:// URL.",
          tiktokUrl: isValidUrl(form.tiktokUrl)
            ? null
            : "Enter a valid https:// URL.",
        };
  const colorErrors =
    form == null
      ? {}
      : {
          primaryColorHex: isValidHexColor(form.primaryColorHex)
            ? null
            : "Use a valid hex color like #1A7A4E.",
          secondaryColorHex: isValidHexColor(form.secondaryColorHex)
            ? null
            : "Use a valid hex color like #0E2B55.",
          accentColorHex: isValidHexColor(form.accentColorHex)
            ? null
            : "Use a valid hex color like #F7B500.",
        };
  const validationErrors =
    form == null
      ? []
      : [
          supportedLanguages.length === 0
            ? "Add at least one supported language."
            : null,
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
        <span className="admin-meta-chip">
          {canSave ? "Editable" : "Read only"}
        </span>
      </div>

      {loading || form == null ? (
        <div className="space-y-4">
          {Array.from({ length: 7 }).map((_, index) => (
            <Skeleton key={index} className="h-14 rounded-[22px]" />
          ))}
        </div>
      ) : (
        <>
          <fieldset disabled={!canSave || saving} className="contents">
            <legend className="sr-only">Club identity fields</legend>
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="grid gap-2 text-sm">
                Club name
                <input
                  value={form.clubName}
                  onChange={(e) => updateField("clubName", e.target.value)}
                  className="dashboard-input"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Short name
                <input
                  value={form.shortName}
                  onChange={(e) => updateField("shortName", e.target.value)}
                  className="dashboard-input"
                />
              </label>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <label className="grid gap-2 text-sm">
                Nickname
                <input
                  value={form.nickname}
                  onChange={(e) => updateField("nickname", e.target.value)}
                  className="dashboard-input"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Country code
                <input
                  value={form.countryCode}
                  onChange={(e) =>
                    updateField(
                      "countryCode",
                      e.target.value.toUpperCase().slice(0, 2),
                    )
                  }
                  maxLength={2}
                  className="dashboard-input uppercase"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Default language
                <select
                  value={defaultLanguage}
                  onChange={(e) =>
                    updateField("defaultLanguage", e.target.value)
                  }
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
                <input
                  value={form.league}
                  onChange={(e) => updateField("league", e.target.value)}
                  className="dashboard-input"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Region
                <input
                  value={form.region}
                  onChange={(e) => updateField("region", e.target.value)}
                  className="dashboard-input"
                />
              </label>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <label className="grid gap-2 text-sm">
                Currency code
                <input
                  value={form.currencyCode}
                  onChange={(e) =>
                    updateField(
                      "currencyCode",
                      e.target.value.toUpperCase().slice(0, 3),
                    )
                  }
                  maxLength={3}
                  className="dashboard-input uppercase"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Currency symbol
                <input
                  value={form.currencySymbol}
                  onChange={(e) =>
                    updateField("currencySymbol", e.target.value)
                  }
                  className="dashboard-input"
                />
              </label>
              <label className="grid gap-2 text-sm">
                Supported languages
                <input
                  value={form.supportedLanguagesText}
                  onChange={(e) =>
                    updateField("supportedLanguagesText", e.target.value)
                  }
                  className="dashboard-input"
                  placeholder="rw, en, fr"
                />
              </label>
            </div>
            <label className="grid gap-2 text-sm">
              Official contact
              <textarea
                rows={2}
                value={form.officialContact}
                onChange={(e) => updateField("officialContact", e.target.value)}
                className="dashboard-input min-h-20 resize-y"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Official logo URL
              <input
                type="url"
                value={form.officialLogoUrl}
                onChange={(e) => updateField("officialLogoUrl", e.target.value)}
                className="dashboard-input"
              />
              {urlErrors.officialLogoUrl ? (
                <span className="text-xs text-rose-300">
                  {urlErrors.officialLogoUrl}
                </span>
              ) : null}
            </label>
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="grid gap-2 text-sm">
                Facebook URL
                <input
                  type="url"
                  value={form.facebookUrl}
                  onChange={(e) => updateField("facebookUrl", e.target.value)}
                  className="dashboard-input"
                />
                {urlErrors.facebookUrl ? (
                  <span className="text-xs text-rose-300">
                    {urlErrors.facebookUrl}
                  </span>
                ) : null}
              </label>
              <label className="grid gap-2 text-sm">
                X / Twitter URL
                <input
                  type="url"
                  value={form.xUrl}
                  onChange={(e) => updateField("xUrl", e.target.value)}
                  className="dashboard-input"
                />
                {urlErrors.xUrl ? (
                  <span className="text-xs text-rose-300">
                    {urlErrors.xUrl}
                  </span>
                ) : null}
              </label>
              <label className="grid gap-2 text-sm">
                Instagram URL
                <input
                  type="url"
                  value={form.instagramUrl}
                  onChange={(e) => updateField("instagramUrl", e.target.value)}
                  className="dashboard-input"
                />
                {urlErrors.instagramUrl ? (
                  <span className="text-xs text-rose-300">
                    {urlErrors.instagramUrl}
                  </span>
                ) : null}
              </label>
              <label className="grid gap-2 text-sm">
                TikTok URL
                <input
                  type="url"
                  value={form.tiktokUrl}
                  onChange={(e) => updateField("tiktokUrl", e.target.value)}
                  className="dashboard-input"
                />
                {urlErrors.tiktokUrl ? (
                  <span className="text-xs text-rose-300">
                    {urlErrors.tiktokUrl}
                  </span>
                ) : null}
              </label>
            </div>
            <div className="rounded-[28px] border border-border-soft bg-white/5 p-5">
              <div className="flex flex-col gap-1">
                <p className="font-display text-2xl font-bold uppercase leading-none">
                  Team colors
                </p>
                <p className="text-sm text-slate-300">
                  Pick a new color visually or type a HEX value like{" "}
                  <span className="font-mono text-slate-100">#0038A8</span>.
                </p>
              </div>
              <div className="mt-4 grid gap-4 sm:grid-cols-3">
                {[
                  {
                    field: "primaryColorHex" as const,
                    label: "Primary color",
                    helper: "Main kit and action color.",
                    placeholder: "#0038A8",
                  },
                  {
                    field: "secondaryColorHex" as const,
                    label: "Secondary color",
                    helper: "Support surface and contrast color.",
                    placeholder: "#0E2B55",
                  },
                  {
                    field: "accentColorHex" as const,
                    label: "Accent color",
                    helper: "Highlights, badges, and emphasis.",
                    placeholder: "#F7B500",
                  },
                ].map((colorField) => (
                  <label
                    key={colorField.field}
                    className="grid gap-2 rounded-[22px] border border-border-soft bg-black/10 p-4 text-sm"
                  >
                    <span className="font-semibold text-slate-100">
                      {colorField.label}
                    </span>
                    <span className="text-xs text-slate-400">
                      {colorField.helper}
                    </span>
                    <div className="grid min-w-0 gap-3">
                      <input
                        type="color"
                        aria-label={`${colorField.label} picker`}
                        value={resolveColorValue(form[colorField.field])}
                        onChange={(e) =>
                          updateColorField(
                            colorField.field,
                            e.target.value,
                            true,
                          )
                        }
                        className="h-16 w-16 min-h-12 min-w-12 appearance-none rounded-2xl border border-border-soft bg-transparent"
                      />
                      <input
                        value={form[colorField.field]}
                        onChange={(e) =>
                          updateColorField(colorField.field, e.target.value)
                        }
                        onBlur={(e) =>
                          updateColorField(
                            colorField.field,
                            e.target.value,
                            true,
                          )
                        }
                        className="dashboard-input min-h-12 min-w-12 font-mono uppercase"
                        placeholder={colorField.placeholder}
                        autoComplete="off"
                        spellCheck={false}
                      />
                    </div>
                    {colorErrors[colorField.field] ? (
                      <span className="text-xs text-rose-300">
                        {colorErrors[colorField.field]}
                      </span>
                    ) : null}
                  </label>
                ))}
              </div>
            </div>
            {validationErrors.length > 0 ? (
              <div className="rounded-[22px] border border-amber-400/20 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
                {validationErrors[0]}
              </div>
            ) : null}
            <button
              type="button"
              onClick={onSave}
              disabled={!isValid || !canSave || saving}
              className="min-h-12 rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-club-accent disabled:cursor-not-allowed disabled:opacity-60 motion-reduce:transition-none"
            >
              {saving ? "Saving settings..." : "Save settings"}
            </button>
          </fieldset>
          {!canSave ? (
            <p className="text-sm leading-6 text-slate-300" role="note">
              Club moderator access is read only. A club administrator must
              review and save identity changes.
            </p>
          ) : null}
        </>
      )}
    </section>
  );
}
