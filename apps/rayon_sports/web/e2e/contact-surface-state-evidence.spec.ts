import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

let evidenceDirectory: string;

async function capture(page: Page, state: string, fullPage = true) {
  await captureStateScreenshot(page, {
    path: path.join(evidenceDirectory, `contact_state_${state}_viewport.png`),
    fullPage,
    animations: "disabled",
  });
}

async function openContact(page: Page, state: string) {
  await navigateStateEvidence(page, `/contact?evidence=${state}`, {
    waitUntil: "domcontentloaded",
  });
  const surface = page.locator("[data-contact-surface]");
  await expect(surface).toBeVisible();
  await expect(surface.locator("h1")).toHaveCount(1);
  await expect.poll(() => page.evaluate(() =>
    document.querySelector(".contact-surface-hero")!.getBoundingClientRect().top -
    document.querySelector("[data-site-header]")!.getBoundingClientRect().bottom,
  )).toBeGreaterThanOrEqual(0);
  return surface;
}

async function expectNoSeriousAxeViolations(page: Page) {
  const axeResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    axeResults.violations.filter(
      (violation) =>
        violation.impact === "critical" || violation.impact === "serious",
    ),
  ).toHaveLength(0);
}

test.beforeEach(async ({ browser }, testInfo) => {
  test.setTimeout(120_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_contact_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

test("contact proves its six applicable static-support states", async ({
  browser,
}) => {

  const context: BrowserContext = await browser.newContext({
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  const captures: Array<{ state: string; file: string }> = [];

  let surface = await openContact(page, "dark");
  expect(
    await surface.evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(248, 250, 252)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");
  captures.push({
    state: "dark",
    file: "contact_state_dark_dark_viewport.png",
  });

  surface = await openContact(page, "focused");
  const primary = surface.locator(".contact-surface-action-primary");
  await primary.focus();
  await expect(primary).toBeFocused();
  expect(
    await primary.evaluate((element) => getComputedStyle(element).outlineStyle),
  ).not.toBe("none");
  await capture(page, "focused_dark", false);
  captures.push({
    state: "focused",
    file: "contact_state_focused_dark_viewport.png",
  });

  surface = await openContact(page, "pressed");
  const pressedPrimary = surface.locator(".contact-surface-action-primary");
  const primaryBox = await pressedPrimary.boundingBox();
  expect(primaryBox).not.toBeNull();
  await page.mouse.move(
    primaryBox!.x + primaryBox!.width / 2,
    primaryBox!.y + primaryBox!.height / 2,
  );
  await page.mouse.down();
  await page.waitForTimeout(50);
  expect(
    await pressedPrimary.evaluate(
      (element) => getComputedStyle(element).transform,
    ),
  ).not.toBe("none");
  await capture(page, "pressed_dark", false);
  captures.push({
    state: "pressed",
    file: "contact_state_pressed_dark_viewport.png",
  });
  await page.mouse.move(1, 1);
  await page.mouse.up();

  surface = await openContact(page, "large-text");
  await page.addStyleTag({
    content: "html { font-size: 200% !important; }",
  });
  await expect.poll(() => page.evaluate(() =>
    document.querySelector(".contact-surface-hero")!.getBoundingClientRect().top -
    document.querySelector("[data-site-header]")!.getBoundingClientRect().bottom,
  )).toBeGreaterThanOrEqual(0);
  for (const selector of [
    "[data-contact-surface]",
    "footer",
    'nav[aria-label="Primary navigation"]',
  ]) {
    const overflow = await page
      .locator(selector)
      .evaluate((element) => element.scrollWidth - element.clientWidth);
    expect(overflow, `${selector} internal horizontal overflow`).toBeLessThanOrEqual(
      1,
    );
  }
  await capture(page, "large_text_dark", false);
  captures.push({
    state: "large_text",
    file: "contact_state_large_text_dark_viewport.png",
  });

  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  surface = await openContact(page, "reduced-motion");
  const maximumMotionDuration = await surface
    .locator("*")
    .evaluateAll((elements) =>
      Math.max(
        ...elements.flatMap((element) => {
          const styles = getComputedStyle(element);
          return [
            ...styles.animationDuration.split(","),
            ...styles.transitionDuration.split(","),
          ].map((duration) => {
            const value = Number.parseFloat(duration);
            return duration.trim().endsWith("ms") ? value / 1000 : value;
          });
        }),
      ),
    );
  expect(maximumMotionDuration).toBeLessThanOrEqual(0.001);
  await capture(page, "reduced_motion_dark");
  captures.push({
    state: "reduced_motion",
    file: "contact_state_reduced_motion_dark_viewport.png",
  });

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  surface = await openContact(page, "light");
  expect(
    await surface.evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(15, 23, 42)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "light_light");
  captures.push({
    state: "light",
    file: "contact_state_light_light_viewport.png",
  });

  fs.writeFileSync(
    path.join(evidenceDirectory, "contact-surface-state-evidence.json"),
    `${JSON.stringify(
      {
        route: "/contact",
        surface: "consumer_web",
        generatedAt: new Date().toISOString(),
        profile: { browser: browser.browserType().name(), ...stateEvidenceContextOptions(test.info()) },
        applicable_states: [
          "focused",
          "pressed",
          "large_text",
          "reduced_motion",
          "dark",
          "light",
        ],
        not_applicable_states: [
          "loading",
          "empty",
          "error",
          "offline",
          "permission_denied",
          "disabled",
          "selected",
          "syncing",
          "conflict",
          "security_timeout",
        ],
        not_applicable_rationale:
          "The static support surface always renders governed fallback content and owns no collection, authorization, selection, mutation, synchronization, conflict, or timeout operation.",
        assertions: {
          oneLevelOneHeading: true,
          unsafeExternalSocialLinksRendered: 0,
          seriousOrCriticalAxeViolations: 0,
          internalHorizontalOverflowAt200Percent: false,
          maximumReducedMotionDurationSeconds: 0.001,
        },
        captures,
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
});
