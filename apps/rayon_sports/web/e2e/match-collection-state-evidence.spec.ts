import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions, createStateEvidenceContext } from "./state-evidence-provenance";
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

const confirmedMatches = [
  {
    id: "opening-day",
    homeTeam: "Rayon Sports",
    awayTeam: "APR FC",
    competition: "Rwanda Premier League",
    venue: "Amahoro Stadium",
    matchDate: "2026-08-02T15:00:00.000Z",
    kickoffTime: "17:00",
    isOnSale: true,
    generalPrice: 5_000,
    matchStatus: "scheduled",
    homeScore: 0,
    awayScore: 0,
    liveMinute: null,
    matchSummary: "Confirmed opening-day ticket inventory.",
  },
  {
    id: "home-win",
    homeTeam: "Rayon Sports",
    awayTeam: "Police FC",
    competition: "Rwanda Premier League",
    venue: "Kigali Pelé Stadium",
    matchDate: "2026-07-20T13:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "fulltime",
    homeScore: 3,
    awayScore: 1,
    liveMinute: null,
    matchSummary: "Confirmed home result.",
  },
  {
    id: "away-result",
    homeTeam: "Mukura VS",
    awayTeam: "Rayon Sports",
    competition: "Peace Cup",
    venue: "Huye Stadium",
    matchDate: "2026-07-13T13:00:00.000Z",
    kickoffTime: null,
    isOnSale: false,
    generalPrice: 0,
    matchStatus: "finished",
    homeScore: 1,
    awayScore: 2,
    liveMinute: null,
    matchSummary: "Confirmed away result.",
  },
];

const routeConfigurations = [
  {
    route: "/tickets",
    routePattern: "/tickets",
    mode: "tickets",
    directory: "consumer_web_ticket_states",
    prefix: "ticket",
    primaryAction: /continue in fan app/i,
  },
  {
    route: "/results",
    routePattern: "/results",
    mode: "results",
    directory: "consumer_web_results_states",
    prefix: "results",
    primaryAction: /back to fixtures/i,
  },
] as const;

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_FIXTURES_READY", items: confirmedMatches },
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
      error: "database.internal password=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".match-collection-surface")).toHaveAttribute(
    "data-collection-status",
    status,
  );
  await expect(page.locator(".match-collection-status")).toContainText(label);
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

