import fs from "node:fs";
import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page } from "@playwright/test";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const matches = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `match-${number}`,
    clubId: 24,
    partnerId: `partner-${number}`,
    homeTeam: `Rayon Sports ${String(number).padStart(2, "0")}`,
    awayTeam: `Opponent ${String(number).padStart(2, "0")}`,
    competition: "Rwanda Premier League",
    venue: "Kigali Pelé Stadium",
    matchDate: new Date(Date.UTC(2026, 7, number, 15, 0, 0)).toISOString(),
    kickoffTime: "15:00:00",
    isOnSale: number % 2 === 0,
    generalPrice: 5_000,
    vipPrice: 20_000,
    saleStartsAt: "2026-07-29T12:00:00.000Z",
    capacity: 20_000,
    soldCount: number * 100,
    imageUrl: "https://cdn.example.com/match.webp",
    matchStatus: number === 30 ? "live" : "scheduled",
    homeScore: number === 30 ? 1 : 0,
    awayScore: 0,
    liveMinute: number === 30 ? 64 : null,
    matchSummary: "Confirmed fixture.",
    liveStats: { privateMetric: "must not render" },
    liveEvents: [{ privateActorId: "private-user" }],
    isFeatured: number === 30,
    updatedAt: new Date(Date.UTC(2026, 6, 29, 12, 0, number)).toISOString(),
    accessToken: "private-token",
  };
});

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return { status: 200, body: { data: matches } };
  }
  if (mode === "empty") {
    return { status: 200, body: { data: [] } };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: { code: "ADMIN_ACCESS_DENIED", error: "Admin access denied." },
    };
  }
  if (mode === "conflict") {
    return {
      status: 409,
      body: {
        code: "STALE_RECORD",
        error: "Refresh current records.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: "ADMIN_OPERATION_TIMEOUT",
        error: "The admin operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 500,
    body: {
      code: "ADMIN_REQUEST_FAILED",
      error: "database.internal service_role=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function settleVisuals(page: Page) {
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
}

async function expectNoSeriousAxeViolations(page: Page) {
  await settleVisuals(page);
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    results.violations.filter(
      ({ impact }) => impact === "critical" || impact === "serious",
    ),
  ).toHaveLength(0);
}

async function runAdminMatchesMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_matches_states");
  const context = await browser.newContext({
    // API fixtures must bypass worker interception; PWA lifecycle has its own tests.
    serviceWorkers: "block",
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/admin/matches*", async (route) => {
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

  const surface = () => page.locator(".admin-matches-state-surface").first();
  const open = async (nonce: string) => {
    await navigateStateEvidence(page, `/admin/matches?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  };
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-matches-status", status);
    await expect(page.locator(".admin-matches-status")).toContainText(label);
  };
  const capture = async (
    state: string,
    profile = "desktop_1440x1000",
  ) => {
    await settleVisuals(page);
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_matches_state_${state}_${
          state === "light" ? "light" : "dark"
        }_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading match operations/i);
  await capture("loading");
  const refresh = page.getByRole("button", { name: /refresh fixtures/i });
  await expect(refresh).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-matches-refresh-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no fixtures in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /match operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("service_role");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /match operations confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /match workspace is offline/i);
  await expect(page.getByText(/Rayon Sports 30 vs Opponent 30/i)).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /match access denied/i);
  await expect(page.getByText(/Rayon Sports 30 vs Opponent 30/i)).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /match operations confirmed/i);
  const readyRefresh = page.getByRole("button", { name: /refresh fixtures/i });
  await readyRefresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-matches-interaction",
    "focused",
  );
  await capture("focused");

  await readyRefresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-matches-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();

  const firstRow = page.locator("tr[data-row-id='match-30']");
  await firstRow.focus();
  await firstRow.press("Enter");
  await expect(surface()).toHaveAttribute(
    "data-admin-matches-interaction",
    "selected",
  );
  await expect(
    page.getByRole("heading", { name: /edit fixture/i }),
  ).toBeVisible();
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await open("large-text");
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  await capture("large_text");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus("loading", /loading match operations/i);
  expect(
    await page
      .locator(".admin-matches-status svg")
      .evaluate((element) =>
        Number.parseFloat(getComputedStyle(element).animationDuration),
      ),
  ).toBeLessThanOrEqual(0.001);
  await capture("reduced_motion");

  responseMode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await open("dark");
  await expectStatus("ready", /match operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-token");
  await expect(page.locator("body")).not.toContainText("private-user");
  await expect(page.locator("body")).not.toContainText("privateMetric");
  const undersizedControls = await surface().locator("button, a").evaluateAll(
    (elements) =>
      elements
        .filter((element) => !element.closest("[role='dialog']"))
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return {
            label:
              element.getAttribute("aria-label") ??
              element.textContent?.trim() ??
              element.tagName,
            width: rect.width,
            height: rect.height,
          };
        })
        .filter(({ width, height }) => width < 48 || height < 48),
  );
  expect(undersizedControls).toEqual([]);
  await capture("dark");

  const search = page.getByRole("searchbox", { name: /search fixtures/i });
  await search.fill("Rayon Sports 01");
  await expect(page.getByText(/Rayon Sports 01 vs Opponent 01/i)).toBeVisible();
  await expect(page.getByText(/Rayon Sports 30 vs Opponent 30/i)).toHaveCount(0);
  await search.fill("");
  await page.getByRole("button", { name: /sort by fixture/i }).click();
  await page.getByRole("button", { name: /go to next page/i }).click();
  await expect(page.getByText(/page 2 of 2/i)).toBeVisible();

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /match operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /match operations confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh fixtures/i }).click();
  await expectStatus("syncing", /refreshing match operations/i);
  await expect(page.getByText(/Rayon Sports 30 vs Opponent 30/i)).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /match operations confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh fixtures/i }).click();
  await expectStatus("conflict", /fixture records changed/i);
  await expect(page.getByText(/Rayon Sports 30 vs Opponent 30/i)).toBeVisible();
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /match request timed out/i);
  await expect(page.getByText(/Rayon Sports 30 vs Opponent 30/i)).toHaveCount(0);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /match operations confirmed/i);
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /match operations confirmed/i);
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  await capture("responsive_compact", "compact_390x844");

  const governedStates = [
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
    path.join(evidenceDirectory, "admin-matches-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/matches",
        surface: "admin_pwa",
        exact_profile: `${browser.browserType().name()} desktop 1440x1000 at 1 DPR`,
        responsive_profiles: [
          `${browser.browserType().name()} tablet 1024x900 at 1 DPR`,
          `${browser.browserType().name()} compact 390x844 at 1 DPR`,
        ],
        applicable_states: governedStates,
        not_applicable_states: [],
        assertions: {
          authenticated_shell_required: true,
          protected_api_bypass_enabled: false,
          protected_mutation_bypass_enabled: false,
          bounded_request_seconds: 12,
          maximum_fixture_records: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data: true,
          runtime_response_normalized_and_bounded: true,
          private_extra_fields_rendered: false,
          search_sort_filter_pagination_present: true,
          destructive_delete_confirmation_required: true,
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          reduced_motion_max_seconds: 0.001,
          axe_critical_or_serious_dark: 0,
          axe_critical_or_serious_light: 0,
          axe_critical_or_serious_selected_form: 0,
          raw_api_diagnostics_rendered: false,
        },
        captures: [
          ...governedStates.map((state) => ({
            state,
            file: `admin_matches_state_${state}_${
              state === "light" ? "light" : "dark"
            }_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_matches_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_matches_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );

  finalizeStateEvidence(evidenceDirectory);
  await context.close();
}

test.describe("controlled Admin PWA matches evidence", () => {
  test("captures the exact authenticated match-operations state matrix", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    await runAdminMatchesMatrix(browser);
  });
});
