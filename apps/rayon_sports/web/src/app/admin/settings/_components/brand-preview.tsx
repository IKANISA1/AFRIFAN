"use client";

import type { Dispatch, SetStateAction } from "react";
import { Skeleton } from "@/components/skeleton";
import { rayonClub } from "@/lib/config";
import type { SettingsForm } from "./settings-form-state";

interface BrandPreviewProps {
  form: SettingsForm | null;
  setForm: Dispatch<SetStateAction<SettingsForm | null>>;
  loading: boolean;
}

export function BrandPreview({ form, setForm, loading }: BrandPreviewProps) {
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
                <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400">Club slug</p>
                <p className="mt-2 font-display text-2xl font-bold uppercase">{rayonClub.slug}</p>
              </div>
              <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400">Numeric id</p>
                <p className="mt-2 font-display text-2xl font-bold uppercase">{rayonClub.numericId}</p>
              </div>
            </div>
          </div>

          <div className="mt-5 rounded-[28px] border border-border-soft bg-white/5 p-5">
            <div className="flex items-start gap-4">
              <div className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-[24px] border border-border-soft bg-black/10">
                {form.officialLogoUrl.trim() ? (
                  // eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs
                  <img src={form.officialLogoUrl} alt={form.clubName} className="h-full w-full object-cover" />
                ) : (
                  <span className="font-display text-xl font-bold uppercase text-club-accent">RS</span>
                )}
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-display text-4xl font-bold uppercase leading-none">{form.clubName}</p>
                <p className="mt-2 text-sm uppercase tracking-[0.18em] text-club-accent">
                  {form.shortName} • {form.nickname}
                </p>
                <p className="mt-3 text-sm leading-6 text-slate-300">{form.officialContact}</p>
              </div>
            </div>
            <div className="mt-5 grid gap-3 sm:grid-cols-3">
              {[
                ["Primary", form.primaryColorHex],
                ["Secondary", form.secondaryColorHex],
                ["Accent", form.accentColorHex],
              ].map(([label, value]) => (
                <div key={label} className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                  <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400">{label}</p>
                  <div className="mt-3 flex items-center gap-3">
                    <span className="h-8 w-8 rounded-full border border-white/15" style={{ backgroundColor: value }} />
                    <span className="text-sm font-semibold text-slate-100">{value}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-5 rounded-[28px] border border-border-soft bg-white/5 p-5">
            <p className="font-mono text-[11px] uppercase tracking-[0.22em] text-club-accent">Feature flags</p>
            <div className="mt-4 grid gap-3 sm:grid-cols-2">
              {Object.entries(form.featureFlags).map(([flag, enabled]) => (
                <label key={flag} className="flex items-center gap-3 rounded-[20px] border border-border-soft bg-black/10 px-4 py-3 text-sm">
                  <input type="checkbox" checked={enabled} onChange={() => toggleFlag(flag)} />
                  <span className="flex-1 capitalize text-slate-200">{flag.replaceAll("_", " ")}</span>
                </label>
              ))}
            </div>
          </div>
        </>
      )}
    </section>
  );
}
