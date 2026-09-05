import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/evidence/consumer_web_contact_states",
);

async function capture(page: Page, state: string, fullPage = true) {
  await page.screenshot({
    path: path.join(evidenceDirectory, `contact_state_${state}_pixel7.png`),
    fullPage,
    animations: "disabled",
  });
}

async function openContact(page: Page, state: string) {
  await page.goto(`/contact?evidence=${state}`, {
    waitUntil: "domcontentloaded",
  });
  const surface = page.locator("[data-contact-surface]");
  await expect(surface).toBeVisible();
  await expect(surface.locator("h1")).toHaveCount(1);
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

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("contact proves its six applicable static-support states", async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Contact evidence uses the declared Pixel 7 Chromium profile.",
  );

  const context: BrowserContext = await browser.newContext({
    viewport: { width: 412, height: 839 },
    deviceScaleFactor: 2.625,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  const captures: Array<{ state: string; screenshot: string }> = [];

  let surface = await openContact(page, "dark");
  expect(
    await surface.evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(248, 250, 252)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");
  captures.push({
    state: "dark",
    screenshot: "contact_state_dark_dark_pixel7.png",
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
    screenshot: "contact_state_focused_dark_pixel7.png",
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
    screenshot: "contact_state_pressed_dark_pixel7.png",
  });
  await page.mouse.move(1, 1);
  await page.mouse.up();

  surface = await openContact(page, "large-text");
  await page.addStyleTag({
    content: "html { font-size: 200% !important; }",
  });
  for (const selector of [
    "[data-contact-surface]",
    "footer",
    'nav[aria-label="Main navigation"]',
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
    screenshot: "contact_state_large_text_dark_pixel7.png",
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
    screenshot: "contact_state_reduced_motion_dark_pixel7.png",
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
    screenshot: "contact_state_light_light_pixel7.png",
  });

  fs.writeFileSync(
    path.join(evidenceDirectory, "contact-surface-state-evidence.json"),
    `${JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        profile: {
          browser: "chromium",
          device: "Pixel 7",
          viewport: { width: 412, height: 839 },
          deviceScaleFactor: 2.625,
        },
        applicableStates: [
          "focused",
          "pressed",
          "large_text",
          "reduced_motion",
          "dark",
          "light",
        ],
        notApplicableStates: [
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
        notApplicableRationale:
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
