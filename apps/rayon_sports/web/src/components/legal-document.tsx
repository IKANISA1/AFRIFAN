type LegalDocumentProps = {
  eyebrow: string;
  title: string;
  content: string;
  documentKind: "privacy" | "terms";
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
}: LegalDocumentProps) {
  const paragraphs = normalizeLegalParagraphs(content);

  return (
    <article
      className="legal-document-page"
      data-legal-document={documentKind}
    >
      <div className="page-shell py-12 md:py-16">
        <header className="legal-document-header">
          <p className="legal-document-eyebrow">{eyebrow}</p>
          <h1 className="legal-document-title">{title}</h1>
        </header>

        <section
          className="legal-document-panel"
          aria-label={`${title} document`}
        >
          {paragraphs.map((paragraph, index) => (
            <p key={`${index}-${paragraph.slice(0, 32)}`}>{paragraph}</p>
          ))}
        </section>
      </div>
    </article>
  );
}
