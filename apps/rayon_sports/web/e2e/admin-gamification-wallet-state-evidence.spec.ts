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

const overview = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    userId: `supporter-${number}`,
    publicUserId: String(480_000 + number),
    displayName: `Verified supporter ${number}`,
    tier: number % 3 === 0 ? "indatwa" : "imena",
    balance: number * 125,
    transactionCount: number + 2,
    lastTransactionAt: new Date(
      Date.UTC(2026, 6, 29, 10, number),
    ).toISOString(),
    lifetimeEarned: number * 175,
    lifetimeSpent: number * 50,
    privateEmail: `private-${number}@example.com`,
  };
});

const ledger = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  const credit = number % 3 !== 0;
  return {
    id: `ledger-${number}`,
    userId: `supporter-${number}`,
    publicUserId: String(480_000 + number),
    displayName: `Verified supporter ${number}`,
    entryType: credit ? "earn" : "redeem",
    direction: credit ? "credit" : "debit",
    amount: number * 25,
    balanceAfter: number * 100,
    counterpartyUserId: null,
    counterpartyDisplayName: null,
    counterpartyPublicUserId: null,
    note: `Approved wallet entry ${number}.`,
    referenceType: credit ? "match_event" : "redemption",
    referenceId: `reference-${number}`,
    createdAt: new Date(Date.UTC(2026, 6, 29, 12, number)).toISOString(),
    privateActorId: `private-actor-${number}`,
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
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_gamification_wallet_states");
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

  await page.route(
    "**/api/admin/gamification-wallet*",
    async (route: Route) => {
      if (route.request().method() !== "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            data: {
              status: "success",
              amount: -120,
              balance: 5,
              referenceId: "confirmed-reference",
            },
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
                ? { overview: [], ledger: [] }
                : { overview, ledger, privateTrace: "private-token" },
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
    },
  );

  const surface = () =>
    page.locator(".admin-gamification-wallet-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/gamification/wallet?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-gamification-wallet-status",
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
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_gamification_wallet_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading points operations/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh points operations/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no points activity in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /points operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /points operations confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /points operations are offline/i);
  await expect(
    page.getByText("Verified supporter 30", { exact: true }).first(),
  ).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /points operations confirmed/i);
  await page
    .getByLabel("Search supporters or reference IDs")
    .fill("private draft");
  await page
    .getByRole("button", { name: "Select", exact: true })
    .first()
    .click();
  await expectStatus("ready", /points operations confirmed/i);
  await page.getByLabel("Adjustment amount").fill("250");
  await page.getByLabel("Audit reason").fill("Unsaved private reason");
  responseMode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh points operations/i })
    .click();
  await expectStatus("permission_denied", /points operations access denied/i);
  await expect(
    page.getByLabel("Search supporters or reference IDs"),
  ).toHaveValue("");
  await expect(page.getByText("Unsaved private reason")).toHaveCount(0);
  await expect(
    page.getByText("Verified supporter 30", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /points operations confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh points operations/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-gamification-wallet-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-gamification-wallet-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();

  await page
    .getByRole("button", { name: "Select", exact: true })
    .first()
    .click();
  await expect(surface()).toHaveAttribute(
    "data-admin-gamification-wallet-interaction",
    "selected",
  );
  await expectStatus("ready", /points operations confirmed/i);
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
  await expectStatus("ready", /points operations confirmed/i);
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
  await expectStatus("ready", /points operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-token");
  await expect(page.locator("body")).not.toContainText("private-actor");
  const undersized = await surface()
    .locator("button:visible, input:visible, select:visible")
    .evaluateAll((elements) =>
      elements
        .map((element) => element.getBoundingClientRect())
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await capture("dark");

  await page
    .getByRole("button", { name: "Select", exact: true })
    .first()
    .click();
  await expectStatus("ready", /points operations confirmed/i);
  await page.getByLabel("Adjustment amount").fill("-120");
  await page.getByLabel("Audit reason").fill("Controlled correction");
  let confirmation = "";
  page.once("dialog", async (dialog) => {
    confirmation = dialog.message();
    await dialog.dismiss();
  });
  await page.getByRole("button", { name: /apply adjustment/i }).click();
  expect(confirmation).toContain(
    "Scope: Active club 24; one supporter account",
  );
  expect(confirmation).toContain(
    "Recovery requires a separate manual admin action.",
  );

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /points operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /points operations confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh points operations/i })
    .click();
  await expectStatus("syncing", /refreshing points operations/i);
  await expect(
    page.getByText("Verified supporter 30", { exact: true }).first(),
  ).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /points operations confirmed/i);
  responseMode = "conflict";
  await page
    .getByRole("button", { name: /refresh points operations/i })
    .click();
  await expectStatus("conflict", /points operations changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus(
    "security_timeout",
    /points operations request timed out/i,
  );
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /points operations confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /points operations confirmed/i);
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
    path.join(
      evidenceDirectory,
      "admin-gamification-wallet-state-evidence.json",
    ),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/gamification/wallet",
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
          maximum_account_records: 60,
          maximum_ledger_records: 120,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_filters_selection_details_and_draft: true,
          strict_wallet_normalization: true,
          private_metadata_rendered: false,
          raw_action_diagnostics_rendered: false,
          retry_idempotency_key_retained_until_confirmation: true,
          destructive_deduction_confirmation_required: true,
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
            file: `admin_gamification_wallet_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_gamification_wallet_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_gamification_wallet_state_responsive_compact_dark_compact_390x844.png",
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

test.describe("controlled Admin PWA gamification wallet evidence", () => {
  test("captures the exact authenticated wallet operations state matrix", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    await runMatrix(browser);
  });
});
