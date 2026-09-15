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

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const sources = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `source-${number}`,
    clubId: number % 3 === 0 ? null : 24,
    sourceKey: `rwanda-league-${number}`,
    displayName: `Rwanda Premier League ${String(number).padStart(2, "0")}`,
    matchAliases: [`RPL ${number}`, `Rwanda League ${number}`],
    countryAliases: ["Rwanda"],
    externalCompetitionIds: [`rpl-${number}`],
    sourceUrls: [
      `https://www.livescore.com/en/football/rwanda/league-${number}/`,
    ],
    priority: number,
    isActive: number % 5 !== 0,
    updatedAt: new Date(Date.UTC(2026, 6, 29, 10, 0, number)).toISOString(),
    serviceRoleKey: "private-key",
    internalCrawlerNote: "private-note",
  };
});

const logs = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  const failed = number % 4 === 0;
  return {
    id: `log-${number}`,
    syncType: "livescore_web",
    status: failed ? "failed" : "completed",
    recordsFetched: 100 + number,
    recordsUpserted: 90 + number,
    webRequestsUsed: 5 + number,
    errorMessage: failed
      ? "database.internal actor_email=private token=secret"
      : null,
    startedAt: new Date(Date.UTC(2026, 6, 29, 12, 0, number)).toISOString(),
    completedAt: new Date(
      Date.UTC(2026, 6, 29, 12, 0, number, 500),
    ).toISOString(),
    metadata: { accessToken: "private-token" },
  };
});

const overview = {
  totalSources: 30,
  activeSources: 24,
  totalFixtures: 240,
  scheduledFixtures: 120,
  liveFixtures: 20,
  finishedFixtures: 100,
  totalTeams: 36,
  lastSyncAt: "2026-07-29T12:00:30.000Z",
  webRequestsToday: 615,
  errorsToday: 7,
  inspectedLogRowsToday: 30,
  internalBudget: "private-budget",
};

const emptyOverview = {
  totalSources: 0,
  activeSources: 0,
  totalFixtures: 0,
  scheduledFixtures: 0,
  liveFixtures: 0,
  finishedFixtures: 0,
  totalTeams: 0,
  lastSyncAt: null,
  webRequestsToday: 0,
  errorsToday: 0,
  inspectedLogRowsToday: 0,
};

