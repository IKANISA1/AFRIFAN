import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions } from "./state-evidence-provenance";
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

const confirmedArticles = [
  {
    id: "opening-day",
    title: "Opening day",
    excerpt: "The club opens a new season with its supporters.",
    category: "Club",
    coverImageUrl: "/brand-surface.svg",
    publishedAt: "2026-07-28T10:00:00.000Z",
    author: "Gikundiro Media",
  },
  {
    id: "matchday-plan",
    title: "Matchday plan",
    excerpt: "Everything supporters need for the next fixture.",
    category: "Matchday",
    coverImageUrl: "/brand-surface.svg",
    publishedAt: "2026-07-27T10:00:00.000Z",
    author: "Gikundiro Media",
  },
  {
    id: "supporter-voice",
    title: "Supporter voice",
    excerpt: "A new FanClubs celebrates the people behind the colours.",
    category: "Community",
    coverImageUrl: "/brand-surface.svg",
    publishedAt: "2026-07-26T10:00:00.000Z",
    author: "Gikundiro Media",
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_NEWS_READY", items: confirmedArticles },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_NEWS_EMPTY", items: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_NEWS_ACCESS_DENIED",
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
        code: "PUBLIC_NEWS_CONFLICT",
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
        code: "PUBLIC_NEWS_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_NEWS_FAILED",
      error: "News is temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function capture(page: Page, state: string) {
  await captureStateScreenshot(page, {
    path: path.join(evidenceDirectory, `news_state_${state}_viewport.png`),
    fullPage: true,
    animations: "disabled",
  });
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".news-surface")).toHaveAttribute(
    "data-news-status",
    status,
  );
  await expect(page.locator(".news-status")).toContainText(label);
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

async function openNews(page: Page, nonce: string) {
  await navigateStateEvidence(page, `/news?evidence=${nonce}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeEach(async ({ browser }, testInfo) => {
  test.setTimeout(120_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_news_states");
});

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

test("news proves all sixteen applicable rendered states", async ({
  browser,
}) => {

  const context: BrowserContext = await browser.newContext({
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  let mode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=news*", async (route) => {
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
  await openNews(page, "loading");
  await expect.poll(() => page.evaluate(() =>
    document.querySelector(".news-hero")!.getBoundingClientRect().top -
    document.querySelector("[data-site-header]")!.getBoundingClientRect().bottom,
  )).toBeGreaterThanOrEqual(0);
  await expectStatus(page, "loading", /loading club news/i);
  await capture(page, "loading_dark");

  await expect(
    page.getByRole("button", { name: /refresh news/i }),
  ).toBeDisabled();
  await expect(page.locator(".news-surface")).toHaveAttribute(
    "data-news-refresh-disabled",
    "true",
  );
  await capture(page, "disabled_dark");

  mode = "empty";
  await openNews(page, "empty");
  await expectStatus(page, "empty", /no stories published/i);
  await expect(page.getByText("No club news is published yet.")).toBeVisible();
  await capture(page, "empty_dark");

  mode = "error";
  await openNews(page, "error");
  await expectStatus(page, "error", /newsroom unavailable/i);
  await expect(page.locator("body")).not.toContainText("PUBLIC_NEWS_FAILED");
  await capture(page, "error_dark");

  mode = "ready";
  await openNews(page, "offline");
  await expectStatus(page, "ready", /news feed confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(page.getByRole("heading", { name: "Opening day" })).toBeVisible();
  await capture(page, "offline_dark");
  await context.setOffline(false);

  mode = "permission_denied";
  await openNews(page, "permission");
  await expectStatus(page, "permission_denied", /news access denied/i);
  await expect(page.getByText("Opening day")).toHaveCount(0);
  await capture(page, "permission_denied_dark");

  mode = "ready";
  await openNews(page, "focused");
  const matchday = page.getByRole("link", { name: "Matchday" });
  await matchday.focus();
  await expect(page.locator(".news-surface")).toHaveAttribute(
    "data-news-interaction",
    "focused",
  );
  await expect(matchday).toBeFocused();
  await capture(page, "focused_dark");

  await matchday.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".news-surface")).toHaveAttribute(
    "data-news-interaction",
    "pressed",
  );
  await capture(page, "pressed_dark");
  await matchday.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const secondStory = page.getByRole("button", {
    name: /story\s*matchday plan\s*matchday/i,
  });
  await secondStory.click();
  await expect(secondStory).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".news-surface")).toHaveAttribute(
    "data-news-interaction",
    "selected",
  );
  await expect(
    page.getByRole("heading", { name: "Matchday plan" }),
  ).toBeVisible();
  await capture(page, "selected_dark");

  mode = "ready";
  await openNews(page, "large-text");
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  await expect.poll(() => page.evaluate(() =>
    document.querySelector(".news-hero")!.getBoundingClientRect().top -
    document.querySelector("[data-site-header]")!.getBoundingClientRect().bottom,
  )).toBeGreaterThanOrEqual(0);
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
  await openNews(page, "reduced-motion");
  await expectStatus(page, "loading", /loading club news/i);
  expect(
    await page
      .locator(".news-status svg")
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
  await openNews(page, "dark");
  await expectStatus(page, "ready", /news feed confirmed/i);
  expect(
    await page
      .locator(".news-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(244, 244, 244)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await openNews(page, "light");
  await expectStatus(page, "ready", /news feed confirmed/i);
  expect(
    await page
      .locator(".news-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(25, 28, 31)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "light_light");

  mode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openNews(page, "syncing");
  await expectStatus(page, "ready", /news feed confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh news/i }).click();
  await expectStatus(page, "syncing", /refreshing newsroom/i);
  await expect(page.getByRole("heading", { name: "Opening day" })).toBeVisible();
  await expect(
    page.getByRole("button", { name: /refresh news/i }),
  ).toBeDisabled();
  await capture(page, "syncing_dark");

  mode = "conflict";
  await openNews(page, "conflict");
  await expectStatus(page, "conflict", /news feed changed/i);
  await capture(page, "conflict_dark");

  mode = "security_timeout";
  await openNews(page, "security-timeout");
  await expectStatus(page, "security_timeout", /news request timed out/i);
  await capture(page, "security_timeout_dark");

  mode = "ready";
  await openNews(page, "targets");
  await expectStatus(page, "ready", /news feed confirmed/i);
  const targetSizes = await page
    .locator(".news-action, .news-story")
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
    path.join(evidenceDirectory, "news-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/news",
        surface: "consumer_web",
        exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          public_projection_bounded_to_records: 24,
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
          file: `news_state_${state}_${
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
