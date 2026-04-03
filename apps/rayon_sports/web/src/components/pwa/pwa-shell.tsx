"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed"; platform: string }>;
}

declare global {
  interface WindowEventMap {
    beforeinstallprompt: BeforeInstallPromptEvent;
  }
}

const dismissedPromptKey = "gikundiro-install-dismissed";

export function PwaShell() {
  const pathname = usePathname();
  const [mounted, setMounted] = useState(false);
  const [deferredPrompt, setDeferredPrompt] =
    useState<BeforeInstallPromptEvent | null>(null);
  const [isOffline, setIsOffline] = useState(false);
  const [updateReady, setUpdateReady] =
    useState<ServiceWorkerRegistration | null>(null);
  const [dismissed, setDismissed] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    queueMicrotask(() => {
      setMounted(true);
      setDismissed(window.localStorage.getItem(dismissedPromptKey) === "true");
      setIsOffline(!window.navigator.onLine);
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
  }, []);

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
          }
        });
      });
    }).catch(() => {});

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    function handleBeforeInstallPrompt(event: BeforeInstallPromptEvent) {
      event.preventDefault();
      setDeferredPrompt(event);
      setDismissed(window.localStorage.getItem(dismissedPromptKey) === "true");
    }

    function handleInstalled() {
      setDeferredPrompt(null);
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
  }, []);

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
      return;
    }
    dismissPrompt();
  }

  function dismissPrompt() {
    if (typeof window !== "undefined") {
      window.localStorage.setItem(dismissedPromptKey, "true");
    }
    setDismissed(true);
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
      window.location.reload();
    }
  }

  const surface = pathname.startsWith("/admin")
    ? "Admin workspace"
    : pathname.startsWith("/app")
      ? "Fan portal"
      : "Website";

  if (!mounted) {
    return null;
  }

  if (!isOffline && updateReady == null && (deferredPrompt == null || dismissed)) {
    return null;
  }

  return (
    <div className="pointer-events-none fixed inset-x-4 bottom-24 z-50 sm:bottom-6 sm:left-auto sm:max-w-md">
      <div className="pointer-events-auto glass-panel rounded-[28px] px-4 py-4 shadow-2xl">
        <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-club-accent">
          {surface}
        </p>
        {isOffline ? (
          <p className="mt-2 text-sm leading-6 text-slate-100">
            You’re offline. Cached pages remain available while live admin and
            fan mutations wait for network recovery.
          </p>
        ) : null}
        {!isOffline && updateReady ? (
          <p className="mt-2 text-sm leading-6 text-slate-100">
            A fresher build is ready with updated routes and cached assets.
          </p>
        ) : null}
        {!isOffline && deferredPrompt && !dismissed ? (
          <p className="mt-2 text-sm leading-6 text-slate-100">
            Install Gikundiro for a fullscreen, app-like matchday and admin
            experience on phone and tablet.
          </p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {deferredPrompt && !dismissed ? (
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
          {deferredPrompt && dismissed && !updateReady ? (
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
