"use client";

import { useEffect, useState } from "react";

/**
 * Detects iOS Safari in browser mode and shows an animated
 * "Add to Home Screen" guidance overlay after engagement threshold.
 *
 * Only shown when:
 * 1. Device is iOS (iPhone/iPad)
 * 2. Browser is Safari (not Chrome/Firefox on iOS)
 * 3. Not already running as standalone PWA
 * 4. Not previously dismissed this session
 * 5. User has been browsing for at least 60 seconds
 */

const DISMISSED_KEY = "africlub-ios-install-dismissed";

interface IosSafariInstallGuideProps {
  enabled?: boolean;
  showAfterMs?: number;
  onShown?: () => void;
  onDismiss?: () => void;
}

function isIosSafari(): boolean {
  if (typeof window === "undefined") return false;

  const ua = navigator.userAgent;
  const isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isSafari = /Safari/.test(ua) && !/CriOS|FxiOS|OPiOS|EdgiOS/.test(ua);

  return isIOS && isSafari;
}

function isStandalone(): boolean {
  if (typeof window === "undefined") return false;

  return (
    window.matchMedia("(display-mode: standalone)").matches ||
    ("standalone" in navigator && (navigator as Record<string, unknown>).standalone === true)
  );
}

export function IosSafariInstallGuide({
  enabled = true,
  showAfterMs = 45_000,
  onShown,
  onDismiss,
}: IosSafariInstallGuideProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!enabled || !isIosSafari() || isStandalone()) return;

    if (sessionStorage.getItem(DISMISSED_KEY) === "true") return;

    // Show only after the user has spent real time on the site.
    const timer = setTimeout(() => {
      setVisible(true);
      onShown?.();
    }, showAfterMs);

    return () => clearTimeout(timer);
  }, [enabled, onShown, showAfterMs]);

  function dismiss() {
    sessionStorage.setItem(DISMISSED_KEY, "true");
    setVisible(false);
    onDismiss?.();
  }

  if (!visible) return null;

  return (
    <div
      role="dialog"
      aria-label="Install the club site on your device"
      className="pointer-events-none fixed inset-x-4 bottom-24 z-50 sm:bottom-6 sm:left-auto sm:max-w-md"
    >
      <div className="pointer-events-auto glass-panel rounded-[28px] px-5 py-5 shadow-2xl">
        <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-club-accent">
          Install the club site
        </p>

        <p className="mt-3 text-sm leading-6 text-slate-100">
          For the best app-like experience, add this club site to your Home Screen:
        </p>

        <ol className="mt-4 space-y-3 text-sm text-slate-200">
          <li className="flex items-start gap-3">
            <span
              className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-club-primary text-xs font-bold text-white"
              aria-hidden="true"
            >
              1
            </span>
            <span>
              Tap the{" "}
              <span className="inline-flex items-center gap-1 font-semibold text-white">
                Share
                <svg
                  className="inline-block h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2}
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M12 4v12m0-12L8 8m4-4l4 4"
                  />
                </svg>
              </span>{" "}
              button in Safari&apos;s toolbar
            </span>
          </li>
          <li className="flex items-start gap-3">
            <span
              className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-club-primary text-xs font-bold text-white"
              aria-hidden="true"
            >
              2
            </span>
            <span>
              Scroll down and tap{" "}
              <span className="font-semibold text-white">
                &quot;Add to Home Screen&quot;
              </span>
            </span>
          </li>
          <li className="flex items-start gap-3">
            <span
              className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-club-primary text-xs font-bold text-white"
              aria-hidden="true"
            >
              3
            </span>
            <span>
              Tap{" "}
              <span className="font-semibold text-white">&quot;Add&quot;</span>{" "}
              to install
            </span>
          </li>
        </ol>

        <div className="mt-5 flex gap-2">
          <button
            type="button"
            onClick={dismiss}
            className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/6"
          >
            Got it
          </button>
        </div>
      </div>
    </div>
  );
}
