import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/implementation_goal_20260724/consumer_web_share_target_states",
);

const populatedRoute =
  "/share-target?title=Official%20match%20report" +
  "&text=Review%20the%20confirmed%20club%20update" +
  "&url=https%3A%2F%2Fexample.com%2Fclub%2Fofficial-report";

async function openShareTarget(page: Page, route = populatedRoute) {
  await page.goto(route, { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", {
      name: /bring shared content into the club flow/i,
    }),
  ).toBeVisible();
  const primary = page.getByRole("link", {
    name: /search the official site/i,
  });
  await expect(primary).toBeVisible();
  const box = await primary.boundingBox();
  expect(box?.height ?? 0).toBeGreaterThanOrEqual(48);
  return primary;
}

async function capture(page: Page, state: string) {
  await page.screenshot({
    path: path.join(
      evidenceDirectory,
      `share_target_state_${state}_pixel7.png`,
    ),
    fullPage: true,
    animations: "disabled",
  });
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("share target proves all eight applicable rendered states", async ({
  page,
  context,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Governed screenshots use the single declared Pixel 7 evidence profile.",
  );

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  let primary = await openShareTarget(page);
  await expect(page.getByText("Official match report")).toBeVisible();
  await expect(
    page.getByRole("link", { name: /open original secure link/i }),
  ).toHaveAttribute("href", "https://example.com/club/official-report");
  expect(
    await page.locator(".share-target-title").evaluate((element) => {
      return getComputedStyle(element).color;
    }),
  ).toBe("rgb(246, 248, 252)");
  await capture(page, "dark_dark");

  const axeResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    axeResults.violations.filter(
      (violation) =>
        violation.impact === "critical" || violation.impact === "serious",
    ),
  ).toHaveLength(0);

  await openShareTarget(
    page,
    "/share-target?url=javascript%3Aalert%281%29",
  );
  await expect(
    page.getByRole("alert").filter({ hasText: /only HTTP and HTTPS/i }),
  ).toContainText(/only HTTP and HTTPS/i);
  await expect(
    page.getByRole("link", { name: /open original/i }),
  ).toHaveCount(0);

  await openShareTarget(page, "/share-target");
  await expect(
    page.getByRole("heading", { name: /no shared content was received/i }),
  ).toBeVisible();
  await capture(page, "empty_dark");

  primary = await openShareTarget(page);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expect(page.getByRole("status")).toContainText(
    /external destinations need a connection/i,
  );
  await capture(page, "offline_dark");
  await context.setOffline(false);
  await page.evaluate(() => window.dispatchEvent(new Event("online")));

  primary = await openShareTarget(page);
  await expect(primary).toHaveText(/search the official site/i);
  await primary.focus();
  await expect(primary).toBeFocused();
  expect(
    await primary.evaluate((element) => getComputedStyle(element).outlineStyle),
  ).not.toBe("none");
  await capture(page, "focused_dark");

  const primaryBox = await primary.boundingBox();
  expect(primaryBox).not.toBeNull();
  await page.mouse.move(
    primaryBox!.x + primaryBox!.width / 2,
    primaryBox!.y + primaryBox!.height / 2,
  );
  await page.mouse.down();
  await page.waitForTimeout(50);
  expect(
    await primary.evaluate((element) => getComputedStyle(element).transform),
  ).not.toBe("none");
  await capture(page, "pressed_dark");
  await page.mouse.move(1, 1);
  await page.mouse.up();

  primary = await openShareTarget(page);
  await page.addStyleTag({
    content: "html { font-size: 200% !important; }",
  });
  const horizontalOverflow = await page.evaluate(
    () =>
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth,
  );
  expect(horizontalOverflow).toBeLessThanOrEqual(1);
  await capture(page, "large_text_dark");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "reduce",
  });
  primary = await openShareTarget(page);
  const reducedDurations = await primary.evaluate((element) =>
    getComputedStyle(element)
      .transitionDuration.split(",")
      .map((duration) => Number.parseFloat(duration)),
  );
  expect(Math.max(...reducedDurations)).toBeLessThanOrEqual(0.001);
  await capture(page, "reduced_motion_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await openShareTarget(page);
  expect(
    await page.locator(".share-target-title").evaluate((element) => {
      return getComputedStyle(element).color;
    }),
  ).toBe("rgb(13, 22, 39)");
  expect(
    await page
      .locator(".share-target-action-primary")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(255, 255, 255)");
  const lightAxeResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    lightAxeResults.violations.filter(
      (violation) =>
        violation.impact === "critical" || violation.impact === "serious",
    ),
  ).toHaveLength(0);
  await capture(page, "light_light");
});
