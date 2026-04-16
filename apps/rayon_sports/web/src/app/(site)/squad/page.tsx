import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ShieldCheck, Zap } from "lucide-react";
import { PageHero } from "@/components/page-hero";
import { getClubProfile, getSquad } from "@/lib/data/public";
import {
  buildPageMetadata,
  buildSquadJsonLd,
  renderJsonLdScriptContent,
} from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import type { SquadPlayer } from "@/lib/types";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.squad.metaTitle(club),
    description: copy.pages.squad.metaDescription(club),
    path: "/squad",
  });
}

export default async function SquadPage() {
  const [club, squad] = await Promise.all([getClubProfile(), getSquad()]);
  const copy = getSiteCopy(club.defaultLanguage);
  
  const positions = [
    { key: 'goalkeepers', label: copy.pages.squad.goalkeepers, filter: (p: SquadPlayer) => p.role.toLowerCase().includes("keeper") },
    { key: 'defenders', label: copy.pages.squad.defenders, filter: (p: SquadPlayer) => /back|defender/.test(p.role.toLowerCase()) },
    { key: 'midfielders', label: copy.pages.squad.midfielders, filter: (p: SquadPlayer) => p.role.toLowerCase().includes("mid") },
    { key: 'attackers', label: copy.pages.squad.attackers, filter: (p: SquadPlayer) => /wing|forward|striker/.test(p.role.toLowerCase()) || !/keeper|back|defender|mid/.test(p.role.toLowerCase()) },
  ];

  return (
    <div className="bg-[var(--club-primary)] min-h-screen pt-24 pb-20 lg:pt-32">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: renderJsonLdScriptContent(buildSquadJsonLd(club, squad)),
        }}
      />
      <div className="page-shell">
        <header className="mb-16 lg:mb-24">
          <p className="text-xs font-bold uppercase tracking-[0.4em] text-[var(--club-accent)] mb-4">{copy.pages.squad.eyebrow}</p>
          <h1 className="font-display text-6xl font-black uppercase italic leading-none tracking-tighter text-white lg:text-9xl">
            {copy.pages.squad.title}
          </h1>
          <div className="mt-8 max-w-2xl text-lg font-medium text-white/60">
            {copy.pages.squad.description(club)}
          </div>
        </header>

        <div className="space-y-24">
          {positions.map((pos) => {
            const players = squad.filter(pos.filter);
            if (players.length === 0) return null;

            return (
              <section key={pos.key}>
                <div className="flex items-end justify-between mb-8 border-b border-white/10 pb-4">
                  <h2 className="font-display text-3xl font-black uppercase italic text-white tracking-tight">{pos.label}</h2>
                  <span className="text-[var(--club-accent)] font-mono text-sm font-bold tracking-widest">{players.length} Players</span>
                </div>
                
                <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4 lg:gap-8">
                  {players.map((player) => (
                    <article key={player.id} className="group relative overflow-hidden rounded-2xl bg-white/5 border border-white/10 aspect-[3/4] transition-all hover:border-[var(--club-accent)]/50">
                      {player.imageUrl && (
                        <Image
                          src={player.imageUrl}
                          alt={player.name}
                          fill
                          className="object-cover transition-transform duration-500 group-hover:scale-110"
                          sizes="(min-width: 1024px) 25vw, (min-width: 768px) 33vw, 50vw"
                        />
                      )}
                      
                      {/* Gradient Overlay */}
                      <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent opacity-60 group-hover:opacity-100 transition-opacity" />
                      
                      {/* Big Number Background */}
                      <div className="absolute top-4 right-4 pointer-events-none opacity-10 group-hover:opacity-20 transition-opacity">
                        <span className="font-display text-8xl font-black italic leading-none text-white">{player.number}</span>
                      </div>

                      <div className="absolute bottom-6 left-6 right-6">
                        <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--club-accent)] mb-1">{player.role}</p>
                        <h3 className="font-display text-2xl font-black uppercase italic leading-none text-white mb-2">{player.name}</h3>
                        <div className="h-0.5 w-0 bg-[var(--club-accent)] transition-all duration-500 group-hover:w-12" />
                        <div className="mt-4 overflow-hidden max-h-0 opacity-0 group-hover:max-h-20 group-hover:opacity-100 transition-all duration-500">
                           <p className="text-xs text-white/60 leading-relaxed line-clamp-2">{player.bio}</p>
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
              </section>
            );
          })}
        </div>
      </div>
    </div>
  );
}
