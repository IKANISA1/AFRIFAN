import Link from "next/link";

export default function OfflinePage() {
  return (
    <div className="page-shell py-16">
      <div className="glass-panel-elevated rounded-[36px] bg-slate-950/94 p-8 sm:p-10">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-slate-200">
          Offline mode
        </p>
        <h1 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white">
          Cached pages stay available
        </h1>
        <p className="mt-5 max-w-3xl text-base leading-8 text-slate-100">
          You are offline right now. Core pages, media, and recent site content
          remain available from cache, while live match state and authenticated
          mutations resume when connectivity returns.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href="/"
            className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            Cached homepage
          </Link>
          <Link
            href="/fixtures"
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Cached fixtures
          </Link>
        </div>
      </div>
    </div>
  );
}
