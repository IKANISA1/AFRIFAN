"use client";

import { projectPwaEvent } from "../../../../../cloudflare/web-observations/contracts.mjs";
import { recordWebObservation } from "./web-observation-client";

type PwaEventPayload = {
  eventType: string;
  surface: "site" | "portal" | "live" | "admin" | "ios-guide";
  // Legacy arguments are accepted for source compatibility and never inspected.
  path?: string; displayMode?: string; payload?: Record<string, unknown>;
};

export function currentDisplayMode() {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") return "browser";
  if (window.matchMedia("(display-mode: standalone)").matches) return "standalone";
  if (window.matchMedia("(display-mode: minimal-ui)").matches) return "minimal-ui";
  return "browser";
}

export function trackPwaEvent(input: PwaEventPayload) {
  if (typeof window === "undefined") return;
  try {
    const observation = projectPwaEvent({
      eventType: input.eventType, surface: input.surface,
      displayMode: input.displayMode ?? currentDisplayMode(),
    });
    if (observation) void recordWebObservation(observation);
  } catch { /* Diagnostics cannot change the original interaction or retry it. */ }
}
