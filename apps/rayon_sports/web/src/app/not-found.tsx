import Link from "next/link";
import { resolveFanAppHref } from "@/lib/config";

export default function NotFound() {
  return (
    <main className="recovery-page">
      <section className="recovery-panel" aria-labelledby="not-found-title">
        <p className="recovery-eyebrow">404</p>
        <h1 id="not-found-title" className="recovery-title">
          Page not found
        </h1>
        <p className="recovery-description">
          This page may have moved. Return home, check the fixtures, or open the fan app.
        </p>
        <div className="recovery-actions">
          <Link
            href="/"
            className="recovery-action recovery-action-primary"
          >
            Return home
          </Link>
          <Link
            href="/fixtures"
            className="recovery-action recovery-action-secondary"
          >
            Fixtures
          </Link>
          <Link
            href={resolveFanAppHref()}
            className="recovery-action recovery-action-secondary"
          >
            Fan app
          </Link>
        </div>
      </section>
    </main>
  );
}
