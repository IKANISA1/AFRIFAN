import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("compact menu waits for client initialization before accepting input", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  let releaseChunks!: () => void;
  const chunksReady = new Promise<void>((resolve) => { releaseChunks = resolve; });
  await page.route(/\/_next\/static\/chunks\/.*\.js/, async (route) => {
    await chunksReady;
    await route.continue();
  });
  try {
    await page.goto("/privacy", { waitUntil: "commit" });
    await page.waitForFunction(() => document.querySelector('[aria-label="Open menu"]') !== null);
    expect(await page.evaluate(() => document.querySelector<HTMLButtonElement>('[aria-label="Open menu"]')!.disabled)).toBe(true);
  } finally {
    releaseChunks();
    await page.unrouteAll({ behavior: "wait" });
  }
  await page.waitForLoadState("domcontentloaded");
  const menu = page.getByRole("button", { name: "Open menu" });
  await expect(menu).toBeEnabled();
  await menu.focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("dialog", { name: "Navigation menu" }).getByRole("button", { name: "Close menu" })).toBeFocused();
});

test("site search is reachable through desktop and compact navigation", async ({ page }) => {
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/privacy", { waitUntil: "domcontentloaded" });
    const navigation = page.getByRole("navigation", { name: "Primary navigation" });
    if (width === 1440) {
      await navigation.getByLabel("Search site").click({ timeout: 5_000 });
    } else {
      await navigation.getByRole("button", { name: "Open menu" }).click({ timeout: 5_000 });
      await page.getByRole("dialog", { name: "Navigation menu" }).getByRole("link", { name: "Search site", exact: true }).click({ timeout: 5_000 });
    }
    await expect(page).toHaveURL(/\/search(?:\?|$)/, { timeout: 5_000 });
    await expect(page.locator("[data-search-page-status]")).toBeVisible();
  }
});

test("compact drawer controls fit and retain 48-pixel targets at enlarged text", async ({ page }) => {
  for (const textPercent of [100, 200]) {
    await page.setViewportSize({ width: 320, height: 900 });
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/privacy", { waitUntil: "domcontentloaded" });
    await page.addStyleTag({ content: `html { font-size: ${textPercent}% !important; }` });
    await page.getByRole("button", { name: "Open menu" }).click();
    const drawer = page.getByRole("dialog", { name: "Navigation menu" });
    await expect(page.locator('[id="mobile-navigation-drawer"]')).toHaveCount(1);
    const branding = await drawer.evaluate((element) => {
      const header = element.firstElementChild!;
      const close = header.querySelector("button")!.getBoundingClientRect();
      return [...header.querySelectorAll("p, img")].map((item) => {
        const box = item.getBoundingClientRect();
        return { label: item.textContent || item.getAttribute("alt"), right: box.right, closeLeft: close.left, overflow: item.scrollWidth - item.clientWidth };
      });
    });
    for (const item of branding) {
      expect(item.right, item.label ?? "club identity").toBeLessThanOrEqual(item.closeLeft);
      expect(item.overflow, item.label ?? "club identity").toBeLessThanOrEqual(1);
    }
    const geometry = await drawer.evaluate((element) => {
      const frame = element.getBoundingClientRect();
      return {
        left: frame.left, right: frame.right,
        controls: [...element.querySelectorAll("a, button")].map((control) => {
          const box = control.getBoundingClientRect();
          return { label: control.getAttribute("aria-label") ?? control.textContent?.trim(), x: box.x, right: box.right, width: box.width, height: box.height, overflow: control.scrollWidth - control.clientWidth };
        }),
      };
    });
    for (const control of geometry.controls) {
      expect(control.width, control.label).toBeGreaterThanOrEqual(48);
      expect(control.height, control.label).toBeGreaterThanOrEqual(48);
      expect(control.x, control.label).toBeGreaterThanOrEqual(geometry.left);
      expect(control.right, control.label).toBeLessThanOrEqual(geometry.right + 1);
      expect(control.overflow, control.label).toBeLessThanOrEqual(1);
    }
    await expect(drawer.getByRole("button", { name: "Close menu" })).toBeInViewport();
  }
});

for (const colorScheme of ["light", "dark"] as const) {
  test(`compact navigation text meets contrast requirements in ${colorScheme} mode`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 });
    await page.emulateMedia({ colorScheme, reducedMotion: "reduce" });
    await page.goto("/privacy", { waitUntil: "domcontentloaded" });
    await page.emulateMedia({ colorScheme, reducedMotion: "reduce" });
    await page.getByRole("button", { name: "Open menu" }).click({ timeout: 5_000 });
    const results = await new AxeBuilder({ page }).include('[role="dialog"][aria-label="Navigation menu"]').withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"]).analyze();
    expect(results.violations).toEqual([]);
  });
}