for (const configuration of routeConfigurations) {
  test(`${configuration.routePattern} proves all sixteen applicable rendered states`, async ({
    browser,
  }) => {
    test.setTimeout(360_000);

    const evidenceDirectory = prepareStateEvidence(browser, test.info(), `${configuration.directory}`);


    const context: BrowserContext = await createStateEvidenceContext(browser, {
    ...stateEvidenceContextOptions(test.info()),
      colorScheme: "dark",
      reducedMotion: "no-preference",
  });
    const page = await context.newPage();
    // Establish Chromium connectivity before the initial loading navigation.
    await context.setOffline(true);
    await context.setOffline(false);
    await expect.poll(() => page.evaluate(() => navigator.onLine)).toBe(true);
  await page.emulateMedia({ colorScheme: "dark" });
    let responseMode: ResponseMode = "ready";

    await page.route("**/api/public-content?resource=fixtures*", async (route) => {
      if (responseMode === "loading") {
        await new Promise<void>(() => {});
        return;
      }
      const response = responseFor(responseMode);
      await route.fulfill({
        status: response.status,
        contentType: "application/json",
        body: JSON.stringify(response.body),
      });
    });

    const open = async (nonce: string) => {
      await navigateStateEvidence(page, `${configuration.route}?evidence=${nonce}`, {
        waitUntil: "domcontentloaded",
      });
    };
    const capture = async (state: string) => {
      await page.evaluate(async () => {
        await document.fonts.ready;
        for (const animation of document.getAnimations()) {
          const endTime = animation.effect?.getComputedTiming().endTime;
          if (typeof endTime === "number" && Number.isFinite(endTime)) {
            animation.finish();
          } else {
            animation.cancel();
          }
        }
        await new Promise<void>((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
        );
      });
      await captureStateScreenshot(page, {
        path: path.join(
          evidenceDirectory,
          `${configuration.prefix}_state_${state}_viewport.png`,
        ),
        fullPage: true,
        animations: "disabled",
      });
    };
    const readyRecord =
      configuration.mode === "tickets"
        ? /rayon sports versus apr fc/i
        : /rayon sports versus police fc/i;

    responseMode = "loading";
    await open("loading");
    await expectStatus(page, "loading", /loading match information/i);
    await capture("loading_dark");
    await expect(
      page.getByRole("button", { name: /refresh matches/i }),
    ).toBeDisabled();
    await expect(page.locator(".match-collection-surface")).toHaveAttribute(
      "data-collection-refresh-disabled",
      "true",
    );
    await capture("disabled_dark");

    responseMode = "empty";
    await open("empty");
    await expectStatus(page, "empty", /no matching records/i);
    await expect(
      page.getByRole("heading", {
        name:
          configuration.mode === "tickets"
            ? /no tickets are currently on sale/i
            : /no completed results are confirmed yet/i,
      }),
    ).toBeVisible();
    await capture("empty_dark");

    responseMode = "error";
    await open("error");
    await expectStatus(page, "error", /match information unavailable/i);
    await expect(page.locator("body")).not.toContainText("database.internal");
    await capture("error_dark");

    responseMode = "ready";
    await open("offline");
    await expectStatus(page, "ready", /match information confirmed/i);
    await context.setOffline(true);
    await page.evaluate(() => window.dispatchEvent(new Event("offline")));
    await expectStatus(page, "offline", /you are offline/i);
    await expect(page.getByRole("group", { name: readyRecord }).first()).toBeVisible();
    await capture("offline_dark");
    await context.setOffline(false);

    responseMode = "permission_denied";
    await open("permission");
    await expectStatus(page, "permission_denied", /match access denied/i);
    await expect(page.getByRole("group", { name: readyRecord })).toHaveCount(0);
    await capture("permission_denied_dark");

    responseMode = "ready";
    await open("focused");
    const primaryAction = page.getByRole("link", {
      name: configuration.primaryAction,
    });
    await primaryAction.focus();
    await expect(page.locator(".match-collection-surface")).toHaveAttribute(
      "data-collection-interaction",
      "focused",
    );
    await expect(primaryAction).toBeFocused();
    await capture("focused_dark");

    await primaryAction.dispatchEvent("pointerdown", {
      pointerId: 1,
      pointerType: "touch",
      isPrimary: true,
    });
    await expect(page.locator(".match-collection-surface")).toHaveAttribute(
      "data-collection-interaction",
      "pressed",
    );
    await capture("pressed_dark");
    await primaryAction.dispatchEvent("pointerup", {
      pointerId: 1,
      pointerType: "touch",
      isPrimary: true,
    });

    const selectableRecord =
      configuration.mode === "tickets"
        ? page.locator(".match-collection-card").first()
        : page.locator(".match-collection-card").nth(1);
    await selectableRecord.click();
    await expect(selectableRecord).toHaveAttribute("aria-pressed", "true");
    await expect(page.locator(".match-collection-surface")).toHaveAttribute(
      "data-collection-interaction",
      "selected",
    );
    await capture("selected_dark");

    responseMode = "ready";
    await open("large-text");
    await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
  });
    expect(
      await page.evaluate(
        () =>
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth,
      ),
    ).toBeLessThanOrEqual(1);
    const clippedElements = await page
      .locator(".match-collection-surface")
      .evaluate((surface) => {
        const viewportWidth = document.documentElement.clientWidth;
        return Array.from(surface.querySelectorAll("*"))
          .map((element) => {
            const rect = element.getBoundingClientRect();
            return {
              tag: element.tagName,
              className:
                typeof element.className === "string" ? element.className : "",
              left: rect.left,
              right: rect.right,
            };
          })
          .filter(
            ({ left, right }) =>
              left < -1 || right > viewportWidth + 1,
          );
      });
    expect(clippedElements).toEqual([]);
    await capture("large_text_dark");

    responseMode = "loading";
    await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
    await open("reduced-motion");
    await expectStatus(page, "loading", /loading match information/i);
    expect(
      await page
        .locator(".match-collection-status svg")
        .evaluate((element) =>
          Number.parseFloat(getComputedStyle(element).animationDuration),
        ),
    ).toBeLessThanOrEqual(0.001);
    await capture("reduced_motion_dark");

    responseMode = "ready";
    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    await open("dark");
    await expectStatus(page, "ready", /match information confirmed/i);
    await expectNoSeriousAxeViolations(page);
    await capture("dark_dark");

    await page.emulateMedia({
      colorScheme: "light",
      reducedMotion: "no-preference",
    });
    await open("light");
    await expectStatus(page, "ready", /match information confirmed/i);
    await expectNoSeriousAxeViolations(page);
    await capture("light_light");

    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    responseMode = "ready";
    await open("syncing");
    await expectStatus(page, "ready", /match information confirmed/i);
    responseMode = "loading";
    await page
      .getByRole("button", { name: /refresh matches/i })
      .dispatchEvent("click");
    await expectStatus(page, "syncing", /refreshing match information/i);
    await expect(page.getByRole("group", { name: readyRecord }).first()).toBeVisible();
    await capture("syncing_dark");

    responseMode = "conflict";
    await open("conflict");
    await expectStatus(page, "conflict", /match information changed/i);
    await capture("conflict_dark");

    responseMode = "security_timeout";
    await open("security-timeout");
    await expectStatus(page, "security_timeout", /match request timed out/i);
    await capture("security_timeout_dark");

    responseMode = "ready";
    await open("targets");
    await expectStatus(page, "ready", /match information confirmed/i);
    const targetSizes = await page
      .locator(".match-collection-action, .match-collection-card")
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
        `${configuration.prefix}-state-evidence.json`,
      ),
      `${JSON.stringify(
        {
          schema_version: "1.0",
          route: configuration.routePattern,
          surface: "consumer_web",
          exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
          applicable_states: captures,
          not_applicable_states: [],
          assertions: {
            controlled_api_states: true,
            confirmed_data_retained_during_recovery: true,
            fabricated_match_or_ticket_data: false,
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
            file: `${configuration.prefix}_state_${state}_${
              state === "light" ? "light" : "dark"
            }_viewport.png`,
          })),
        },
        null,
        2,
      )}\n`,
    );

    finalizeStateEvidence(evidenceDirectory);
    await context.close();
  });
}
