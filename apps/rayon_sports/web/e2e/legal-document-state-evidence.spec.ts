import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/implementation_goal_20260724/consumer_web_legal_document_states",
);

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
  await page.screenshot({
    path: path.join(
      evidenceDirectory,
      `${kind}_state_${state}_pixel7.png`,
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
    document.locator("a, button, input, select, textarea"),
  ).toHaveCount(0);
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
  await page.goto(`${route}?evidence=${state}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("privacy and terms prove their four applicable document states", async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Legal-document evidence uses the declared Pixel 7 Chromium profile.",
  );

  const context: BrowserContext = await browser.newContext({
    viewport: { width: 412, height: 839 },
    deviceScaleFactor: 2.625,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  const capturedStates: Array<{
    route: string;
    state: string;
    screenshot: string;
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
    await capture(page, route.kind, "large_text_dark", false);
    capturedStates.push({
      route: route.path,
      state: "large_text",
      screenshot: `${route.kind}_state_large_text_dark_pixel7.png`,
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
      screenshot: `${route.kind}_state_reduced_motion_dark_pixel7.png`,
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
    ).toBe("rgb(248, 250, 252)");
    await expectNoSeriousAxeViolations(page);
    await capture(page, route.kind, "dark_dark");
    capturedStates.push({
      route: route.path,
      state: "dark",
      screenshot: `${route.kind}_state_dark_dark_pixel7.png`,
    });

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
    ).toBe("rgb(15, 23, 42)");
    await expectNoSeriousAxeViolations(page);
    await capture(page, route.kind, "light_light");
    capturedStates.push({
      route: route.path,
      state: "light",
      screenshot: `${route.kind}_state_light_light_pixel7.png`,
    });
  }

  fs.writeFileSync(
    path.join(evidenceDirectory, "legal-document-state-evidence.json"),
    `${JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        profile: {
          browser: "chromium",
          device: "Pixel 7",
          viewport: { width: 412, height: 839 },
          deviceScaleFactor: 2.625,
        },
        applicableStates: ["large_text", "reduced_motion", "dark", "light"],
        notApplicableStates: [
          "loading",
          "empty",
          "error",
          "offline",
          "permission_denied",
          "disabled",
          "focused",
          "pressed",
          "selected",
          "syncing",
          "conflict",
          "security_timeout",
        ],
        notApplicableRationale:
          "These informational documents always render governed fallback copy when CMS content is absent and own no controls, authentication, mutations, synchronization, conflict, or timeout workflow.",
        assertions: {
          oneLevelOneHeading: true,
          documentParagraphsPresent: true,
          pageOwnedControls: 0,
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
