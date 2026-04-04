"use client";

import { Trash2 } from "lucide-react";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminSquadPlayer } from "@/lib/data/admin";
import { positionColor } from "./squad-form-state";

interface SquadListProps {
  players: AdminSquadPlayer[];
  filter: string;
  setFilter: (f: string) => void;
  loading: boolean;
  onEdit: (player: AdminSquadPlayer) => void;
  onDelete: (player: AdminSquadPlayer) => void;
}

export function SquadList({ players, filter, setFilter, loading, onEdit, onDelete }: SquadListProps) {
  const filteredPlayers = players.filter((player) => {
    if (filter === "ALL") return true;
    return player.role.toLowerCase().includes(filter.toLowerCase());
  });

  return (
    <section className="glass-panel rounded-[32px] p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          Squad roster
        </p>
        <div className="flex flex-wrap gap-2">
          {["ALL", "GOALKEEPER", "DEFENDER", "MIDFIELDER", "FORWARD"].map((item) => (
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
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="flex items-center gap-4 rounded-[26px] border border-border-soft bg-white/5 p-5">
                <Skeleton className="h-14 w-14 flex-shrink-0 rounded-full" />
                <div className="flex-1 space-y-2">
                  <Skeleton className="skeleton-text h-5 w-2/5" />
                  <Skeleton className="skeleton-text h-3 w-full" />
                </div>
              </div>
            ))}
          </div>
        ) : null}
        
        {!loading && filteredPlayers.length === 0 ? (
          <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
            {filter === "ALL"
              ? "No players in the squad yet. Use the form to add the first player."
              : `No ${filter.toLowerCase()}s found.`}
          </p>
        ) : null}
        
        {!loading &&
          filteredPlayers.map((player) => (
            <article
              key={player.id}
              className={cn(
                "card-interactive flex items-start gap-4 rounded-[26px] border border-border-soft p-5 transition",
                player.isActive ? "bg-white/5" : "bg-white/[0.02] opacity-60",
              )}
            >
              {player.imageUrl ? (
                <div className="hidden sm:block h-14 w-14 flex-shrink-0 overflow-hidden rounded-full border-2 border-border-soft">
                  {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
                  <img src={player.imageUrl} alt={player.name} className="h-full w-full object-cover" />
                </div>
              ) : (
                <div className="hidden sm:flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-full border-2 border-border-soft bg-white/5 font-display text-xl font-bold text-club-accent">
                  {player.number}
                </div>
              )}
              <div className="flex-1 min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="font-display text-2xl font-bold uppercase leading-none">{player.name}</p>
                  <span className="font-display text-lg font-bold text-club-accent">#{player.number}</span>
                </div>
                <p className="mt-1 truncate text-sm text-slate-300">
                  {player.nationality} • {player.bio}
                </p>
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <span
                    className={cn(
                      "rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]",
                      positionColor(player.role),
                    )}
                  >
                    {player.role}
                  </span>
                  {!player.isActive ? (
                    <span className="rounded-full border border-rose-400/30 bg-rose-500/10 px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-rose-300">
                      Inactive
                    </span>
                  ) : null}
                </div>
              </div>
              <div className="flex flex-shrink-0 gap-2">
                <button
                  type="button"
                  onClick={() => onEdit(player)}
                  className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-white/8"
                  title="Edit"
                >
                  <span className="text-xs">✏️</span>
                </button>
                <button
                  type="button"
                  onClick={() => onDelete(player)}
                  className="rounded-full border border-border-soft p-2.5 text-slate-100 transition hover:bg-rose-500/15 hover:border-rose-400/30 hover:text-rose-300"
                  title="Remove"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </article>
          ))}
      </div>
    </section>
  );
}
