import Link from "next/link";

export default function AdminOfflinePage() {
  return (
    <div className="page-shell py-16">
      <div className="glass-panel-elevated rounded-[36px] border border-border-soft p-8 sm:p-10">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          Admin offline
        </p>
        <h1 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white">
          Admin data needs a live connection
        </h1>
        <p className="mt-5 max-w-3xl text-base leading-8 text-slate-300">
          The admin workspace is intentionally network-first so operators never
          act on stale club data. Reconnect to continue publishing, editing, or
          reconciling supporter activity.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href="/admin"
            className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            Retry admin workspace
          </Link>
          <Link
            href="/"
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Open public site
          </Link>
        </div>
      </div>
    </div>
  );
}
