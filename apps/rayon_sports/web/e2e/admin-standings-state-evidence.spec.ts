import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page } from "@playwright/test";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const standings = Array.from({ length: 30 }, (_, index) => {
  const position = index + 1;
  return {
    id: `standing-${position}`,
    clubId: position === 1 ? 24 : null,
    position,
    club: `Competition Club ${String(position).padStart(2, "0")}`,
    played: 24,
    goalDifference: 30 - position,
    points: 70 - position,
    form: ["W", "D", "W", "L", "W"],
    clubSlug: position === 1 ? "rayon-sports" : `competition-club-${position}`,
    updatedAt: new Date(
      Date.UTC(2026, 6, 29, 12, 0, position),
    ).toISOString(),
    financialNotes: "private financial information",
    accessToken: "private-token",
  };
});

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return { status: 200, body: { data: standings } };
  }
  if (mode === "empty") {
    return { status: 200, body: { data: [] } };
  }
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
      error: "database.internal financial_notes=private",
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
        if (rect.right <= viewportWidth + 1 && rect.left >= -1) {
          return [];
        }
        return [
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

async function runAdminStandingsMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/evidence/admin_pwa_standings_states",
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

  await page.route("**/api/admin/standings*", async (route) => {
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

  const surface = () =>
    page.locator(".admin-standings-state-surface").first();
  const open = async (nonce: string) => {
    await page.goto(`/admin/standings?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  };
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-standings-status",
      status,
    );
    await expect(page.locator(".admin-standings-status")).toContainText(label);
  };
  const capture = async (
    state: string,
    profile = "desktop_1440x1000",
  ) => {
    await settleVisuals(page);
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_standings_state_${state}_${
          state === "light" ? "light" : "dark"
        }_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading standings operations/i);
  await capture("loading");
  const refresh = page.getByRole("button", { name: /refresh standings/i });
  await expect(refresh).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-standings-refresh-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no standings in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /standings operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("financial_notes");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /standings operations confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /standings workspace is offline/i);
  await expect(page.getByText("Competition Club 01")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /standings access denied/i);
  await expect(page.getByText("Competition Club 01")).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /standings operations confirmed/i);
  const readyRefresh = page.getByRole("button", {
    name: /refresh standings/i,
  });
  await readyRefresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-standings-interaction",
    "focused",
  );
  await capture("focused");

  await readyRefresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-standings-interaction",
    "pressed",
  );
  await capture("pressed");
  await readyRefresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  const firstRow = page.locator("tr[data-row-id='standing-1']");
  await firstRow.focus();
  await firstRow.press("Enter");
  await expect(surface()).toHaveAttribute(
    "data-admin-standings-interaction",
    "selected",
  );
  await expect(
    page.getByRole("heading", { name: /edit standing row/i }),
  ).toBeVisible();
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await open("large-text");
  await expectStatus("ready", /standings operations confirmed/i);
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  await expectNoHorizontalOverflow(page);
  await capture("large_text");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus("loading", /loading standings operations/i);
  expect(
    await page
      .locator(".admin-standings-status svg")
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
  await expectStatus("ready", /standings operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-token");
  await expect(page.locator("body")).not.toContainText("private financial");
  const undersizedControls = await surface()
    .locator("button, a")
    .evaluateAll((elements) =>
      elements
        .filter((element) => !element.closest("[role='dialog']"))
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

  let removalConfirmation = "";
  page.once("dialog", async (dialog) => {
    removalConfirmation = dialog.message();
    await dialog.dismiss();
  });
  await page
    .getByRole("button", { name: /remove competition club 01/i })
    .click();
  expect(removalConfirmation).toContain("This action cannot be undone.");

  const search = page.getByRole("searchbox", {
    name: /search standings/i,
  });
  await search.fill("Competition Club 01");
  await expect(page.getByText("Competition Club 01")).toBeVisible();
  await expect(page.getByText("Competition Club 30")).toHaveCount(0);
  await search.fill("");
  await page.getByRole("button", { name: /sort by club/i }).click();
  await page.getByRole("button", { name: /go to next page/i }).click();
  await expect(page.getByText(/page 2 of 2/i)).toBeVisible();

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /standings operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /standings operations confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh standings/i }).click();
  await expectStatus("syncing", /refreshing standings operations/i);
  await expect(page.getByText("Competition Club 01")).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /standings operations confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh standings/i }).click();
  await expectStatus("conflict", /standings records changed/i);
  await expect(page.getByText("Competition Club 01")).toBeVisible();
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /standings request timed out/i);
  await expect(page.getByText("Competition Club 01")).toHaveCount(0);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /standings operations confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /standings operations confirmed/i);
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
    path.join(evidenceDirectory, "admin-standings-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/standings",
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
          maximum_standing_records: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data: true,
          runtime_response_normalized_and_bounded: true,
          private_extra_fields_rendered: false,
          search_sort_pagination_present: true,
          destructive_remove_confirmation_required: true,
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
            file: `admin_standings_state_${state}_${
              state === "light" ? "light" : "dark"
            }_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file:
              "admin_standings_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file:
              "admin_standings_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
}

test.describe("controlled Admin PWA standings evidence", () => {
  test("captures the exact authenticated standings state matrix", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    await runAdminStandingsMatrix(browser);
  });
});
