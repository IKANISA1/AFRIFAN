import type { ReactNode } from "react";

export function PortalStateCard({
  label,
  value,
  helper,
}: {
  label: string;
  value: string;
  helper: ReactNode;
}) {
  return (
    <article className="glass-panel rounded-[28px] p-5">
      <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
        {label}
      </p>
      <p className="mt-4 font-display text-4xl font-bold uppercase leading-none">
        {value}
      </p>
      <div className="mt-3 text-sm leading-6 text-slate-300">{helper}</div>
    </article>
  );
}
