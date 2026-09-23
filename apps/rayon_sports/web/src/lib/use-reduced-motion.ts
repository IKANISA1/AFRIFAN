"use client";

import { useEffect, useState } from "react";

const reducedMotionQuery = "(prefers-reduced-motion: reduce)";

export function useReducedMotion() {
  const [reducedMotion, setReducedMotion] = useState(() =>
    typeof window === "undefined"
      ? false
      : window.matchMedia(reducedMotionQuery).matches,
  );

  useEffect(() => {
    const mediaQuery = window.matchMedia(reducedMotionQuery);
    const syncPreference = () => setReducedMotion(mediaQuery.matches);

    syncPreference();
    mediaQuery.addEventListener("change", syncPreference);
    return () => mediaQuery.removeEventListener("change", syncPreference);
  }, []);

  return reducedMotion;
}
