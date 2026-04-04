"use client";

import { useEffect } from "react";

/**
 * Invisible client component that initializes Web Vitals RUM collection.
 * Renders nothing — exists solely to run the vitals reporter once on mount.
 */
export function WebVitalsReporter() {
  useEffect(() => {
    import("@/lib/vitals").then(({ reportWebVitals }) => {
      reportWebVitals();
    });
  }, []);

  return null;
}
