"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

type ShareTargetContentProps = {
  appHref: string;
  query: string;
  sharedTitle: string;
  sharedText: string;
  sharedUrl: string | null;
  unsafeUrlOmitted: boolean;
  shortTitle: string;
};

export function ShareTargetContent({
  appHref,
  query,
  sharedTitle,
  sharedText,
  sharedUrl,
  unsafeUrlOmitted,
  shortTitle,
}: ShareTargetContentProps) {
  const [isOffline, setIsOffline] = useState(false);

  useEffect(() => {
    const updateStatus = () => setIsOffline(!navigator.onLine);
    updateStatus();
    window.addEventListener("online", updateStatus);
    window.addEventListener("offline", updateStatus);
    return () => {
      window.removeEventListener("online", updateStatus);
      window.removeEventListener("offline", updateStatus);
    };
  }, []);

  const hasSharedContent = Boolean(sharedTitle || sharedText || sharedUrl);

  return (
    <main className="share-target-page">
      <section
        className="share-target-panel page-shell"
        aria-labelledby="share-target-title"
        aria-describedby="share-target-description"
      >
        <p className="share-target-eyebrow">
          Shared into {shortTitle}
        </p>
        <h1 id="share-target-title" className="share-target-title">
          Bring shared content into the club flow
        </h1>
        <p id="share-target-description" className="share-target-description">
          Review what was received before you continue to official search, the
          supporter app, or the original secure web page.
        </p>

        <p
          className={`share-target-network ${isOffline ? "is-offline" : ""}`}
          role="status"
          aria-live="polite"
        >
          {isOffline
            ? "Offline: this received content stays visible, but external destinations need a connection."
            : "Received content remains on this page until you choose where to continue."}
        </p>

        {hasSharedContent ? (
          <dl className="share-target-content" aria-label="Received content">
            {sharedTitle ? (
              <div className="share-target-field">
                <dt>Title</dt>
                <dd>{sharedTitle}</dd>
              </div>
            ) : null}
            {sharedText ? (
              <div className="share-target-field">
                <dt>Text</dt>
                <dd>{sharedText}</dd>
              </div>
            ) : null}
            {sharedUrl ? (
              <div className="share-target-field">
                <dt>Secure web link</dt>
                <dd>{sharedUrl}</dd>
              </div>
            ) : null}
          </dl>
        ) : (
          <div className="share-target-empty" role="note">
            <h2>No shared content was received</h2>
            <p>
              You can still open official search or return to the supporter
              app. Nothing has been submitted or published.
            </p>
          </div>
        )}

        {unsafeUrlOmitted ? (
          <p className="share-target-warning" role="alert">
            An unsupported link was omitted. Only HTTP and HTTPS web links can
            be opened from this page.
          </p>
        ) : null}

        <div className="share-target-actions">
          <Link
            href={query ? `/search?q=${encodeURIComponent(query)}` : "/search"}
            className="share-target-action share-target-action-primary"
          >
            Search the official site
          </Link>
          <Link
            href={appHref}
            className="share-target-action share-target-action-secondary"
          >
            Open supporter app
          </Link>
          {sharedUrl ? (
            <a
              href={sharedUrl}
              target="_blank"
              rel="noreferrer"
              className="share-target-action share-target-action-secondary"
            >
              Open original secure link
            </a>
          ) : null}
        </div>
      </section>
    </main>
  );
}
