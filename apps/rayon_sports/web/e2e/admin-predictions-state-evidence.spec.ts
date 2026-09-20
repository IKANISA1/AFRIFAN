import fs from "node:fs";
import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import {
  expect,
  test,
  type Browser,
  type Page,
  type Route,
} from "@playwright/test";
import {
  installEvidenceNavigationStability,
  primeEvidenceScreenshot,
  settleEvidenceVisuals,
} from "./evidence-navigation-stability";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const timestamp = "2026-07-30T09:00:00.000Z";

const markets = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `market-${number}`,
    slug: `verified-market-${number}`,
    name: `Verified prediction template ${number}`,
    shortName: `VPT ${number}`,
    marketGroup: "match_result",
    marketCategory: "result",
    betType: "single",
    difficultyTier: number % 2 === 0 ? "mid" : "entry",
    defaultFetValue: 100 + number,
    description: "Verified fixed-outcome prediction template.",
    isActive: number % 7 !== 0,
    leagueAvailability: ["RPL"],
    sortOrder: number,
    createdAt: timestamp,
    updatedAt: timestamp,
    private_formula: `private-market-${number}`,
  };
});

const competitions = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `competition-${number}`,
    slug: `verified-competition-${number}`,
    name: `Verified competition ${number}`,
    shortName: `VC ${number}`,
    competitionKind: number % 2 === 0 ? "cup" : "league",
    region: "Africa",
    countryCode: "RW",
    countryName: "Rwanda",
    isActive: number % 6 !== 0,
    createdAt: timestamp,
    updatedAt: timestamp,
    provider_secret: `private-competition-${number}`,
  };
});

const seasons = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `season-${number}`,
    competitionId: `competition-${number}`,
    competitionName: `Verified competition ${number}`,
    slug: `2026-27-${number}`,
    label: `2026/27 · ${number}`,
    yearStart: 2026,
    yearEnd: 2027,
    startsOn: "2026-08-01",
    endsOn: "2027-06-30",
    status: number % 5 === 0 ? "planned" : "active",
    isActive: number % 5 !== 0,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
});

const fixtures = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `fixture-${number}`,
    competitionName: `Verified competition ${number}`,
    seasonLabel: `2026/27 · ${number}`,
    roundName: `Round ${number}`,
    kickoffAt: new Date(Date.UTC(2026, 7, 15 + number, 16, 0)).toISOString(),
    venueName: "Kigali Pelé Stadium",
    homeTeamName: `Verified home team ${number}`,
    homeTeamShortName: `Home ${number}`,
    awayTeamName: `Verified away team ${number}`,
    awayTeamShortName: `Away ${number}`,
    homeScore: null,
    awayScore: null,
    status: "scheduled",
    updatedAt: timestamp,
    private_provider_payload: `private-fixture-${number}`,
  };
});

const partners = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `partner-${number}`,
    name: `Verified partner ${number}`,
    slug: `verified-partner-${number}`,
    category: number % 2 === 0 ? "mobility" : "matchday",
    private_contact: `private-partner-${number}@example.com`,
  };
});

const partnerPools = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `pool-${number}`,
    clubId: 24,
    partnerId: `partner-${number}`,
    partnerName: `Verified partner ${number}`,
    partnerSlug: `verified-partner-${number}`,
    initiativeId: null,
    fixtureId: `fixture-${number}`,
    title: `Verified derby pool ${number}`,
    predictionKind: "wdw",
    partnerStakeFet: 5_000 + number,
    fanEntryFet: 100,
    eligibilityMode: "partner_earn_required",
    status: "open",
    lockAt: new Date(Date.UTC(2026, 7, 15 + number, 15, 55)).toISOString(),
    totalEntries: number,
    totalFanEntryFet: number * 100,
    settlement: null,
    viewer_entry: { supporter_id: `private-supporter-${number}` },
    metadata: { accessToken: `private-pool-${number}` },
  };
});

const workspace = {
  markets,
  competitions,
  seasons,
  fixtures,
  partnerPools,
  partners,
};

