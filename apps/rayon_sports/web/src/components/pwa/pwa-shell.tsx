"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { IosSafariInstallGuide } from "./ios-safari-install-guide";
import { currentDisplayMode, trackPwaEvent } from "@/lib/pwa-analytics";

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

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    queueMicrotask(() => {
      setMounted(true);
        const nextVisitCount =
        Number(window.localStorage.getItem("africlub-pwa-visits") || "0") + 1;
      window.localStorage.setItem("africlub-pwa-visits", String(nextVisitCount));
      setVisitCount(nextVisitCount);
      setDismissed(window.localStorage.getItem(dismissedPromptKey) === "true");
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

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
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
      setDismissed(window.localStorage.getItem(dismissedPromptKey) === "true");
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
      window.localStorage.removeItem(dismissedPromptKey);
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
      window.localStorage.setItem(dismissedPromptKey, "true");
    }
    setDismissed(true);
    trackPwaEvent({
      eventType: "install-prompt-dismissed",
      surface: analyticsSurface,
    });
  }

  function showPromptAgain() {
    if (typeof window !== "undefined") {
      window.localStorage.removeItem(dismissedPromptKey);
    }
    setDismissed(false);
  }

  function applyUpdate() {
    if (updateReady?.waiting) {
      updateReady.waiting.postMessage({ type: "SKIP_WAITING" });
      trackPwaEvent({
        eventType: "sw-update-applied",
        surface: analyticsSurface,
      });
      window.location.reload();
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
          <p className="mt-2 text-sm leading-6 text-slate-100">
            {isAdminSurface
              ? "You’re offline. The admin shell stays available, but live admin data and writes require the network before they can resume."
              : "You’re offline. Cached pages remain available while live fan and site mutations wait for network recovery."}
          </p>
        ) : null}
        {!isOffline && updateReady ? (
          <p className="mt-2 text-sm leading-6 text-slate-100">
            {isAdminSurface
              ? "A fresher admin build is ready with updated routes and cached workspace assets."
              : "A fresher build is ready with updated routes and cached assets."}
          </p>
        ) : null}
        {!isOffline && showInstallPrompt ? (
          <p className="mt-2 text-sm leading-6 text-slate-100">
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
                className="rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white"
              >
                Install app
              </button>
              <button
                type="button"
                onClick={dismissPrompt}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100"
              >
                Not now
              </button>
            </>
          ) : null}
          {updateReady ? (
            <button
              type="button"
              onClick={applyUpdate}
              className="rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white"
            >
              Refresh app
            </button>
          ) : null}
          {deferredPrompt && dismissed && installEligible && !updateReady && !isStandalone ? (
            <button
              type="button"
              onClick={showPromptAgain}
              className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100"
            >
              Show install prompt
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
