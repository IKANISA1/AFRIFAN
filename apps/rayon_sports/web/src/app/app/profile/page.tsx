"use client";

import { useState } from "react";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";

export default function FanProfilePage() {
  const { profile, updateProfile, loading } = useFanPortal();
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

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Profile"
        title="Keep your supporter identity current."
        description="The same profile contract drives web and mobile. Public alias stays separate from private contact fields."
      />
      <form action={handleSubmit} className="glass-panel grid gap-5 rounded-[32px] p-6 md:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Display name
          <input
            name="displayName"
            defaultValue={profile?.displayName ?? ""}
            className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3 outline-none"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Country code
          <input
            name="countryCode"
            defaultValue={profile?.countryCode ?? "RW"}
            className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3 outline-none"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Language code
          <input
            name="languageCode"
            defaultValue={profile?.languageCode ?? "rw"}
            className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3 outline-none"
          />
        </label>
        <label className="grid gap-2 text-sm">
          MoMo number
          <input
            name="momoNumber"
            defaultValue={profile?.momoNumber ?? ""}
            className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3 outline-none"
          />
        </label>
        <label className="grid gap-2 text-sm md:col-span-2">
          WhatsApp number
          <input
            name="whatsappNumber"
            defaultValue={profile?.whatsappNumber ?? ""}
            className="rounded-2xl border border-border-soft bg-white/6 px-4 py-3 outline-none"
          />
        </label>
        <div className="md:col-span-2 flex items-center gap-4">
          <button
            type="submit"
            disabled={loading}
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
          >
            Save profile
          </button>
          {status ? <p className="text-sm text-slate-300">{status}</p> : null}
        </div>
      </form>
    </div>
  );
}
