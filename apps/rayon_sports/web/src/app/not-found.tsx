import Link from "next/link";
import { resolveFanAppHref } from "@/lib/config";

export default function NotFound() {
  return (
    <div className="page-shell py-16">
      <div className="glass-panel-elevated rounded-[36px] border border-border-soft p-8 sm:p-10">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-club-accent">
          404
        </p>
        <h1 className="mt-4 font-display text-5xl font-bold uppercase leading-none text-white">
          That route does not exist
        </h1>
        <p className="mt-5 max-w-3xl text-base leading-8 text-slate-300">
          The supporter journey should remain clear even when a route is missing.
          Use the links below to get back to a live public page or the fan app.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href="/"
            className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
          >
            Return home
          </Link>
          <Link
            href="/fixtures"
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Fixtures
          </Link>
          <Link
            href={resolveFanAppHref()}
            className="rounded-full border border-border-soft bg-white/5 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
          >
            Fan app
          </Link>
        </div>
      </div>
    </div>
  );
}
