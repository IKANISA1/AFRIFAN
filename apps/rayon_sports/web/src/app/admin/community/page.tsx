"use client";

import { useCallback, useEffect, useState } from "react";
import { Trash2, Users } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { cn } from "@/lib/utils";
import {
  deleteAdminFanClub,
  getAdminFanClubs,
  saveAdminFanClub,
} from "@/lib/data/admin";
import type { AdminFanClub } from "@/lib/types";

type CommunityForm = {
  id: string;
  name: string;
  region: string;
  description: string;
  memberCount: string;
  eventCount: string;
  rating: string;
  bannerImageUrl: string;
  isActive: boolean;
};

const emptyForm: CommunityForm = {
  id: "",
  name: "",
  region: "",
  description: "",
  memberCount: "0",
  eventCount: "0",
  rating: "0",
  bannerImageUrl: "",
  isActive: true,
};

export default function AdminCommunityPage() {
  const { access, client } = useAdminPortal();
  const [clubs, setClubs] = useState<AdminFanClub[]>([]);
  const [form, setForm] = useState<CommunityForm>(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setClubs(await getAdminFanClubs(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load fan clubs.",
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

  function beginEdit(club: AdminFanClub) {
    setForm({
      id: club.id,
      name: club.name,
      region: club.region,
      description: club.description,
      memberCount: String(club.memberCount),
      eventCount: String(club.eventCount),
      rating: String(club.rating),
      bannerImageUrl: club.bannerImageUrl ?? "",
      isActive: club.isActive,
    });
    showAdminToast(`Editing ${club.name}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) return;

    showAdminToast(form.id ? "Saving chapter..." : "Creating chapter...", "info");
    try {
      await saveAdminFanClub(client, access, {
        id: form.id || null,
        name: String(formData.get("name") ?? ""),
        region: String(formData.get("region") ?? ""),
        description: String(formData.get("description") ?? ""),
        memberCount: Number(formData.get("memberCount") ?? 0),
        eventCount: Number(formData.get("eventCount") ?? 0),
        rating: Number(formData.get("rating") ?? 0),
        bannerImageUrl: String(formData.get("bannerImageUrl") ?? ""),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Chapter saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save chapter.",
        "error",
      );
    }
  }

  async function removeClub(club: AdminFanClub) {
    if (client == null) return;

    try {
      await deleteAdminFanClub(client, club.id);
      await load();
      showAdminToast(`${club.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove chapter.",
        "error",
      );
    }
  }

  const totalMembers = clubs.reduce((sum, club) => sum + club.memberCount, 0);
  const regions = Array.from(new Set(clubs.map((club) => club.region)));

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Community manager"
        title="Manage supporter chapters published on the fan clubs page."
        description="Add, edit, and retire supporter chapters. These records power the public community view and the wider supporter network."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Chapters"
          value={loading ? "..." : clubs.length.toString()}
          helper="Registered supporter chapters."
          icon={Users}
        />
        <AdminStateCard
          label="Members"
          value={loading ? "..." : totalMembers.toString()}
          helper="Aggregate member count across all chapters."
        />
        <AdminStateCard
          label="Regions"
          value={loading ? "..." : regions.length.toString()}
          helper="Geographic coverage of the supporter network."
        />
        <AdminStateCard
          label="Active"
          value={
            loading ? "..." : clubs.filter((club) => club.isActive).length.toString()
          }
          helper="Chapters currently visible on the public site."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              {form.id ? "Edit chapter" : "New chapter"}
            </p>
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

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Chapter name
              <input
                name="name"
                required
                value={form.name}
                onChange={(event) =>
                  setForm((current) => ({ ...current, name: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Region
              <input
                name="region"
                value={form.region}
                onChange={(event) =>
                  setForm((current) => ({ ...current, region: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="grid gap-2 text-sm">
            Description
            <textarea
              name="description"
              rows={3}
              value={form.description}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  description: event.target.value,
                }))
              }
              className="dashboard-input min-h-20 resize-y"
            />
          </label>

          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Members
              <input
                type="number"
                name="memberCount"
                value={form.memberCount}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    memberCount: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Events
              <input
                type="number"
                name="eventCount"
                value={form.eventCount}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    eventCount: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Rating
              <input
                type="number"
                name="rating"
                step="0.1"
                max="5"
                value={form.rating}
                onChange={(event) =>
                  setForm((current) => ({ ...current, rating: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
          </div>

          <label className="grid gap-2 text-sm">
            Banner image URL
            <input
              name="bannerImageUrl"
              value={form.bannerImageUrl}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  bannerImageUrl: event.target.value,
                }))
              }
              className="dashboard-input"
            />
          </label>
          {form.bannerImageUrl.trim() ? (
            <div className="overflow-hidden rounded-[22px] border border-border-soft">
              {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
              <img src={form.bannerImageUrl} alt="Preview" className="h-28 w-full object-cover" />
            </div>
          ) : null}

          <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
            <input
              type="checkbox"
              name="isActive"
              checked={form.isActive}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  isActive: event.target.checked,
                }))
              }
            />
            Active on public site
          </label>

          <button
            type="submit"
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {form.id ? "Save chapter" : "Add chapter"}
          </button>
        </form>

        <section className="glass-panel rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">
            Chapters
          </p>
          <div className="mt-5 space-y-3">
            {loading
              ? Array.from({ length: 3 }).map((_, index) => (
                  <div
                    key={index}
                    className="rounded-[26px] border border-border-soft bg-white/5 p-5"
                  >
                    <Skeleton className="skeleton-text h-6 w-2/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                  </div>
                ))
              : null}
            {!loading && clubs.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No chapters registered yet.
              </p>
            ) : null}
            {!loading &&
              clubs.map((club) => (
                <article
                  key={club.id}
                  className={cn(
                    "card-interactive rounded-[26px] border border-border-soft p-5",
                    club.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60",
                  )}
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div className="flex flex-wrap items-center gap-3">
                        <p className="font-display text-2xl font-bold uppercase leading-none">
                          {club.name}
                        </p>
                        {!club.isActive ? (
                          <span className="rounded-full border border-rose-400/30 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-rose-300">
                            Inactive
                          </span>
                        ) : null}
                      </div>
                      <p className="mt-1 text-sm uppercase tracking-[0.2em] text-club-accent">
                        {club.region}
                      </p>
                      <p className="mt-2 text-sm text-slate-300">
                        {club.description}
                      </p>
                    </div>
                    <div className="flex flex-shrink-0 gap-2">
                      <button
                        type="button"
                        onClick={() => beginEdit(club)}
                        className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-white/8"
                        title="Edit"
                      >
                        <span className="text-xs">✏️</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          removeClub(club).catch(() => {});
                        }}
                        className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:border-rose-400/30 hover:bg-rose-500/15 hover:text-rose-300"
                        title="Remove"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                      <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                        Members
                      </p>
                      <p className="mt-2 font-display text-xl font-bold">
                        {club.memberCount}
                      </p>
                    </div>
                    <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                      <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                        Events
                      </p>
                      <p className="mt-2 font-display text-xl font-bold">
                        {club.eventCount}
                      </p>
                    </div>
                    <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                      <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                        Rating
                      </p>
                      <p className="mt-2 font-display text-xl font-bold">
                        {club.rating.toFixed(1)}
                      </p>
                    </div>
                  </div>
                </article>
              ))}
          </div>
        </section>
      </div>
    </div>
  );
}
