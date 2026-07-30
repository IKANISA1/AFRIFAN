import Link from "next/link";

type RecoveryAction = {
  href: string;
  label: string;
};

type RecoveryPageProps = {
  eyebrow: string;
  title: string;
  description: string;
  primaryAction: RecoveryAction;
  secondaryAction: RecoveryAction;
};

export function RecoveryPage({
  eyebrow,
  title,
  description,
  primaryAction,
  secondaryAction,
}: RecoveryPageProps) {
  return (
    <main className="recovery-page">
      <section
        className="recovery-panel page-shell"
        aria-labelledby="recovery-title"
        aria-describedby="recovery-description"
      >
        <p className="recovery-eyebrow" role="status">
          {eyebrow}
        </p>
        <h1 id="recovery-title" className="recovery-title">
          {title}
        </h1>
        <p id="recovery-description" className="recovery-description">
          {description}
        </p>
        <div className="recovery-actions">
          <Link
            href={primaryAction.href}
            className="recovery-action recovery-action-primary"
          >
            {primaryAction.label}
          </Link>
          <Link
            href={secondaryAction.href}
            className="recovery-action recovery-action-secondary"
          >
            {secondaryAction.label}
          </Link>
        </div>
      </section>
    </main>
  );
}
