"use client";

import { useCallback, useEffect, useState } from "react";
import { CalendarDays, Radio, Ticket, Trash2 } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminMatch,
  getAdminMatches,
  saveAdminMatch,
} from "@/lib/data/admin";
import { formatCurrency, formatDate } from "@/lib/utils";
import { cn } from "@/lib/utils";
import type { AdminMatchItem } from "@/lib/types";

const emptyForm = {
  id: "",
  homeTeam: "Rayon Sports",
  awayTeam: "",
  competition: "Rwanda Premier League",
  venue: "Kigali Pele Stadium",
  matchDate: new Date().toISOString().slice(0, 10),
  kickoffTime: "18:00",
  isOnSale: false,
  generalPrice: "3000",
  vipPrice: "10000",
  capacity: "18000",
  imageUrl: "",
  matchStatus: "scheduled",
  homeScore: "0",
  awayScore: "0",
  liveMinute: "",
  matchSummary: "",
  isFeatured: false,
};

const statusColors: Record<string, string> = {
  live: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  halftime: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  fulltime: "bg-slate-500/15 text-slate-300 border-slate-500/30",
  scheduled: "bg-club-accent/10 text-club-accent border-club-accent/30",
  postponed: "bg-rose-500/15 text-rose-300 border-rose-500/30",
  cancelled: "bg-rose-500/15 text-rose-300 border-rose-500/30",
};

function MatchStatusBadge({ status }: { status: string }) {
  const colorClass = statusColors[status] ?? statusColors.scheduled;
  const isLive = status === "live" || status === "halftime";

  return (
    <span className={cn("inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]", colorClass)}>
      {isLive ? <span className="h-1.5 w-1.5 rounded-full bg-current animate-pulse" /> : null}
      {status}
    </span>
  );
}

