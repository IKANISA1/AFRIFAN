import { localClubId } from "./fixtures/local-route-assertions.mjs";
import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

let evidenceDirectory: string;

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
  await navigateStateEvidence(page, route.path, { waitUntil: "domcontentloaded" });
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
  await captureStateScreenshot(page, {
    path: path.join(
      evidenceDirectory,
      `${filePrefix}_state_${state}_viewport.png`,
    ),
    fullPage: true,
    animations: "disabled",
  });
}

test.beforeEach(async ({ browser }, testInfo) => {
  if (testInfo.title === "/admin/offline redirects before the admin layout renders") return;
  test.setTimeout(360_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_recovery_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.title === "/admin/offline redirects before the admin layout renders") return;
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

test("/admin/offline redirects before the admin layout renders", async ({
  page,
}) => {

  await navigateStateEvidence(page, "/admin/offline?source=legacy", {
    waitUntil: "domcontentloaded",
  });
  await expect(page).toHaveURL((url) =>
    url.pathname === "/admin-offline" &&
    url.searchParams.get("source") === "legacy" &&
    url.searchParams.get("club") === String(localClubId()),
  );
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
  }) => {

    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    let primary = await openRecovery(page, route);

    expect(
      await page.locator(".recovery-title").evaluate((element) => {
        return getComputedStyle(element).color;
      }),
    ).toBe("rgb(244, 244, 244)");
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
    await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
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
    ).toBe("rgb(25, 28, 31)");
    await capture(page, route.filePrefix, "light_light");
    const states = ["dark", "offline", "focused", "pressed", "large_text", "reduced_motion", "light"];
    fs.writeFileSync(path.join(evidenceDirectory, `${route.filePrefix}-state-evidence.json`), JSON.stringify({
      schema_version: "1.0", route: route.path,
      surface: route.path === "/admin-offline" ? "admin_pwa" : "consumer_web",
      applicable_states: states,
      not_applicable_states: ["loading", "empty", "error", "permission_denied", "disabled", "selected", "syncing", "conflict", "security_timeout"],
      not_applicable_rationale: "This standalone recovery document owns navigation links and online/offline status; it does not fetch protected collections or submit mutations. Applicability remains subject to review.",
      assertions: { visible_recovery_action: true, minimum_action_height: 48, horizontal_overflow_at_200_percent: false },
      captures: states.map((state) => ({ state, file: `${route.filePrefix}_state_${state}_${state === "light" ? "light" : "dark"}_viewport.png` })),
    }, null, 2));
  });
}
