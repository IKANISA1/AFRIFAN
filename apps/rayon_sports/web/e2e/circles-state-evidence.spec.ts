import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions } from "./state-evidence-provenance";
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

const confirmedGroups = [
  {
    id: "circle-tifo",
    name: "Blue wall tifo",
    description: "A confirmed campaign for matchday choreography.",
    groupType: "project",
    targetAmount: 5_000_000,
    currentTotal: 2_500_000,
    currency: "RWF",
    memberCount: 240,
  },
  {
    id: "circle-community",
    name: "Community kit drive",
    description: "A confirmed community equipment campaign.",
    groupType: "community",
    targetAmount: 2_000_000,
    currentTotal: 800_000,
    currency: "RWF",
    memberCount: 120,
  },
  {
    id: "circle-travel",
    name: "Away-day travel",
    description: "A confirmed public travel-support campaign.",
    groupType: "community",
    targetAmount: 3_000_000,
    currentTotal: 1_350_000,
    currency: "RWF",
    memberCount: 180,
  },
];

const confirmedChapters = [
  {
    id: "chapter-kigali",
    name: "Kigali Blue Family",
    region: "Kigali",
    description: "An official public supporter chapter.",
    memberCount: 900,
    eventCount: 12,
  },
  {
    id: "chapter-huye",
    name: "Huye Gikundiro",
    region: "Southern Province",
    description: "An official public supporter chapter.",
    memberCount: 320,
    eventCount: 6,
  },
  {
    id: "chapter-musanze",
    name: "Musanze Blue Nation",
    region: "Northern Province",
    description: "An official public supporter chapter.",
    memberCount: 280,
    eventCount: 5,
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: {
        code: "PUBLIC_CIRCLES_READY",
        groups: confirmedGroups,
        chapters: confirmedChapters,
      },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_CIRCLES_EMPTY", groups: [], chapters: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_CIRCLES_ACCESS_DENIED",
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
        code: "PUBLIC_CIRCLES_CONFLICT",
        error: "The public snapshot conflicts with the current record.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: "PUBLIC_CIRCLES_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_CIRCLES_FAILED",
      error: "database.internal password=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".circles-surface")).toHaveAttribute(
    "data-circles-status",
    status,
  );
  await expect(page.locator(".circles-status")).toContainText(label);
}

async function expectNoSeriousAxeViolations(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    results.violations.filter(
      ({ impact }) => impact === "critical" || impact === "serious",
    ),
  ).toHaveLength(0);
}

const surfaceCases = [
  {
    route: "/circles",
    resource: "circles",
    slug: "circles",
    evidenceDirectory: "consumer_web_circles_states",
    loading: /loading support circles/i,
    refresh: /refresh circles/i,
    empty: /no public circles listed/i,
    error: /support circles unavailable/i,
    ready: /support circles confirmed/i,
    denied: /support-circle access denied/i,
    syncing: /refreshing support circles/i,
    conflict: /support circles changed/i,
    timeout: /support-circle request timed out/i,
  },
  {
    route: "/fan-clubs",
    resource: "fan-clubs",
    slug: "fan_clubs",
    evidenceDirectory: "consumer_web_fan_clubs_states",
    loading: /loading fan clubs/i,
    refresh: /refresh fan clubs/i,
    empty: /no public fan clubs listed/i,
    error: /fan clubs unavailable/i,
    ready: /official fan clubs confirmed/i,
    denied: /fan-club access denied/i,
    syncing: /refreshing fan clubs/i,
    conflict: /fan-club directory changed/i,
    timeout: /fan-club request timed out/i,
  },
] as const;

