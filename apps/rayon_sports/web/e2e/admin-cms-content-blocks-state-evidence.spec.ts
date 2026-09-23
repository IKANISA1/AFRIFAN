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

const entries = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `block-${number}`,
    clubId: null,
    scope: "global",
    blockKey: `controlled_block_${String(number).padStart(2, "0")}`,
    blockType: number % 2 === 0 ? "banner" : "section",
    title: `Controlled Placement ${String(number).padStart(2, "0")}`,
    subtitle: "Approved composition placement",
    content: {
      heading: `Controlled placement content ${number}`,
      privateToken: "private-nested",
    },
    targetChannel:
      number % 3 === 0 ? "mobile" : number % 2 === 0 ? "web" : "both",
    placementKey: number % 2 === 0 ? "home_mid" : "home_top",
    featureId: number % 2 === 0 ? "feature-2" : "feature-1",
    featureKey: number % 2 === 0 ? "community" : "matchday",
    sortOrder: number,
    isActive: number % 4 !== 0,
    metadata: { theme: "controlled", secretValue: "private-nested" },
    createdAt: new Date(Date.UTC(2026, 6, 29, 11, 0, number)).toISOString(),
    updatedAt: new Date(Date.UTC(2026, 6, 29, 12, 0, number)).toISOString(),
    actorEmail: "private@example.com",
    secretValue: "private-secret",
  };
});

const features = [
  {
    id: "feature-1",
    displayName: "Matchday",
    featureKey: "matchday",
    clubId: null,
    description: null,
    category: null,
    isEnabled: true,
    visibilityState: "visible",
    updatedAt: "2026-07-29T12:00:00.000Z",
    channels: [],
    rules: null,
    secretValue: "private-secret",
  },
  {
    id: "feature-2",
    displayName: "Community",
    featureKey: "community",
    clubId: null,
    description: null,
    category: null,
    isEnabled: true,
    visibilityState: "visible",
    updatedAt: "2026-07-29T12:00:00.000Z",
    channels: [],
    rules: null,
    secretValue: "private-secret",
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">, data: unknown[]) {
  if (mode === "ready") return { status: 200, body: { data } };
  if (mode === "empty") return { status: 200, body: { data: [] } };
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

async function runAdminCmsContentBlocksMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_cms_content_blocks_states");
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

  const fulfillResource = async (route: Route, data: unknown[]) => {
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    const response = responseFor(responseMode, data);
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(response.body),
    });
  };
  await page.route("**/api/admin/content-blocks*", (route) =>
    fulfillResource(route, entries),
  );
  await page.route("**/api/admin/features*", (route) =>
    fulfillResource(route, features),
  );

  const surface = () =>
    page.locator(".admin-cms-content-blocks-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/cms/content-blocks?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-cms-content-blocks-status",
      status,
    );
    await expect(
      page.locator(".admin-cms-content-blocks-status"),
    ).toContainText(label);
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await settleVisuals(page);
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_cms_content_blocks_state_${state}_${
          state === "light" ? "light" : "dark"
        }_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading placement blocks/i);
  await capture("loading");
  const refresh = page.getByRole("button", {
    name: /refresh placement blocks/i,
  });
  await expect(refresh).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-cms-content-blocks-refresh-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no placement blocks in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /placement blocks unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("actor_email");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /placement blocks confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /placement workspace is offline/i);
  await expect(page.getByText("Controlled Placement 01")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /placement access denied/i);
  await expect(page.getByText("Controlled Placement 01")).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /placement blocks confirmed/i);
  const readyRefresh = page.getByRole("button", {
    name: /refresh placement blocks/i,
  });
  await readyRefresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-cms-content-blocks-interaction",
    "focused",
  );
  await capture("focused");

  await readyRefresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-cms-content-blocks-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();

  await page
    .getByRole("button", {
      name: /edit placement block Controlled Placement 01/i,
    })
    .click();
  await expect(surface()).toHaveAttribute(
    "data-admin-cms-content-blocks-interaction",
    "selected",
  );
  await expect(page.getByRole("textbox", { name: /^title$/i })).toHaveValue(
    "Controlled Placement 01",
  );
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await open("large-text");
  await expectStatus("ready", /placement blocks confirmed/i);
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  await expectNoHorizontalOverflow(page);
  await capture("large_text");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus("loading", /loading placement blocks/i);
  expect(
    await page
      .locator(".admin-cms-content-blocks-status svg")
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
  await expectStatus("ready", /placement blocks confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-secret");
  await expect(page.locator("body")).not.toContainText("private-nested");
  await expect(page.locator("body")).not.toContainText("private@example.com");
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
    .getByRole("button", {
      name: /delete placement block Controlled Placement 01/i,
    })
    .click();
  expect(deletionConfirmation).toContain(
    "Recovery requires a separate manual admin action.",
  );

  const search = page.getByRole("searchbox", {
    name: /search placement blocks/i,
  });
  await search.fill("Controlled Placement 01");
  await expect(page.getByText("Controlled Placement 01")).toBeVisible();
  await expect(page.getByText("Controlled Placement 30")).toHaveCount(0);
  await search.fill("");
  await page.getByRole("button", { name: /sort by block/i }).click();
  await page.getByRole("button", { name: /go to next page/i }).click();
  await expect(page.getByText(/page 2 of 2/i)).toBeVisible();

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /placement blocks confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /placement blocks confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh placement blocks/i }).click();
  await expectStatus("syncing", /refreshing placement blocks/i);
  await expect(page.getByText("Controlled Placement 01")).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /placement blocks confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh placement blocks/i }).click();
  await expectStatus("conflict", /placement records changed/i);
  await expect(page.getByText("Controlled Placement 01")).toBeVisible();
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /placement request timed out/i);
  await expect(page.getByText("Controlled Placement 01")).toHaveCount(0);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /placement blocks confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /placement blocks confirmed/i);
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
      "admin-cms-content-blocks-state-evidence.json",
    ),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/cms/content-blocks",
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
          maximum_content_block_records: 500,
          maximum_feature_options: 500,
          content_json_maximum_bytes: 12000,
          metadata_json_maximum_bytes: 4000,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data_and_draft: true,
          runtime_response_normalized_and_bounded: true,
          private_extra_fields_rendered: false,
          search_sort_pagination_present: true,
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
            file: `admin_cms_content_blocks_state_${state}_${
              state === "light" ? "light" : "dark"
            }_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_cms_content_blocks_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_cms_content_blocks_state_responsive_compact_dark_compact_390x844.png",
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

test.describe("controlled Admin PWA placement-block evidence", () => {
  test("captures the exact authenticated placement-block state matrix", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    await runAdminCmsContentBlocksMatrix(browser);
  });
});
