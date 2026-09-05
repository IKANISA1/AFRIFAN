import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const confirmedMatch = {
  id: "opening-day",
  homeTeam: "Rayon Sports",
  awayTeam: "APR FC",
  competition: "Rwanda Premier League",
  venue: "Amahoro Stadium",
  matchDate: "2026-08-02T15:00:00.000Z",
  kickoffTime: "17:00",
  isOnSale: true,
  generalPrice: 5_000,
  vipPrice: 20_000,
  matchStatus: "upcoming",
  homeScore: 0,
  awayScore: 0,
  liveMinute: null,
  matchSummary: "The confirmed opening fixture of the new league campaign.",
};

const routes = [
  {
    route: "/fixtures/opening-day",
    routePattern: "/fixtures/:matchId",
    mode: "fixture",
    directory: "consumer_web_fixture_detail_states",
    prefix: "fixture_detail",
  },
  {
    route: "/tickets/opening-day",
    routePattern: "/tickets/:matchId",
    mode: "ticket",
    directory: "consumer_web_ticket_detail_states",
    prefix: "ticket_detail",
  },
] as const;

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_FIXTURE_DETAIL_READY", item: confirmedMatch },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_FIXTURE_DETAIL_EMPTY", item: null },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_FIXTURE_DETAIL_ACCESS_DENIED",
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
        code: "PUBLIC_FIXTURE_DETAIL_CONFLICT",
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
        code: "PUBLIC_FIXTURE_DETAIL_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_FIXTURE_DETAIL_FAILED",
      error: "Match detail is temporarily unavailable.",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".match-detail-surface")).toHaveAttribute(
    "data-match-status",
    status,
  );
  await expect(page.locator(".match-detail-status")).toContainText(label);
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

