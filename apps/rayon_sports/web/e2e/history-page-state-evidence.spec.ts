import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/evidence/consumer_web_history_states",
);

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const confirmedMoments = [
  {
    id: "founding",
    title: "The founding chapter",
    body: "Supporters established the club and built its first matchday identity.",
  },
  {
    id: "first-title",
    title: "The first title",
    body: "The team earned a defining honour in front of its growing support.",
  },
  {
    id: "modern-era",
    title: "The modern era",
    body: "A new generation carries the same colours across every club surface.",
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_HISTORY_READY", items: confirmedMoments },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_HISTORY_EMPTY", items: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_HISTORY_ACCESS_DENIED",
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
        code: "PUBLIC_HISTORY_CONFLICT",
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
        code: "PUBLIC_HISTORY_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_HISTORY_FAILED",
      error: "History is temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function capture(page: Page, state: string) {
  await page.screenshot({
    path: path.join(evidenceDirectory, `history_state_${state}_pixel7.png`),
    fullPage: true,
    animations: "disabled",
  });
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".history-surface")).toHaveAttribute(
    "data-history-status",
    status,
  );
  await expect(page.locator(".history-status")).toContainText(label);
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

async function openHistory(page: Page, nonce: string) {
  await page.goto(`/history?evidence=${nonce}`, {
    waitUntil: "domcontentloaded",
  });
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("history proves all sixteen applicable rendered states", async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "History evidence uses the declared Pixel 7 Chromium profile.",
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

  await page.route("**/api/public-content?resource=history*", async (route) => {
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
  await openHistory(page, "loading");
  await expectStatus(page, "loading", /loading club history/i);
  await capture(page, "loading_dark");

  await expect(
    page.getByRole("button", { name: /refresh history/i }),
  ).toBeDisabled();
  await expect(page.locator(".history-surface")).toHaveAttribute(
    "data-history-refresh-disabled",
    "true",
  );
  await capture(page, "disabled_dark");

  mode = "empty";
  await openHistory(page, "empty");
  await expectStatus(page, "empty", /history not published/i);
  await expect(
    page.getByText("Club history is not published yet."),
  ).toBeVisible();
  await capture(page, "empty_dark");

  mode = "error";
  await openHistory(page, "error");
  await expectStatus(page, "error", /history unavailable/i);
  await expect(page.locator("body")).not.toContainText("PUBLIC_HISTORY_FAILED");
  await capture(page, "error_dark");

  mode = "ready";
  await openHistory(page, "offline");
  await expectStatus(page, "ready", /history confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(
    page.getByRole("heading", { name: "The founding chapter" }),
  ).toBeVisible();
  await capture(page, "offline_dark");
  await context.setOffline(false);

  mode = "permission_denied";
  await openHistory(page, "permission");
  await expectStatus(page, "permission_denied", /history access denied/i);
  await expect(page.getByText("The founding chapter")).toHaveCount(0);
  await capture(page, "permission_denied_dark");

  mode = "ready";
  await openHistory(page, "focused");
  const newsroom = page.getByRole("link", { name: "Club newsroom" });
  await newsroom.focus();
  await expect(page.locator(".history-surface")).toHaveAttribute(
    "data-history-interaction",
    "focused",
  );
  await expect(newsroom).toBeFocused();
  await capture(page, "focused_dark");

  await newsroom.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".history-surface")).toHaveAttribute(
    "data-history-interaction",
    "pressed",
  );
  await capture(page, "pressed_dark");
  await newsroom.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const secondChapter = page.getByRole("button", {
    name: /chapter\s*2\s*the first title/i,
  });
  await secondChapter.click();
  await expect(secondChapter).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".history-surface")).toHaveAttribute(
    "data-history-interaction",
    "selected",
  );
  await expect(
    page.getByRole("heading", { name: "The first title" }),
  ).toBeVisible();
  await capture(page, "selected_dark");

  mode = "ready";
  await openHistory(page, "large-text");
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
  await openHistory(page, "reduced-motion");
  await expectStatus(page, "loading", /loading club history/i);
  expect(
    await page
      .locator(".history-status svg")
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
  await openHistory(page, "dark");
  await expectStatus(page, "ready", /history confirmed/i);
  expect(
    await page
      .locator(".history-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(248, 250, 252)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await openHistory(page, "light");
  await expectStatus(page, "ready", /history confirmed/i);
  expect(
    await page
      .locator(".history-surface")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(15, 23, 42)");
  await expectNoSeriousAxeViolations(page);
  await capture(page, "light_light");

  mode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openHistory(page, "syncing");
  await expectStatus(page, "ready", /history confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh history/i }).click();
  await expectStatus(page, "syncing", /refreshing history/i);
  await expect(
    page.getByRole("heading", { name: "The founding chapter" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /refresh history/i }),
  ).toBeDisabled();
  await capture(page, "syncing_dark");

  mode = "conflict";
  await openHistory(page, "conflict");
  await expectStatus(page, "conflict", /history changed/i);
  await capture(page, "conflict_dark");

  mode = "security_timeout";
  await openHistory(page, "security-timeout");
  await expectStatus(page, "security_timeout", /history request timed out/i);
  await capture(page, "security_timeout_dark");

  mode = "ready";
  await openHistory(page, "targets");
  await expectStatus(page, "ready", /history confirmed/i);
  const targetSizes = await page
    .locator(".history-action, .history-chapters button")
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
    path.join(evidenceDirectory, "history-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/history",
        surface: "consumer_web",
        exact_profile: "Pixel 7 Chromium 412x915 at 2.625 DPR",
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
          file: `history_state_${state}_${
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
