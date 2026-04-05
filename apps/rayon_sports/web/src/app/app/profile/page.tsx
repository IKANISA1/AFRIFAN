"use client";

import { useState } from "react";
import { CircleUserRound, Save } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { useFanPortal } from "@/components/portal/fan-portal-provider";

export default function FanProfilePage() {
  const { profile, membership, updateProfile, loading } = useFanPortal();
  const [status, setStatus] = useState<string | null>(null);

  async function handleSubmit(formData: FormData) {
    setStatus("Saving profile...");

    try {
      await updateProfile({
        displayName: String(formData.get("displayName") ?? ""),
        countryCode: String(formData.get("countryCode") ?? "RW"),
        languageCode: String(formData.get("languageCode") ?? "rw"),
        momoNumber: String(formData.get("momoNumber") ?? ""),
        whatsappNumber: String(formData.get("whatsappNumber") ?? ""),
      });
      setStatus("Profile saved.");
    } catch (caught) {
      setStatus(caught instanceof Error ? caught.message : "Save failed.");
    }
  }

  const tierLabel = (membership?.tier ?? "fan").toUpperCase();
  const supporterAlias = profile?.publicUserId ?? "Pending";
  const chapterLabel = membership?.chapter ?? "Main stand";

  return (
    <div className="section-grid">
      <PageHero
        eyebrow="Settings"
        title="Your supporter identity."
        description="Update your name, contact details, and preferences. Everything here stays tied to your matchday account."
        stats={[
          { label: "Tier", value: tierLabel },
          { label: "Alias", value: supporterAlias },
          { label: "Chapter", value: chapterLabel },
        ]}
        actions={
          <a
            href="#profile-form"
            className="inline-flex min-h-11 items-center gap-2 rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110"
          >
            Edit profile <CircleUserRound size={18} />
          </a>
        }
        media={
          <article className="rounded-[28px] border border-border-soft bg-black/20 p-5">
            <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-club-accent">
              Supporter card
            </p>
            <p className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
              {profile?.displayName ?? "Gikundiro supporter"}
            </p>
            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-300">
                  Membership
                </p>
                <p className="mt-2 font-semibold text-white">
                  {membership?.membershipNumber ?? "Pending"}
                </p>
              </div>
              <div className="rounded-[20px] border border-border-soft bg-white/5 px-4 py-3">
                <p className="text-[10px] uppercase tracking-[0.18em] text-slate-300">
                  XP
                </p>
                <p className="mt-2 font-semibold text-white">
                  {membership?.points ?? 0}
                </p>
              </div>
            </div>
          </article>
        }
      />

      <form
        id="profile-form"
        action={handleSubmit}
        className="glass-panel-elevated grid gap-5 rounded-[32px] p-6"
      >
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Profile details
          </p>
          <h2 className="mt-4 font-display text-4xl font-bold uppercase leading-none text-white">
            Keep your info current.
          </h2>
          <p className="mt-4 text-sm leading-7 text-slate-300">
            Your name and contact details are used for ticket confirmations,
            order updates, and supporter communications.
          </p>
        </div>

        <div className="grid gap-5 md:grid-cols-2">
          <label className="grid gap-2 text-sm">
            Display name
            <input
              name="displayName"
              defaultValue={profile?.displayName ?? ""}
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm">
            Country code
            <input
              name="countryCode"
              defaultValue={profile?.countryCode ?? "RW"}
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm">
            Language code
            <input
              name="languageCode"
              defaultValue={profile?.languageCode ?? "rw"}
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm">
            MoMo number
            <input
              name="momoNumber"
              defaultValue={profile?.momoNumber ?? ""}
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm md:col-span-2">
            WhatsApp number
            <input
              name="whatsappNumber"
              defaultValue={profile?.whatsappNumber ?? ""}
              className="dashboard-input"
            />
          </label>
        </div>

        <div className="flex items-center gap-4">
          <button
            type="submit"
            disabled={loading}
            className="rounded-full bg-club-accent px-5 py-3 font-semibold text-slate-950 transition hover:brightness-110 disabled:opacity-60"
          >
            <span className="inline-flex items-center gap-2">
              Save profile <Save size={16} />
            </span>
          </button>
          {status ? <p className="text-sm text-slate-300">{status}</p> : null}
        </div>
      </form>
    </div>
  );
}
