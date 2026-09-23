"use client";

import { useId, useRef, useState } from 'react';
import { teamOptions } from '@/lib/team-identity';
import { TeamCard } from './team-card';

export function TeamSelect({ name, value, onChange, label = 'Team' }: { name: string; value: string; onChange: (value: string) => void; label?: string }) {
  const id = useId();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const trigger = useRef<HTMLButtonElement>(null);
  const close = () => { setOpen(false); setQuery(''); trigger.current?.focus(); };
  const options = teamOptions.filter(team => `${team.name} ${team.initials}`.toLowerCase().includes(query.toLowerCase()));
  return <div className="grid gap-2 text-sm" onKeyDown={event => { if (event.key === "Escape" && open) { event.stopPropagation(); close(); } }}>
    <span className="sr-only" id={id}>{label}</span>
    <input type="hidden" name={name} value={value} />
    <button ref={trigger} className="dashboard-input flex items-center justify-between gap-2" type="button" aria-labelledby={id} aria-expanded={open} onClick={() => setOpen(!open)}>
      {value ? <TeamCard name={value} /> : <span>Select team</span>}<span aria-hidden="true">⌄</span>
    </button>
    {open ? <div className="grid gap-2 rounded-2xl border border-border-soft p-3">
      <input autoFocus className="dashboard-input" aria-label="Search teams" placeholder="Search teams" value={query} onChange={event => setQuery(event.target.value)} />
      <div className="grid max-h-64 grid-cols-2 gap-2 overflow-y-auto" aria-label="Choose team">
        {options.map((team, index) => <button type="button" key={`${team.name}-${index}`} className="min-h-12 rounded-2xl text-left" aria-label={team.name} aria-pressed={value === team.name} onClick={() => { onChange(team.name); close(); }}><TeamCard name={team.name} /></button>)}
      </div>
      {!options.length ? <p role="status">No matching team</p> : null}
      <button type="button" className="min-h-12" onClick={close}>Close</button>
    </div> : null}
  </div>;
}
