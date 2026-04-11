"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CalendarDays, Edit3, Plus, Sparkles, Trash2, Users } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminFantasyCompetition,
  deleteAdminFantasyGameweek,
  deleteAdminFantasyPlayer,
  getAdminFantasyCompetitions,
  getAdminFantasyOperations,
  saveAdminFantasyCompetition,
  saveAdminFantasyGameweek,
  saveAdminFantasyPlayer,
} from "@/lib/data/admin/fantasy";
import type {
  AdminFantasyCompetition,
  AdminFantasyGameweek,
  AdminFantasyGameweekStatus,
  AdminFantasyOperationsSnapshot,
  AdminFantasyPlayer,
  AdminFantasyPlayerPosition,
  FantasyCompetitionMode,
} from "@/lib/types";

type FantasyForm = {
  id: string;
  slug: string;
  name: string;
  shortName: string;
  season: string;
  description: string;
  mode: FantasyCompetitionMode;
  backendStatus: "draft" | "active" | "finished";
  primaryColor: string;
  logoUrl: string;
  countryCode: string;
  provider: string;
  promoTitle: string;
  promoBody: string;
  badgeLabel: string;
  ctaLabel: string;
  heroImageUrl: string;
  sortOrder: number;
  isVisible: boolean;
  isFeatured: boolean;
  isPlayable: boolean;
  startAt: string;
  endAt: string;
  entryWindowOpensAt: string;
  entryWindowClosesAt: string;
};

type PlayerForm = {
  externalId: string;
  name: string;
  shortName: string;
  position: AdminFantasyPlayerPosition;
  teamId: string;
  teamName: string;
  teamShort: string;
  nationality: string;
  photoUrl: string;
  teamLogoUrl: string;
  price: string;
  priceChange: string;
  ownershipPercent: string;
};

type GameweekForm = {
  id: string;
  number: string;
  name: string;
  status: AdminFantasyGameweekStatus;
  deadlineAt: string;
  startAt: string;
  endAt: string;
  isDoubleGameweek: boolean;
};

