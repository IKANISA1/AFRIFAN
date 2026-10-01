import Link from "next/link";
import { ExternalLink, MessagesSquare, ShieldCheck } from "lucide-react";

type ContactSocialLink = {
  label: string;
  href: string | null | undefined;
};

type ContactSurfaceProps = {
  eyebrow: string;
  title: string;
  description: string;
  fanAppHref: string;
  openFanAppLabel: string;
  membershipSupportLabel: string;
  officialContact: string;
  languages: string[];
  digitalSupportTitle: string;
  digitalSupportDescription: string;
  supportBlocks: string[];
  socialChannelsLabel: string;
  newsroomLabel: string;
  socialLinks: ContactSocialLink[];
};

export function normalizeContactExternalHref(
  candidate: string | null | undefined,
) {
  if (!candidate) return null;
  try {
    const url = new URL(candidate);
    return url.protocol === "https:" || url.protocol === "http:"
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

export function normalizeContactSupportBlocks(blocks: string[]) {
  return Array.from(
    new Set(blocks.map((block) => block.trim()).filter(Boolean)),
  );
}

export function ContactSurface({
  eyebrow,
  title,
  description,
  fanAppHref,
  openFanAppLabel,
  membershipSupportLabel,
  officialContact,
  languages,
  digitalSupportTitle,
  digitalSupportDescription,
  supportBlocks,
  socialChannelsLabel,
  newsroomLabel,
  socialLinks,
}: ContactSurfaceProps) {
  const safeSocialLinks = socialLinks.flatMap((entry) => {
    const href = normalizeContactExternalHref(entry.href);
    return href ? [{ ...entry, href }] : [];
  });
  const uniqueSupportBlocks = normalizeContactSupportBlocks(supportBlocks);

  return (
    <article className="contact-surface" data-contact-surface>
      <div className="page-shell py-12 md:py-16">
        <header className="contact-surface-hero">
          <p className="contact-surface-eyebrow">{eyebrow}</p>
          <h1 className="contact-surface-title">{title}</h1>
          <p className="contact-surface-description">{description}</p>
          <div className="contact-surface-actions">
            <Link
              href={fanAppHref}
              className="contact-surface-action contact-surface-action-primary"
            >
              {openFanAppLabel}
            </Link>
            <Link
              href="/membership"
              className="contact-surface-action contact-surface-action-secondary"
            >
              {membershipSupportLabel}
            </Link>
          </div>
        </header>

        <div className="contact-surface-grid">
          <section
            className="contact-surface-panel"
            aria-labelledby="contact-club-heading"
          >
            <p className="contact-surface-kicker" id="contact-club-heading">
              Club contact
            </p>
            <p className="contact-surface-card-title">{officialContact}</p>
            <div className="contact-surface-tags" role="group" aria-label="Supported languages">
              {languages.map((language) => (
                <span key={language} className="contact-surface-tag">
                  {language.toUpperCase()}
                </span>
              ))}
            </div>
          </section>

          <section
            className="contact-surface-panel"
            aria-labelledby="contact-support-heading"
          >
            <p
              className="contact-surface-card-title"
              id="contact-support-heading"
            >
              {digitalSupportTitle}
            </p>
            <p className="contact-surface-copy">{digitalSupportDescription}</p>
            <div className="contact-surface-support-list">
              {uniqueSupportBlocks.map((supportBlock, index) => {
                const Icon = index === 0 ? ShieldCheck : MessagesSquare;
                return (
                  <div key={supportBlock} className="contact-surface-support">
                    <span className="contact-surface-icon" aria-hidden="true">
                      <Icon size={18} />
                    </span>
                    <p>{supportBlock}</p>
                  </div>
                );
              })}
            </div>
          </section>
        </div>

        <section
          className="contact-surface-panel contact-surface-channels"
          aria-labelledby="contact-channels-heading"
        >
          <p className="contact-surface-kicker" id="contact-channels-heading">
            {socialChannelsLabel}
          </p>
          <div className="contact-surface-actions">
            {safeSocialLinks.map((entry) => (
              <a
                key={entry.label}
                href={entry.href}
                target="_blank"
                rel="noreferrer"
                className="contact-surface-action contact-surface-action-secondary"
              >
                {entry.label} <ExternalLink size={16} aria-hidden="true" />
              </a>
            ))}
            <Link
              href="/news"
              className="contact-surface-action contact-surface-action-secondary"
            >
              {newsroomLabel}
            </Link>
          </div>
        </section>
      </div>
    </article>
  );
}
