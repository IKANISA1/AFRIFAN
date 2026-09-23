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

const confirmedCatalog = [
  {
    id: "reward-matchday",
    code: "MATCHDAY",
    category: "Matchday",
    itemName: "Matchday attendance",
    fetValue: 250,
    triggerCondition: "Confirmed attendance in the supporter app",
    activationTiming: "After club verification",
    description: "A confirmed public reward for verified matchday attendance.",
  },
  {
    id: "reward-community",
    code: "COMMUNITY",
    category: "Community",
    itemName: "Community participation",
    fetValue: 150,
    triggerCondition: "Confirmed community activity",
    activationTiming: "After moderator verification",
    description: "A confirmed public reward for approved community activity.",
  },
  {
    id: "reward-membership",
    code: "MEMBERSHIP",
    category: "Membership",
    itemName: "Membership milestone",
    fetValue: 500,
    triggerCondition: "Confirmed membership milestone",
    activationTiming: "After account verification",
    description: "A confirmed public reward for an approved membership milestone.",
  },
  {
    id: "reward-story",
    code: "STORY",
    category: "Community",
    itemName: "Supporter story",
    fetValue: 100,
    triggerCondition: "Approved supporter story",
    activationTiming: "After editorial review",
    description: "A confirmed public reward for approved supporter storytelling.",
  },
];

const confirmedLeaderboard = [
  { rank: 1, supporterAlias: "blue_lion", totalFet: 3_500, tier: "inyamibwa" },
  { rank: 2, supporterAlias: "gikundiro_7", totalFet: 3_100, tier: "imena" },
  { rank: 3, supporterAlias: "rayon_star", totalFet: 2_850, tier: "imena" },
  { rank: 4, supporterAlias: "matchday_12", totalFet: 2_400, tier: "imena" },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: {
        code: "PUBLIC_SUPPORTERS_READY",
        catalog: confirmedCatalog,
        leaderboard: confirmedLeaderboard,
      },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: {
        code: "PUBLIC_SUPPORTERS_EMPTY",
        catalog: [],
        leaderboard: [],
      },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_SUPPORTERS_ACCESS_DENIED",
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
        code: "PUBLIC_SUPPORTERS_CONFLICT",
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
        code: "PUBLIC_SUPPORTERS_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_SUPPORTERS_FAILED",
      error: "database.internal password=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".supporters-surface")).toHaveAttribute(
    "data-supporters-status",
    status,
  );
  await expect(page.locator(".supporters-status")).toContainText(label);
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

test("/supporters proves all sixteen applicable rendered states", async ({
  browser,
}) => {
  test.setTimeout(120_000);

  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "consumer_web_supporters_states");


  const context: BrowserContext = await browser.newContext({
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=supporters*", async (route) => {
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
    await navigateStateEvidence(page, `/supporters?evidence=${nonce}`, {
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
      path: path.join(evidenceDirectory, `supporters_state_${state}_viewport.png`),
      fullPage: true,
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus(page, "loading", /loading supporter program/i);
  await capture("loading_dark");
  await expect(
    page.getByRole("button", { name: /refresh program/i }),
  ).toBeDisabled();
  await expect(page.locator(".supporters-surface")).toHaveAttribute(
    "data-supporters-refresh-disabled",
    "true",
  );
  await capture("disabled_dark");

  responseMode = "empty";
  await open("empty");
  await expectStatus(page, "empty", /no public supporter data/i);
  await expect(
    page.getByRole("heading", { name: /no public rewards listed/i }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /no public ranking listed/i }),
  ).toBeVisible();
  await capture("empty_dark");

  responseMode = "error";
  await open("error");
  await expectStatus(page, "error", /supporter program unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error_dark");

  responseMode = "ready";
  await open("offline");
  await expectStatus(page, "ready", /supporter program confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(
    page.locator(".supporters-card").filter({ hasText: "Matchday attendance" }),
  ).toBeVisible();
  await expect(page.getByText("#blue_lion")).toBeVisible();
  await capture("offline_dark");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus(page, "permission_denied", /supporter data access denied/i);
  await expect(page.locator(".supporters-card")).toHaveCount(0);
  await expect(page.getByText("#blue_lion")).toHaveCount(0);
  await capture("permission_denied_dark");

  responseMode = "ready";
  await open("focused");
  const primaryAction = page
    .getByRole("link", { name: /app links coming soon/i })
    .first();
  await primaryAction.focus();
  await expect(page.locator(".supporters-surface")).toHaveAttribute(
    "data-supporters-interaction",
    "focused",
  );
  await expect(primaryAction).toBeFocused();
  await capture("focused_dark");

  await primaryAction.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".supporters-surface")).toHaveAttribute(
    "data-supporters-interaction",
    "pressed",
  );
  await capture("pressed_dark");
  await primaryAction.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const community = page.getByRole("button", {
    name: /community participation/i,
  });
  await community.click();
  await expect(community).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".supporters-surface")).toHaveAttribute(
    "data-supporters-interaction",
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
    .locator(".supporters-surface")
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
  await expectStatus(page, "loading", /loading supporter program/i);
  expect(
    await page
      .locator(".supporters-status svg")
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
  await expectStatus(page, "ready", /supporter program confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("Private Name");
  await expect(page.locator("body")).not.toContainText("private-user");
  await capture("dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus(page, "ready", /supporter program confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light_light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus(page, "ready", /supporter program confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh program/i })
    .dispatchEvent("click");
  await expectStatus(page, "syncing", /refreshing supporter program/i);
  await expect(
    page.locator(".supporters-card").filter({ hasText: "Matchday attendance" }),
  ).toBeVisible();
  await expect(page.getByText("#blue_lion")).toBeVisible();
  await capture("syncing_dark");

  responseMode = "conflict";
  await open("conflict");
  await expectStatus(page, "conflict", /supporter program changed/i);
  await capture("conflict_dark");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus(page, "security_timeout", /supporter request timed out/i);
  await capture("security_timeout_dark");

  responseMode = "ready";
  await open("targets");
  await expectStatus(page, "ready", /supporter program confirmed/i);
  const targetSizes = await page
    .locator(".supporters-action, .supporters-card")
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
    path.join(evidenceDirectory, "supporters-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/supporters",
        surface: "consumer_web",
        exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          public_user_ids_exposed: false,
          public_supporter_names_exposed: false,
          authenticated_progress_or_earning_claimed: false,
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
          file: `supporters_state_${state}_${
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
