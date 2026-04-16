"use client";

import { cn } from "@/lib/utils";

interface PlayerSnippet {
  id: string;
  name: string;
  number: number;
  position: "GK" | "DEF" | "MID" | "FWD";
  isCaptain?: boolean;
}

interface TacticalPitchProps {
  startingXI: PlayerSnippet[];
  formation: string;
  teamColor?: string;
}

export function TacticalPitch({ startingXI, formation, teamColor = "var(--club-primary)" }: TacticalPitchProps) {
  // Simple coordinate mapping logic based on formation (e.g., "4-3-3")
  // For a truly world-class version, we'd have precise (x,y) for each player.
  // Here I'll approximate positions based on the index in each group.
  
  const goalkeepers = startingXI.filter(p => p.position === "GK");
  const defenders = startingXI.filter(p => p.position === "DEF");
  const midfielders = startingXI.filter(p => p.position === "MID");
  const forwards = startingXI.filter(p => p.position === "FWD");

  return (
    <div className="relative aspect-[3/4] w-full overflow-hidden rounded-3xl border border-white/10 bg-[#12223a] shadow-2xl lg:aspect-[4/5]">
      {/* Pitch Lines */}
      <div className="absolute inset-0 opacity-20">
        <div className="absolute inset-[5%] border-2 border-white" />
        <div className="absolute left-1/2 top-[5%] h-[15%] w-[40%] -translate-x-1/2 border-2 border-t-0 border-white" />
        <div className="absolute left-1/2 bottom-[5%] h-[15%] w-[40%] -translate-x-1/2 border-2 border-b-0 border-white" />
        <div className="absolute left-1/2 top-1/2 h-px w-[90%] -translate-x-1/2 bg-white" />
        <div className="absolute left-1/2 top-1/2 h-[20%] aspect-square -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white" />
      </div>

      {/* Players */}
      <div className="relative h-full w-full p-[10%]">
        {/* GK */}
        <div className="absolute bottom-[5%] left-1/2 -translate-x-1/2">
          {goalkeepers.map(p => <PlayerCircle key={p.id} player={p} color={teamColor} />)}
        </div>

        {/* DEF */}
        <div className="absolute bottom-[25%] left-0 right-0 flex justify-around px-[10%]">
          {defenders.map(p => <PlayerCircle key={p.id} player={p} color={teamColor} />)}
        </div>

        {/* MID */}
        <div className="absolute bottom-[50%] left-0 right-0 flex justify-around px-[12%] -translate-y-1/2">
          {midfielders.map(p => <PlayerCircle key={p.id} player={p} color={teamColor} />)}
        </div>

        {/* FWD */}
        <div className="absolute top-[15%] left-0 right-0 flex justify-around px-[15%]">
          {forwards.map(p => <PlayerCircle key={p.id} player={p} color={teamColor} />)}
        </div>
      </div>

      <div className="absolute bottom-4 right-6 text-[10px] font-black uppercase tracking-[0.3em] text-white/20 italic">
        {formation} Tactical Shape
      </div>
    </div>
  );
}

function PlayerCircle({ player, color }: { player: PlayerSnippet, color: string }) {
  return (
    <div className="group relative flex flex-col items-center gap-1">
      <div 
        className="flex h-10 w-10 items-center justify-center rounded-full border-2 border-white/80 font-score text-sm font-black text-white shadow-2xl transition-transform group-hover:scale-110"
        style={{ backgroundColor: color }}
      >
        {player.number}
      </div>
      <div className="rounded-md bg-black/40 px-2 py-0.5 backdrop-blur-md">
        <p className="whitespace-nowrap text-[9px] font-black uppercase tracking-wider text-white">
          {player.name}
          {player.isCaptain && <span className="ml-1 text-[var(--club-accent)]">*</span>}
        </p>
      </div>
    </div>
  );
}
