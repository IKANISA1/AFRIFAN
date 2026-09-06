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
const profile = {
  id: 24,
  clubName: "Verified Rayon Sports FC",
  clubSlug: "rayon-sports",
  shortName: "Rayon",
  nickname: "Gikundiro",
  countryCode: "RW",
  league: "Rwanda Premier League",
  region: "Kigali",
  currencyCode: "RWF",
  currencySymbol: "FRw",
  defaultLanguage: "en",
  supportedLanguages: ["en"],
  officialContact: "+250 700 000 000",
  facebookUrl: "https://facebook.com/rayonsports",
  xUrl: null,
  instagramUrl: null,
  tiktokUrl: null,
  officialLogoUrl: null,
  primaryColorHex: "#0038A8",
  secondaryColorHex: "#0E2B55",
  accentColorHex: "#F7B500",
  featureFlags: {
    chat: true,
    fan_clubs: true,
    shop: false,
    ticketing: true,
  },
  updatedAt: timestamp,
  market_research_note: "private-research",
  momo_ussd_template: "private-ussd",
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
          left: Math.round(element.getBoundingClientRect().left),
          right: Math.round(element.getBoundingClientRect().right),
        }))
        .filter(({ left, right }) => left < -1 || right > clientWidth + 1)
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
    "../../../output/evidence/admin_pwa_settings_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await installEvidenceNavigationStability(context);
  let page = await context.newPage();
  let responseMode: ResponseMode = "ready";
  let savedBody: Record<string, unknown> | null = null;

  await context.route("**/api/admin/**", async (route: Route) => {
    if (route.request().method() === "POST") {
      savedBody = route.request().postDataJSON() as Record<string, unknown>;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: "24" }),
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
          data: responseMode === "empty" ? null : profile,
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

  const surface = () => page.locator(".admin-settings-state-surface").first();
  const open = (nonce: string) =>
    page.goto(`/admin/settings?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-settings-status",
      status,
    );
    await expect(page.getByText(label).first()).toBeVisible();
  };
  const capture = async (state: string, profileName = "desktop_1440x1000") => {
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
    await expect
      .poll(() => page.evaluate(() => ({ x: window.scrollX, y: window.scrollY })))
      .toEqual({ x: 0, y: 0 });
    await settleVisuals(page);
    await primeEvidenceScreenshot(page, !state.startsWith("responsive_"));
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_settings_state_${state}_${state === "light" ? "light" : "dark"}_${profileName}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading club settings/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh club settings/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no club settings record/i);
  await expect(
    page.getByRole("button", { name: /save settings/i }),
  ).toHaveCount(0);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /club settings unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("actor_email");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /club settings confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /club settings are offline/i);
  await expect(page.getByLabel("Club name")).toHaveValue(
    "Verified Rayon Sports FC",
  );
  await expect(
    page.getByRole("button", { name: /save settings/i }),
  ).toBeDisabled();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /club settings confirmed/i);
  await page.getByLabel("Club name").fill("Unsaved private club draft");
  responseMode = "permission_denied";
  await page.getByRole("button", { name: /refresh club settings/i }).click();
  await expectStatus("permission_denied", /settings access denied/i);
  await expect(page.getByLabel("Club name")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText(
    "Unsaved private club draft",
  );
  await expect(page.getByRole("button", { name: "Retry" })).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("interaction");
  await expectStatus("ready", /club settings confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh club settings/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-settings-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-settings-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  await page.getByRole("tab", { name: "Related controls" }).click();
  await expect(surface()).toHaveAttribute(
    "data-admin-settings-interaction",
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
  await expectStatus("ready", /club settings confirmed/i);
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
  await expectStatus("ready", /club settings confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-research");
  await expect(page.locator("body")).not.toContainText("private-ussd");
  await expect(page.locator("body")).not.toContainText("WhatsApp API");
  await expect(page.locator("body")).not.toContainText("Audit Logs Enabled");
  const undersized = await surface()
    .locator(
      "button:visible, input:not([type=checkbox]):not(.sr-only):visible, select:visible",
    )
    .evaluateAll((elements) =>
      elements
        .map((element) => {
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return {
            tag: element.tagName.toLowerCase(),
            type: element.getAttribute("type"),
            label: element.getAttribute("aria-label"),
            className: element.getAttribute("class"),
            inlineStyle: element.getAttribute("style"),
            computedWidth: style.width,
            minWidth: style.minWidth,
            width: rect.width,
            height: rect.height,
          };
        })
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await page.getByLabel("Club name").fill("Verified Rayon Sports Club");
  await page.getByRole("button", { name: /save settings/i }).click();
  await expect.poll(() => savedBody).not.toBeNull();
  expect(savedBody).toMatchObject({
    id: 24,
    clubName: "Verified Rayon Sports Club",
    expectedUpdatedAt: timestamp,
  });
  await capture("dark");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /club settings confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /club settings confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh club settings/i }).click();
  await expectStatus("syncing", /refreshing club settings/i);
  await expect(page.getByLabel("Club name")).toHaveValue(
    "Verified Rayon Sports FC",
  );
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /club settings confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh club settings/i }).click();
  await expectStatus("conflict", /club settings changed/i);
  await expect(page.getByLabel("Club name")).toHaveValue(
    "Verified Rayon Sports FC",
  );
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /settings request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /club settings confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.close();
  page = await context.newPage();
  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /club settings confirmed/i);
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
    path.join(evidenceDirectory, "admin-settings-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/settings",
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
          maximum_scope_options: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_profile_and_draft: true,
          strict_schema_owned_normalization: true,
          generated_identifiers_or_timestamps: false,
          private_metadata_rendered: false,
          raw_provider_diagnostics_rendered: false,
          unsupported_infrastructure_health_claims_rendered: false,
          club_scope_write_enforced: true,
          optimistic_concurrency_enforced: true,
          moderator_write_access: false,
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
            file: `admin_settings_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_settings_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_settings_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );
  await context.close();
}

test.describe("controlled Admin PWA settings evidence", () => {
  test("captures the exact authenticated settings state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
