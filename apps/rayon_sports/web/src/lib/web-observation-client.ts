"use client";

import { normalizeObservation, type WebObservation } from "../../../../../cloudflare/web-observations/contracts.mjs";

export function createWebObservationReporter(options: {
  enabled: boolean; origin: string; fetch: typeof fetch;
}) {
  const seenVitals = new Set<string>();
  let attempts = 0;
  return async (input: WebObservation): Promise<boolean> => {
    if (!options.enabled || attempts >= 35) return false;
    let origin: URL;
    try {
      origin = new URL(options.origin);
      if (origin.protocol !== "https:" || origin.origin !== options.origin) return false;
    } catch { return false; }
    const observation = normalizeObservation(input);
    if (!observation) return false;
    if (observation.event === "web_vital") {
      if (seenVitals.has(observation.name)) return false;
      seenVitals.add(observation.name);
    }
    attempts++;
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const path = observation.event === "web_vital" ? "/api/telemetry/vitals" : "/api/pwa/events";
      const attempt = Promise.resolve().then(() => options.fetch(origin.origin + path, {
        method: "POST", body: JSON.stringify(observation),
        headers: { "content-type": "application/json", "x-africlub-csrf": "1" },
        credentials: "omit", mode: "same-origin", redirect: "error",
        cache: "no-store", referrerPolicy: "no-referrer", keepalive: true,
        signal: controller.signal,
      }));
      const response = await Promise.race([attempt, new Promise<never>((_resolve, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(Error("observation_unavailable")); }, 1000);
      })]);
      return response.status === 201 && response.headers.get("cache-control")?.split(",")
        .some(part => part.trim() === "no-store") === true;
    } catch { return false; }
    finally { clearTimeout(timer); }
  };
}

let reporter: ReturnType<typeof createWebObservationReporter> | undefined;
export function recordWebObservation(observation: WebObservation): Promise<boolean> {
  if (typeof window === "undefined") return Promise.resolve(false);
  reporter ??= createWebObservationReporter({
    enabled: process.env.NEXT_PUBLIC_WEB_OBSERVATIONS_ENABLED === "true",
    origin: window.location.origin, fetch: (...args) => fetch(...args),
  });
  return reporter(observation);
}
