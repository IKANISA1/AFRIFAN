"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";

/**
 * Moves focus to the main content area on route changes.
 * Improves accessibility for screen reader and keyboard users
 * who would otherwise remain focused on the nav after navigation.
 *
 * Mount this once in the root layout or portal shell.
 */
export function FocusOnRouteChange({ targetId = "fan-main-content" }: { targetId?: string }) {
  const pathname = usePathname();
  const isFirstRender = useRef(true);

  useEffect(() => {
    // Don't move focus on initial page load
    if (isFirstRender.current) {
      isFirstRender.current = false;
      return;
    }

    // Small delay to allow the new page to render
    const timer = setTimeout(() => {
      const target = document.getElementById(targetId);
      if (target) {
        target.focus({ preventScroll: true });
      }
    }, 100);

    return () => clearTimeout(timer);
  }, [pathname, targetId]);

  return null;
}
