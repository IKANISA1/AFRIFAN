"use client";

type PwaEventPayload = {
  eventType: string;
  surface: "site" | "portal" | "live" | "admin" | "ios-guide";
  path?: string;
  displayMode?: string;
  payload?: Record<string, unknown>;
};

export function currentDisplayMode() {
  if (typeof window === "undefined") {
    return "browser";
  }

  if (window.matchMedia("(display-mode: standalone)").matches) {
    return "standalone";
  }

  if (window.matchMedia("(display-mode: minimal-ui)").matches) {
    return "minimal-ui";
  }

  return "browser";
}

export function trackPwaEvent({
  eventType,
  surface,
  path,
  displayMode,
  payload,
}: PwaEventPayload) {
  if (typeof window === "undefined") {
    return;
  }

  const body = JSON.stringify({
    eventType,
    surface,
    path: path ?? window.location.pathname,
    displayMode: displayMode ?? currentDisplayMode(),
    payload,
  });

  if (navigator.sendBeacon) {
    navigator.sendBeacon("/api/pwa/events", body);
    return;
  }

  fetch("/api/pwa/events", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Africlub-CSRF": "1",
    },
    body,
    keepalive: true,
    credentials: "same-origin",
  }).catch(() => {});
}
