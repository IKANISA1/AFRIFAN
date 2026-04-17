"use client";

import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Calendar, MapPin, Ticket } from "lucide-react";
import { resolveFanAppHref } from "@/lib/config";
import { cn, formatDateTime } from "@/lib/utils";
import type { ClubProfile, MatchItem } from "@/lib/types";

interface EliteHeroProps {
  club: ClubProfile;
  featuredMatch: MatchItem | null;
  tagline?: string;
  headline?: string;
  description?: string;
}

export function EliteHero({
  club,
  featuredMatch,
  tagline,
  headline,
  description,
}: EliteHeroProps) {
  return (
    <section className="relative overflow-hidden bg-[var(--club-primary)]">
      {/* Editorial Background */}
      <div className="relative aspect-[16/9] w-full lg:aspect-[21/9]">
        <Image
          src="/media/stadium-hero.jpg"
          alt="Rayon Sports Stadium Atmosphere"
          fill
          priority
          className="object-cover object-center opacity-60 mix-blend-luminosity grayscale-[0.2]"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-[var(--club-primary)] via-[var(--club-primary)]/40 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-r from-[var(--club-primary)] via-transparent to-transparent" />
      </div>

      {/* Hero Content */}
      <div className="page-shell relative z-10 -mt-32 pb-12 lg:-mt-64 lg:pb-24">
        <div className="max-w-3xl">
          <p className="mb-4 text-xs font-bold uppercase tracking-[0.4em] text-[var(--club-accent)] drop-shadow-sm lg:text-sm">
            {tagline || "Gikundiro Elite"}
          </p>
          <h1 className="font-display text-5xl font-black uppercase italic leading-[0.9] tracking-tighter text-white drop-shadow-xl lg:text-8xl">
            {headline || "One Club. One City. One Beloved."}
          </h1>
          <p className="mt-6 max-w-xl text-lg font-medium leading-relaxed text-white/92 drop-shadow-md lg:text-xl">
            {description || "Join the legacy of Rwanda's most successful club. Experience matchday magic, exclusive content, and a community like no other."}
          </p>
          
          <div className="mt-10 flex flex-wrap gap-4">
            <Link 
              href="/membership" 
              className="group flex items-center gap-3 rounded-full bg-[var(--club-accent)] px-8 py-4 text-sm font-black uppercase tracking-widest text-slate-950 transition-all hover:scale-105 hover:bg-white"
            >
              Join the Beloved <ArrowRight size={18} className="transition-transform group-hover:translate-x-1" />
            </Link>
            <Link 
              href={resolveFanAppHref()}
              aria-label="Open supporter app"
              className="flex items-center gap-3 rounded-full border-2 border-white/18 bg-slate-950/72 px-8 py-4 text-sm font-black uppercase tracking-widest text-white backdrop-blur-md transition-all hover:border-white/40 hover:bg-slate-900/88"
            >
              Open supporter app
            </Link>
          </div>
        </div>
      </div>

      {/* Matchday Strip (The World-Class Anchor) */}
      <div className="page-shell relative z-20 -mb-16 lg:-mb-20">
        {featuredMatch && (
          <div className="overflow-hidden rounded-3xl bg-white shadow-2xl transition-transform hover:scale-[1.01] lg:flex">
            <div className="flex flex-1 items-center justify-between p-6 lg:p-10">
              <div className="flex flex-1 items-center justify-center gap-4 lg:gap-12">
                <div className="text-center">
                  <div className="h-16 w-16 mx-auto rounded-full bg-slate-100 p-2 lg:h-24 lg:w-24">
                    {/* Placeholder for crests */}
                    <div className="h-full w-full rounded-full border-2 border-dashed border-slate-300" />
                  </div>
                  <p className="mt-3 text-xs font-black uppercase tracking-tighter text-slate-900 lg:text-lg">{featuredMatch.homeTeam}</p>
                </div>
                
                <div className="text-center">
                  <div className="mb-2 inline-block rounded-full bg-slate-100 px-3 py-1 text-[10px] font-black uppercase tracking-widest text-slate-700">
                    {featuredMatch.competition}
                  </div>
                  <p className="font-display text-4xl font-black italic text-slate-500 lg:text-6xl">VS</p>
                  <p className="mt-2 text-[10px] font-bold uppercase tracking-widest text-slate-700">
                    {formatDateTime(featuredMatch.matchDate)}
                  </p>
                </div>

                <div className="text-center">
                  <div className="h-16 w-16 mx-auto rounded-full bg-slate-100 p-2 lg:h-24 lg:w-24">
                    <div className="h-full w-full rounded-full border-2 border-dashed border-slate-300" />
                  </div>
                  <p className="mt-3 text-xs font-black uppercase tracking-tighter text-slate-900 lg:text-lg">{featuredMatch.awayTeam}</p>
                </div>
              </div>
            </div>

            <div className="border-t border-slate-100 bg-slate-50 p-6 lg:w-80 lg:border-l lg:border-t-0 lg:p-10">
              <div className="space-y-4">
                <div className="flex items-center gap-3 text-slate-600">
                  <MapPin size={18} />
                  <p className="text-xs font-bold uppercase tracking-wide">{featuredMatch.venue}</p>
                </div>
                <div className="flex items-center gap-3 text-slate-600">
                  <Calendar size={18} />
                  <p className="text-xs font-bold uppercase tracking-wide">{featuredMatch.kickoffTime || "18:00"}</p>
                </div>
                {featuredMatch.isOnSale ? (
                  <Link 
                    href="/tickets" 
                    className="flex w-full items-center justify-center gap-2 rounded-xl bg-[var(--club-primary)] py-4 text-xs font-black uppercase tracking-widest text-white transition-all hover:bg-[var(--club-primary-light)] shadow-lg active:scale-95"
                  >
                    <Ticket size={16} /> Buy Tickets
                  </Link>
                ) : (
                  <Link 
                    href="/news" 
                    className="flex w-full items-center justify-center gap-2 rounded-xl bg-slate-800 py-4 text-xs font-black uppercase tracking-widest text-white transition-all hover:bg-slate-700"
                  >
                    Match Center
                  </Link>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
