"use client";

import Link from "next/link";
import { resolveFanAppHref } from "@/lib/config";

export default function SiteError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="recovery-page site-boundary">
      <section className="recovery-panel" aria-labelledby="page-error-title">
        <p className="recovery-eyebrow">Something went wrong</p>
        <h1 id="page-error-title" className="recovery-title">
          We couldn’t load this page
        </h1>
        <p className="recovery-description">
          Try again, or return home to keep exploring your club.
        </p>
        <div className="recovery-actions">
          <button
            type="button"
            onClick={reset}
            className="recovery-action recovery-action-primary"
          >
            Retry
          </button>
          <Link
            href="/"
            className="recovery-action recovery-action-secondary"
          >
            Return home
          </Link>
          <Link
            href={resolveFanAppHref()}
            className="recovery-action recovery-action-secondary"
          >
            Open fan app
          </Link>
        </div>
      </section>
    </div>
  );
}
