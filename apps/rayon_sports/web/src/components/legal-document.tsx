export type LegalDocumentSection = {
  id?: string;
  heading: string;
  paragraphs?: string[];
  items?: string[];
};

type LegalDocumentAction = {
  href: string;
  label: string;
};

type LegalDocumentProps = {
  eyebrow: string;
  title: string;
  content: string;
  documentKind: "privacy" | "terms";
  lastUpdated?: string;
  sections?: LegalDocumentSection[];
  actions?: LegalDocumentAction[];
};

export function resolveLegalDocumentText(
  candidate: string | null | undefined,
  fallback: string,
) {
  const normalized = candidate?.trim();
  return normalized ? normalized : fallback.trim();
}

export function normalizeLegalParagraphs(content: string) {
  return content
    .replaceAll("\r\n", "\n")
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);
}

export function LegalDocument({
  eyebrow,
  title,
  content,
  documentKind,
  lastUpdated,
  sections = [],
  actions = [],
}: LegalDocumentProps) {
  const paragraphs = normalizeLegalParagraphs(content);

  return (
    <article
      className="legal-document-page"
      data-legal-document={documentKind}
    >
      <div className="page-shell pb-12 pt-28 md:pb-16 md:pt-36">
        <header className="legal-document-header">
          <p className="legal-document-eyebrow">{eyebrow}</p>
          <h1 className="legal-document-title">{title}</h1>
          {lastUpdated ? (
            <p className="legal-document-updated">Last updated: {lastUpdated}</p>
          ) : null}
        </header>

        <section
          className="legal-document-panel"
          aria-label={`${title} document`}
        >
          {paragraphs.map((paragraph, index) => (
            <p key={`${index}-${paragraph.slice(0, 32)}`}>{paragraph}</p>
          ))}

          {sections.map((section) => (
            <section
              className="legal-document-section"
              id={section.id}
              key={section.id ?? section.heading}
            >
              <h2>{section.heading}</h2>
              {section.paragraphs?.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
              {section.items?.length ? (
                <ul>
                  {section.items.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              ) : null}
            </section>
          ))}

          {actions.length ? (
            <nav className="legal-document-actions" aria-label={`${title} actions`}>
              {actions.map((action) => (
                <a href={action.href} key={action.href}>
                  {action.label}
                </a>
              ))}
            </nav>
          ) : null}
        </section>
      </div>
    </article>
  );
}
