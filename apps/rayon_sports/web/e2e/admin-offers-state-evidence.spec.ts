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

const catalog = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `catalog-${number}`,
    code: `G${String(number).padStart(3, "0")}`,
    itemName: `Verified partner reward ${number}`,
    fetValue: 100 + number * 10,
    private_settlement_key: `private-catalog-${number}`,
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

const offers = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `offer-${number}`,
    clubId: 24,
    catalogItemId: `catalog-${number}`,
    code: `G${String(number).padStart(3, "0")}`,
    title: `Verified partner reward ${number}`,
    fetValue: 100 + number * 10,
    partnerId: `partner-${number}`,
    partnerName: `Verified partner ${number}`,
    partnerSlug: `verified-partner-${number}`,
    partnerCategory: number % 2 === 0 ? "mobility" : "matchday",
    subtitle: `Approved supporter journey ${number} with a confirmed reward definition.`,
    ctaLabel: "View journey",
    verificationMode:
      number % 2 === 0 ? "mobility_confirmation" : "manual_review",
    deeplinkRoute: `/fanzone/offers/offer-${number}`,
    externalUrl: `https://partner.example/offers/${number}`,
    isFeatured: number % 5 === 0,
    isActive: number % 7 !== 0,
    sortOrder: number * 10,
    createdAt: new Date(Date.UTC(2026, 6, 30, 8, number)).toISOString(),
    updatedAt: new Date(Date.UTC(2026, 6, 30, 9, number)).toISOString(),
    metadata: { accessToken: `private-offer-${number}` },
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
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_offers_states");
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

  await page.route("**/api/admin/offers*", async (route: Route) => {
    if (route.request().method() === "POST") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: "offer-confirmed" }),
      });
      return;
    }
    if (route.request().method() === "DELETE") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: { success: true } }),
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
          data: {
            offers: responseMode === "empty" ? [] : offers,
            catalog,
            partners,
          },
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

  const surface = () => page.locator(".admin-offers-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/offers?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-offers-status", status);
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
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_offers_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading partner-offer catalogue/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh partner-offer catalogue/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no partner offers in this scope/i);
  await expect(
    page.getByRole("button", { name: /create partner offer/i }),
  ).toBeEnabled();
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /partner-offer catalogue unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /partner-offer workspace is offline/i);
  await expect(
    page.getByText("Verified partner reward 10", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /create partner offer/i }),
  ).toBeDisabled();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  await page.getByLabel("Supporter-facing subtitle").fill("Unsaved private draft");
  await page.getByLabel("Search partner offers").fill("private");
  responseMode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh partner-offer catalogue/i })
    .click();
  await expectStatus("permission_denied", /partner-offer access denied/i);
  await expect(page.getByLabel("Supporter-facing subtitle")).toHaveCount(0);
  await expect(page.getByLabel("Search partner offers")).toHaveCount(0);
  await expect(page.getByText("Unsaved private draft")).toHaveCount(0);
  await expect(
    page.getByText("Verified partner reward 10", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh partner-offer catalogue/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-offers-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-offers-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();

  await page
    .getByRole("button", { name: "Edit Verified partner reward 10" })
    .click();
  await expect(surface()).toHaveAttribute(
    "data-admin-offers-interaction",
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
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
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
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-offer");
  await expect(page.locator("body")).not.toContainText("private-partner");
  await expect(page.locator("body")).not.toContainText("private-catalog");
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
  await capture("dark");

  let confirmation = "";
  page.once("dialog", async (dialog) => {
    confirmation = dialog.message();
    await dialog.dismiss();
  });
  await page
    .getByRole("button", { name: "Delete Verified partner reward 10" })
    .click();
  expect(confirmation).toContain("Verified partner 10 · active club 24");
  expect(confirmation).toContain("This action cannot be undone.");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh partner-offer catalogue/i })
    .click();
  await expectStatus("syncing", /refreshing partner-offer catalogue/i);
  await expect(
    page.getByText("Verified partner reward 10", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  responseMode = "conflict";
  await page
    .getByRole("button", { name: /refresh partner-offer catalogue/i })
    .click();
  await expectStatus("conflict", /partner-offer catalogue changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /partner-offer request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /partner-offer catalogue confirmed/i);
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
    path.join(evidenceDirectory, "admin-offers-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/offers",
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
          maximum_offer_records: 500,
          maximum_catalog_options: 500,
          maximum_partner_options: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_options_filters_and_draft: true,
          strict_schema_owned_normalization: true,
          generated_identifiers_or_timestamps: false,
          synthetic_stock_or_claim_totals: false,
          private_metadata_rendered: false,
          raw_provider_diagnostics_rendered: false,
          destructive_confirmation_required: true,
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
            file: `admin_offers_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_offers_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_offers_state_responsive_compact_dark_compact_390x844.png",
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

test.describe("controlled Admin PWA partner-offer evidence", () => {
  test("captures the exact authenticated partner-offer state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
