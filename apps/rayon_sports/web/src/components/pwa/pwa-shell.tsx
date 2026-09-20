"use client";

import { useEffect, useRef, useState, type CSSProperties } from "react";
import { usePathname } from "next/navigation";
import { IosSafariInstallGuide } from "./ios-safari-install-guide";
import { currentDisplayMode, trackPwaEvent } from "@/lib/pwa-analytics";
import { readPwaPreference, writePwaPreference } from "@/lib/pwa-preferences";
import { activatePwaUpdate } from "@/lib/pwa-update";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed"; platform: string }>;
}

declare global {
  interface WindowEventMap {
    beforeinstallprompt: BeforeInstallPromptEvent;
  }
}

const INSTALL_VISIT_THRESHOLD = 3;

function isStandaloneDisplayMode() {
  if (typeof window === "undefined") {
    return false;
  }

  return window.matchMedia("(display-mode: standalone)").matches;
}

export function PwaShell() {
  const pathname = usePathname();
  const isAdminSurface = pathname.startsWith("/admin");
  const analyticsSurface = isAdminSurface
    ? "admin"
    : "site";
  const dismissedPromptKey = isAdminSurface
    ? "africlub-admin-install-dismissed"
    : "africlub-install-dismissed";
  const [mounted, setMounted] = useState(false);
  const [visitCount, setVisitCount] = useState(0);
  const [deferredPrompt, setDeferredPrompt] =
    useState<BeforeInstallPromptEvent | null>(null);
  const [isOffline, setIsOffline] = useState(false);
  const [updateReady, setUpdateReady] =
    useState<ServiceWorkerRegistration | null>(null);
  const [dismissed, setDismissed] = useState(true);
  const [isStandalone, setIsStandalone] = useState(false);
  const [confirmRefresh, setConfirmRefresh] = useState(false);
  const [applyingUpdate, setApplyingUpdate] = useState(false);
  const [updateError, setUpdateError] = useState<string | null>(null);
  const updateRequest = useRef<AbortController | null>(null);
  const keepEditingButton = useRef<HTMLButtonElement | null>(null);
  const refreshButton = useRef<HTMLButtonElement | null>(null);

  useEffect(() => () => updateRequest.current?.abort(), []);
  useEffect(() => {
    if (confirmRefresh) keepEditingButton.current?.focus();
  }, [confirmRefresh]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    queueMicrotask(() => {
      setMounted(true);
      const storedVisits = Number(readPwaPreference("local", "africlub-pwa-visits") || "0");
      const nextVisitCount = Number.isSafeInteger(storedVisits) && storedVisits >= 0
        ? Math.min(storedVisits + 1, INSTALL_VISIT_THRESHOLD)
        : 1;
      writePwaPreference("local", "africlub-pwa-visits", String(nextVisitCount));
      setVisitCount(nextVisitCount);
      setDismissed(readPwaPreference("local", dismissedPromptKey) === "true");
      setIsOffline(!window.navigator.onLine);
      setIsStandalone(isStandaloneDisplayMode());
    });

    function handleOnline() {
      setIsOffline(false);
    }

    function handleOffline() {
      setIsOffline(true);
    }

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    document.documentElement.dataset.africlubNetworkObserver = "ready";

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
      delete document.documentElement.dataset.africlubNetworkObserver;
    };
  }, [dismissedPromptKey]);

  useEffect(() => {
    if (
      typeof window === "undefined" ||
      !("serviceWorker" in navigator) ||
      process.env.NODE_ENV !== "production"
    ) {
      return;
    }

    let mounted = true;

    navigator.serviceWorker.register("/sw.js", { scope: "/" }).then((registration) => {
      if (!mounted) {
        return;
      }

      if (registration.waiting) {
        setUpdateReady(registration);
        trackPwaEvent({
          eventType: "sw-update-ready",
          surface: analyticsSurface,
        });
      }

      registration.addEventListener("updatefound", () => {
        const worker = registration.installing;
        if (!worker) {
          return;
        }

        worker.addEventListener("statechange", () => {
          if (
            worker.state === "installed" &&
            navigator.serviceWorker.controller != null
          ) {
            setUpdateReady(registration);
            trackPwaEvent({
              eventType: "sw-update-ready",
              surface: analyticsSurface,
            });
          }
        });
      });

      const periodicSync = (
        registration as ServiceWorkerRegistration & {
          periodicSync?: { register: (tag: string, options: { minInterval: number }) => Promise<void> };
        }
      ).periodicSync;
      if (periodicSync) {
        periodicSync
          .register(
            isAdminSurface ? "admin-dashboard-refresh" : "public-content-refresh",
            {
              minInterval: isAdminSurface
                ? 60 * 60 * 1000
                : 12 * 60 * 60 * 1000,
            },
          )
          .catch(() => {});
      }

      if (isAdminSurface) {
        registration.active?.postMessage({ type: "CLEAR_BADGE" });
      }
    }).catch(() => {});

    return () => {
      mounted = false;
    };
  }, [analyticsSurface, isAdminSurface]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    function handleBeforeInstallPrompt(event: BeforeInstallPromptEvent) {
      event.preventDefault();
      setDeferredPrompt(event);
      setDismissed(readPwaPreference("local", dismissedPromptKey) === "true");
      trackPwaEvent({
        eventType: "install-prompt-captured",
        surface: analyticsSurface,
      });
    }

    function handleInstalled() {
      setDeferredPrompt(null);
      setIsStandalone(true);
      trackPwaEvent({
        eventType: "install-completed",
        surface: analyticsSurface,
        displayMode: currentDisplayMode(),
      });
    }

    window.addEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
    window.addEventListener("appinstalled", handleInstalled);

    return () => {
      window.removeEventListener(
        "beforeinstallprompt",
        handleBeforeInstallPrompt,
      );
      window.removeEventListener("appinstalled", handleInstalled);
    };
  }, [analyticsSurface, dismissedPromptKey]);

  async function handleInstall() {
    if (deferredPrompt == null) {
      return;
    }

    await deferredPrompt.prompt();
    const choice = await deferredPrompt.userChoice;
    if (choice.outcome === "accepted") {
      setDeferredPrompt(null);
      setDismissed(true);
      writePwaPreference("local", dismissedPromptKey, null);
      trackPwaEvent({
        eventType: "install-prompt-accepted",
        surface: analyticsSurface,
      });
      return;
    }
    dismissPrompt();
  }

  function dismissPrompt() {
    if (typeof window !== "undefined") {
      writePwaPreference("local", dismissedPromptKey, "true");
    }
    setDismissed(true);
    trackPwaEvent({
      eventType: "install-prompt-dismissed",
      surface: analyticsSurface,
    });
  }

  function showPromptAgain() {
    if (typeof window !== "undefined") {
      writePwaPreference("local", dismissedPromptKey, null);
    }
    setDismissed(false);
  }

  async function applyUpdate() {
    if (!updateReady || updateRequest.current) return;
    const request = new AbortController();
    updateRequest.current = request;
    setApplyingUpdate(true);
    setUpdateError(null);
    try {
      await activatePwaUpdate(updateReady, navigator.serviceWorker, request.signal);
      if (request.signal.aborted) return;
      trackPwaEvent({
        eventType: "sw-update-applied",
        surface: analyticsSurface,
      });
      window.location.reload();
    } catch {
      if (!request.signal.aborted) {
        setUpdateError("The update is not ready yet. Your page has been kept open. Try again.");
      }
    } finally {
      if (updateRequest.current === request) {
        updateRequest.current = null;
        if (!request.signal.aborted) setApplyingUpdate(false);
      }
    }
  }

  const surface = isAdminSurface
    ? "Admin workspace"
    : "Website";
  const installEligible = visitCount >= INSTALL_VISIT_THRESHOLD;
  const showInstallPrompt =
    deferredPrompt != null &&
    !dismissed &&
    installEligible &&
    !isStandalone;

  if (!mounted) {
    return null;
  }

  if (!isOffline && updateReady == null && !showInstallPrompt) {
    return (
      <IosSafariInstallGuide
        enabled={installEligible && !isStandalone}
        onShown={() => {
          trackPwaEvent({
            eventType: "ios-install-guide-shown",
            surface: "ios-guide",
            path: pathname,
          });
        }}
        onDismiss={() => {
          trackPwaEvent({
            eventType: "ios-install-guide-dismissed",
            surface: "ios-guide",
            path: pathname,
          });
        }}
      />
    );
  }

  return (
    <div
      data-pwa-shell
      style={{ "--pwa-copy": isAdminSurface ? "var(--admin-text)" : "var(--foreground)" } as CSSProperties}
      className={[
        "pointer-events-none fixed inset-x-4 z-50 sm:left-auto sm:max-w-md",
        isAdminSurface ? "top-4 sm:top-6" : "bottom-24 sm:bottom-6",
      ].join(" ")}
    >
      <div className="pointer-events-auto glass-panel rounded-[28px] px-4 py-4 shadow-2xl">
        <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-club-accent">
          {surface}
        </p>
        {isOffline ? (
          <p className="mt-2 text-sm leading-6 text-[var(--pwa-copy)]">
            {isAdminSurface
              ? "You’re offline. The admin shell stays available, but live admin data and writes require the network before they can resume."
              : "You’re offline. Cached pages remain available while live fan and site mutations wait for network recovery."}
          </p>
        ) : null}
        {!isOffline && updateReady ? (
          <p className="mt-2 text-sm leading-6 text-[var(--pwa-copy)]">
            {isAdminSurface
              ? "A workspace update is ready."
              : "An app update is ready."}
          </p>
        ) : null}
        {!isOffline && showInstallPrompt ? (
          <p className="mt-2 text-sm leading-6 text-[var(--pwa-copy)]">
            {isAdminSurface
              ? "Install the admin workspace for a fullscreen, tablet-ready operations experience."
              : "Install the official club site for a fullscreen, app-like matchday experience on phone and tablet after you have seen enough value to keep it."}
          </p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {showInstallPrompt ? (
            <>
              <button
                type="button"
                onClick={() => {
                  handleInstall().catch(() => {});
                }}
                className="min-h-12 rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white"
              >
                Install app
              </button>
              <button
                type="button"
                onClick={dismissPrompt}
                className="min-h-12 rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-[var(--pwa-copy)]"
              >
                Not now
              </button>
            </>
          ) : null}
          {updateReady && !confirmRefresh ? (
            <button
              ref={refreshButton}
              type="button"
              disabled={isOffline}
              onClick={() => setConfirmRefresh(true)}
              className="min-h-12 rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white"
            >
              Refresh app
            </button>
          ) : null}
          {updateReady && confirmRefresh ? (
            <div>
              <p className="mb-3 text-sm leading-6 text-[var(--pwa-copy)]" role="status">
                Save any unfinished changes before refreshing. Refreshing reloads this page.
              </p>
              {updateError ? <p className="mb-3 text-sm text-[var(--pwa-copy)]" role="alert">{updateError}</p> : null}
              <div className="flex flex-wrap gap-2">
                <button
                  ref={keepEditingButton}
                  type="button"
                  onClick={() => {
                    updateRequest.current?.abort();
                    updateRequest.current = null;
                    setApplyingUpdate(false);
                    setConfirmRefresh(false);
                    setUpdateError(null);
                    requestAnimationFrame(() => refreshButton.current?.focus());
                  }}
                  className="min-h-12 rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-[var(--pwa-copy)]"
                >Keep editing</button>
                <button
                  type="button"
                  disabled={isOffline || applyingUpdate}
                  onClick={() => { void applyUpdate(); }}
                  className="min-h-12 rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white"
                >{applyingUpdate ? "Preparing update…" : "Refresh now"}</button>
              </div>
            </div>
          ) : null}
          {deferredPrompt && dismissed && installEligible && !updateReady && !isStandalone ? (
            <button
              type="button"
              onClick={showPromptAgain}
              className="min-h-12 rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-[var(--pwa-copy)]"
            >
              Show install prompt
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
