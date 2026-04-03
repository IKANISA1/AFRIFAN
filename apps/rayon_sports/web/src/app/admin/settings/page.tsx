"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Palette, ShieldCheck, Languages, Phone } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { rayonClub } from "@/lib/config";
import { getAdminClubProfile, saveAdminClubProfile } from "@/lib/data/admin";
import type { ClubProfile, FeatureFlags } from "@/lib/types";

type SettingsForm = {
  clubName: string;
  shortName: string;
  nickname: string;
  countryCode: string;
  league: string;
  region: string;
  currencyCode: string;
  currencySymbol: string;
  defaultLanguage: string;
  supportedLanguagesText: string;
  officialContact: string;
  facebookUrl: string;
  xUrl: string;
  instagramUrl: string;
  tiktokUrl: string;
  officialLogoUrl: string;
  primaryColorHex: string;
  secondaryColorHex: string;
  accentColorHex: string;
  featureFlags: FeatureFlags;
};

const defaultFeatureFlags: FeatureFlags = {
  biopay: true,
  chat: true,
  fan_clubs: true,
  shop: true,
  sms_ledger: true,
  ticketing: true,
};

function profileToForm(profile: ClubProfile): SettingsForm {
  return {
    clubName: profile.clubName,
    shortName: profile.shortName,
    nickname: profile.nickname,
    countryCode: profile.countryCode,
    league: profile.league,
    region: profile.region,
    currencyCode: profile.currencyCode,
    currencySymbol: profile.currencySymbol,
    defaultLanguage: profile.defaultLanguage,
    supportedLanguagesText: profile.supportedLanguages.join(", "),
    officialContact: profile.officialContact,
    facebookUrl: profile.facebookUrl ?? "",
    xUrl: profile.xUrl ?? "",
    instagramUrl: profile.instagramUrl ?? "",
    tiktokUrl: profile.tiktokUrl ?? "",
    officialLogoUrl: profile.officialLogoUrl ?? "",
    primaryColorHex: profile.primaryColorHex,
    secondaryColorHex: profile.secondaryColorHex,
    accentColorHex: profile.accentColorHex,
    featureFlags: {
      ...defaultFeatureFlags,
      ...profile.featureFlags,
    },
  };
}

function formToProfile(form: SettingsForm): ClubProfile {
  return {
    id: rayonClub.numericId,
    clubName: form.clubName.trim(),
    clubSlug: rayonClub.slug,
    shortName: form.shortName.trim(),
    nickname: form.nickname.trim(),
    countryCode: form.countryCode.trim(),
    league: form.league.trim(),
    region: form.region.trim(),
    currencyCode: form.currencyCode.trim(),
    currencySymbol: form.currencySymbol.trim(),
    defaultLanguage: form.defaultLanguage.trim(),
    supportedLanguages: form.supportedLanguagesText
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean),
    officialContact: form.officialContact.trim(),
    facebookUrl: form.facebookUrl.trim() || null,
    xUrl: form.xUrl.trim() || null,
    instagramUrl: form.instagramUrl.trim() || null,
    tiktokUrl: form.tiktokUrl.trim() || null,
    officialLogoUrl: form.officialLogoUrl.trim() || null,
    primaryColorHex: form.primaryColorHex.trim(),
    secondaryColorHex: form.secondaryColorHex.trim(),
    accentColorHex: form.accentColorHex.trim(),
    featureFlags: form.featureFlags,
  };
}

