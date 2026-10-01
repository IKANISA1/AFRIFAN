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

const confirmedStandings = [
  {
    position: 1,
    club: "APR FC",
    played: 24,
    goalDifference: 28,
    points: 58,
    form: ["W", "W", "D", "W", "L"],
    highlight: false,
  },
  {
    position: 2,
    club: "Rayon Sports",
    played: 24,
    goalDifference: 23,
    points: 55,
    form: ["W", "D", "W", "W", "W"],
    highlight: true,
  },
  {
    position: 3,
    club: "Police FC",
    played: 24,
    goalDifference: 16,
    points: 48,
    form: ["L", "W", "D", "W", "D"],
    highlight: false,
  },
  {
    position: 4,
    club: "Mukura Victory Sports",
    played: 24,
    goalDifference: 8,
    points: 39,
    form: ["D", "L", "W", "D", "W"],
    highlight: false,
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_STANDINGS_READY", items: confirmedStandings },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_STANDINGS_EMPTY", items: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_STANDINGS_ACCESS_DENIED",
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
        code: "PUBLIC_STANDINGS_CONFLICT",
        error: "The table conflicts with the current record.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: "PUBLIC_STANDINGS_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_STANDINGS_FAILED",
      error: "database.internal password=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".standings-surface")).toHaveAttribute(
    "data-standings-status",
    status,
  );
  await expect(page.locator(".standings-status")).toContainText(label);
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

test("/standings proves all sixteen applicable rendered states", async ({
  browser,
}) => {
  test.setTimeout(360_000);

  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "consumer_web_standings_states");


  const context: BrowserContext = await createStateEvidenceContext(browser, {
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=standings*", async (route) => {
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
    await navigateStateEvidence(page, `/standings?evidence=${nonce}`, {
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
        `standings_state_${state}_viewport.png`,
      ),
      fullPage: true,
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus(page, "loading", /loading league table/i);
  await capture("loading_dark");
  await expect(
    page.getByRole("button", { name: /refresh standings/i }),
  ).toBeDisabled();
  await expect(page.locator(".standings-surface")).toHaveAttribute(
    "data-standings-refresh-disabled",
    "true",
  );
  await capture("disabled_dark");

  responseMode = "empty";
  await open("empty");
  await expectStatus(page, "empty", /no standings listed/i);
  await expect(
    page.getByRole("heading", { name: /no standings listed/i }),
  ).toBeVisible();
  await capture("empty_dark");

  responseMode = "error";
  await open("error");
  await expectStatus(page, "error", /league table unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error_dark");

  responseMode = "ready";
  await open("offline");
  await expectStatus(page, "ready", /league table confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(
    page.locator(".standings-card").filter({ has: page.getByRole("group", { name: "Rayon Sports", exact: true }) }),
  ).toBeVisible();
  await capture("offline_dark");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus(page, "permission_denied", /standings access denied/i);
  await expect(page.locator(".standings-card")).toHaveCount(0);
  await capture("permission_denied_dark");

  responseMode = "ready";
  await open("focused");
  const primaryAction = page.getByRole("link", { name: /fixture hub/i });
  await primaryAction.focus();
  await expect(page.locator(".standings-surface")).toHaveAttribute(
    "data-standings-interaction",
    "focused",
  );
  await expect(primaryAction).toBeFocused();
  await capture("focused_dark");

  await primaryAction.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".standings-surface")).toHaveAttribute(
    "data-standings-interaction",
    "pressed",
  );
  await capture("pressed_dark");
  await primaryAction.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const police = page.getByRole("button", { name: /police fc/i });
  await police.click();
  await expect(police).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".standings-surface")).toHaveAttribute(
    "data-standings-interaction",
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
    .locator(".standings-surface")
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
  await expectStatus(page, "loading", /loading league table/i);
  expect(
    await page
      .locator(".standings-status svg")
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
  await expectStatus(page, "ready", /league table confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus(page, "ready", /league table confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light_light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus(page, "ready", /league table confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh standings/i })
    .dispatchEvent("click");
  await expectStatus(page, "syncing", /refreshing league table/i);
  await expect(
    page.locator(".standings-card").filter({ has: page.getByRole("group", { name: "Rayon Sports", exact: true }) }),
  ).toBeVisible();
  await capture("syncing_dark");

  responseMode = "conflict";
  await open("conflict");
  await expectStatus(page, "conflict", /league table changed/i);
  await capture("conflict_dark");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus(page, "security_timeout", /standings request timed out/i);
  await capture("security_timeout_dark");

  responseMode = "ready";
  await open("targets");
  await expectStatus(page, "ready", /league table confirmed/i);
  const targetSizes = await page
    .locator(".standings-action, .standings-card")
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
    path.join(evidenceDirectory, "standings-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/standings",
        surface: "consumer_web",
        exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          fabricated_standings_data: false,
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
          file: `standings_state_${state}_${
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