for (const width of [320, 768, 1440]) {
  for (const textPercent of [100, 200]) {
    test(`primary navigation remains usable at ${width}px and ${textPercent}% text`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
      await page.goto("/privacy", { waitUntil: "domcontentloaded" });
      await expect(page.locator('[data-legal-document="privacy"]')).toBeVisible();
      await page.addStyleTag({ content: `html { font-size: ${textPercent}% !important; }` });
      const navigation = page.locator("nav.page-shell");
      // Measure and select visible targets in one browser snapshot. A separate
      // :visible query can precede the container-query reflow after text sizing.
      const targets = await navigation.locator("a, button").evaluateAll((elements) => elements.map((element) => {
        const box = element.getBoundingClientRect();
        return { label: element.getAttribute("aria-label") ?? element.textContent?.trim(), left: box.left, right: box.right, width: box.width, height: box.height, visibility: getComputedStyle(element).visibility };
      }).filter((target) => target.width > 0 && target.height > 0 && target.visibility !== "hidden"));
      expect(targets.length).toBeGreaterThan(1);
      expect(targets.filter((target) => target.left < 0 || target.right > width)).toEqual([]);
      for (const target of targets) {
        expect(target.left, target.label).toBeGreaterThanOrEqual(0);
        expect(target.right, target.label).toBeLessThanOrEqual(width);
        expect(target.width, target.label).toBeGreaterThanOrEqual(48);
        expect(target.height, target.label).toBeGreaterThanOrEqual(48);
      }
      const menu = page.getByRole("button", { name: "Open menu" });
      expect(await menu.isVisible() || await navigation.getByRole("link", { name: "Membership", exact: true }).isVisible()).toBe(true);
      if (await menu.isVisible()) {
        await expect(menu).toBeEnabled();
        await menu.focus();
        await page.keyboard.press("Enter");
        const drawer = page.getByRole("dialog", { name: "Navigation menu", includeHidden: true });
        await expect(drawer).toBeVisible();
        await expect(drawer.getByRole("link", { name: "Membership", exact: true })).toBeVisible();
        await expect(drawer.getByRole("button", { name: "Close menu" })).toBeFocused();
        await page.keyboard.press("Escape");
        await expect(drawer).toHaveAttribute("aria-hidden", "true");
        await expect(drawer).not.toBeInViewport();
        await expect(menu).toBeFocused();
      }
    });
  }
}

test("primary navigation stays onscreen after scrolling on a compact page", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/privacy", { waitUntil: "domcontentloaded" });
  await expect(page.locator('[data-legal-document="privacy"]')).toBeVisible();
  await page.evaluate(() => window.scrollTo(0, 600));
  const header = page.locator("nav.page-shell");
  await expect.poll(() => header.evaluate((element) => element.parentElement!.className)).toContain("shadow-xl");
  await expect.poll(() => header.evaluate((element) => element.getBoundingClientRect().top)).toBeGreaterThanOrEqual(0);
  const trigger = page.getByRole("button", { name: "Open menu" });
  await trigger.click();
  const drawer = page.getByRole("dialog", { name: "Navigation menu" });
  await expect(drawer).toBeInViewport();
  await expect.poll(() => drawer.evaluate((element) => element.getBoundingClientRect().height)).toBe(844);
});

test("primary navigation restores keyboard focus after the menu closes", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/privacy", { waitUntil: "domcontentloaded" });
  const trigger = page.getByRole("button", { name: "Open menu" });
  await expect(trigger).toBeEnabled();
  await trigger.focus(); await page.keyboard.press("Enter");
  const drawer = page.getByRole("dialog", { name: "Navigation menu", includeHidden: true });
  await expect(drawer.getByRole("button", { name: "Close menu" })).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(drawer).toHaveAttribute("aria-hidden", "true");
  await expect(trigger).toBeFocused();
});

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

test("admin sign-in has no critical a11y violations", async ({
  page,
  browserName,
}) => {
  await page.goto("/admin", { waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: /secure sign in/i }).waitFor({
    timeout: 15_000,
  });

  const phoneInput = page.locator('input[type="tel"]');
  await expect(phoneInput).toHaveCSS("height", "56px", { timeout: 15_000 });
  const phoneInputBox = await phoneInput.boundingBox();
  expect(phoneInputBox?.height ?? 0).toBeGreaterThanOrEqual(44);

  const builder = new AxeBuilder({ page }).withTags([
    "wcag2a",
    "wcag2aa",
    "wcag22aa",
  ]);
  if (browserName === "webkit") {
    // Axe/WebKit measures the input content box instead of its rendered 56px
    // control. The explicit bounding-box assertion above preserves the actual
    // WCAG target-size gate while avoiding that engine-specific false positive.
    builder.disableRules(["target-size"]);
  }
  const results = await builder.analyze();

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