function responseFor(mode: Exclude<ResponseMode, "loading">, data: unknown) {
  if (mode === "ready" || mode === "empty") {
    return { status: 200, body: { data } };
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
      error: "database.internal actor_email=private",
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

async function expectNoHorizontalOverflow(page: Page) {
  const result = await page.evaluate(() => {
    const viewportWidth = document.documentElement.clientWidth;
    const offenders = Array.from(
      document.querySelectorAll<HTMLElement>("body *"),
    )
      .flatMap((element) => {
        const rect = element.getBoundingClientRect();
        return rect.right <= viewportWidth + 1 && rect.left >= -1
          ? []
          : [
              {
                tag: element.tagName.toLowerCase(),
                className: element.className,
                left: Math.round(rect.left * 10) / 10,
                right: Math.round(rect.right * 10) / 10,
              },
            ];
      })
      .slice(0, 12);
    return {
      overflow:
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
      offenders,
    };
  });
  expect(
    result.overflow,
    `Horizontal overflow descendants: ${JSON.stringify(result.offenders)}`,
  ).toBeLessThanOrEqual(1);
}

async function runAdminFootballSyncMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_football_sync_states");
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  // Firefox requires page-level emulation for the initial document.
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "no-preference" });
  let responseMode: ResponseMode = "ready";

  const fulfillResource = async (
    route: Route,
    readyData: unknown,
    emptyData: unknown,
  ) => {
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    const response = responseFor(
      responseMode,
      responseMode === "empty" ? emptyData : readyData,
    );
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(response.body),
    });
  };

  await page.route("**/api/admin/football-sync-overview*", (route) =>
    fulfillResource(route, overview, emptyOverview),
  );
  await page.route("**/api/admin/livescore-sources*", (route) =>
    fulfillResource(route, sources, []),
  );
  await page.route("**/api/admin/football-sync-logs*", (route) =>
    fulfillResource(route, logs, []),
  );

  const surface = () =>
    page.locator(".admin-football-sync-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/football-sync?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-football-sync-status",
      status,
    );
    await expect(page.locator(".admin-football-sync-status")).toContainText(
      label,
    );
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await settleVisuals(page);
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_football_sync_state_${state}_${
          state === "light" ? "light" : "dark"
        }_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading football synchronization/i);
  await capture("loading");
  const refresh = page.getByRole("button", {
    name: /refresh football synchronization/i,
  });
  await expect(refresh).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-football-sync-refresh-disabled",
    "true",
  );
  await expect(surface()).toHaveAttribute(
    "data-admin-football-sync-mutation-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no synchronization records in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /football synchronization unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("actor_email");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /synchronization workspace is offline/i);
  await expect(page.getByText("24/30")).toBeVisible();
  await expect(surface()).toHaveAttribute(
    "data-admin-football-sync-mutation-disabled",
    "true",
  );
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await page.getByRole("tab", { name: /livescore sources/i }).click();
  await page
    .getByRole("button", { name: /edit Rwanda Premier League 01/i })
    .click();
  await page
    .getByRole("textbox", { name: /display name/i })
    .fill("Unsaved private draft");
  responseMode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh football synchronization/i })
    .evaluate((button: HTMLButtonElement) => button.click());
  await expectStatus("permission_denied", /synchronization access denied/i);
  await expect(page.getByText("Rwanda Premier League 01")).toHaveCount(0);
  await expect(page.getByText("Unsaved private draft")).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  const readyRefresh = page.getByRole("button", {
    name: /refresh football synchronization/i,
  });
  await readyRefresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-football-sync-interaction",
    "focused",
  );
  await capture("focused");

  await readyRefresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-football-sync-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();

  await page.getByRole("tab", { name: /livescore sources/i }).click();
  await page
    .getByRole("button", { name: /edit Rwanda Premier League 01/i })
    .click();
  await expect(surface()).toHaveAttribute(
    "data-admin-football-sync-interaction",
    "selected",
  );
  await expect(
    page.getByRole("textbox", { name: /display name/i }),
  ).toHaveValue("Rwanda Premier League 01");
  await page.evaluate(() => window.scrollTo(0, 0));
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await open("large-text");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await page.getByRole("tab", { name: /livescore sources/i }).click();
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  await expectNoHorizontalOverflow(page);
  await capture("large_text");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus("loading", /loading football synchronization/i);
  expect(
    await page
      .locator(".admin-football-sync-status svg")
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
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await page.getByRole("tab", { name: /livescore sources/i }).click();
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-key");
  await expect(page.locator("body")).not.toContainText("private-note");
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("actor_email");
  await expect(page.locator("body")).not.toContainText("token=secret");
  const undersizedControls = await surface()
    .locator("button, a, label[for]")
    .evaluateAll((elements) =>
      elements
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

  let deletionConfirmation = "";
  page.once("dialog", async (dialog) => {
    deletionConfirmation = dialog.message();
    await dialog.dismiss();
  });
  await page
    .getByRole("button", { name: /delete Rwanda Premier League 01/i })
    .click();
  expect(deletionConfirmation).toContain("This action cannot be undone.");

  const sourceSearch = page.getByRole("searchbox", {
    name: /search LiveScore sources/i,
  });
  await sourceSearch.fill("Rwanda Premier League 30");
  await expect(page.getByText("Rwanda Premier League 30")).toBeVisible();
  await expect(page.getByText("Rwanda Premier League 01")).toHaveCount(0);
  await sourceSearch.fill("");
  await page.getByRole("button", { name: /sort name/i }).click();
  await page.getByRole("button", { name: /sort priority/i }).click();
  await page.getByRole("button", { name: /go to next page/i }).click();
  await expect(page.getByText(/page 2 of 2/i)).toBeVisible();

  await page.getByRole("tab", { name: /sync logs/i }).click();
  await page.locator('tr[data-row-id="log-30"]').click();
  await expect(
    page.getByRole("dialog", { name: /synchronization log details/i }),
  ).toBeVisible();
  await expect(page.locator("body")).not.toContainText("accessToken");
  await page.getByRole("button", { name: /close/i }).click();

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh football synchronization/i })
    .click();
  await expectStatus("syncing", /refreshing football synchronization/i);
  await expect(page.getByText("24/30")).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  responseMode = "conflict";
  await page
    .getByRole("button", { name: /refresh football synchronization/i })
    .click();
  await expectStatus("conflict", /synchronization records changed/i);
  await expect(page.getByText("24/30")).toBeVisible();
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /synchronization request timed out/i);
  await expect(page.getByText("24/30")).toHaveCount(0);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await page.getByRole("tab", { name: /livescore sources/i }).click();
  await expectNoHorizontalOverflow(page);
  await page.evaluate(() => window.scrollTo(0, 0));
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /synchronization snapshot confirmed/i);
  await page.getByRole("tab", { name: /livescore sources/i }).click();
  await expectNoHorizontalOverflow(page);
  await page.evaluate(() => window.scrollTo({ top: 0, behavior: "instant" }));
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
    path.join(evidenceDirectory, "admin-football-sync-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/football-sync",
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
          maximum_source_records: 500,
          maximum_log_records: 500,
          overview_uses_bounded_counts_and_latest_500_daily_logs: true,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data_filters_selection_details_and_drafts: true,
          strict_source_log_and_overview_normalization: true,
          raw_provider_errors_and_private_metadata_rendered: false,
          source_urls_restricted_to_https_livescore_hosts: true,
          search_stable_sort_and_page_size_25_present: true,
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
            file: `admin_football_sync_state_${state}_${
              state === "light" ? "light" : "dark"
            }_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_football_sync_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_football_sync_state_responsive_compact_dark_compact_390x844.png",
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

test.describe("controlled Admin PWA football synchronization evidence", () => {
  test("captures the exact authenticated football-sync state matrix", async ({
    browser,
  }) => {
    test.setTimeout(150_000);
    await runAdminFootballSyncMatrix(browser);
  });
});
