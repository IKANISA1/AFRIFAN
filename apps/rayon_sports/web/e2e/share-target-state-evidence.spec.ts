import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

let evidenceDirectory: string;

const populatedRoute =
  "/share-target?title=Official%20match%20report" +
  "&text=Review%20the%20confirmed%20club%20update" +
  "&url=https%3A%2F%2Fexample.com%2Fclub%2Fofficial-report";

async function openShareTarget(page: Page, route = populatedRoute) {
  await navigateStateEvidence(page, route, { waitUntil: "domcontentloaded" });
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
  await captureStateScreenshot(page, {
    path: path.join(
      evidenceDirectory,
      `share_target_state_${state}_viewport.png`,
    ),
    fullPage: true,
    animations: "disabled",
  });
}

test.beforeEach(async ({ browser }, testInfo) => {
  test.setTimeout(360_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_share_target_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

test("share target proves nine rendered states including invalid URLs", async ({
  page,
  context,
}) => {

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
  ).toBe("rgb(244, 244, 244)");
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
  await capture(page, "invalid_dark");

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

  // Full-page captures can leave this link below the mobile viewport. Hover
  // scrolls the actual target into view before the pointer press is measured.
  await primary.hover();
  await page.mouse.down();
  await expect.poll(() =>
    primary.evaluate((element) => getComputedStyle(element).transform),
  ).not.toBe("none");
  await capture(page, "pressed_dark");
  await page.mouse.move(1, 1);
  await page.mouse.up();

  primary = await openShareTarget(page);
  await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
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
  ).toBe("rgb(25, 28, 31)");
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
  const states = ["dark", "invalid", "empty", "offline", "focused", "pressed", "large_text", "reduced_motion", "light"];
  fs.writeFileSync(path.join(evidenceDirectory, "share-target-state-evidence.json"), JSON.stringify({
    schema_version: "1.0", route: "/share-target", surface: "consumer_web",
    applicable_states: states,
    not_applicable_states: ["loading", "permission_denied", "disabled", "selected", "syncing", "conflict", "security_timeout"],
    not_applicable_rationale: "This read-only shared-content handoff parses the current URL and owns navigation links, with no authenticated mutation or remote submission. Applicability remains subject to review.",
    assertions: { unsafe_url_has_no_external_action: true, empty_payload_has_explicit_state: true, light_and_dark_axe_serious_or_critical: 0 },
    captures: states.map((state) => ({ state, file: `share_target_state_${state}_${state === "light" ? "light" : "dark"}_viewport.png` })),
  }, null, 2));
});
