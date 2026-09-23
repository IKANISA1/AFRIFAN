"use client";

import Image from 'next/image';
import { teamCrestUrl, teamInitials } from '@/lib/team-identity';

export function TeamCard({ name, crestUrl, vertical = false }: { name: string; crestUrl?: string | null; vertical?: boolean }) {
  const src = teamCrestUrl(name, crestUrl);
  return <span className={`team-card${vertical ? ' team-card--vertical' : ''}`} role="group" aria-label={name}>
    {src ? <Image className="team-card__crest" src={src} width={32} height={32} alt="" unoptimized onError={event => { event.currentTarget.style.visibility = 'hidden'; }} /> : null}
    <span className="team-card__initials" aria-hidden="true">{teamInitials(name)}</span>
  </span>;
}

export function FixtureTeams({ homeTeam, awayTeam, homeCrest, awayCrest, score }: {
  homeTeam: string; awayTeam: string; homeCrest?: string | null; awayCrest?: string | null; score?: string;
}) {
  return <span className="fixture-teams" role="group" aria-label={`${homeTeam} versus ${awayTeam}`}>
    <TeamCard name={homeTeam} crestUrl={homeCrest} vertical />
    <span className="fixture-teams__score">{score ?? '·'}</span>
    <TeamCard name={awayTeam} crestUrl={awayCrest} vertical />
  </span>;
}
