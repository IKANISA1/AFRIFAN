import { Gamepad2, Monitor, ShieldCheck, Trophy } from "lucide-react";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import {
  buildTvDisplayViewModel,
  createDemoTvSessionState,
} from "@/lib/game-runtime";
import { rayonClub } from "@/lib/config";
import { GamesControlClient } from "./games-control-client";

const readinessItems = [
  {
    title: "Runtime foundation",
    body: "Game sessions, TV devices, question packs, answer attempts, claims, scores, and audit logs are modeled in the africlub_game schema.",
  },
  {
    title: "Fair-play contract",
    body: "The answer RPC accepts one attempt per player per question and records the first correct claim with idempotency protection.",
  },
  {
    title: "TV display contract",
    body: "The TV state RPC returns public session state and withholds correct-answer material until claim, reveal, or closed states.",
  },
  {
    title: "Admin actions",
    body: "Open and reveal actions are routed through the game-session-action function and club-admin verification.",
  },
];

export default function AdminGamesPage() {
  const display = buildTvDisplayViewModel(createDemoTvSessionState());

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Matchday games"
        title="Game Control Room"
        meta={
          <p className="max-w-3xl text-sm leading-6 text-[var(--admin-muted)]">
            Operate quiz sessions, pair venue displays, and monitor fair-play
            state from one admin workspace.
          </p>
        }
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Runtime"
          value="SQL"
          helper="Dedicated africlub_game schema."
          icon={Gamepad2}
        />
        <AdminStateCard
          label="TV display"
          value={display.joinCode ?? "/tv-display"}
          helper="Large-screen session surface and join code."
          icon={Monitor}
        />
        <AdminStateCard
          label="Answer claims"
          value={display.claimLabel === "Waiting for answer" ? "Open" : "Claimed"}
          helper="First correct answer wins the claim."
          icon={Trophy}
        />
        <AdminStateCard
          label="Guardrails"
          value="RLS"
          helper="Club-scoped access boundaries."
          icon={ShieldCheck}
        />
      </div>

      <GamesControlClient defaultClubId={rayonClub.numericId} />

      <section className="grid gap-4 lg:grid-cols-2">
        {readinessItems.map((item) => (
          <article
            key={item.title}
            className="rounded-lg border border-[var(--admin-border)] bg-[var(--admin-surface)] p-5 shadow-sm"
          >
            <h2 className="text-base font-semibold text-[var(--admin-text)]">
              {item.title}
            </h2>
            <p className="mt-2 text-sm leading-6 text-[var(--admin-muted)]">
              {item.body}
            </p>
          </article>
        ))}
      </section>
    </div>
  );
}