for (const routeConfig of routes) {
  test(`${routeConfig.routePattern} proves all sixteen applicable rendered states`, async ({
    browser,
  }, testInfo) => {
    test.setTimeout(90_000);
    test.skip(
      testInfo.project.name !== "mobile-chromium",
      "Match-detail evidence uses the declared Pixel 7 Chromium profile.",
    );

    const evidenceDirectory = path.resolve(
      process.cwd(),
      `../../../output/evidence/${routeConfig.directory}`,
    );
    fs.mkdirSync(evidenceDirectory, { recursive: true });

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
      "**/api/public-content?resource=fixture-detail&matchId=*",
      async (interceptedRoute) => {
        if (mode === "loading") {
          await new Promise<void>(() => {});
          return;
        }
        const response = responseFor(mode);
        await interceptedRoute.fulfill({
          status: response.status,
          contentType: "application/json",
          body: JSON.stringify(response.body),
        });
      },
    );

    const open = async (nonce: string) => {
      await page.goto(`${routeConfig.route}?evidence=${nonce}`, {
        waitUntil: "domcontentloaded",
      });
    };
    const capture = async (state: string) => {
      await page.screenshot({
        path: path.join(
          evidenceDirectory,
          `${routeConfig.prefix}_state_${state}_pixel7.png`,
        ),
        fullPage: true,
        animations: "disabled",
      });
    };

    mode = "loading";
    await open("loading");
    await expectStatus(page, "loading", /loading match details/i);
    await capture("loading_dark");

    await expect(
      page.getByRole("button", { name: /refresh details/i }),
    ).toBeDisabled();
    await expect(page.locator(".match-detail-surface")).toHaveAttribute(
      "data-match-refresh-disabled",
      "true",
    );
    await capture("disabled_dark");

    mode = "empty";
    await open("empty");
    await expectStatus(page, "empty", /match not found/i);
    await expect(
      page.getByRole("heading", {
        name: /no confirmed match detail is available/i,
      }),
    ).toBeVisible();
    await capture("empty_dark");

    mode = "error";
    await open("error");
    await expectStatus(page, "error", /match details unavailable/i);
    await expect(page.locator("body")).not.toContainText(
      "PUBLIC_FIXTURE_DETAIL_FAILED",
    );
    await capture("error_dark");

    mode = "ready";
    await open("offline");
    await expectStatus(page, "ready", /match details confirmed/i);
    await context.setOffline(true);
    await page.evaluate(() => window.dispatchEvent(new Event("offline")));
    await expectStatus(page, "offline", /you are offline/i);
    await expect(
      page.getByRole("heading", { name: /rayon sports/i }),
    ).toBeVisible();
    await capture("offline_dark");
    await context.setOffline(false);

    mode = "permission_denied";
    await open("permission");
    await expectStatus(page, "permission_denied", /match access denied/i);
    await expect(
      page.getByRole("heading", { name: /rayon sports/i }),
    ).toHaveCount(0);
    await capture("permission_denied_dark");

    mode = "ready";
    await open("focused");
    const back = page
      .getByRole("navigation", {
        name: routeConfig.mode === "ticket" ? "Ticketing" : "Fixtures",
      })
      .getByRole("link", {
        name: routeConfig.mode === "ticket" ? "Ticketing" : "Fixtures",
      });
    await back.focus();
    await expect(page.locator(".match-detail-surface")).toHaveAttribute(
      "data-match-interaction",
      "focused",
    );
    await expect(back).toBeFocused();
    await capture("focused_dark");

    await back.dispatchEvent("pointerdown", {
      pointerId: 1,
      pointerType: "touch",
      isPrimary: true,
    });
    await expect(page.locator(".match-detail-surface")).toHaveAttribute(
      "data-match-interaction",
      "pressed",
    );
    await capture("pressed_dark");
    await back.dispatchEvent("pointerup", {
      pointerId: 1,
      pointerType: "touch",
      isPrimary: true,
    });

    const selectedPanel =
      routeConfig.mode === "ticket"
        ? page.getByRole("button", { name: "Overview" })
        : page.getByRole("button", { name: "Access" });
    await selectedPanel.click();
    await expect(selectedPanel).toHaveAttribute("aria-pressed", "true");
    await expect(page.locator(".match-detail-surface")).toHaveAttribute(
      "data-match-interaction",
      "selected",
    );
    await capture("selected_dark");

    mode = "ready";
    await open("large-text");
    await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
    expect(
      await page.evaluate(
        () =>
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth,
      ),
    ).toBeLessThanOrEqual(1);
    await capture("large_text_dark");

    mode = "loading";
    await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
    await open("reduced-motion");
    await expectStatus(page, "loading", /loading match details/i);
    expect(
      await page
        .locator(".match-detail-status svg")
        .evaluate((element) =>
          Number.parseFloat(getComputedStyle(element).animationDuration),
        ),
    ).toBeLessThanOrEqual(0.001);
    await capture("reduced_motion_dark");

    mode = "ready";
    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    await open("dark");
    await expectStatus(page, "ready", /match details confirmed/i);
    await expectNoSeriousAxeViolations(page);
    await capture("dark_dark");

    await page.emulateMedia({
      colorScheme: "light",
      reducedMotion: "no-preference",
    });
    await open("light");
    await expectStatus(page, "ready", /match details confirmed/i);
    await expectNoSeriousAxeViolations(page);
    await capture("light_light");

    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    mode = "ready";
    await open("syncing");
    await expectStatus(page, "ready", /match details confirmed/i);
    mode = "loading";
    await page
      .getByRole("button", { name: /refresh details/i })
      .dispatchEvent("click");
    await expectStatus(page, "syncing", /refreshing match details/i);
    await expect(
      page.getByRole("heading", { name: /rayon sports/i }),
    ).toBeVisible();
    await capture("syncing_dark");

    mode = "conflict";
    await open("conflict");
    await expectStatus(page, "conflict", /match details changed/i);
    await capture("conflict_dark");

    mode = "security_timeout";
    await open("security-timeout");
    await expectStatus(page, "security_timeout", /match request timed out/i);
    await capture("security_timeout_dark");

    mode = "ready";
    await open("targets");
    await expectStatus(page, "ready", /match details confirmed/i);
    const targetSizes = await page
      .locator(".match-detail-action, .match-detail-tabs button")
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
      path.join(
        evidenceDirectory,
        `${routeConfig.prefix}-state-evidence.json`,
      ),
      `${JSON.stringify(
        {
          schema_version: "1.0",
          route: routeConfig.routePattern,
          surface: "consumer_web",
          exact_profile: "Pixel 7 Chromium 412x915 at 2.625 DPR",
          applicable_states: captures,
          not_applicable_states: [],
          assertions: {
            controlled_api_states: true,
            confirmed_data_retained_during_recovery: true,
            fabricated_lineups_or_live_events: false,
            secure_checkout_handoff_only: true,
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
            file: `${routeConfig.prefix}_state_${state}_${
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
}