function toDateTimeLocal(value: string | null) {
  if (!value) {
    return "";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
    .toISOString()
    .slice(0, 16);
}

function toIso(value: string) {
  return value ? new Date(value).toISOString() : "";
}

function formatBudget(value: number) {
  return `${Math.floor(value / 10)}.${Math.abs(value % 10)}`;
}

const emptyForm: FantasyForm = {
  id: "",
  slug: "",
  name: "",
  shortName: "",
  season: "2026",
  description: "",
  mode: "season_long",
  backendStatus: "draft",
  primaryColor: "#1A7A4E",
  logoUrl: "",
  countryCode: "",
  provider: "",
  promoTitle: "",
  promoBody: "",
  badgeLabel: "",
  ctaLabel: "",
  heroImageUrl: "",
  sortOrder: 0,
  isVisible: true,
  isFeatured: false,
  isPlayable: false,
  startAt: "",
  endAt: "",
  entryWindowOpensAt: "",
  entryWindowClosesAt: "",
};

const emptyPlayerForm: PlayerForm = {
  externalId: "",
  name: "",
  shortName: "",
  position: "MID",
  teamId: "",
  teamName: "",
  teamShort: "",
  nationality: "",
  photoUrl: "",
  teamLogoUrl: "",
  price: "55",
  priceChange: "0",
  ownershipPercent: "0",
};

const emptyGameweekForm: GameweekForm = {
  id: "",
  number: "1",
  name: "Gameweek 1",
  status: "upcoming",
  deadlineAt: "",
  startAt: "",
  endAt: "",
  isDoubleGameweek: false,
};

function competitionToForm(competition: AdminFantasyCompetition): FantasyForm {
  return {
    id: competition.id,
    slug: competition.slug,
    name: competition.name,
    shortName: competition.shortName,
    season: competition.season,
    description: competition.description,
    mode: competition.mode,
    backendStatus: competition.backendStatus,
    primaryColor: competition.primaryColor,
    logoUrl: competition.logoUrl ?? "",
    countryCode: competition.countryCode ?? "",
    provider: competition.provider ?? "",
    promoTitle: competition.promoTitle ?? "",
    promoBody: competition.promoBody ?? "",
    badgeLabel: competition.badgeLabel ?? "",
    ctaLabel: competition.ctaLabel ?? "",
    heroImageUrl: competition.heroImageUrl ?? "",
    sortOrder: competition.sortOrder,
    isVisible: competition.isVisible,
    isFeatured: competition.isFeatured,
    isPlayable: competition.isPlayable,
    startAt: toDateTimeLocal(competition.startAt),
    endAt: toDateTimeLocal(competition.endAt),
    entryWindowOpensAt: toDateTimeLocal(competition.entryWindowOpensAt),
    entryWindowClosesAt: toDateTimeLocal(competition.entryWindowClosesAt),
  };
}

function playerToForm(player: AdminFantasyPlayer): PlayerForm {
  return {
    externalId: String(player.externalId),
    name: player.name,
    shortName: player.shortName,
    position: player.position,
    teamId: String(player.teamId),
    teamName: player.teamName,
    teamShort: player.teamShort,
    nationality: player.nationality ?? "",
    photoUrl: player.photoUrl ?? "",
    teamLogoUrl: player.teamLogoUrl ?? "",
    price: String(player.price),
    priceChange: String(player.priceChange),
    ownershipPercent: String(player.ownershipPercent),
  };
}

function gameweekToForm(gameweek: AdminFantasyGameweek): GameweekForm {
  return {
    id: gameweek.id,
    number: String(gameweek.number),
    name: gameweek.name,
    status: gameweek.status,
    deadlineAt: toDateTimeLocal(gameweek.deadlineAt),
    startAt: toDateTimeLocal(gameweek.startAt),
    endAt: toDateTimeLocal(gameweek.endAt),
    isDoubleGameweek: gameweek.isDoubleGameweek,
  };
}

export default function AdminFantasyPage() {
  const { access, client } = useAdminPortal();
  const [competitions, setCompetitions] = useState<AdminFantasyCompetition[]>([]);
  const [form, setForm] = useState<FantasyForm>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [activeCompetitionId, setActiveCompetitionId] = useState("");
  const [operations, setOperations] = useState<AdminFantasyOperationsSnapshot | null>(null);
  const [opsLoading, setOpsLoading] = useState(false);
  const [playerForm, setPlayerForm] = useState<PlayerForm>(emptyPlayerForm);
  const [gameweekForm, setGameweekForm] = useState<GameweekForm>(emptyGameweekForm);

  const selectedCompetition = useMemo(
    () => competitions.find((competition) => competition.id === activeCompetitionId) ?? null,
    [activeCompetitionId, competitions],
  );

  const loadCompetitions = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      const nextCompetitions = await getAdminFantasyCompetitions(client, access);
      setCompetitions(nextCompetitions);
      setActiveCompetitionId((current) => {
        if (current && nextCompetitions.some((competition) => competition.id === current)) {
          return current;
        }
        return nextCompetitions[0]?.id ?? "";
      });
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load fantasy competitions.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  const loadOperations = useCallback(async () => {
    if (client == null || !activeCompetitionId) {
      setOperations(null);
      return;
    }

    setOpsLoading(true);
    try {
      setOperations(
        await getAdminFantasyOperations(client, access, activeCompetitionId),
      );
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load fantasy operations.",
        "error",
      );
      setOperations(null);
    } finally {
      setOpsLoading(false);
    }
  }, [access, activeCompetitionId, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadCompetitions().catch(() => {});
  }, [access.hasAccess, client, loadCompetitions]);

  useEffect(() => {
    if (client == null || !access.hasAccess || !activeCompetitionId) {
      return;
    }
    loadOperations().catch(() => {});
  }, [access.hasAccess, activeCompetitionId, client, loadOperations]);

  async function submitCompetition(event: React.FormEvent) {
    event.preventDefault();
    if (client == null) {
      return;
    }

    try {
      const competitionId = await saveAdminFantasyCompetition(client, access, {
        id: form.id || null,
        slug: form.slug,
        name: form.name,
        shortName: form.shortName,
        season: form.season,
        description: form.description,
        mode: form.mode,
        backendStatus: form.backendStatus,
        primaryColor: form.primaryColor,
        logoUrl: form.logoUrl,
        countryCode: form.countryCode,
        provider: form.provider,
        promoTitle: form.promoTitle,
        promoBody: form.promoBody,
        badgeLabel: form.badgeLabel,
        ctaLabel: form.ctaLabel,
        heroImageUrl: form.heroImageUrl,
        sortOrder: form.sortOrder,
        isVisible: form.isVisible,
        isFeatured: form.isFeatured,
        isPlayable: form.isPlayable,
        startAt: toIso(form.startAt),
        endAt: toIso(form.endAt),
        entryWindowOpensAt: form.entryWindowOpensAt ? toIso(form.entryWindowOpensAt) : null,
        entryWindowClosesAt: form.entryWindowClosesAt ? toIso(form.entryWindowClosesAt) : null,
      });
      setForm(emptyForm);
      await loadCompetitions();
      setActiveCompetitionId(competitionId);
      showAdminToast("Fantasy competition saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not save fantasy competition.",
        "error",
      );
    }
  }

  async function submitPlayer(event: React.FormEvent) {
    event.preventDefault();
    if (client == null || !selectedCompetition) {
      return;
    }

    try {
      await saveAdminFantasyPlayer(client, access, {
        competitionId: selectedCompetition.id,
        externalId: Number(playerForm.externalId),
        name: playerForm.name,
        shortName: playerForm.shortName,
        position: playerForm.position,
        teamId: Number(playerForm.teamId),
        teamName: playerForm.teamName,
        teamShort: playerForm.teamShort,
        nationality: playerForm.nationality,
        photoUrl: playerForm.photoUrl,
        teamLogoUrl: playerForm.teamLogoUrl,
        price: Number(playerForm.price),
        priceChange: Number(playerForm.priceChange),
        ownershipPercent: Number(playerForm.ownershipPercent),
      });
      setPlayerForm(emptyPlayerForm);
      await loadOperations();
      showAdminToast("Fantasy player saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save fantasy player.",
        "error",
      );
    }
  }

  async function submitGameweek(event: React.FormEvent) {
    event.preventDefault();
    if (client == null || !selectedCompetition) {
      return;
    }

    try {
      await saveAdminFantasyGameweek(client, access, {
        id: gameweekForm.id || null,
        competitionId: selectedCompetition.id,
        number: Number(gameweekForm.number),
        name: gameweekForm.name,
        status: gameweekForm.status,
        deadlineAt: toIso(gameweekForm.deadlineAt),
        startAt: toIso(gameweekForm.startAt),
        endAt: toIso(gameweekForm.endAt),
        isDoubleGameweek: gameweekForm.isDoubleGameweek,
      });
      setGameweekForm(emptyGameweekForm);
      await loadOperations();
      showAdminToast("Gameweek saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save gameweek.",
        "error",
      );
    }
  }

  async function removeCompetition(competition: AdminFantasyCompetition) {
    if (client == null) {
      return;
    }

    try {
      await deleteAdminFantasyCompetition(client, access, competition.id);
      if (form.id === competition.id) {
        setForm(emptyForm);
      }
      await loadCompetitions();
      showAdminToast(`${competition.name} removed from this club scope.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not remove fantasy competition.",
        "error",
      );
    }
  }

  async function removePlayer(player: AdminFantasyPlayer) {
    if (client == null || !selectedCompetition) {
      return;
    }

    try {
      await deleteAdminFantasyPlayer(
        client,
        access,
        selectedCompetition.id,
        player.externalId,
      );
      if (playerForm.externalId === String(player.externalId)) {
        setPlayerForm(emptyPlayerForm);
      }
      await loadOperations();
      showAdminToast(`${player.name} removed from this competition.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove player.",
        "error",
      );
    }
  }

  async function removeGameweek(gameweek: AdminFantasyGameweek) {
    if (client == null) {
      return;
    }

    try {
      await deleteAdminFantasyGameweek(client, access, gameweek.id);
      if (gameweekForm.id === gameweek.id) {
        setGameweekForm(emptyGameweekForm);
      }
      await loadOperations();
      showAdminToast(`${gameweek.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove gameweek.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Fantasy"
        title="Manage competitions, priced players, gameweeks, and homepage promotion."
      />

      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-5">
        <AdminStateCard
          label="Competitions"
          value={loading ? "..." : competitions.length.toString()}
          helper="Configured for this club scope."
          icon={Sparkles}
        />
        <AdminStateCard
          label="Featured"
          value={
            loading
              ? "..."
              : competitions.filter((competition) => competition.isFeatured).length.toString()
          }
          helper="Pinned on homepage surfaces."
        />
        <AdminStateCard
          label="Entries"
          value={
            loading
              ? "..."
              : competitions.reduce((sum, competition) => sum + competition.activeEntries, 0).toString()
          }
          helper="Current total entries."
          icon={Users}
        />
        <AdminStateCard
          label="Players"
          value={opsLoading ? "..." : String(operations?.players.length ?? 0)}
          helper="Priced for selected competition."
        />
        <AdminStateCard
          label="Gameweeks"
          value={opsLoading ? "..." : String(operations?.gameweeks.length ?? 0)}
          helper="Operational rounds loaded."
          icon={CalendarDays}
        />
      </div>

      <div className="glass-panel rounded-[32px] p-6">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Active competition
        </p>
        <div className="mt-4 flex flex-wrap gap-3">
          {competitions.map((competition) => (
            <button
              key={competition.id}
              type="button"
              onClick={() => setActiveCompetitionId(competition.id)}
              className={`rounded-full border px-4 py-2 text-sm font-semibold transition ${
                activeCompetitionId === competition.id
                  ? "border-club-accent bg-club-accent/15 text-white"
                  : "border-border-soft text-slate-200 hover:bg-white/8"
              }`}
            >
              {competition.name}
            </button>
          ))}
        </div>
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.95fr_1.05fr]">
        <form onSubmit={submitCompetition} className="glass-panel rounded-[32px] p-6 grid gap-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                Competition editor
              </p>
              <p className="mt-2 font-display text-3xl font-bold uppercase leading-none text-white">
                {form.id ? "Edit competition" : "New competition"}
              </p>
            </div>
            {form.id ? (
              <button
                type="button"
                onClick={() => setForm(emptyForm)}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-white/8"
              >
                Clear
              </button>
            ) : null}
          </div>

          <label className="grid gap-2">
            <span className="text-sm font-semibold text-slate-100">Slug</span>
            <input
              value={form.slug}
              onChange={(event) => setForm((current) => ({ ...current, slug: event.target.value }))}
              className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              placeholder="wc-2026"
              required
            />
          </label>

          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Name</span>
              <input
                value={form.name}
                onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                placeholder="World Cup Fantasy"
                required
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Short name</span>
              <input
                value={form.shortName}
                onChange={(event) => setForm((current) => ({ ...current, shortName: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                placeholder="World Cup"
                required
              />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-3">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Season</span>
              <input
                value={form.season}
                onChange={(event) => setForm((current) => ({ ...current, season: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                required
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Mode</span>
              <select
                value={form.mode}
                onChange={(event) =>
                  setForm((current) => ({ ...current, mode: event.target.value as FantasyCompetitionMode }))
                }
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              >
                <option value="season_long">Season long</option>
                <option value="tournament">Tournament</option>
              </select>
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Backend status</span>
              <select
                value={form.backendStatus}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    backendStatus: event.target.value as FantasyForm["backendStatus"],
                  }))
                }
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              >
                <option value="draft">Draft</option>
                <option value="active">Active</option>
                <option value="finished">Finished</option>
              </select>
            </label>
          </div>

          <label className="grid gap-2">
            <span className="text-sm font-semibold text-slate-100">Description</span>
            <textarea
              value={form.description}
              onChange={(event) => setForm((current) => ({ ...current, description: event.target.value }))}
              className="min-h-28 rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
            />
          </label>

          <div className="grid gap-4 md:grid-cols-3">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Primary color</span>
              <input
                value={form.primaryColor}
                onChange={(event) => setForm((current) => ({ ...current, primaryColor: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Country code</span>
              <input
                value={form.countryCode}
                onChange={(event) => setForm((current) => ({ ...current, countryCode: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Provider</span>
              <input
                value={form.provider}
                onChange={(event) => setForm((current) => ({ ...current, provider: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Start</span>
              <input
                type="datetime-local"
                value={form.startAt}
                onChange={(event) => setForm((current) => ({ ...current, startAt: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                required
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">End</span>
              <input
                type="datetime-local"
                value={form.endAt}
                onChange={(event) => setForm((current) => ({ ...current, endAt: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                required
              />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Promo title</span>
              <input
                value={form.promoTitle}
                onChange={(event) => setForm((current) => ({ ...current, promoTitle: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">CTA label</span>
              <input
                value={form.ctaLabel}
                onChange={(event) => setForm((current) => ({ ...current, ctaLabel: event.target.value }))}
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Entry window opens</span>
              <input
                type="datetime-local"
                value={form.entryWindowOpensAt}
                onChange={(event) =>
                  setForm((current) => ({ ...current, entryWindowOpensAt: event.target.value }))
                }
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-100">Entry window closes</span>
              <input
                type="datetime-local"
                value={form.entryWindowClosesAt}
                onChange={(event) =>
                  setForm((current) => ({ ...current, entryWindowClosesAt: event.target.value }))
                }
                className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
              />
            </label>
          </div>

          <div className="grid gap-3 md:grid-cols-3">
            {[
              { key: "isVisible", label: "Visible" },
              { key: "isFeatured", label: "Featured" },
              { key: "isPlayable", label: "Playable" },
            ].map((toggle) => (
              <label
                key={toggle.key}
                className="flex items-center justify-between rounded-2xl border border-border-soft bg-white/5 px-4 py-3"
              >
                <span className="text-sm font-semibold text-slate-100">{toggle.label}</span>
                <input
                  type="checkbox"
                  checked={form[toggle.key as keyof FantasyForm] as boolean}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      [toggle.key]: event.target.checked,
                    }))
                  }
                />
              </label>
            ))}
          </div>

          <button
            type="submit"
            className="inline-flex items-center justify-center gap-2 rounded-full bg-club-accent px-5 py-3 text-sm font-semibold text-white transition hover:opacity-90"
          >
            <Plus className="h-4 w-4" />
            {form.id ? "Update competition" : "Create competition"}
          </button>
        </form>

        <div className="glass-panel rounded-[32px] p-6">
          <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
            Current competitions
          </p>
          <div className="mt-4 grid gap-3">
            {competitions.map((competition) => (
              <div
                key={competition.id}
                className="rounded-[28px] border border-border-soft bg-white/5 p-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="font-semibold text-white">{competition.name}</p>
                    <p className="mt-1 text-sm text-slate-300">
                      {competition.season} • {competition.mode.replace("_", " ")} • {competition.backendStatus}
                    </p>
                    <p className="mt-2 text-sm text-slate-400">
                      {competition.activeEntries} entries • {competition.isFeatured ? "Featured" : "Standard"}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        setForm(competitionToForm(competition));
                        setActiveCompetitionId(competition.id);
                      }}
                      className="rounded-full border border-border-soft p-2 text-slate-200 transition hover:bg-white/8"
                    >
                      <Edit3 className="h-4 w-4" />
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        removeCompetition(competition).catch(() => {});
                      }}
                      className="rounded-full border border-red-500/30 p-2 text-red-200 transition hover:bg-red-500/10"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
            {!loading && competitions.length === 0 ? (
              <div className="rounded-[28px] border border-dashed border-border-soft p-6 text-sm text-slate-400">
                No fantasy competitions configured yet.
              </div>
            ) : null}
          </div>
        </div>
      </div>

      {selectedCompetition ? (
        <div className="grid gap-5 xl:grid-cols-2">
          <div className="glass-panel rounded-[32px] p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                  Players & prices
                </p>
                <p className="mt-2 font-display text-3xl font-bold uppercase leading-none text-white">
                  {selectedCompetition.shortName}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setPlayerForm(emptyPlayerForm)}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-white/8"
              >
                Clear
              </button>
            </div>

            <form onSubmit={submitPlayer} className="mt-5 grid gap-4">
              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">External id</span>
                  <input
                    value={playerForm.externalId}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, externalId: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Position</span>
                  <select
                    value={playerForm.position}
                    onChange={(event) =>
                      setPlayerForm((current) => ({
                        ...current,
                        position: event.target.value as AdminFantasyPlayerPosition,
                      }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  >
                    <option value="GK">Goalkeeper</option>
                    <option value="DEF">Defender</option>
                    <option value="MID">Midfielder</option>
                    <option value="FWD">Forward</option>
                  </select>
                </label>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Name</span>
                  <input
                    value={playerForm.name}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, name: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Short name</span>
                  <input
                    value={playerForm.shortName}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, shortName: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
              </div>

              <div className="grid gap-4 md:grid-cols-3">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Team id</span>
                  <input
                    value={playerForm.teamId}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, teamId: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Team name</span>
                  <input
                    value={playerForm.teamName}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, teamName: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Team short</span>
                  <input
                    value={playerForm.teamShort}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, teamShort: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
              </div>

              <div className="grid gap-4 md:grid-cols-3">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Price</span>
                  <input
                    value={playerForm.price}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, price: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Price change</span>
                  <input
                    value={playerForm.priceChange}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, priceChange: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Ownership %</span>
                  <input
                    value={playerForm.ownershipPercent}
                    onChange={(event) =>
                      setPlayerForm((current) => ({
                        ...current,
                        ownershipPercent: event.target.value,
                      }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  />
                </label>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Nationality</span>
                  <input
                    value={playerForm.nationality}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, nationality: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Photo URL</span>
                  <input
                    value={playerForm.photoUrl}
                    onChange={(event) =>
                      setPlayerForm((current) => ({ ...current, photoUrl: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  />
                </label>
              </div>

              <button
                type="submit"
                className="inline-flex items-center justify-center gap-2 rounded-full bg-club-accent px-5 py-3 text-sm font-semibold text-white transition hover:opacity-90"
              >
                <Plus className="h-4 w-4" />
                Save priced player
              </button>
            </form>

            <div className="mt-6 grid gap-3">
              {(operations?.players ?? []).map((player) => (
                <div
                  key={`${player.competitionId}-${player.externalId}`}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-semibold text-white">
                        {player.shortName} • {player.position}
                      </p>
                      <p className="mt-1 text-sm text-slate-300">
                        {player.teamName} • {formatBudget(player.price)}M
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setPlayerForm(playerToForm(player))}
                        className="rounded-full border border-border-soft p-2 text-slate-200 transition hover:bg-white/8"
                      >
                        <Edit3 className="h-4 w-4" />
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          removePlayer(player).catch(() => {});
                        }}
                        className="rounded-full border border-red-500/30 p-2 text-red-200 transition hover:bg-red-500/10"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
              {!opsLoading && (operations?.players.length ?? 0) === 0 ? (
                <div className="rounded-[24px] border border-dashed border-border-soft p-6 text-sm text-slate-400">
                  No priced players yet for this competition.
                </div>
              ) : null}
            </div>
          </div>

          <div className="glass-panel rounded-[32px] p-6">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
                  Gameweeks
                </p>
                <p className="mt-2 font-display text-3xl font-bold uppercase leading-none text-white">
                  Operational rounds
                </p>
              </div>
              <button
                type="button"
                onClick={() => setGameweekForm(emptyGameweekForm)}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-white/8"
              >
                Clear
              </button>
            </div>

            <form onSubmit={submitGameweek} className="mt-5 grid gap-4">
              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Number</span>
                  <input
                    value={gameweekForm.number}
                    onChange={(event) =>
                      setGameweekForm((current) => ({ ...current, number: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Status</span>
                  <select
                    value={gameweekForm.status}
                    onChange={(event) =>
                      setGameweekForm((current) => ({
                        ...current,
                        status: event.target.value as AdminFantasyGameweekStatus,
                      }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  >
                    <option value="upcoming">Upcoming</option>
                    <option value="live">Live</option>
                    <option value="scoring">Scoring</option>
                    <option value="finished">Finished</option>
                  </select>
                </label>
              </div>

              <label className="grid gap-2">
                <span className="text-sm font-semibold text-slate-100">Name</span>
                <input
                  value={gameweekForm.name}
                  onChange={(event) =>
                    setGameweekForm((current) => ({ ...current, name: event.target.value }))
                  }
                  className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                  required
                />
              </label>

              <div className="grid gap-4">
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Deadline</span>
                  <input
                    type="datetime-local"
                    value={gameweekForm.deadlineAt}
                    onChange={(event) =>
                      setGameweekForm((current) => ({
                        ...current,
                        deadlineAt: event.target.value,
                      }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">Start</span>
                  <input
                    type="datetime-local"
                    value={gameweekForm.startAt}
                    onChange={(event) =>
                      setGameweekForm((current) => ({ ...current, startAt: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
                <label className="grid gap-2">
                  <span className="text-sm font-semibold text-slate-100">End</span>
                  <input
                    type="datetime-local"
                    value={gameweekForm.endAt}
                    onChange={(event) =>
                      setGameweekForm((current) => ({ ...current, endAt: event.target.value }))
                    }
                    className="rounded-2xl border border-border-soft bg-white/5 px-4 py-3 text-white outline-none"
                    required
                  />
                </label>
              </div>

              <label className="flex items-center justify-between rounded-2xl border border-border-soft bg-white/5 px-4 py-3">
                <span className="text-sm font-semibold text-slate-100">Double gameweek</span>
                <input
                  type="checkbox"
                  checked={gameweekForm.isDoubleGameweek}
                  onChange={(event) =>
                    setGameweekForm((current) => ({
                      ...current,
                      isDoubleGameweek: event.target.checked,
                    }))
                  }
                />
              </label>

              <button
                type="submit"
                className="inline-flex items-center justify-center gap-2 rounded-full bg-club-accent px-5 py-3 text-sm font-semibold text-white transition hover:opacity-90"
              >
                <Plus className="h-4 w-4" />
                Save gameweek
              </button>
            </form>

            <div className="mt-6 grid gap-3">
              {(operations?.gameweeks ?? []).map((gameweek) => (
                <div
                  key={gameweek.id}
                  className="rounded-[24px] border border-border-soft bg-white/5 p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-semibold text-white">
                        GW {gameweek.number} • {gameweek.name}
                      </p>
                      <p className="mt-1 text-sm text-slate-300">
                        {gameweek.status} • deadline {new Date(gameweek.deadlineAt).toLocaleString()}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setGameweekForm(gameweekToForm(gameweek))}
                        className="rounded-full border border-border-soft p-2 text-slate-200 transition hover:bg-white/8"
                      >
                        <Edit3 className="h-4 w-4" />
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          removeGameweek(gameweek).catch(() => {});
                        }}
                        className="rounded-full border border-red-500/30 p-2 text-red-200 transition hover:bg-red-500/10"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
              {!opsLoading && (operations?.gameweeks.length ?? 0) === 0 ? (
                <div className="rounded-[24px] border border-dashed border-border-soft p-6 text-sm text-slate-400">
                  No gameweeks yet for this competition.
                </div>
              ) : null}
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
