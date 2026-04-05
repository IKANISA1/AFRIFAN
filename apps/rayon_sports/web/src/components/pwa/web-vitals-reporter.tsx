"use client";

import { useEffect } from "react";

/**
 * Invisible client component that initializes Web Vitals RUM collection.
 * Renders nothing — exists solely to run the vitals reporter once on mount.
 */
export function WebVitalsReporter() {
  useEffect(() => {
    let cancelled = false;
    let cancelScheduled = () => {};

    const startReporting = () => {
      if (cancelled) {
        return;
      }

      import("@/lib/vitals").then(({ reportWebVitals }) => {
        if (!cancelled) {
          reportWebVitals();
        }
      });
    };

    const schedule = () => {
      const deferredHandle = globalThis.setTimeout(() => {
        if ("requestIdleCallback" in window) {
          const idleHandle = window.requestIdleCallback(startReporting, {
            timeout: 2000,
          });
          cancelScheduled = () => window.cancelIdleCallback(idleHandle);
          return;
        }

        const handle = globalThis.setTimeout(startReporting, 250);
        cancelScheduled = () => globalThis.clearTimeout(handle);
      }, 2500);

      cancelScheduled = () => globalThis.clearTimeout(deferredHandle);
    };

    if (document.readyState === "complete") {
      schedule();
    } else {
      const handleLoad = () => {
        schedule();
      };

      window.addEventListener("load", handleLoad, { once: true });
      cancelScheduled = () => {
        window.removeEventListener("load", handleLoad);
      };
    }

    return () => {
      cancelled = true;
      cancelScheduled();
    };
  }, []);

  return null;
}
