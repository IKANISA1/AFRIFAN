"use client";

/**
 * Web Vitals RUM reporter.
 *
 * Collects Core Web Vitals 2.0 (LCP, INP, CLS) plus FCP and TTFB from
 * real user sessions. In development, metrics are logged to the console.
 * In production, they can be sent to an analytics endpoint.
 *
 * Usage: import and call `reportWebVitals()` once in a client layout or
 * root component.
 */

import { onCLS, onFCP, onINP, onLCP, onTTFB } from "web-vitals";
import type { Metric } from "web-vitals";

function sendToAnalytics(metric: Metric) {
  // Development: log to console with color coding
  if (process.env.NODE_ENV !== "production") {
    const colorMap: Record<string, string> = {
      LCP: "#2563eb",
      INP: "#16a34a",
      CLS: "#d97706",
      FCP: "#7c3aed",
      TTFB: "#0891b2",
    };
    const color = colorMap[metric.name] ?? "#64748b";
    console.log(
      `%c[Web Vitals] ${metric.name}: ${metric.value.toFixed(
        metric.name === "CLS" ? 4 : 0,
      )}${metric.name === "CLS" ? "" : "ms"} (${metric.rating})`,
      `color: ${color}; font-weight: bold`,
    );
    return;
  }

  // Production: send to analytics endpoint if configured
  // Replace with your analytics endpoint (Google Analytics, PostHog, etc.)
  const analyticsUrl = process.env.NEXT_PUBLIC_VITALS_ENDPOINT;
  if (analyticsUrl) {
    const body = JSON.stringify({
      name: metric.name,
      value: metric.value,
      rating: metric.rating,
      delta: metric.delta,
      id: metric.id,
      navigationType: metric.navigationType,
    });

    if (navigator.sendBeacon) {
      navigator.sendBeacon(analyticsUrl, body);
    } else {
      fetch(analyticsUrl, {
        method: "POST",
        body,
        headers: { "Content-Type": "application/json" },
        keepalive: true,
      }).catch(() => {});
    }
  }
}

export function reportWebVitals() {
  onLCP(sendToAnalytics);
  onINP(sendToAnalytics);
  onCLS(sendToAnalytics);
  onFCP(sendToAnalytics);
  onTTFB(sendToAnalytics);
}
