/**
 * Playwright screenshot capture for PWA manifest install images.
 *
 * Captures:
 *   1. fans-home.png    — /supporters on mobile (1080×2340)
 *   2. fans-tickets.png — /tickets on mobile (1080×2340)
 *   3. admin-matches-rayon.png — /admin/matches on desktop (1024×1024)
 *
 * Usage:
 *   npx playwright test e2e/capture-screenshots.spec.ts --project=mobile-chromium
 *
 * Note: Admin screenshot needs a separate desktop project or explicit viewport override.
 *       The script overrides viewport per-test where needed.
 */
import path from "node:path";
import { test } from "@playwright/test";

const SCREENSHOTS_DIR = path.join(process.cwd(), "public", "screenshots");

/* ── Supporters: Landing ───────────────────────────────────── */

test("capture supporters home screenshot", async ({ page }) => {
  // Mobile viewport (Android flagship)
  await page.setViewportSize({ width: 412, height: 915 });

  await page.goto("/supporters", {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });

  await page.waitForSelector("text=/supporters|fan app|mobile/i", {
    timeout: 15_000,
  }).catch(() => {
    // Capture a deterministic fallback even if content streams in slowly
  });

  // Additional settle time for animations
  await page.waitForTimeout(1_000);

  await page.screenshot({
    path: path.join(SCREENSHOTS_DIR, "fans-home.png"),
    fullPage: false,
    type: "png",
  });
});

/* ── Tickets: Public site ─────────────────────────────────── */

test("capture fans tickets screenshot", async ({ page }) => {
  await page.setViewportSize({ width: 412, height: 915 });

  await page.goto("/tickets", {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });

  // Wait for ticket content
  await page.waitForSelector("text=/matchday tickets|checkout|reserve/i", {
    timeout: 15_000,
  }).catch(() => {});

  await page.waitForTimeout(1_000);

  await page.screenshot({
    path: path.join(SCREENSHOTS_DIR, "fans-tickets.png"),
    fullPage: false,
    type: "png",
  });
});

/* ── Admin: Matches (desktop) ─────────────────────────────── */

test("capture admin matches screenshot", async ({ page }) => {
  // Override to desktop viewport for admin
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto("/admin/matches", {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });

  // Wait for auth card or dashboard to render
  await page.waitForTimeout(3_000);

  // Wait for admin content — either the match manager or the auth form
  await page.waitForSelector("text=/match manager|admin workspace|sign in/i", {
    timeout: 15_000,
  }).catch(() => {});

  await page.waitForTimeout(1_000);

  await page.screenshot({
    path: path.join(SCREENSHOTS_DIR, "admin-matches-rayon.png"),
    fullPage: false,
    type: "png",
    clip: { x: 0, y: 0, width: 1024, height: 1024 },
  });
});
