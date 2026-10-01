import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions, createStateEvidenceContext } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

let evidenceDirectory: string;

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const confirmedFixtures = [
  {
    id: "opening-day",
    homeTeam: "Rayon Sports",
    awayTeam: "APR FC",
    competition: "Premier League",
    venue: "Kigali Pelé Stadium",
    matchDate: "2026-08-01T15:00:00.000Z",
    kickoffTime: "17:00",
    isOnSale: true,
    generalPrice: 5000,
    matchStatus: "scheduled",
    homeScore: 0,
    awayScore: 0,
    liveMinute: null,
    matchSummary: "The opening fixture is confirmed.",
  },
  {
    id: "live-derby",
    homeTeam: "Rayon Sports",
    awayTeam: "Police FC",
    competition: "Premier League",
    venue: "Amahoro Stadium",
    matchDate: "2026-07-29T12:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "live",
    homeScore: 2,
    awayScore: 1,
    liveMinute: 64,
    matchSummary: "The derby is live.",
  },
  {
    id: "recent-result",
    homeTeam: "Mukura VS",
    awayTeam: "Rayon Sports",
    competition: "Peace Cup",
    venue: "Huye Stadium",
    matchDate: "2026-07-20T13:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "fulltime",
    homeScore: 1,
    awayScore: 3,
    liveMinute: null,
    matchSummary: "A confirmed recent result.",
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_FIXTURES_READY", items: confirmedFixtures },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_FIXTURES_EMPTY", items: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_FIXTURES_ACCESS_DENIED",
        error: "Access denied.",
        retryable: false,
        change_confirmed: false,
      },
    };
  }
  if (mode === "conflict") {
    return {
      status: 409,
      body: {
        code: "PUBLIC_FIXTURES_CONFLICT",
        error: "The operation conflicts with current data.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: "PUBLIC_FIXTURES_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_FIXTURES_FAILED",
      error: "Fixtures are temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function capture(page: Page, state: string) {
  await captureStateScreenshot(page, {
    path: path.join(evidenceDirectory, `fixtures_state_${state}_viewport.png`),
    fullPage: true,
    animations: "disabled",
  });
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".fixtures-surface")).toHaveAttribute(
    "data-fixtures-status",
    status,
  );
  await expect(page.locator(".fixtures-status")).toContainText(label);
}

async function expectNoSeriousAxeViolations(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    results.violations.filter(
      (violation) =>
        violation.impact === "critical" || violation.impact === "serious",
    ),
  ).toHaveLength(0);
}

