type SupportStep = {
  heading: string;
  body: string;
};

type SupportAction = {
  href: string;
  label: string;
  primary?: boolean;
};

type SupportSurfaceProps = {
  kind: "support" | "account-deletion";
  eyebrow: string;
  title: string;
  description: string;
  steps: SupportStep[];
  notice: string;
  actions: SupportAction[];
};

function isSafeSupportHref(href: string) {
  const normalized = href.trim();
  if (normalized.startsWith("/") && !normalized.startsWith("//")) {
    return !normalized.startsWith("/\\");
  }

  try {
    const parsed = new URL(normalized);
    if (parsed.protocol === "mailto:") {
      return parsed.pathname.toLowerCase() === "support@ikanisa.com";
    }
    return parsed.protocol === "https:" && parsed.origin === "https://gikundiro.com";
  } catch {
    return false;
  }
}

export function SupportSurface({
  kind,
  eyebrow,
  title,
  description,
  steps,
  notice,
  actions,
}: SupportSurfaceProps) {
  const safeActions = actions.filter((action) => isSafeSupportHref(action.href));

  return (
    <article className="release-support-surface" data-support-kind={kind}>
      <div className="page-shell pb-12 pt-28 md:pb-16 md:pt-36">
        <header className="release-support-hero">
          <p className="release-support-eyebrow">{eyebrow}</p>
          <h1 className="release-support-title">{title}</h1>
          <p className="release-support-description">{description}</p>
        </header>

        <ol className="release-support-steps">
          {steps.map((step, index) => (
            <li key={step.heading}>
              <span aria-hidden="true">{index + 1}</span>
              <div>
                <h2>{step.heading}</h2>
                <p>{step.body}</p>
              </div>
            </li>
          ))}
        </ol>

        <aside className="release-support-notice" aria-label="Security notice">
          <strong>Protect your account</strong>
          <p>{notice}</p>
        </aside>

        <nav className="release-support-actions" aria-label={`${title} actions`}>
          {safeActions.map((action) => (
            <a
              className={action.primary ? "release-support-action-primary" : undefined}
              href={action.href}
              key={action.href}
            >
              {action.label}
            </a>
          ))}
        </nav>
      </div>
    </article>
  );
}

export { isSafeSupportHref };
