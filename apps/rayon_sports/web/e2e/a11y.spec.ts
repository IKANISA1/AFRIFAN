import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

/**
 * Automated accessibility audit using axe-core.
 *
 * Scans key surfaces for WCAG 2.2 AA violations.
 * Runs in CI to prevent accessibility regressions.
 */

/* ────────────────────────────────────────────────────────── */
/*  Public site accessibility                                 */
/* ────────────────────────────────────────────────────────── */

test("public home page has no critical a11y violations", async ({
  page,
  browserName,
}) => {
  await page.goto("/", { waitUntil: "domcontentloaded" });

  const builder = new AxeBuilder({ page }).withTags([
    "wcag2a",
    "wcag2aa",
    "wcag22aa",
  ]);
  if (browserName === "webkit") {
    builder.disableRules(["target-size"]);
  }
  const results = await builder.analyze();

  // Filter to only critical and serious violations
  const critical = results.violations.filter(
    (v) => v.impact === "critical" || v.impact === "serious",
  );

  if (critical.length > 0) {
    const summary = critical
      .map(
        (v) =>
          `[${v.impact}] ${v.id}: ${v.description} (${v.nodes.length} instances)`,
      )
      .join("\n");
    console.error("Accessibility violations:\n", summary);
  }

  expect(critical).toHaveLength(0);
});

/* ────────────────────────────────────────────────────────── */
/*  Supporter app handoff accessibility                       */
/* ────────────────────────────────────────────────────────── */

test("supporters handoff page has no critical a11y violations", async ({
  page,
  browserName,
}) => {
  await page.goto("/supporters", { waitUntil: "domcontentloaded" });

  const builder = new AxeBuilder({ page }).withTags([
    "wcag2a",
    "wcag2aa",
    "wcag22aa",
  ]);
  if (browserName === "webkit") {
    builder.disableRules(["target-size"]);
  }
  const results = await builder.analyze();

  const critical = results.violations.filter(
    (v) => v.impact === "critical" || v.impact === "serious",
  );

  expect(critical).toHaveLength(0);
});

/* ────────────────────────────────────────────────────────── */
/*  Admin sign-in surface accessibility                       */
/* ────────────────────────────────────────────────────────── */

test("admin sign-in has no critical a11y violations", async ({ page }) => {
  await page.goto("/admin", { waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: /secure sign in/i }).waitFor({
    timeout: 15_000,
  });

  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();

  const critical = results.violations.filter(
    (v) => v.impact === "critical" || v.impact === "serious",
  );

  if (critical.length > 0) {
    const summary = critical
      .map(
        (v) =>
          `[${v.impact}] ${v.id}: ${v.description} (${v.nodes.length} instances)`,
      )
      .join("\n");
    console.error("Admin a11y violations:\n", summary);
  }

  expect(critical).toHaveLength(0);
});

/* ────────────────────────────────────────────────────────── */
/*  Offline page accessibility                                */
/* ────────────────────────────────────────────────────────── */

test("offline pages have no a11y violations", async ({ page }) => {
  await page.goto("/offline", { waitUntil: "domcontentloaded" });

  const offlineResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa"])
    .analyze();

  expect(
    offlineResults.violations.filter(
      (v) => v.impact === "critical" || v.impact === "serious",
    ),
  ).toHaveLength(0);

  await page.goto("/admin-offline", { waitUntil: "domcontentloaded" });

  const adminOfflineResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa"])
    .analyze();

  expect(
    adminOfflineResults.violations.filter(
      (v) => v.impact === "critical" || v.impact === "serious",
    ),
  ).toHaveLength(0);
});
