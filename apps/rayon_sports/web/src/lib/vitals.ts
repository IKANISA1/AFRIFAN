"use client";

import { onCLS, onFCP, onINP, onLCP, onTTFB, type Metric } from "web-vitals";
import { projectWebVital } from "../../../../../cloudflare/web-observations/contracts.mjs";
import { recordWebObservation } from "./web-observation-client";

/** Finite, rounded observations only. Raw metric IDs, navigation and entries are never read. */
export function sendToAnalytics(metric: Metric) {
  const observation = projectWebVital(metric);
  if (!observation) return;
  if (process.env.NODE_ENV !== "production") {
    try { console.info(observation); } catch { /* Observations cannot affect rendering. */ }
    return;
  }
  void recordWebObservation(observation);
}

let registered = false;
export function reportWebVitals() {
  if (registered) return;
  registered = true;
  onLCP(sendToAnalytics);
  onINP(sendToAnalytics);
  onCLS(sendToAnalytics);
  onFCP(sendToAnalytics);
  onTTFB(sendToAnalytics);
}
