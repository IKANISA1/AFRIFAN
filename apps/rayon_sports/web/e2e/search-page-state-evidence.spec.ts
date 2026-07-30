import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/implementation_goal_20260724/consumer_web_search_states",
);

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const confirmedItems = [
  {
    id: "fixture-next",
    title: "Next home fixture",
    description: "Kickoff details and ticket availability for the next league match.",
    href: "/fixtures",
    category: "Match",
    meta: "Saturday 18:00",
  },
  {
    id: "membership-plans",
    title: "Membership plans",
    description: "Compare supporter membership tiers and matchday benefits.",
    href: "/membership",
    category: "Membership",
    meta: "Three tiers",
  },
  {
    id: "club-news",
    title: "Club newsroom",
    description: "Official matchday and supporter updates.",
    href: "/news",
    category: "News",
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "SEARCH_INDEX_READY", items: confirmedItems },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "SEARCH_INDEX_EMPTY", items: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "SEARCH_INDEX_ACCESS_DENIED",
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
        code: "SEARCH_INDEX_CONFLICT",
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
        code: "SEARCH_INDEX_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "SEARCH_INDEX_FAILED",
      error: "Search is temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function capture(page: Page, state: string) {
  await page.screenshot({
    path: path.join(evidenceDirectory, `search_state_${state}_pixel7.png`),
    fullPage: true,
    animations: "disabled",
  });
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator("[data-search-page-status]")).toHaveAttribute(
    "data-search-page-status",
    status,
  );
  await expect(page.locator("[data-search-status]")).toContainText(label);
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

async function openSearch(page: Page, nonce: string) {
  await page.goto(`/search?evidence=${nonce}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("search proves all sixteen applicable rendered states", async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Search evidence uses the declared Pixel 7 Chromium profile.",
  );

  const context: BrowserContext = await browser.newContext({
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2.625,
    isMobile: true,
    hasTouch: true,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  let mode: ResponseMode = "ready";

  await page.route("**/api/search-index", async (route) => {
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
  await openSearch(page, "loading");
  await expectStatus(page, "loading", /loading search/i);
  await capture(page, "loading_dark");

  await expect(
    page.getByRole("button", { name: /refresh results/i }),
  ).toBeDisabled();
  await expect(page.locator("[data-search-refresh-disabled]")).toHaveAttribute(
    "data-search-refresh-disabled",
    "true",
  );
  await capture(page, "disabled_dark");

  mode = "empty";
  await openSearch(page, "empty");
  await expectStatus(page, "empty", /no results/i);
  await expect(page.getByText("Try fixtures, tickets, membership, Groups, or shop.")).toBeVisible();
  await capture(page, "empty_dark");

  mode = "error";
  await openSearch(page, "error");
  await expectStatus(page, "error", /search unavailable/i);
  await expect(page.locator("body")).not.toContainText("SEARCH_INDEX_FAILED");
  await capture(page, "error_dark");

  mode = "ready";
  await openSearch(page, "offline");
  await expectStatus(page, "ready", /search ready/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(page.getByText("Next home fixture")).toBeVisible();
  await capture(page, "offline_dark");
  await context.setOffline(false);

  mode = "permission_denied";
  await openSearch(page, "permission");
  await expectStatus(page, "permission_denied", /search access denied/i);
  await expect(page.getByText("Next home fixture")).toHaveCount(0);
  await capture(page, "permission_denied_dark");

  mode = "ready";
  await openSearch(page, "focused");
  const searchbox = page.getByRole("searchbox");
  await searchbox.focus();
  await expect(page.locator("[data-search-interaction]")).toHaveAttribute(
    "data-search-interaction",
    "focused",
  );
  await expect(searchbox).toBeFocused();
  await capture(page, "focused_dark");

  const submit = page.getByRole("button", { name: "Search", exact: true });
  await submit.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator("[data-search-interaction]")).toHaveAttribute(
    "data-search-interaction",
    "pressed",
  );
  await capture(page, "pressed_dark");
  await submit.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const membershipSuggestion = page.getByRole("button", {
    name: "Membership",
    exact: true,
  });
  await membershipSuggestion.click();
  await expect(membershipSuggestion).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator("[data-search-interaction]")).toHaveAttribute(
    "data-search-interaction",
    "selected",
  );
  await capture(page, "selected_dark");

  mode = "ready";
  await openSearch(page, "large-text");
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
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
  await openSearch(page, "reduced-motion");
  await expectStatus(page, "loading", /loading search/i);
  expect(
    await page
      .locator("[data-search-status] svg")
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
  await openSearch(page, "dark");
  await expectStatus(page, "ready", /search ready/i);
  expect(
    await page
      .locator("[data-search-page-status]")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(248, 250, 252)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await openSearch(page, "light");
  await expectStatus(page, "ready", /search ready/i);
  expect(
    await page
      .locator("[data-search-page-status]")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(15, 23, 42)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "light_light");

  mode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openSearch(page, "syncing");
  await expectStatus(page, "ready", /search ready/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh results/i }).click();
  await expectStatus(page, "syncing", /refreshing results/i);
  await expect(page.getByText("Next home fixture")).toBeVisible();
  await expect(
    page.getByRole("button", { name: /refresh results/i }),
  ).toBeDisabled();
  await capture(page, "syncing_dark");

  mode = "conflict";
  await openSearch(page, "conflict");
  await expectStatus(page, "conflict", /search index changed/i);
  await capture(page, "conflict_dark");

  mode = "security_timeout";
  await openSearch(page, "security-timeout");
  await expectStatus(page, "security_timeout", /search timed out/i);
  await capture(page, "security_timeout_dark");

  mode = "ready";
  await openSearch(page, "targets");
  const targetSizes = await page
    .locator(
      ".search-form button, .search-form input, .search-suggestions button",
    )
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
    path.join(evidenceDirectory, "search-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/search",
        surface: "consumer_web",
        exact_profile: "Pixel 7 Chromium 412x915 at 2.625 DPR",
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          unsafe_result_links_rejected_by_unit_test: true,
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
          file: `search_state_${state}_${
            state === "light" ? "light" : "dark"
          }_pixel7.png`,
        })),
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
});
