"use client";

import Link from "next/link";
import { resolveFanAppHref } from "@/lib/config";

export default function SiteError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="page-shell py-16">
      <div className="glass-panel-elevated rounded-[36px] border border-border-soft p-8 sm:p-10">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Public site error
        </p>
        <h1 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white">
          The page lost matchday shape
        </h1>
        <p className="mt-5 max-w-3xl text-base leading-8 text-slate-300">
          Something failed while loading this route. Navigation, retry, and
          fan app access stay available here instead of dropping the supporter
          onto a blank page.
        </p>
        {error.message ? (
          <p className="mt-4 rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm leading-7 text-slate-300">
            {error.message}
          </p>
        ) : null}
        <div className="mt-6 flex flex-wrap gap-3">
          <button
            type="button"
            onClick={reset}
            className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            Retry
          </button>
          <Link
            href="/"
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Return home
          </Link>
          <Link
            href={resolveFanAppHref()}
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Open fan app
          </Link>
        </div>
      </div>
    </div>
  );
}
