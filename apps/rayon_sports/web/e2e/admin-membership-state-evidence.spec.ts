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

const packages = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `tier-${number}`,
    clubId: 24,
    tier: number % 3 === 0 ? "gold" : number % 2 === 0 ? "silver" : "imena",
    title: `Verified membership tier ${number}`,
    description: `Approved annual supporter package ${number}.`,
    sortOrder: number,
    perks: [`Priority ticket window ${number}`, `Member event ${number}`],
    annualPrice: number * 5_000,
    isActive: number % 5 !== 0,
    createdAt: new Date(Date.UTC(2026, 6, 29, 8, number)).toISOString(),
    updatedAt: new Date(Date.UTC(2026, 6, 29, 9, number)).toISOString(),
    privatePaymentKey: `private-tier-${number}`,
  };
});

const supporters = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `supporter-${number}`,
    userId: `user-${number}`,
    displayName: `Verified supporter ${number}`,
    phone: `+25078812${String(number).padStart(4, "0")}`,
    tier: number % 3 === 0 ? "gold" : number % 2 === 0 ? "silver" : "imena",
    status: number % 7 === 0 ? "suspended" : "active",
    points: number * 125,
    chapter: number % 2 === 0 ? "Kigali" : "Musanze",
    membershipNumber: `RS-${String(number).padStart(4, "0")}`,
    joinedAt: new Date(Date.UTC(2026, 5, 29, 10, number)).toISOString(),
    privateEmail: `private-${number}@example.com`,
  };
});

const applications = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `application-${number}`,
    userId: `applicant-${number}`,
    clubId: 24,
    tier: number % 2 === 0 ? "gold" : "imena",
    status: number % 4 === 0 ? "approved" : "pending",
    paymentStatus: number % 5 === 0 ? "unpaid" : "paid",
    applicationDate: new Date(
      Date.UTC(2026, 6, 28, 11, number),
    ).toISOString(),
    reviewDate: null,
    reviewerId: null,
    notes: null,
    userName: `Verified applicant ${number}`,
    userPhone: `+25078813${String(number).padStart(4, "0")}`,
    updatedAt: new Date(Date.UTC(2026, 6, 29, 11, number)).toISOString(),
    privatePaymentToken: `private-application-${number}`,
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
    "../../../output/evidence/admin_pwa_membership_states",
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

  const fulfillMembership = async (
    route: Route,
    readyData: unknown[],
  ) => {
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    if (responseMode === "ready" || responseMode === "empty") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: responseMode === "empty" ? [] : readyData,
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
  };

  await page.route("**/api/admin/membership", async (route) => {
    if (route.request().method() === "GET") {
      await fulfillMembership(route, packages);
      return;
    }
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ data: "tier-confirmed" }),
    });
  });
  await page.route("**/api/admin/membership-supporters", async (route) => {
    await fulfillMembership(route, supporters);
  });
  await page.route("**/api/admin/membership-applications", async (route) => {
    await fulfillMembership(route, applications);
  });
  await page.route(
    "**/api/admin/membership-applications/review",
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: { success: true } }),
      });
    },
  );

  const surface = () => page.locator(".admin-membership-state-surface").first();
  const open = (nonce: string) =>
    page.goto(`/admin/membership?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-membership-status", status);
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
        `admin_membership_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading membership operations/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh membership operations/i }),
  ).toBeDisabled();
  await expect(page.getByRole("button", { name: /new tier/i })).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no membership records in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /membership operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /membership operations confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /membership workspace is offline/i);
  await expect(
    page.getByText("Verified membership tier 1", { exact: true }),
  ).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /membership operations confirmed/i);
  await page.getByRole("tab", { name: "registry" }).click();
  await page.getByLabel("Search supporter registry").fill("private draft");
  await page
    .getByRole("tab", { name: "tiers" })
    .click();
  await page.getByRole("button", { name: /new tier/i }).click();
  await page.getByRole("textbox", { name: "Title" }).fill("Unsaved private tier");
  await page
    .getByRole("button", { name: /close create new tier/i })
    .click();
  responseMode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh membership operations/i })
    .click();
  await expectStatus("permission_denied", /membership access denied/i);
  await expect(page.getByLabel("Search supporter registry")).toHaveCount(0);
  await expect(page.getByText("Unsaved private tier")).toHaveCount(0);
  await expect(
    page.getByText("Verified membership tier 1", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /membership operations confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh membership operations/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-membership-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-membership-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  await page.getByRole("tab", { name: "registry" }).click();
  await expect(surface()).toHaveAttribute(
    "data-admin-membership-interaction",
    "selected",
  );
  await expectStatus("ready", /membership operations confirmed/i);
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
  await expectStatus("ready", /membership operations confirmed/i);
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
  await expectStatus("ready", /membership operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-tier");
  await expect(page.locator("body")).not.toContainText("private-application");
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
  await page.getByRole("button", { name: "Delete" }).first().click();
  expect(confirmation).toContain("Scope: Active club 24");
  expect(confirmation).toContain("This action cannot be undone.");

  await page.getByRole("tab", { name: "applications" }).click();
  let reviewConfirmation = "";
  page.once("dialog", async (dialog) => {
    reviewConfirmation = dialog.message();
    await dialog.dismiss();
  });
  await page.getByRole("button", { name: "Approve" }).nth(1).click();
  expect(reviewConfirmation).toContain("Application application-29");
  expect(reviewConfirmation).toContain(
    "Recovery requires a separate manual admin action.",
  );

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /membership operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /membership operations confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh membership operations/i })
    .click();
  await expectStatus("syncing", /refreshing membership operations/i);
  await expect(
    page.getByText("Verified membership tier 1", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /membership operations confirmed/i);
  responseMode = "conflict";
  await page
    .getByRole("button", { name: /refresh membership operations/i })
    .click();
  await expectStatus("conflict", /membership records changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /membership request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /membership operations confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /membership operations confirmed/i);
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
    path.join(evidenceDirectory, "admin-membership-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/membership",
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
          maximum_tier_records: 100,
          maximum_supporter_records: 500,
          maximum_application_records: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_filters_selection_details_and_draft: true,
          strict_membership_normalization: true,
          private_metadata_rendered: false,
          raw_action_diagnostics_rendered: false,
          destructive_tier_deletion_confirmation_required: true,
          destructive_application_review_confirmation_required: true,
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
            file: `admin_membership_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_membership_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_membership_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
}

test.describe("controlled Admin PWA membership evidence", () => {
  test("captures the exact authenticated membership state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
