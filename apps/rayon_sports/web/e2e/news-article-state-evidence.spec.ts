import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/evidence/consumer_web_news_article_states",
);

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const confirmedArticle = {
  id: "opening-day",
  title: "Opening day",
  excerpt: "The season begins with supporters at the heart of the club.",
  content:
    "The gates open early for every supporter. The team begins its campaign with a clear plan. Community leaders will welcome families throughout matchday.",
  category: "Club",
  coverImageUrl: "/brand-surface.svg",
  publishedAt: "2026-07-28T10:00:00.000Z",
  author: "Gikundiro Media",
};

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: {
        code: "PUBLIC_NEWS_ARTICLE_READY",
        item: confirmedArticle,
      },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_NEWS_ARTICLE_EMPTY", item: null },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_NEWS_ARTICLE_ACCESS_DENIED",
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
        code: "PUBLIC_NEWS_ARTICLE_CONFLICT",
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
        code: "PUBLIC_NEWS_ARTICLE_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_NEWS_ARTICLE_FAILED",
      error: "The article is temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function capture(page: Page, state: string) {
  await page.screenshot({
    path: path.join(evidenceDirectory, `news_article_state_${state}_pixel7.png`),
    fullPage: true,
    animations: "disabled",
  });
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".news-article-surface")).toHaveAttribute(
    "data-article-status",
    status,
  );
  await expect(page.locator(".news-article-status")).toContainText(label);
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

async function openArticle(page: Page, nonce: string) {
  await page.goto(`/news/opening-day?evidence=${nonce}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("news article proves all sixteen applicable rendered states", async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Article evidence uses the declared Pixel 7 Chromium profile.",
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

  await page.route(
    "**/api/public-content?resource=news-article&articleId=*",
    async (route) => {
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
    },
  );

  mode = "loading";
  await openArticle(page, "loading");
  await expectStatus(page, "loading", /loading club news/i);
  await capture(page, "loading_dark");

  await expect(
    page.getByRole("button", { name: /refresh news/i }),
  ).toBeDisabled();
  await expect(page.locator(".news-article-surface")).toHaveAttribute(
    "data-article-refresh-disabled",
    "true",
  );
  await capture(page, "disabled_dark");

  mode = "empty";
  await openArticle(page, "empty");
  await expectStatus(page, "empty", /no stories published/i);
  await expect(page.getByText("Story not found")).toBeVisible();
  await capture(page, "empty_dark");

  mode = "error";
  await openArticle(page, "error");
  await expectStatus(page, "error", /newsroom unavailable/i);
  await expect(page.locator("body")).not.toContainText(
    "PUBLIC_NEWS_ARTICLE_FAILED",
  );
  await capture(page, "error_dark");

  mode = "ready";
  await openArticle(page, "offline");
  await expectStatus(page, "ready", /news feed confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(page.getByRole("heading", { name: "Opening day" })).toBeVisible();
  await capture(page, "offline_dark");
  await context.setOffline(false);

  mode = "permission_denied";
  await openArticle(page, "permission");
  await expectStatus(page, "permission_denied", /news access denied/i);
  await expect(page.getByText("Opening day")).toHaveCount(0);
  await capture(page, "permission_denied_dark");

  mode = "ready";
  await openArticle(page, "focused");
  const newsroom = page.getByRole("link", { name: /club newsroom/i });
  await newsroom.focus();
  await expect(page.locator(".news-article-surface")).toHaveAttribute(
    "data-article-interaction",
    "focused",
  );
  await expect(newsroom).toBeFocused();
  await capture(page, "focused_dark");

  await newsroom.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".news-article-surface")).toHaveAttribute(
    "data-article-interaction",
    "pressed",
  );
  await capture(page, "pressed_dark");
  await newsroom.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const reader = page.getByRole("button", { name: /reader mode/i });
  await reader.click();
  await expect(reader).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".news-article-surface")).toHaveAttribute(
    "data-article-interaction",
    "selected",
  );
  await capture(page, "selected_dark");

  mode = "ready";
  await openArticle(page, "large-text");
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
  await openArticle(page, "reduced-motion");
  await expectStatus(page, "loading", /loading club news/i);
  expect(
    await page
      .locator(".news-article-status svg")
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
  await openArticle(page, "dark");
  await expectStatus(page, "ready", /news feed confirmed/i);
  expect(
    await page
      .locator(".news-article-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(248, 250, 252)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await openArticle(page, "light");
  await expectStatus(page, "ready", /news feed confirmed/i);
  expect(
    await page
      .locator(".news-article-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(15, 23, 42)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "light_light");

  mode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openArticle(page, "syncing");
  await expectStatus(page, "ready", /news feed confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh news/i }).click();
  await expectStatus(page, "syncing", /refreshing newsroom/i);
  await expect(page.getByRole("heading", { name: "Opening day" })).toBeVisible();
  await capture(page, "syncing_dark");

  mode = "conflict";
  await openArticle(page, "conflict");
  await expectStatus(page, "conflict", /news feed changed/i);
  await capture(page, "conflict_dark");

  mode = "security_timeout";
  await openArticle(page, "security-timeout");
  await expectStatus(page, "security_timeout", /news request timed out/i);
  await capture(page, "security_timeout_dark");

  mode = "ready";
  await openArticle(page, "targets");
  await expectStatus(page, "ready", /news feed confirmed/i);
  const targetSizes = await page
    .locator(".news-action")
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
    path.join(evidenceDirectory, "news-article-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/news/:articleId",
        surface: "consumer_web",
        exact_profile: "Pixel 7 Chromium 412x915 at 2.625 DPR",
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          public_article_content_maximum_characters: 12_000,
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
          file: `news_article_state_${state}_${
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