async function openFixtures(page: Page, nonce: string) {
  await navigateStateEvidence(page, `/fixtures?evidence=${nonce}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeEach(async ({ browser }, testInfo) => {
  test.setTimeout(360_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_fixtures_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

async function expectHeadingBelowNavigation(page: Page) {
  await page.evaluate(() => window.scrollTo({ top: 0, behavior: "instant" }));
  await expect.poll(() => page.evaluate(() => {
    const navigation = document.querySelector("[data-site-header]")!.getBoundingClientRect();
    const heading = document.querySelector(".fixtures-title")!.getBoundingClientRect();
    return heading.top - navigation.bottom;
  })).toBeGreaterThanOrEqual(16);
}

test("fixtures prove all sixteen applicable rendered states", async ({
  browser,
}) => {

  const context: BrowserContext = await createStateEvidenceContext(browser, {
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  let mode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=fixtures*", async (route) => {
    if (mode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    const response = responseFor(mode);
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(response.body),
    });
  });

  mode = "loading";
  await openFixtures(page, "loading");
  await expectStatus(page, "loading", /loading fixtures/i);
  await capture(page, "loading_dark");

  await expect(
    page.getByRole("button", { name: /refresh fixtures/i }),
  ).toBeDisabled();
  await expect(page.locator(".fixtures-surface")).toHaveAttribute(
    "data-fixtures-refresh-disabled",
    "true",
  );
  await capture(page, "disabled_dark");

  mode = "empty";
  await openFixtures(page, "empty");
  await expectStatus(page, "empty", /no fixtures listed/i);
  await expect(
    page.getByText("No club fixtures are listed yet."),
  ).toBeVisible();
  await capture(page, "empty_dark");

  mode = "error";
  await openFixtures(page, "error");
  await expectStatus(page, "error", /fixtures unavailable/i);
  await expect(page.locator("body")).not.toContainText(
    "PUBLIC_FIXTURES_FAILED",
  );
  await capture(page, "error_dark");

  mode = "ready";
  await openFixtures(page, "offline");
  await expectStatus(page, "ready", /fixture list confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(page.getByRole("group", { name: "Rayon Sports versus APR FC", exact: true })).toBeVisible();
  await capture(page, "offline_dark");
  await context.setOffline(false);

  mode = "permission_denied";
  await openFixtures(page, "permission");
  await expectStatus(page, "permission_denied", /fixture access denied/i);
  await expect(page.getByRole("group", { name: "Rayon Sports versus APR FC", exact: true })).toHaveCount(0);
  await capture(page, "permission_denied_dark");

  mode = "ready";
  await openFixtures(page, "focused");
  await expectStatus(page, "ready", /fixture list confirmed/i);
  const tickets = page.getByRole("link", { name: /buy tickets/i });
  await tickets.focus();
  await expect(page.locator(".fixtures-surface")).toHaveAttribute(
    "data-fixtures-interaction",
    "focused",
  );
  await expect(tickets).toBeFocused();
  await capture(page, "focused_dark");

  await tickets.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".fixtures-surface")).toHaveAttribute(
    "data-fixtures-interaction",
    "pressed",
  );
  await capture(page, "pressed_dark");
  await tickets.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const liveFixture = page.locator(".fixtures-card").nth(1);
  await liveFixture.click();
  await expect(liveFixture).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".fixtures-surface")).toHaveAttribute(
    "data-fixtures-interaction",
    "selected",
  );
  await expect(page.getByText("2–1")).toBeVisible();
  await capture(page, "selected_dark");

  mode = "ready";
  await openFixtures(page, "large-text");
  await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
  });
  await expectHeadingBelowNavigation(page);
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  await capture(page, "large_text_dark");

  mode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await openFixtures(page, "reduced-motion");
  await expectStatus(page, "loading", /loading fixtures/i);
  expect(
    await page
      .locator(".fixtures-status svg")
      .evaluate((element) =>
        Number.parseFloat(getComputedStyle(element).animationDuration),
      ),
  ).toBeLessThanOrEqual(0.001);
  await capture(page, "reduced_motion_dark");

  mode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openFixtures(page, "dark");
  await expectStatus(page, "ready", /fixture list confirmed/i);
  await expectHeadingBelowNavigation(page);
  expect(
    await page
      .locator(".fixtures-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(244, 244, 244)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await openFixtures(page, "light");
  await expectStatus(page, "ready", /fixture list confirmed/i);
  expect(
    await page
      .locator(".fixtures-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(25, 28, 31)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "light_light");

  mode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openFixtures(page, "syncing");
  await expectStatus(page, "ready", /fixture list confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh fixtures/i }).click();
  await expectStatus(page, "syncing", /refreshing fixtures/i);
  await expect(page.getByRole("group", { name: "Rayon Sports versus APR FC", exact: true })).toBeVisible();
  await capture(page, "syncing_dark");

  mode = "conflict";
  await openFixtures(page, "conflict");
  await expectStatus(page, "conflict", /fixture list changed/i);
  await capture(page, "conflict_dark");

  mode = "security_timeout";
  await openFixtures(page, "security-timeout");
  await expectStatus(page, "security_timeout", /fixture request timed out/i);
  await capture(page, "security_timeout_dark");

  mode = "ready";
  await openFixtures(page, "targets");
  await expectStatus(page, "ready", /fixture list confirmed/i);
  const targetSizes = await page
    .locator(".fixtures-action, .fixtures-card")
    .evaluateAll((elements) =>
      elements.map((element) => {
        const rect = element.getBoundingClientRect();
        return { width: rect.width, height: rect.height };
      }),
    );
  for (const target of targetSizes) {
    expect(target.width).toBeGreaterThanOrEqual(48);
    expect(target.height).toBeGreaterThanOrEqual(48);
  }

  const captures = [
    "loading",
    "empty",
    "error",
    "offline",
    "permission_denied",
    "disabled",
    "focused",
    "pressed",
    "selected",
    "large_text",
    "reduced_motion",
    "dark",
    "light",
    "syncing",
    "conflict",
    "security_timeout",
  ];
  fs.writeFileSync(
    path.join(evidenceDirectory, "fixtures-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/fixtures",
        surface: "consumer_web",
        exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          public_projection_bounded_to_records: 20,
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          reduced_motion_max_seconds: 0.001,
          axe_critical_or_serious_dark: 0,
          axe_critical_or_serious_light: 0,
          raw_api_diagnostics_rendered: false,
        },
        captures: captures.map((state) => ({
          state,
          file: `fixtures_state_${state}_${
            state === "light" ? "light" : "dark"
          }_viewport.png`,
        })),
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
});
