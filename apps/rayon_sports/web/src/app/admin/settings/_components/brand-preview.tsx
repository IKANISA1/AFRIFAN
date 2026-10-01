"use client";

import type { Dispatch, SetStateAction } from "react";
import { Skeleton } from "@/components/skeleton";
import { normalizeHexColorInput } from "@/lib/utils";
import type { SettingsForm } from "./settings-form-state";

interface BrandPreviewProps {
  form: SettingsForm | null;
  setForm: Dispatch<SetStateAction<SettingsForm | null>>;
  loading: boolean;
  canEdit: boolean;
}

export function BrandPreview({
  form,
  setForm,
  loading,
  canEdit,
}: BrandPreviewProps) {
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
    <section className="ui-panel min-w-0 rounded-[32px] p-4 [overflow-wrap:anywhere] sm:p-6">
      <p className="font-display text-3xl font-medium normal-case leading-none">
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
          <div className="mt-5 min-w-0 rounded-[28px] border border-border-soft bg-[var(--admin-surface-muted)] p-3 sm:p-5">
            <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-accent)]">
              Locked club scope
            </p>
            <div className="mt-3 grid grid-cols-[repeat(auto-fit,minmax(min(100%,16rem),1fr))] gap-3">
              <div className="min-w-0 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3">
                <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">Club slug</p>
                <p className="mt-2 font-display text-2xl font-medium normal-case">{form.clubSlug}</p>
              </div>
              <div className="min-w-0 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3">
                <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">Numeric id</p>
                <p className="mt-2 font-display text-2xl font-medium normal-case">{form.id}</p>
              </div>
            </div>
          </div>

          <div className="mt-5 min-w-0 rounded-[28px] border border-border-soft bg-[var(--admin-surface-muted)] p-3 sm:p-5">
            <div className="flex flex-wrap items-start gap-4">
              <div className="flex aspect-square w-20 max-w-full shrink-0 items-center justify-center overflow-hidden rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)]">
                {form.officialLogoUrl.trim() ? (
                  // eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs
                  <img src={form.officialLogoUrl} alt={form.clubName} className="h-full w-full object-contain" />
                ) : (
                  <span className="font-display text-xl font-medium normal-case text-[var(--admin-accent)]">RS</span>
                )}
              </div>
              <div className="min-w-0 flex-[1_1_12rem]">
                <p className="font-display text-4xl font-medium normal-case leading-none">{form.clubName}</p>
                <p className="mt-2 text-sm normal-case tracking-normal text-[var(--admin-accent)]">
                  {form.shortName} • {form.nickname}
                </p>
                <p className="mt-3 text-sm leading-6 text-[var(--admin-text-muted)]">{form.officialContact}</p>
              </div>
            </div>
            <div className="mt-5 grid grid-cols-[repeat(auto-fit,minmax(min(100%,8rem),1fr))] gap-3">
              {[
                ["Primary", form.primaryColorHex],
                ["Secondary", form.secondaryColorHex],
                ["Accent", form.accentColorHex],
              ].map(([label, value]) => (
                <div key={label} className="min-w-0 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3">
                  <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">{label}</p>
                  <div className="mt-3 flex flex-wrap items-center gap-3">
                    <span
                      className="h-8 w-8 shrink-0 rounded-full border border-white/15"
                      style={{ backgroundColor: normalizeHexColorInput(value) || "var(--admin-surface-muted)" }}
                    />
                    <span className="text-sm font-semibold text-[var(--admin-text-strong)]">
                      {normalizeHexColorInput(value) || value}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-5 min-w-0 rounded-[28px] border border-border-soft bg-[var(--admin-surface-muted)] p-3 sm:p-5">
            <p className="font-mono text-xs normal-case tracking-normal text-[var(--admin-accent)]">Feature flags</p>
            <div className="mt-4 grid grid-cols-[repeat(auto-fit,minmax(min(100%,10rem),1fr))] gap-3">
              {Object.entries(form.featureFlags).map(([flag, enabled]) => (
                <label key={flag} className="flex min-w-0 items-center gap-3 rounded-[20px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
                  <input
                    type="checkbox"
                    checked={enabled}
                    disabled={!canEdit}
                    onChange={() => toggleFlag(flag)}
                  />
                  <span className="min-w-0 flex-1 capitalize text-[var(--admin-text-strong)]">{flag.replaceAll("_", " ")}</span>
                </label>
              ))}
            </div>
          </div>
        </>
      )}
    </section>
  );
}
