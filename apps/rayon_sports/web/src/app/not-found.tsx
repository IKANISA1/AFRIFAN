import Link from "next/link";

export default function NotFound() {
  return (
    <main className="recovery-page">
      <section className="recovery-panel" aria-labelledby="not-found-title">
        <p className="recovery-eyebrow">404</p>
        <h1 id="not-found-title" className="recovery-title">
          Page not found
        </h1>
        <p className="recovery-description">
          This page may have moved. Return home, check the fixtures, or open the member area.
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
            href="/membership"
            className="recovery-action recovery-action-secondary"
          >
            Member area
          </Link>
        </div>
      </section>
    </main>
  );
}