export default function AdminSettingsPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState<SettingsForm | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      const profile = await getAdminClubProfile(client);
      setForm(profileToForm(profile));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load club settings.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

  const enabledFlags = useMemo(
    () =>
      form == null
        ? 0
        : Object.values(form.featureFlags).filter(Boolean).length,
    [form],
  );

  async function submitForm() {
    if (client == null || form == null) return;

    showAdminToast("Saving club settings...", "info");
    try {
      await saveAdminClubProfile(client, formToProfile(form));
      await load();
      showAdminToast("Club settings updated.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not save club settings.",
        "error",
      );
    }
  }

  function updateField<K extends keyof SettingsForm>(field: K, value: SettingsForm[K]) {
    setForm((current) => (current ? { ...current, [field]: value } : current));
  }

  function toggleFlag(flag: string) {
    setForm((current) => {
      if (!current) return current;
      return {
        ...current,
        featureFlags: {
          ...current.featureFlags,
          [flag]: !current.featureFlags[flag],
        },
      };
    });
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Club settings"
        title="Control the brand, contact, language, and public feature switches."
        description="These values drive the public web experience and give the admin team one place to maintain core club identity in Supabase."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Languages"
          value={
            loading || form == null
              ? "..."
              : form.supportedLanguagesText
                  .split(",")
                  .map((item) => item.trim())
                  .filter(Boolean).length.toString()
          }
          helper="Languages exposed across the public shell."
          icon={Languages}
        />
        <AdminStateCard
          label="Features"
          value={loading ? "..." : enabledFlags.toString()}
          helper="Enabled public feature flags."
          icon={ShieldCheck}
        />
        <AdminStateCard
          label="Contact"
          value={loading || form == null ? "..." : "Live"}
          helper="Official support and matchday contact channel."
          icon={Phone}
        />
        <AdminStateCard
          label="Brand"
          value={loading || form == null ? "..." : "Synced"}
          helper="Primary, secondary, and accent club colors."
          icon={Palette}
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
        <section className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Identity settings
            </p>
            <button
              type="button"
              onClick={() => {
                load().catch(() => {});
              }}
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
                  <input
                    value={form.clubName}
                    onChange={(event) => updateField("clubName", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Short name
                  <input
                    value={form.shortName}
                    onChange={(event) => updateField("shortName", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
              </div>

              <div className="grid gap-4 sm:grid-cols-3">
                <label className="grid gap-2 text-sm">
                  Nickname
                  <input
                    value={form.nickname}
                    onChange={(event) => updateField("nickname", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Country code
                  <input
                    value={form.countryCode}
                    onChange={(event) => updateField("countryCode", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Default language
                  <input
                    value={form.defaultLanguage}
                    onChange={(event) =>
                      updateField("defaultLanguage", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                <label className="grid gap-2 text-sm">
                  League
                  <input
                    value={form.league}
                    onChange={(event) => updateField("league", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Region
                  <input
                    value={form.region}
                    onChange={(event) => updateField("region", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
              </div>

              <div className="grid gap-4 sm:grid-cols-3">
                <label className="grid gap-2 text-sm">
                  Currency code
                  <input
                    value={form.currencyCode}
                    onChange={(event) =>
                      updateField("currencyCode", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Currency symbol
                  <input
                    value={form.currencySymbol}
                    onChange={(event) =>
                      updateField("currencySymbol", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Supported languages
                  <input
                    value={form.supportedLanguagesText}
                    onChange={(event) =>
                      updateField("supportedLanguagesText", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
              </div>

              <label className="grid gap-2 text-sm">
                Official contact
                <textarea
                  rows={2}
                  value={form.officialContact}
                  onChange={(event) =>
                    updateField("officialContact", event.target.value)
                  }
                  className="dashboard-input min-h-20 resize-y"
                />
              </label>

              <label className="grid gap-2 text-sm">
                Official logo URL
                <input
                  value={form.officialLogoUrl}
                  onChange={(event) =>
                    updateField("officialLogoUrl", event.target.value)
                  }
                  className="dashboard-input"
                />
              </label>

              <div className="grid gap-4 sm:grid-cols-2">
                <label className="grid gap-2 text-sm">
                  Facebook URL
                  <input
                    value={form.facebookUrl}
                    onChange={(event) =>
                      updateField("facebookUrl", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  X / Twitter URL
                  <input
                    value={form.xUrl}
                    onChange={(event) => updateField("xUrl", event.target.value)}
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Instagram URL
                  <input
                    value={form.instagramUrl}
                    onChange={(event) =>
                      updateField("instagramUrl", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  TikTok URL
                  <input
                    value={form.tiktokUrl}
                    onChange={(event) =>
                      updateField("tiktokUrl", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
              </div>

              <div className="grid gap-4 sm:grid-cols-3">
                <label className="grid gap-2 text-sm">
                  Primary color
                  <input
                    value={form.primaryColorHex}
                    onChange={(event) =>
                      updateField("primaryColorHex", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Secondary color
                  <input
                    value={form.secondaryColorHex}
                    onChange={(event) =>
                      updateField("secondaryColorHex", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
                <label className="grid gap-2 text-sm">
                  Accent color
                  <input
                    value={form.accentColorHex}
                    onChange={(event) =>
                      updateField("accentColorHex", event.target.value)
                    }
                    className="dashboard-input"
                  />
                </label>
              </div>

              <button
                type="button"
                onClick={() => {
                  submitForm().catch(() => {});
                }}
                className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
              >
                Save settings
              </button>
            </>
          )}
        </section>

        <section className="glass-panel rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">
            Brand preview
          </p>
          {loading || form == null ? (
            <div className="mt-5 space-y-4">
              <Skeleton className="h-48 rounded-[26px]" />
              <Skeleton className="h-14 rounded-[22px]" />
              <Skeleton className="h-28 rounded-[22px]" />
            </div>
          ) : (
            <>
              <div className="mt-5 rounded-[28px] border border-border-soft bg-white/5 p-5">
                <p className="font-mono text-[11px] uppercase tracking-[0.22em] text-club-accent">
                  Locked club scope
                </p>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400">
                      Club slug
                    </p>
                    <p className="mt-2 font-display text-2xl font-bold uppercase">
                      {rayonClub.slug}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400">
                      Numeric id
                    </p>
                    <p className="mt-2 font-display text-2xl font-bold uppercase">
                      {rayonClub.numericId}
                    </p>
                  </div>
                </div>
              </div>

              <div className="mt-5 rounded-[28px] border border-border-soft bg-white/5 p-5">
                <div className="flex items-start gap-4">
                  <div className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-[24px] border border-border-soft bg-black/10">
                    {form.officialLogoUrl.trim() ? (
                      // eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting.
                      <img
                        src={form.officialLogoUrl}
                        alt={form.clubName}
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <span className="font-display text-xl font-bold uppercase text-club-accent">
                        RS
                      </span>
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="font-display text-4xl font-bold uppercase leading-none">
                      {form.clubName}
                    </p>
                    <p className="mt-2 text-sm uppercase tracking-[0.18em] text-club-accent">
                      {form.shortName} • {form.nickname}
                    </p>
                    <p className="mt-3 text-sm leading-6 text-slate-300">
                      {form.officialContact}
                    </p>
                  </div>
                </div>
                <div className="mt-5 grid gap-3 sm:grid-cols-3">
                  {[
                    ["Primary", form.primaryColorHex],
                    ["Secondary", form.secondaryColorHex],
                    ["Accent", form.accentColorHex],
                  ].map(([label, value]) => (
                    <div
                      key={label}
                      className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3"
                    >
                      <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400">
                        {label}
                      </p>
                      <div className="mt-3 flex items-center gap-3">
                        <span
                          className="h-8 w-8 rounded-full border border-white/15"
                          style={{ backgroundColor: value }}
                        />
                        <span className="text-sm font-semibold text-slate-100">
                          {value}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="mt-5 rounded-[28px] border border-border-soft bg-white/5 p-5">
                <p className="font-mono text-[11px] uppercase tracking-[0.22em] text-club-accent">
                  Feature flags
                </p>
                <div className="mt-4 grid gap-3 sm:grid-cols-2">
                  {Object.entries(form.featureFlags).map(([flag, enabled]) => (
                    <label
                      key={flag}
                      className="flex items-center gap-3 rounded-[20px] border border-border-soft bg-black/10 px-4 py-3 text-sm"
                    >
                      <input
                        type="checkbox"
                        checked={enabled}
                        onChange={() => toggleFlag(flag)}
                      />
                      <span className="flex-1 capitalize text-slate-200">
                        {flag.replaceAll("_", " ")}
                      </span>
                    </label>
                  ))}
                </div>
              </div>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
