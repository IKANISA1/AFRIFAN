"use client";

import { AlertCircle, ArrowLeftRight, Goal, Square } from "lucide-react";
import type { MatchEventItem } from "@/lib/types";
import { cn } from "@/lib/utils";

interface MatchTimelineProps {
  events: MatchEventItem[];
  homeTeam: string;
  awayTeam: string;
}

export function MatchTimeline({ events, homeTeam, awayTeam }: MatchTimelineProps) {
  if (events.length === 0) {
    return (
      <div className="rounded-[32px] border border-white/5 bg-white/4 p-10 text-center">
        <p className="text-sm text-slate-400">
          No events recorded yet. Updates will appear as they happen.
        </p>
      </div>
    );
  }

  // Sort events by minute (descending for latest first)
  const sortedEvents = [...events].sort((a, b) => {
    const minA = parseInt(a.minute.replace("'", ""));
    const minB = parseInt(b.minute.replace("'", ""));
    return minB - minA;
  });

  return (
    <div className="relative space-y-6 before:absolute before:left-[17px] before:top-2 before:h-[calc(100%-16px)] before:w-0.5 before:bg-white/10 sm:before:left-1/2 sm:before:-translate-x-1/2">
      {sortedEvents.map((event, index) => {
        const isHome = event.side === "home";
        const icon = resolveEventIcon(event.event);
        
        return (
          <div 
            key={`${event.minute}-${event.event}-${index}`}
            className={cn(
              "relative flex items-center gap-6 sm:gap-0",
              isHome ? "sm:flex-row-reverse" : "sm:flex-row"
            )}
          >
            {/* Minute Marker */}
            <div className="z-10 flex h-9 w-9 shrink-0 items-center justify-center rounded-full border-2 border-[var(--club-primary)] bg-[#0a1628] font-mono text-[11px] font-bold text-white shadow-xl sm:absolute sm:left-1/2 sm:-translate-x-1/2">
              {event.minute}
            </div>

            {/* Event Card */}
            <div className={cn(
              "flex-1 rounded-[24px] border border-white/8 bg-white/5 p-4 shadow-sm transition-all hover:border-white/20 sm:w-[calc(50%-2.5rem)]",
              isHome ? "sm:ml-auto" : "sm:mr-auto"
            )}>
              <div className={cn(
                "flex items-center gap-3",
                isHome ? "flex-row" : "sm:flex-row-reverse"
              )}>
                <span className={cn(
                  "flex h-8 w-8 items-center justify-center rounded-full bg-white/10",
                  event.event.toLowerCase().includes("goal") ? "text-emerald-400" : "text-club-accent"
                )}>
                  {icon}
                </span>
                <div className={cn(
                  "flex-1",
                  !isHome && "sm:text-right"
                )}>
                  <p className="text-xs font-bold uppercase tracking-widest text-slate-400">
                    {isHome ? homeTeam : awayTeam}
                  </p>
                  <p className="mt-1 text-sm font-semibold text-white leading-snug">
                    {event.event}
                  </p>
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function resolveEventIcon(eventText: string) {
  const text = eventText.toLowerCase();
  if (text.includes("goal")) return <Goal size={16} />;
  if (text.includes("yellow card")) return <Square size={16} className="fill-amber-400 text-amber-400" />;
  if (text.includes("red card")) return <Square size={16} className="fill-rose-500 text-rose-500" />;
  if (text.includes("substitution") || text.includes("off") || text.includes("on")) return <ArrowLeftRight size={16} />;
  return <AlertCircle size={16} />;
}
