import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/implementation_goal_20260724/consumer_web_recovery_states",
);

const recoveryRoutes = [
  {
    path: "/offline",
    filePrefix: "offline",
    heading: /cached pages stay available/i,
    primaryAction: /cached homepage/i,
  },
  {
    path: "/admin-offline",
    filePrefix: "admin_offline",
    heading: /admin data needs a live connection/i,
    primaryAction: /retry admin workspace/i,
  },
] as const;

async function openRecovery(
  page: Page,
  route: (typeof recoveryRoutes)[number],
) {
  await page.goto(route.path, { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", { name: route.heading }),
  ).toBeVisible();
  const primary = page.getByRole("link", { name: route.primaryAction });
  await expect(primary).toBeVisible();
  const box = await primary.boundingBox();
  expect(box?.height ?? 0).toBeGreaterThanOrEqual(48);
  return primary;
}

async function capture(page: Page, filePrefix: string, state: string) {
  await page.screenshot({
    path: path.join(
      evidenceDirectory,
      `${filePrefix}_state_${state}_pixel7.png`,
    ),
    fullPage: true,
    animations: "disabled",
  });
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("/admin/offline redirects before the admin layout renders", async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "The canonical recovery redirect is verified once on the governed browser profile.",
  );

  await page.goto("/admin/offline?source=legacy", {
    waitUntil: "domcontentloaded",
  });
  await expect(page).toHaveURL(/\/admin-offline\?source=legacy$/);
  await expect(
    page.getByRole("heading", {
      name: /admin data needs a live connection/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /secure sign in/i }),
  ).toHaveCount(0);
});

for (const route of recoveryRoutes) {
  test(`${route.path} proves all seven applicable recovery states`, async ({
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
    let primary = await openRecovery(page, route);

    expect(
      await page.locator(".recovery-title").evaluate((element) => {
        return getComputedStyle(element).color;
      }),
    ).toBe("rgb(246, 248, 252)");
    await capture(page, route.filePrefix, "dark_dark");

    const axeResults = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    expect(
      axeResults.violations.filter(
        (violation) =>
          violation.impact === "critical" || violation.impact === "serious",
      ),
    ).toHaveLength(0);

    await context.setOffline(true);
    await page.evaluate(() => window.dispatchEvent(new Event("offline")));
    await expect(page.getByRole("status")).toContainText(/offline/i);
    await capture(page, route.filePrefix, "offline_dark");
    await context.setOffline(false);

    await primary.focus();
    await expect(primary).toBeFocused();
    expect(
      await primary.evaluate((element) => getComputedStyle(element).outlineStyle),
    ).not.toBe("none");
    await capture(page, route.filePrefix, "focused_dark");

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
    await capture(page, route.filePrefix, "pressed_dark");
    await page.mouse.move(1, 1);
    await page.mouse.up();

    primary = await openRecovery(page, route);
    await page.addStyleTag({
      content: "html { font-size: 200% !important; }",
    });
    await expect(
      page.getByRole("heading", { name: route.heading }),
    ).toBeVisible();
    const horizontalOverflow = await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    );
    expect(horizontalOverflow).toBeLessThanOrEqual(1);
    await capture(page, route.filePrefix, "large_text_dark");

    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "reduce",
    });
    primary = await openRecovery(page, route);
    const reducedDurations = await primary.evaluate((element) =>
      getComputedStyle(element)
        .transitionDuration.split(",")
        .map((duration) => Number.parseFloat(duration)),
    );
    expect(Math.max(...reducedDurations)).toBeLessThanOrEqual(0.001);
    await capture(page, route.filePrefix, "reduced_motion_dark");

    await page.emulateMedia({
      colorScheme: "light",
      reducedMotion: "no-preference",
    });
    await openRecovery(page, route);
    expect(
      await page.locator(".recovery-title").evaluate((element) => {
        return getComputedStyle(element).color;
      }),
    ).toBe("rgb(13, 22, 39)");
    await capture(page, route.filePrefix, "light_light");
  });
}