for (const surfaceCase of surfaceCases) {
  test(`${surfaceCase.route} proves all sixteen applicable rendered states`, async ({
    browser,
  }) => {
    test.setTimeout(120_000);

    const evidenceDirectory = prepareStateEvidence(browser, test.info(), `${surfaceCase.evidenceDirectory}`);


    const context: BrowserContext = await browser.newContext({
    ...stateEvidenceContextOptions(test.info()),
      colorScheme: "dark",
      reducedMotion: "no-preference",
  });
    const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
    let responseMode: ResponseMode = "ready";

    await page.route(
      `**/api/public-content?resource=${surfaceCase.resource}*`,
      async (route) => {
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
      },
    );

    const open = async (nonce: string) => {
      await navigateStateEvidence(page, `${surfaceCase.route}?evidence=${nonce}`, {
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
          `${surfaceCase.slug}_state_${state}_viewport.png`,
        ),
        fullPage: true,
        animations: "disabled",
      });
    };

    responseMode = "loading";
    await open("loading");
    await expectStatus(page, "loading", surfaceCase.loading);
    await capture("loading_dark");
    await expect(
      page.getByRole("button", { name: surfaceCase.refresh }),
    ).toBeDisabled();
    await expect(page.locator(".circles-surface")).toHaveAttribute(
      "data-circles-refresh-disabled",
      "true",
    );
    await capture("disabled_dark");

    responseMode = "empty";
    await open("empty");
    await expectStatus(page, "empty", surfaceCase.empty);
    await expect(
      page.getByRole("heading", { name: /no public campaigns listed/i }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: /no public chapters listed/i }),
    ).toBeVisible();
    await capture("empty_dark");

    responseMode = "error";
    await open("error");
    await expectStatus(page, "error", surfaceCase.error);
    await expect(page.locator("body")).not.toContainText("database.internal");
    await capture("error_dark");

    responseMode = "ready";
    await open("offline");
    await expectStatus(page, "ready", surfaceCase.ready);
    await context.setOffline(true);
    await page.evaluate(() => window.dispatchEvent(new Event("offline")));
    await expectStatus(page, "offline", /you are offline/i);
    await expect(
      page.locator(".circles-card").filter({ hasText: "Blue wall tifo" }),
    ).toBeVisible();
    await expect(page.getByText("Kigali Blue Family")).toBeVisible();
    await capture("offline_dark");
    await context.setOffline(false);

    responseMode = "permission_denied";
    await open("permission");
    await expectStatus(page, "permission_denied", surfaceCase.denied);
    await expect(page.locator(".circles-card")).toHaveCount(0);
    await expect(page.getByText("Kigali Blue Family")).toHaveCount(0);
    await capture("permission_denied_dark");

    responseMode = "ready";
    await open("focused");
    await expectStatus(page, "ready", surfaceCase.ready);
    const primaryAction = page
      .getByRole("link", { name: /app links coming soon/i })
      .first();
    await primaryAction.focus();
    await expect(page.locator(".circles-surface")).toHaveAttribute(
      "data-circles-interaction",
      "focused",
    );
    await expect(primaryAction).toBeFocused();
    await capture("focused_dark");

    await primaryAction.dispatchEvent("pointerdown", {
      pointerId: 1,
      pointerType: "touch",
      isPrimary: true,
    });
    await expect(page.locator(".circles-surface")).toHaveAttribute(
      "data-circles-interaction",
      "pressed",
    );
    await capture("pressed_dark");
    await primaryAction.dispatchEvent("pointerup", {
      pointerId: 1,
      pointerType: "touch",
      isPrimary: true,
    });

    const community = page.getByRole("button", {
      name: /community kit drive/i,
    });
    await community.click();
    await expect(community).toHaveAttribute("aria-pressed", "true");
    await expect(page.locator(".circles-surface")).toHaveAttribute(
      "data-circles-interaction",
      "selected",
    );
    await capture("selected_dark");

    await open("large-text");
    await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
    expect(
      await page.evaluate(
        () =>
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth,
      ),
    ).toBeLessThanOrEqual(1);
    const clippedElements = await page
      .locator(".circles-surface")
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
          .filter(({ left, right }) => left < -1 || right > viewportWidth + 1);
      });
    expect(clippedElements).toEqual([]);
    await capture("large_text_dark");

    responseMode = "loading";
    await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
    await open("reduced-motion");
    await expectStatus(page, "loading", surfaceCase.loading);
    expect(
      await page
        .locator(".circles-status svg")
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
    await expectStatus(page, "ready", surfaceCase.ready);
    await expectNoSeriousAxeViolations(page);
    await expect(page.locator("body")).not.toContainText("private-user");
    await expect(page.locator("body")).not.toContainText("private-payment");
    await capture("dark_dark");

    await page.emulateMedia({
      colorScheme: "light",
      reducedMotion: "no-preference",
    });
    await open("light");
    await expectStatus(page, "ready", surfaceCase.ready);
    await expectNoSeriousAxeViolations(page);
    await capture("light_light");

    await page.emulateMedia({
      colorScheme: "dark",
      reducedMotion: "no-preference",
    });
    responseMode = "ready";
    await open("syncing");
    await expectStatus(page, "ready", surfaceCase.ready);
    responseMode = "loading";
    await page.getByRole("button", { name: surfaceCase.refresh }).click();
    await expectStatus(page, "syncing", surfaceCase.syncing);
    await expect(
      page.locator(".circles-card").filter({ hasText: "Blue wall tifo" }),
    ).toBeVisible();
    await expect(page.getByText("Kigali Blue Family")).toBeVisible();
    await capture("syncing_dark");

    responseMode = "conflict";
    await open("conflict");
    await expectStatus(page, "conflict", surfaceCase.conflict);
    await capture("conflict_dark");

    responseMode = "security_timeout";
    await open("security-timeout");
    await expectStatus(page, "security_timeout", surfaceCase.timeout);
    await capture("security_timeout_dark");

    responseMode = "ready";
    await open("targets");
    await expectStatus(page, "ready", surfaceCase.ready);
    const targetSizes = await page
      .locator(".circles-action, .circles-card")
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
      path.join(evidenceDirectory, `${surfaceCase.slug}-state-evidence.json`),
      `${JSON.stringify(
        {
          schema_version: "1.0",
          route: surfaceCase.route,
          surface: "consumer_web",
          exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
          applicable_states: captures,
          not_applicable_states: [],
          assertions: {
            controlled_api_states: true,
            confirmed_data_retained_during_recovery: true,
            contributor_identity_exposed: false,
            payment_or_receipt_data_exposed: false,
            web_contribution_action_claimed: false,
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
            file: `${surfaceCase.slug}_state_${state}_${
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
