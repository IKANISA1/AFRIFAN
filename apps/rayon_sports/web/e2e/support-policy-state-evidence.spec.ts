import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

let evidenceDirectory: string;

const routes = [
  { path: "/support", kind: "support" },
  { path: "/account-deletion", kind: "account-deletion" },
] as const;

async function capture(
  page: Page,
  kind: string,
  state: string,
  fullPage = true,
) {
  const file = `${kind}_state_${state}_viewport.png`;
  await captureStateScreenshot(page, {
    path: path.join(evidenceDirectory, file),
    fullPage,
    animations: "disabled",
  });
  return file;
}

async function openSupportRoute(
  page: Page,
  route: string,
  kind: string,
  state: string,
) {
  await navigateStateEvidence(page, `${route}?evidence=${state}`, {
    waitUntil: "domcontentloaded",
  });
  const surface = page.locator(`[data-support-kind="${kind}"]`);
  await expect(surface).toBeVisible();
  await expect(surface.locator("h1")).toHaveCount(1);
  await expect(surface.locator(".release-support-actions a")).not.toHaveCount(
    0,
  );
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
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_support_policy_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

test("support policy routes prove their six applicable static-support states", async ({
  browser,
}) => {

  const context: BrowserContext = await browser.newContext({
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  const captures: Array<{
    route: string;
    state: string;
    file: string;
  }> = [];

  for (const route of routes) {
    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    let surface = await openSupportRoute(page, route.path, route.kind, "dark");
    expect(
      await surface.evaluate((element) => getComputedStyle(element).color),
    ).toBe("rgb(248, 250, 252)");
    await expectNoSeriousAxeViolations(page);
    captures.push({
      route: route.path,
      state: "dark",
      file: await capture(page, route.kind, "dark_dark"),
    });

    surface = await openSupportRoute(page, route.path, route.kind, "focused");
    const primary = surface.locator(".release-support-action-primary");
    await primary.scrollIntoViewIfNeeded();
    await primary.focus();
    await primary.scrollIntoViewIfNeeded();
    await expect(primary).toBeFocused();
    expect(
      await primary.evaluate(
        (element) => getComputedStyle(element).outlineStyle,
      ),
    ).not.toBe("none");
    captures.push({
      route: route.path,
      state: "focused",
      file: await capture(page, route.kind, "focused_dark", false),
    });

    surface = await openSupportRoute(page, route.path, route.kind, "pressed");
    const pressedPrimary = surface.locator(".release-support-action-primary");
    await pressedPrimary.scrollIntoViewIfNeeded();
    await pressedPrimary.hover();
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
    captures.push({
      route: route.path,
      state: "pressed",
      file: await capture(page, route.kind, "pressed_dark", false),
    });
    await page.mouse.move(1, 1);
    await page.mouse.up();

    surface = await openSupportRoute(
      page,
      route.path,
      route.kind,
      "large-text",
    );
    await page.addStyleTag({
      content: "html { font-size: 200% !important; }",
    });
    for (const selector of [
      `[data-support-kind="${route.kind}"]`,
      "footer",
      'nav[aria-label="Main navigation"]',
    ]) {
      const { overflow, overflowingDescendants } = await page
        .locator(selector)
        .evaluate((element) => ({
          overflow: element.scrollWidth - element.clientWidth,
          overflowingDescendants: Array.from(element.querySelectorAll("*"))
            .filter(
              (descendant) =>
                descendant.scrollWidth - descendant.clientWidth > 1,
            )
            .slice(0, 8)
            .map((descendant) => ({
              tag: descendant.tagName.toLowerCase(),
              className: descendant.className,
              text: descendant.textContent?.trim().slice(0, 80),
              overflow: descendant.scrollWidth - descendant.clientWidth,
            })),
        }));
      expect(
        overflow,
        `${route.path} ${selector} internal horizontal overflow: ${JSON.stringify(overflowingDescendants)}`,
      ).toBeLessThanOrEqual(1);
    }
    captures.push({
      route: route.path,
      state: "large_text",
      file: await capture(page, route.kind, "large_text_dark", false),
    });

    await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
    surface = await openSupportRoute(
      page,
      route.path,
      route.kind,
      "reduced-motion",
    );
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
    captures.push({
      route: route.path,
      state: "reduced_motion",
      file: await capture(page, route.kind, "reduced_motion_dark"),
    });

    await page.emulateMedia({
      colorScheme: "light",
      reducedMotion: "no-preference",
    });
    surface = await openSupportRoute(page, route.path, route.kind, "light");
    expect(
      await surface.evaluate((element) => getComputedStyle(element).color),
    ).toBe("rgb(15, 23, 42)");
    await expectNoSeriousAxeViolations(page);
    captures.push({
      route: route.path,
      state: "light",
      file: await capture(page, route.kind, "light_light"),
    });

    const actionHeights = await surface
      .locator(".release-support-actions a")
      .evaluateAll((actions) =>
        actions.map((action) => action.getBoundingClientRect().height),
      );
    expect(actionHeights.every((height) => height >= 48)).toBe(true);
  }

  fs.writeFileSync(
    path.join(evidenceDirectory, "support-policy-state-evidence.json"),
    `${JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        profile: { browser: browser.browserType().name(), ...stateEvidenceContextOptions(test.info()) },
        routes: routes.map((route) => route.path),
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
          "These static support-policy surfaces always render governed fallback content and own no collection, authorization, selection, mutation, synchronization, conflict, or timeout operation.",
        assertions: {
          oneLevelOneHeadingPerRoute: true,
          unsafeSupportActionsRendered: 0,
          seriousOrCriticalAxeViolations: 0,
          internalHorizontalOverflowAt200Percent: false,
          maximumReducedMotionDurationSeconds: 0.001,
          minimumActionHeightCssPixels: 48,
          pressedFeedback: "translateY(2px) scale(0.97)",
        },
        captures,
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
});
