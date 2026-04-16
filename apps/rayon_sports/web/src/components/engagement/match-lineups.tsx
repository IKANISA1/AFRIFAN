"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import { TacticalPitch } from "./tactical-pitch";

interface PlayerSnippet {
  id: string;
  name: string;
  number: number;
  position: "GK" | "DEF" | "MID" | "FWD";
  isCaptain?: boolean;
}

interface TeamLineup {
  teamName: string;
  formation: string;
  startingXI: PlayerSnippet[];
  subs: PlayerSnippet[];
  manager: string;
  color?: string;
}

interface MatchLineupsProps {
  home: TeamLineup;
  away: TeamLineup;
}

export function MatchLineups({ home, away }: MatchLineupsProps) {
  const [activeTab, setActiveTab] = useState<"home" | "away">("home");
  
  const activeTeam = activeTab === "home" ? home : away;
  
  const goalkeepers = activeTeam.startingXI.filter(p => p.position === "GK");
  const defenders = activeTeam.startingXI.filter(p => p.position === "DEF");
  const midfielders = activeTeam.startingXI.filter(p => p.position === "MID");
  const forwards = activeTeam.startingXI.filter(p => p.position === "FWD");
  
  return (
    <div className="glass-panel rounded-[32px] p-6 lg:p-8">
      <p className="font-mono text-xs uppercase tracking-[0.24em] text-[var(--club-accent)]">
        Tactics & Personnel
      </p>
      
      <div className="mt-6 flex rounded-2xl bg-black/20 p-1 lg:max-w-md">
        <button
          className={cn(
            "flex-1 rounded-xl py-3 text-xs font-black uppercase tracking-widest transition-all",
            activeTab === "home" ? "bg-[var(--club-primary)] text-white shadow-lg" : "text-white/40 hover:text-white"
          )}
          onClick={() => setActiveTab("home")}
        >
          {home.teamName}
        </button>
        <button
          className={cn(
            "flex-1 rounded-xl py-3 text-xs font-black uppercase tracking-widest transition-all",
            activeTab === "away" ? "bg-[var(--club-primary)] text-white shadow-lg" : "text-white/40 hover:text-white"
          )}
          onClick={() => setActiveTab("away")}
        >
          {away.teamName}
        </button>
      </div>

      <div className="mt-8 grid gap-10 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-8">
          <header>
            <h2 className="font-display text-4xl font-black uppercase italic text-white tracking-tight">
              Formation: {activeTeam.formation}
            </h2>
            <p className="mt-2 text-[10px] font-bold uppercase tracking-[0.3em] text-white/40">
              MGR: {activeTeam.manager}
            </p>
          </header>

          <TacticalPitch 
            startingXI={activeTeam.startingXI} 
            formation={activeTeam.formation}
            teamColor={activeTeam.color}
          />
        </div>

        <div className="space-y-8">
          {/* Starting XI List */}
          <div className="space-y-6">
            <LineupGroup title="Goalkeeper" players={goalkeepers} />
            <LineupGroup title="Defenders" players={defenders} />
            <LineupGroup title="Midfielders" players={midfielders} />
            <LineupGroup title="Forwards" players={forwards} />
          </div>
          
          {/* Bench */}
          <div className="rounded-2xl border border-white/5 bg-white/4 p-6">
            <h3 className="font-mono text-[10px] font-black uppercase tracking-[0.3em] text-white/30 mb-5">Substitutes</h3>
            <div className="grid grid-cols-2 gap-3">
              {activeTeam.subs.map(sub => (
                <div key={sub.id} className="flex items-center gap-2 text-xs font-bold text-white/70">
                  <span className="font-mono text-[var(--club-accent)]">{sub.number}</span>
                  {sub.name}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function LineupGroup({ title, players }: { title: string, players: PlayerSnippet[] }) {
  if (players.length === 0) return null;
  return (
    <div>
      <h3 className="font-mono text-[10px] font-black uppercase tracking-[0.3em] text-white/30 mb-4">{title}</h3>
      <div className="grid gap-3">
        {players.map(player => (
          <div key={player.id} className="flex items-center gap-4 rounded-xl border border-white/5 bg-white/5 px-4 py-3 transition-colors hover:bg-white/8">
            <span className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--club-primary)]/40 font-display text-base font-black italic text-white shadow-xl">
              {player.number}
            </span>
            <div>
              <p className="text-sm font-black uppercase italic tracking-tight text-white">
                {player.name}
              </p>
              {player.isCaptain && <p className="text-[9px] font-black uppercase tracking-widest text-[var(--club-accent)] mt-0.5">Captain</p>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
