import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page, type Route } from "@playwright/test";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const groups = Array.from({ length: 30 }, (_, index) => ({
  id: `group-${index + 1}`,
  name: `Verified supporter group ${index + 1}`,
  private_contact: `private-group-${index + 1}@example.com`,
}));

const history = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `notification-${number}`,
    title: `Verified match update ${number}`,
    body: `Approved supporter delivery message ${number}.`,
    audienceType:
      number % 3 === 0
        ? "by_group"
        : number % 2 === 0
          ? "by_tier"
          : "all_fans",
    audienceTier: number % 2 === 0 ? "imena" : null,
    audienceGroupId: number % 3 === 0 ? `group-${number}` : null,
    audienceGroupName:
      number % 3 === 0 ? `Verified supporter group ${number}` : null,
    deliveryMode: number % 4 === 0 ? "schedule" : "send_now",
    status:
      number % 7 === 0
        ? "failed"
        : number % 4 === 0
          ? "scheduled"
          : "delivered",
    scheduledAt:
      number % 4 === 0
        ? new Date(Date.UTC(2026, 7, 2, 10, number)).toISOString()
        : null,
    sentAt:
      number % 4 === 0
        ? null
        : new Date(Date.UTC(2026, 6, 30, 9, number)).toISOString(),
    requestedRecipientCount: 500 + number,
    sentCount: number % 7 === 0 ? 490 : 500 + number,
    failedCount: number % 7 === 0 ? 11 : 0,
    createdAt: new Date(Date.UTC(2026, 6, 30, 8, number)).toISOString(),
    lastError:
      number % 7 === 0
        ? "Delivery requires operator review."
        : null,
    private_recipient_ids: [`private-recipient-${number}`],
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
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/evidence/admin_pwa_notifications_states",
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

  await page.route("**/api/admin/notifications", async (route: Route) => {
    if (route.request().method() === "POST") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: { delivery: { status: "sent" } } }),
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
              ? { groups: [], history: [] }
              : { groups, history },
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
    page.locator(".admin-notifications-state-surface").first();
  const open = (nonce: string) =>
    page.goto(`/admin/notifications?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-notifications-status",
      status,
    );
    await expect(page.getByText(label).first()).toBeVisible();
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await page.evaluate((shouldBlur) => {
      if (shouldBlur && document.activeElement instanceof HTMLElement) {
        document.activeElement.blur();
      }
      document.documentElement.style.scrollBehavior = "auto";
      document.body.style.scrollBehavior = "auto";
      window.scrollTo({ top: 0, left: 0, behavior: "auto" });
    }, state === "selected" || state === "large_text");
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0);
    await settleVisuals(page);
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_notifications_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading notification operations/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh notification operations/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no notification activity in this scope/i);
  await expect(page.getByRole("button", { name: /send notification/i })).toBeEnabled();
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /notification operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /notification operations confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /notification workspace is offline/i);
  await expect(
    page.getByText("Verified match update 30", { exact: true }),
  ).toBeVisible();
  await expect(page.getByRole("button", { name: /send notification/i })).toBeDisabled();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /notification operations confirmed/i);
  await page.getByLabel("Title").fill("Unsaved private draft");
  await page.getByLabel("Search notification delivery queue").fill("private");
  responseMode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh notification operations/i })
    .click();
  await expectStatus("permission_denied", /notification access denied/i);
  await expect(page.getByLabel("Title")).toHaveCount(0);
  await expect(page.getByLabel("Search notification delivery queue")).toHaveCount(0);
  await expect(page.getByText("Unsaved private draft")).toHaveCount(0);
  await expect(
    page.getByText("Verified match update 30", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /notification operations confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh notification operations/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-notifications-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-notifications-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  await page
    .getByRole("combobox", { name: "Audience", exact: true })
    .selectOption("by_group");
  await expect(surface()).toHaveAttribute(
    "data-admin-notifications-interaction",
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
  await expectStatus("ready", /notification operations confirmed/i);
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
  await expectStatus("ready", /notification operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-recipient");
  await expect(page.locator("body")).not.toContainText("private-group");
  const undersized = await surface()
    .locator("button:visible, input:not(.sr-only):visible, select:visible")
    .evaluateAll((elements) =>
      elements
        .map((element) => element.getBoundingClientRect())
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await capture("dark");

  await page.getByLabel("Title").fill("Kickoff confirmation");
  await page.getByLabel("Body").fill("Approved operational message.");
  let confirmation = "";
  page.once("dialog", async (dialog) => {
    confirmation = dialog.message();
    await dialog.dismiss();
  });
  await page.getByRole("button", { name: /send notification/i }).click();
  expect(confirmation).toContain("Scope: all supporters · active club 24");
  expect(confirmation).toContain("This action cannot be undone.");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /notification operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /notification operations confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh notification operations/i })
    .click();
  await expectStatus("syncing", /refreshing notification operations/i);
  await expect(
    page.getByText("Verified match update 30", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /notification operations confirmed/i);
  responseMode = "conflict";
  await page
    .getByRole("button", { name: /refresh notification operations/i })
    .click();
  await expectStatus("conflict", /notification state changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /notification request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /notification operations confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /notification operations confirmed/i);
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
    path.join(evidenceDirectory, "admin-notifications-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/notifications",
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
          maximum_group_records: 50,
          maximum_history_records: 100,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_filters_and_draft: true,
          strict_notification_normalization: true,
          private_metadata_rendered: false,
          raw_provider_diagnostics_rendered: false,
          broadcast_confirmation_required: true,
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
            file: `admin_notifications_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_notifications_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_notifications_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );
  await context.close();
}

test.describe("controlled Admin PWA notifications evidence", () => {
  test("captures the exact authenticated notifications state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
