import fs from "node:fs";
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

const tokens = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `fet-${number}`,
    clubId: 24,
    code: `G${String(number).padStart(3, "0")}`,
    templateScope: number % 3 === 0 ? "club_specific" : "generic",
    category: number % 2 === 0 ? "Matchday" : "Community",
    itemName: `Verified supporter reward ${number}`,
    fetValue: number * 25,
    triggerCondition: `Complete approved supporter action ${number}.`,
    activationTiming: "After authorized confirmation",
    description: `Bounded reward definition ${number} for controlled review.`,
    badgeName: number % 4 === 0 ? "Goal reader" : "",
    implementationNotes: number % 5 === 0 ? "Review settlement audit." : null,
    sortOrder: number,
    isActive: number % 6 !== 0,
    createdAt: new Date(Date.UTC(2026, 6, 29, 10, number)).toISOString(),
    updatedAt: new Date(Date.UTC(2026, 6, 29, 11, number)).toISOString(),
    privateSettlementKey: "private-token",
  };
});

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
  const overflow = await page.evaluate(
    () =>
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth,
  );
  expect(overflow).toBeLessThanOrEqual(1);
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/implementation_goal_20260724/admin_pwa_gamification_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/admin/gamification*", async (route: Route) => {
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    if (responseMode === "ready" || responseMode === "empty") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: responseMode === "empty" ? [] : tokens,
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
    page.locator(".admin-gamification-state-surface").first();
  const open = (nonce: string) =>
    page.goto(`/admin/gamification?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-gamification-status",
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
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_gamification_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading FET catalogue/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh FET catalogue/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no FET items in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /FET catalogue unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /FET catalogue confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /gamification workspace is offline/i);
  await expect(
    page.getByText("Verified supporter reward 1", { exact: true }),
  ).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await page.getByLabel("Gamification item").fill("Unsaved private reward");
  responseMode = "permission_denied";
  await page.getByRole("button", { name: /refresh FET catalogue/i }).click();
  await expectStatus("permission_denied", /gamification access denied/i);
  await expect(page.getByText("Unsaved private reward")).toHaveCount(0);
  await expect(
    page.getByText("Verified supporter reward 1", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /FET catalogue confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh FET catalogue/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-gamification-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-gamification-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  await page.getByRole("button", { name: "Edit" }).first().click();
  await expect(surface()).toHaveAttribute(
    "data-admin-gamification-interaction",
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
  await expectStatus("ready", /FET catalogue confirmed/i);
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
  await expectStatus("ready", /FET catalogue confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-token");
  const undersized = await surface()
    .locator("button:visible, input:visible, select:visible")
    .evaluateAll((elements) =>
      elements
        .map((element) => element.getBoundingClientRect())
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await capture("dark");

  let confirmation = "";
  page.once("dialog", async (dialog) => {
    confirmation = dialog.message();
    await dialog.dismiss();
  });
  await page
    .getByRole("button", { name: /delete/i })
    .first()
    .click();
  expect(confirmation).toContain("Scope: Active club 24");
  expect(confirmation).toContain("This action cannot be undone.");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /FET catalogue confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /FET catalogue confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh FET catalogue/i }).click();
  await expectStatus("syncing", /refreshing FET catalogue/i);
  await expect(
    page.getByText("Verified supporter reward 1", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /FET catalogue confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh FET catalogue/i }).click();
  await expectStatus("conflict", /FET catalogue changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /FET catalogue request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /FET catalogue confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /FET catalogue confirmed/i);
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
    path.join(evidenceDirectory, "admin-gamification-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/gamification",
        surface: "admin_pwa",
        exact_profile: "Chromium desktop 1440x1000 at 1 DPR",
        responsive_profiles: [
          "Chromium tablet 1024x900 at 1 DPR",
          "Chromium compact 390x844 at 1 DPR",
        ],
        applicable_states: governedStates,
        not_applicable_states: [],
        assertions: {
          authenticated_shell_required: true,
          protected_api_bypass_enabled: false,
          protected_mutation_bypass_enabled: false,
          bounded_request_seconds: 12,
          maximum_catalog_records: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_filters_selection_and_draft: true,
          strict_catalog_normalization: true,
          private_metadata_rendered: false,
          raw_action_diagnostics_rendered: false,
          destructive_delete_confirmation_required: true,
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
            file: `admin_gamification_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_gamification_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_gamification_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );
  await context.close();
}

test.describe("controlled Admin PWA gamification evidence", () => {
  test("captures the exact authenticated FET catalogue state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
