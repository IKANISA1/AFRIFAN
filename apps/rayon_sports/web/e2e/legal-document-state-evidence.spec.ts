import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

let evidenceDirectory: string;

const routes = [
  { path: "/privacy", kind: "privacy" },
  { path: "/terms", kind: "terms" },
] as const;

async function capture(
  page: Page,
  kind: string,
  state: string,
  fullPage = true,
) {
  await captureStateScreenshot(page, {
    path: path.join(
      evidenceDirectory,
      `${kind}_state_${state}_viewport.png`,
    ),
    fullPage,
    animations: "disabled",
  });
}

async function expectDocumentContract(page: Page, kind: string) {
  const document = page.locator(`[data-legal-document="${kind}"]`);
  await expect(document).toBeVisible();
  await expect(document.locator("h1")).toHaveCount(1);
  await expect(document.locator("section p")).not.toHaveCount(0);
  await expect(
    document.locator("button, input, select, textarea"),
  ).toHaveCount(0);
  await expect(document.locator(".legal-document-actions a")).toHaveCount(2);
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

async function openRoute(page: Page, route: string, state: string) {
  await navigateStateEvidence(page, `${route}?evidence=${state}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeEach(async ({ browser }, testInfo) => {
  test.setTimeout(120_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_legal_document_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

test("privacy and terms prove their six applicable document states", async ({
  browser,
}) => {

  const context: BrowserContext = await browser.newContext({
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  const capturedStates: Array<{
    route: string;
    state: string;
    file: string;
  }> = [];

  for (const route of routes) {
    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    await openRoute(page, route.path, "large-text");
    await page.addStyleTag({
      content: "html { font-size: 200% !important; }",
    });
    await expectDocumentContract(page, route.kind);
    expect(
      await page.evaluate(
        () =>
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth,
      ),
    ).toBeLessThanOrEqual(1);
    for (const selector of [
      `[data-legal-document="${route.kind}"]`,
      "footer",
      'nav[aria-label="Main navigation"]',
    ]) {
      expect(
        await page
          .locator(selector)
          .evaluate((element) => element.scrollWidth - element.clientWidth),
      ).toBeLessThanOrEqual(1);
    }
    await capture(page, route.kind, "large_text_dark");
    capturedStates.push({
      route: route.path,
      state: "large_text",
      file: `${route.kind}_state_large_text_dark_viewport.png`,
    });

    await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
    await openRoute(page, route.path, "reduced-motion");
    await expectDocumentContract(page, route.kind);
    const maximumMotionDuration = await page
      .locator(`[data-legal-document="${route.kind}"], [data-legal-document="${route.kind}"] *`)
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
    await capture(page, route.kind, "reduced_motion_dark");
    capturedStates.push({
      route: route.path,
      state: "reduced_motion",
      file: `${route.kind}_state_reduced_motion_dark_viewport.png`,
    });

    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    await openRoute(page, route.path, "dark");
    await expectDocumentContract(page, route.kind);
    expect(
      await page
        .locator(`[data-legal-document="${route.kind}"]`)
        .evaluate((element) => getComputedStyle(element).color),
    ).toBe("rgb(244, 244, 244)");
    await expectNoSeriousAxeViolations(page);
    await capture(page, route.kind, "dark_dark");
    capturedStates.push({
      route: route.path,
      state: "dark",
      file: `${route.kind}_state_dark_dark_viewport.png`,
    });

    const actions = page.locator(`[data-legal-document="${route.kind}"] .legal-document-actions a`);
    for (const action of await actions.all()) {
      const box = await action.boundingBox();
      expect(box?.height).toBeGreaterThanOrEqual(48);
      expect(box?.width).toBeGreaterThanOrEqual(48);
    }
    const primary = actions.first();
    // WebKit on macOS uses Option-Tab for links unless full keyboard
    // navigation is enabled. Exercise its real supported key sequence.
    const linkTab = browser.browserType().name() === "webkit" ? "Alt+Tab" : "Tab";
    await primary.focus();
    await page.keyboard.press(linkTab);
    await expect(actions.nth(1)).toBeFocused();
    await page.keyboard.press(`Shift+${linkTab}`);
    await expect(primary).toBeFocused();
    expect(await primary.evaluate((element) => getComputedStyle(element).outlineStyle)).not.toBe("none");
    await capture(page, route.kind, "focused_dark");
    capturedStates.push({ route: route.path, state: "focused", file: `${route.kind}_state_focused_dark_viewport.png` });

    await primary.scrollIntoViewIfNeeded();
    const box = await primary.boundingBox();
    expect(box).not.toBeNull();
    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    expect(await primary.evaluate((element) => element.matches(":active"))).toBe(true);
    await expect.poll(() => primary.evaluate((element) => getComputedStyle(element).transform)).not.toBe("none");
    await capture(page, route.kind, "pressed_dark");
    capturedStates.push({ route: route.path, state: "pressed", file: `${route.kind}_state_pressed_dark_viewport.png` });
    await page.mouse.move(1, 1);
    await page.mouse.up();

    await page.emulateMedia({
      colorScheme: "light",
      reducedMotion: "no-preference",
    });
    await openRoute(page, route.path, "light");
    await expectDocumentContract(page, route.kind);
    expect(
      await page
        .locator(`[data-legal-document="${route.kind}"]`)
        .evaluate((element) => getComputedStyle(element).color),
    ).toBe("rgb(25, 28, 31)");
    await expectNoSeriousAxeViolations(page);
    await capture(page, route.kind, "light_light");
    capturedStates.push({
      route: route.path,
      state: "light",
      file: `${route.kind}_state_light_light_viewport.png`,
    });
  }

  fs.writeFileSync(
    path.join(evidenceDirectory, "legal-document-state-evidence.json"),
    `${JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        profile: { browser: browser.browserType().name(), ...stateEvidenceContextOptions(test.info()) },
        applicable_states: ["large_text", "reduced_motion", "dark", "light", "focused", "pressed"],
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
          "These informational documents render fallback copy when CMS content is absent. Their two navigation/support links have focus and held-press coverage; they own no form, authentication, mutation, synchronization, conflict, or timeout workflow. Applicability remains subject to review.",
        assertions: {
          oneLevelOneHeading: true,
          documentParagraphsPresent: true,
          pageOwnedLinks: 2,
          formControls: 0,
          minimumActionSizePixels: 48,
          keyboardLinkOrderVerified: true,
          keyboardLinkNavigation: browser.browserType().name() === "webkit" ? "Option-Tab" : "Tab",
          heldPressVerified: true,
          seriousOrCriticalAxeViolations: 0,
          horizontalOverflowAt200Percent: false,
          maximumReducedMotionDurationSeconds: 0.001,
        },
        captures: capturedStates,
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
});
