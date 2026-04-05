"use client";

import { useId, useState } from "react";
import { cn } from "@/lib/utils";

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
}

interface MatchLineupsProps {
  home: TeamLineup;
  away: TeamLineup;
}

export function MatchLineups({ home, away }: MatchLineupsProps) {
  const [activeTab, setActiveTab] = useState<"home" | "away">("home");
  const idPrefix = useId();
  
  const activeTeam = activeTab === "home" ? home : away;
  
  const goalkeepers = activeTeam.startingXI.filter(p => p.position === "GK");
  const defenders = activeTeam.startingXI.filter(p => p.position === "DEF");
  const midfielders = activeTeam.startingXI.filter(p => p.position === "MID");
  const forwards = activeTeam.startingXI.filter(p => p.position === "FWD");
  
  return (
    <div className="glass-panel rounded-[32px] p-6">
      <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
        Lineups & Formations
      </p>
      
      <div className="mt-4 flex rounded-xl bg-white/5 p-1">
        <button
          className={cn(
            "flex-1 rounded-lg py-2.5 text-xs font-semibold uppercase tracking-wider transition-colors",
            activeTab === "home" ? "bg-club-primary text-white" : "text-slate-400 hover:text-white"
          )}
          onClick={() => setActiveTab("home")}
        >
          {home.teamName}
        </button>
        <button
          className={cn(
            "flex-1 rounded-lg py-2.5 text-xs font-semibold uppercase tracking-wider transition-colors",
            activeTab === "away" ? "bg-club-primary text-white" : "text-slate-400 hover:text-white"
          )}
          onClick={() => setActiveTab("away")}
        >
          {away.teamName}
        </button>
      </div>
      
      <div className="mt-6 flex items-center justify-between">
        <p className="font-display text-2xl font-bold uppercase text-white">
          Formation: {activeTeam.formation}
        </p>
        <p className="text-xs text-slate-400 uppercase tracking-widest">
          MGR: {activeTeam.manager}
        </p>
      </div>
      
      {/* Starting XI List */}
      <div className="mt-5 space-y-5">
        <LineupGroup title="Goalkeeper" players={goalkeepers} />
        <LineupGroup title="Defenders" players={defenders} />
        <LineupGroup title="Midfielders" players={midfielders} />
        <LineupGroup title="Forwards" players={forwards} />
      </div>
      
      {/* Bench */}
      <div className="mt-6 border-t border-white/10 pt-5">
        <h3 className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400 mb-3">Substitutes</h3>
        <div className="flex flex-wrap gap-2">
          {activeTeam.subs.map(sub => (
            <span key={sub.id} className="flex items-center gap-1.5 rounded-full bg-white/5 px-2.5 py-1 text-xs text-slate-300">
              <span className="font-mono font-bold text-club-accent">{sub.number}</span>
              {sub.name}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

function LineupGroup({ title, players }: { title: string, players: PlayerSnippet[] }) {
  if (players.length === 0) return null;
  return (
    <div>
      <h3 className="font-mono text-[10px] uppercase tracking-[0.2em] text-slate-400 mb-2">{title}</h3>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {players.map(player => (
          <div key={player.id} className="flex items-center gap-3 rounded-xl border border-white/5 bg-white/4 px-3 py-2">
            <span className="flex h-8 w-8 items-center justify-center rounded-full bg-club-primary/20 font-score text-sm font-bold text-white">
              {player.number}
            </span>
            <span className="font-semibold text-slate-200">
              {player.name} {player.isCaptain && <span className="ml-1 text-xs text-club-accent">(C)</span>}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