async function settleVisuals(page: Page) {
  await settleEvidenceVisuals(page);
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

async function expectNoHorizontalOverflow(page: Page) {
  const result = await page.evaluate(() => {
    const clientWidth = document.documentElement.clientWidth;
    return {
      overflow: document.documentElement.scrollWidth - clientWidth,
      offenders: Array.from(document.querySelectorAll<HTMLElement>("body *"))
        .map((element) => ({
          tag: element.tagName.toLowerCase(),
          className: element.className.toString().slice(0, 120),
          right: Math.round(element.getBoundingClientRect().right),
          width: Math.round(element.getBoundingClientRect().width),
        }))
        .filter(({ right }) => right > clientWidth + 1)
        .slice(0, 12),
    };
  });
  expect(result.overflow, JSON.stringify(result.offenders)).toBeLessThanOrEqual(
    1,
  );
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_predictions_states");
  const context = await browser.newContext({
    // API fixtures must bypass worker interception; PWA lifecycle has its own tests.
    serviceWorkers: "block",
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await installEvidenceNavigationStability(context);
  let page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  let responseMode: ResponseMode = "ready";

  await context.route("**/api/admin/**", async (route: Route) => {
    if (route.request().method() !== "GET") {
      const requestUrl = route.request().url();
      const settled = requestUrl.includes("partner-prediction-pool-settlement");
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: settled
            ? {
                ...partnerPools[0],
                status: "settled",
                settlement: {
                  officialOutcome: "home_win",
                  logicalWinners: 4,
                  eligibleWinners: 4,
                  ineligibleWinners: 0,
                  totalPaidFet: 5_001,
                  totalRefundedFet: 0,
                  unawardedPartnerFet: 0,
                  settlementMode: "equal_split",
                  settledAt: timestamp,
                },
              }
            : requestUrl.includes("partner-prediction-pools")
              ? partnerPools[0]
              : "mutation-confirmed",
        }),
      });
      return;
    }
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    if (responseMode === "ready" || responseMode === "empty") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data:
            responseMode === "empty"
              ? {
                  markets: [],
                  competitions: [],
                  seasons: [],
                  fixtures: [],
                  partnerPools: [],
                  partners: [],
                }
              : workspace,
        }),
      });
      return;
    }
    const status =
      responseMode === "permission_denied"
        ? 403
        : responseMode === "conflict"
          ? 409
          : responseMode === "security_timeout"
            ? 504
            : 500;
    await route.fulfill({
      status,
      contentType: "application/json",
      body: JSON.stringify({
        error: "database.internal actor_email=private token=secret",
      }),
    });
  });

  const surface = () =>
    page.locator(".admin-predictions-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/predictions?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-predictions-status",
      status,
    );
    await expect(page.getByText(label).first()).toBeVisible();
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await page.evaluate(
      (shouldBlur) => {
        if (shouldBlur && document.activeElement instanceof HTMLElement) {
          document.activeElement.blur();
        }
        document.documentElement.style.scrollBehavior = "auto";
        document.body.style.scrollBehavior = "auto";
        window.scrollTo({ top: 0, left: 0, behavior: "auto" });
      },
      state === "selected" || state === "large_text",
    );
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0);
    await settleVisuals(page);
    await primeEvidenceScreenshot(page, !state.startsWith("responsive_"));
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_predictions_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading prediction operations/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh prediction operations/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no prediction records in this scope/i);
  await expect(
    page.getByRole("button", { name: /create WDW pool/i }),
  ).toBeDisabled();
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /prediction workspace unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /prediction workspace confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /prediction workspace is offline/i);
  await expect(
    page.getByText("Verified derby pool 10", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /create WDW pool/i }),
  ).toBeDisabled();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /prediction workspace confirmed/i);
  await page.getByLabel("Pool title").fill("Unsaved private pool draft");
  await page.getByLabel("Search partner prediction pools").fill("private");
  responseMode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh prediction operations/i })
    .click();
  await expectStatus("permission_denied", /prediction access denied/i);
  await expect(page.getByLabel("Pool title")).toHaveCount(0);
  await expect(page.getByLabel("Search partner prediction pools")).toHaveCount(
    0,
  );
  await expect(page.getByText("Unsaved private pool draft")).toHaveCount(0);
  await expect(
    page.getByText("Verified derby pool 10", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /prediction workspace confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh prediction operations/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-predictions-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-predictions-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();

  await page.getByRole("button", { name: "Templates" }).click();
  await expect(surface()).toHaveAttribute(
    "data-admin-predictions-interaction",
    "selected",
  );
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await page.evaluate(() => {
    document.documentElement.style.fontSize = "200%";
  });
  await expectNoHorizontalOverflow(page);
  await capture("large_text");
  await page.evaluate(() => {
    document.documentElement.style.fontSize = "";
  });

  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
  await open("reduced-motion");
  await expectStatus("ready", /prediction workspace confirmed/i);
  const longestMotionSeconds = await page.evaluate(
    () =>
      Math.max(
        0,
        ...document
          .getAnimations()
          .map(
            (animation) => Number(animation.effect?.getTiming().duration) || 0,
          ),
      ) / 1_000,
  );
  expect(longestMotionSeconds).toBeLessThanOrEqual(0.001);
  await capture("reduced_motion");

  await page.emulateMedia({
    reducedMotion: "no-preference",
    colorScheme: "dark",
  });
  await open("dark");
  await expectStatus("ready", /prediction workspace confirmed/i);
  await expectNoSeriousAxeViolations(page);
  for (const privateText of [
    "private-market",
    "private-competition",
    "private-fixture",
    "private-partner",
    "private-supporter",
    "private-pool",
  ]) {
    await expect(page.locator("body")).not.toContainText(privateText);
  }
  const undersized = await surface()
    .locator(
      "button:visible, input:not([type=checkbox]):not(.sr-only):visible, select:visible",
    )
    .evaluateAll((elements) =>
      elements
        .map((element) => element.getBoundingClientRect())
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await page.getByRole("button", { name: "Fixtures" }).click();
  const firstFixtureStatus = page
    .getByLabel(/change status for Home 1 versus Away 1/i)
    .first();
  await expect(
    firstFixtureStatus.locator('option[value="finished"]'),
  ).toHaveCount(1);
  await expect(
    firstFixtureStatus.locator('option[value="completed"]'),
  ).toHaveCount(0);
  await capture("dark");

  await page.getByRole("button", { name: "Partner Pools" }).click();
  let confirmation = "";
  page.once("dialog", async (dialog) => {
    confirmation = dialog.message();
    await dialog.dismiss();
  });
  await page.getByRole("button", { name: "Settle" }).first().click();
  expect(confirmation).toContain("Verified derby pool 1");
  expect(confirmation).toContain("This action cannot be undone.");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /prediction workspace confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /prediction workspace confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh prediction operations/i })
    .click();
  await expectStatus("syncing", /refreshing prediction operations/i);
  await expect(
    page.getByText("Verified derby pool 10", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /prediction workspace confirmed/i);
  responseMode = "conflict";
  await page
    .getByRole("button", { name: /refresh prediction operations/i })
    .click();
  await expectStatus("conflict", /prediction data changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /prediction request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /prediction workspace confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.close();
  page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /prediction workspace confirmed/i);
  await expectNoHorizontalOverflow(page);
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
    path.join(evidenceDirectory, "admin-predictions-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/predictions",
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
          maximum_catalog_records: 500,
          maximum_fixture_records: 500,
          maximum_partner_options: 500,
          maximum_partner_pool_records: 100,
          page_size: 25,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_options_filters_details_and_draft: true,
          strict_schema_owned_normalization: true,
          generated_identifiers_or_timestamps: false,
          private_metadata_rendered: false,
          raw_provider_diagnostics_rendered: false,
          destructive_settlement_confirmation_required: true,
          fixture_finished_status_matches_schema: true,
          global_catalog_mutations_require_platform_admin: true,
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          reduced_motion_max_seconds: 0.001,
          axe_critical_or_serious_dark: 0,
          axe_critical_or_serious_light: 0,
          axe_critical_or_serious_selected: 0,
        },
        captures: [
          ...governedStates.map((state) => ({
            state,
            file: `admin_predictions_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_predictions_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_predictions_state_responsive_compact_dark_compact_390x844.png",
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

test.describe("controlled Admin PWA prediction evidence", () => {
  test("captures the exact authenticated prediction state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