export default function AdminMatchesPage() {
  const { access, client } = useAdminPortal();
  const [matches, setMatches] = useState<AdminMatchItem[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [filter, setFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);

  const loadMatches = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setMatches(await getAdminMatches(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load matches.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadMatches().catch(() => {});
  }, [access.hasAccess, client, loadMatches]);

  function beginEdit(match: AdminMatchItem) {
    setForm({
      id: match.id,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      competition: match.competition,
      venue: match.venue,
      matchDate: match.matchDate.slice(0, 10),
      kickoffTime: (match.kickoffTime ?? "18:00:00").slice(0, 5),
      isOnSale: match.isOnSale,
      generalPrice: String(match.generalPrice),
      vipPrice: String(match.vipPrice),
      capacity: String(match.capacity),
      imageUrl: match.imageUrl ?? "",
      matchStatus: match.matchStatus,
      homeScore: String(match.homeScore),
      awayScore: String(match.awayScore),
      liveMinute: match.liveMinute == null ? "" : String(match.liveMinute),
      matchSummary: match.matchSummary ?? "",
      isFeatured: match.isFeatured,
    });
    showAdminToast(`Editing ${match.homeTeam} vs ${match.awayTeam}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    const saving = form.id ? "Saving fixture..." : "Creating fixture...";
    showAdminToast(saving, "info");

    try {
      await saveAdminMatch(client, access, {
        id: form.id || null,
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
      await loadMatches();
      showAdminToast("Fixture saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save match.",
        "error",
      );
    }
  }

  async function removeMatch(match: AdminMatchItem) {
    if (client == null) {
      return;
    }

    try {
      await deleteAdminMatch(client, match.id);
      await loadMatches();
      showAdminToast(
        `${match.homeTeam} vs ${match.awayTeam} removed.`,
        "success",
      );
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove fixture.",
        "error",
      );
    }
  }

  const filteredMatches = matches.filter((match) => {
    const date = new Date(match.matchDate);
    const today = new Date();
    const upcoming = date >= new Date(today.getFullYear(), today.getMonth(), today.getDate());

    switch (filter) {
      case "LIVE":
        return match.matchStatus === "live" || match.matchStatus === "halftime";
      case "UPCOMING":
        return upcoming;
      case "COMPLETED":
        return !upcoming;
      case "ON SALE":
        return match.isOnSale;
      default:
        return true;
    }
  });

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Match manager"
        title="Control fixtures, ticket sales, and live-state from one mobile-first surface."
        description="This editor keeps the club website, fan portal, and live center aligned on the same match contract."
      />

      <div className="grid gap-5 md:grid-cols-3">
        <AdminStateCard
          label="Matches"
          value={loading ? "..." : matches.length.toString()}
          helper="All club-scoped fixtures currently visible to admin."
          icon={CalendarDays}
        />
        <AdminStateCard
          label="On sale"
          value={loading ? "..." : matches.filter((match) => match.isOnSale).length.toString()}
          helper="Fixtures with active ticket sales in the supporter surfaces."
          icon={Ticket}
        />
        <AdminStateCard
          label="Live now"
          value={loading ? "..." : matches.filter((match) => match.matchStatus === "live").length.toString()}
          helper="Live-score driven fixtures currently pushing updates."
          icon={Radio}
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              {form.id ? "Edit fixture" : "New fixture"}
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
              Home team
              <input
                name="homeTeam"
                value={form.homeTeam}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    homeTeam: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Away team
              <input
                name="awayTeam"
                required
                value={form.awayTeam}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    awayTeam: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Competition
              <input
                name="competition"
                value={form.competition}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    competition: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Venue
              <input
                name="venue"
                value={form.venue}
                onChange={(event) =>
                  setForm((current) => ({ ...current, venue: event.target.value }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Match date
              <input
                type="date"
                name="matchDate"
                value={form.matchDate}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    matchDate: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Kickoff time
              <input
                type="time"
                name="kickoffTime"
                value={form.kickoffTime}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    kickoffTime: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              General price
              <input
                type="number"
                name="generalPrice"
                value={form.generalPrice}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    generalPrice: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              VIP price
              <input
                type="number"
                name="vipPrice"
                value={form.vipPrice}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    vipPrice: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Capacity
              <input
                type="number"
                name="capacity"
                value={form.capacity}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    capacity: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Match status
              <select
                name="matchStatus"
                value={form.matchStatus}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    matchStatus: event.target.value,
                  }))
                }
                className="dashboard-input"
              >
                <option value="scheduled">Scheduled</option>
                <option value="live">Live</option>
                <option value="halftime">Half-time</option>
                <option value="fulltime">Full-time</option>
                <option value="postponed">Postponed</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </label>
            <label className="grid gap-2 text-sm">
              Hero image URL
              <input
                name="imageUrl"
                value={form.imageUrl}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    imageUrl: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          {form.imageUrl.trim() ? (
            <div className="overflow-hidden rounded-[22px] border border-border-soft">
              {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
              <img src={form.imageUrl} alt="Preview" className="h-32 w-full object-cover" />
            </div>
          ) : null}
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="grid gap-2 text-sm">
              Home score
              <input
                type="number"
                name="homeScore"
                value={form.homeScore}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    homeScore: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Away score
              <input
                type="number"
                name="awayScore"
                value={form.awayScore}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    awayScore: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Live minute
              <input
                type="number"
                name="liveMinute"
                value={form.liveMinute}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    liveMinute: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          <label className="grid gap-2 text-sm">
            Match summary
            <textarea
              name="matchSummary"
              rows={4}
              value={form.matchSummary}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  matchSummary: event.target.value,
                }))
              }
              className="dashboard-input min-h-28 resize-y"
            />
          </label>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
              <input
                type="checkbox"
                name="isOnSale"
                checked={form.isOnSale}
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
                checked={form.isFeatured}
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

        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Fixture list
            </p>
            <div className="flex flex-wrap gap-2">
              {["ALL", "LIVE", "UPCOMING", "COMPLETED", "ON SALE"].map((item) => (
                <button
                  key={item}
                  type="button"
                  data-active={filter === item}
                  onClick={() => setFilter(item)}
                  className="dashboard-chip"
                >
                  {item}
                </button>
              ))}
            </div>
          </div>

          <div className="mt-5 space-y-3">
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                    <Skeleton className="skeleton-text h-6 w-3/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                    <div className="mt-4 grid gap-3 sm:grid-cols-3">
                      {Array.from({ length: 3 }).map((_, j) => (
                        <Skeleton key={j} className="h-16 rounded-[22px]" />
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            ) : null}
            {!loading && filteredMatches.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No fixtures match the current filter.
              </p>
            ) : null}
            {!loading && filteredMatches.map((match) => (
              <article
                key={match.id}
                className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="flex flex-wrap items-center gap-3">
                      <p className="font-display text-2xl font-bold uppercase leading-none">
                        {match.homeTeam} vs {match.awayTeam}
                      </p>
                      <MatchStatusBadge status={match.matchStatus} />
                    </div>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      {match.competition} • {match.venue} • {formatDate(match.matchDate)}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => beginEdit(match)}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        removeMatch(match).catch(() => {});
                      }}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-200 transition hover:border-rose-400/30 hover:bg-rose-500/15"
                    >
                      <span className="inline-flex items-center gap-1.5">
                        <Trash2 size={12} />
                        Delete
                      </span>
                    </button>
                  </div>
                </div>
                <div className="mt-4 grid gap-3 sm:grid-cols-3">
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Sales
                    </p>
                    <p className="mt-2 text-sm text-slate-200">
                      <span className={match.isOnSale ? "text-emerald-400" : "text-slate-400"}>
                        {match.isOnSale ? "On sale" : "Closed"}
                      </span>
                      {" • "}
                      {formatCurrency(match.generalPrice)}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Score
                    </p>
                    <p className="mt-2 font-display text-xl font-bold text-slate-200">
                      {match.homeScore} – {match.awayScore}
                    </p>
                  </div>
                  <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                    <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                      Capacity
                    </p>
                    <div className="mt-2">
                      <ProgressBar value={match.soldCount} max={match.capacity} compact />
                    </div>
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
