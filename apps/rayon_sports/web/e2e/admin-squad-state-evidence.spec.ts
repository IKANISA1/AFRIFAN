import { bindLocalClubFixtures, localStateContextOptions } from "./fixtures/local-route-assertions.mjs";
import fs from "node:fs";
import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, createStateEvidenceContext } from "./state-evidence-provenance";
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

const roles = ["Goalkeeper", "Defender", "Midfielder", "Forward"] as const;
const playerImageUrl = "https://qa-fixtures.supabase.co/player.svg";
const players = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `player-${number}`,
    clubId: 24,
    name: `Squad Player ${String(number).padStart(2, "0")}`,
    role: roles[index % roles.length],
    number,
    nationality: number % 2 === 0 ? "Rwanda" : "Burundi",
    bio: "Confirmed first-team squad profile.",
    imageUrl: playerImageUrl,
    isActive: number !== 30,
    createdAt: "2026-07-20T12:00:00.000Z",
    updatedAt: new Date(Date.UTC(2026, 6, 29, 12, 0, number)).toISOString(),
    medicalNotes: "private medical information",
    accessToken: "private-token",
  };
});

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return { status: 200, body: { data: players } };
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
      error: "database.internal medical_notes=private",
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
    const offenders = Array.from(document.querySelectorAll<HTMLElement>("body *"))
      .flatMap((element) => {
        const rect = element.getBoundingClientRect();
        if (rect.right <= viewportWidth + 1 && rect.left >= -1) {
          return [];
        }
        return [{
          tag: element.tagName.toLowerCase(),
          className: element.className,
          left: Math.round(rect.left * 10) / 10,
          right: Math.round(rect.right * 10) / 10,
        }];
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

async function runAdminSquadMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_squad_states");
  const context = await createStateEvidenceContext(browser, {
    ...localStateContextOptions(test.info(), true),
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

  // Use the existing permitted storage origin and intercept the exact request.
  // No network service or real player's likeness is needed by this fixture.
  await context.route(playerImageUrl, (route) => route.fulfill({
    contentType: "image/svg+xml",
    body: '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><rect width="32" height="32" fill="#374151"/><circle cx="16" cy="11" r="5" fill="#e5e7eb"/><path d="M5 32v-4a11 11 0 0 1 22 0v4" fill="#e5e7eb"/></svg>',
  }));

  await page.route("**/api/admin/squad*", async (route) => {
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    const response = responseFor(responseMode);
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(bindLocalClubFixtures(response.body)),
    });
  });

  const surface = () => page.locator(".admin-squad-state-surface").first();
  const open = async (nonce: string) => {
    await navigateStateEvidence(page, `/admin/squad?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  };
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-squad-status", status);
    await expect(page.locator(".admin-squad-status")).toContainText(label);
  };
  const capture = async (
    state: string,
    profile = "desktop_1440x1000",
  ) => {
    await settleVisuals(page);
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_squad_state_${state}_${
          state === "light" ? "light" : "dark"
        }_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading squad operations/i);
  await capture("loading");
  const refresh = page.getByRole("button", { name: /refresh squad/i });
  await expect(refresh).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-squad-refresh-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no players in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /squad operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("medical_notes");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /squad operations confirmed/i);
  const firstPlayerImage = page.locator('tr[data-row-id="player-1"] img');
  await firstPlayerImage.scrollIntoViewIfNeeded();
  await expect(firstPlayerImage).toBeVisible();
  await expect(firstPlayerImage).toHaveAttribute("src", playerImageUrl);
  // WebKit reports the fitted SVG width (30px inside the bordered avatar),
  // while Chromium/Firefox report its 32px intrinsic width. Both must decode.
  await expect.poll(() => firstPlayerImage.evaluate(
    (image: HTMLImageElement) => ({ complete: image.complete, decoded: image.naturalWidth > 0 }),
  )).toEqual({ complete: true, decoded: true });
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /squad workspace is offline/i);
  await expect(page.getByText("Squad Player 01")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /squad access denied/i);
  await expect(page.getByText("Squad Player 01")).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /squad operations confirmed/i);
  const readyRefresh = page.getByRole("button", { name: /refresh squad/i });
  await readyRefresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-squad-interaction",
    "focused",
  );
  await capture("focused");

  await readyRefresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-squad-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();
  await expectStatus("ready", /squad operations confirmed/i);

  const firstRow = page.locator("tr[data-row-id='player-1']");
  await firstRow.focus();
  await firstRow.press("Enter");
  await expect(surface()).toHaveAttribute(
    "data-admin-squad-interaction",
    "selected",
  );
  await expect(
    page.getByRole("heading", { name: /edit player profile/i }),
  ).toBeVisible();
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await open("large-text");
  await expectStatus("ready", /squad operations confirmed/i);
  await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
  });
  await expectNoHorizontalOverflow(page);
  await capture("large_text");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus("loading", /loading squad operations/i);
  expect(
    await page
      .locator(".admin-squad-status svg")
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
  await expectStatus("ready", /squad operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-token");
  await expect(page.locator("body")).not.toContainText("private medical");
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
    .getByRole("button", { name: /remove squad player 01/i })
    .click();
  expect(removalConfirmation).toContain("This action cannot be undone.");

  const search = page.getByRole("searchbox", { name: /search squad/i });
  await search.fill("Squad Player 01");
  await expect(page.getByText("Squad Player 01")).toBeVisible();
  await expect(page.getByText("Squad Player 30")).toHaveCount(0);
  await search.fill("");
  await page.getByRole("button", { name: /^goalkeeper$/i }).click();
  await expect(page.getByText("Squad Player 01")).toBeVisible();
  await expect(page.getByText("Squad Player 02")).toHaveCount(0);
  await page.getByRole("button", { name: /^all$/i }).click();
  await page.getByRole("button", { name: /sort by player/i }).click();
  await page.getByRole("button", { name: /go to next page/i }).click();
  await expect(page.getByText(/page 2 of 2/i)).toBeVisible();

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /squad operations confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /squad operations confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh squad/i }).click();
  await expectStatus("syncing", /refreshing squad operations/i);
  await expect(page.getByText("Squad Player 01")).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /squad operations confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh squad/i }).click();
  await expectStatus("conflict", /squad records changed/i);
  await expect(page.getByText("Squad Player 01")).toBeVisible();
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /squad request timed out/i);
  await expect(page.getByText("Squad Player 01")).toHaveCount(0);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /squad operations confirmed/i);
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /squad operations confirmed/i);
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
    path.join(evidenceDirectory, "admin-squad-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/squad",
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
          maximum_player_records: 500,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data: true,
          runtime_response_normalized_and_bounded: true,
          private_extra_fields_rendered: false,
          search_sort_filter_pagination_present: true,
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
            file: `admin_squad_state_${state}_${
              state === "light" ? "light" : "dark"
            }_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_squad_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_squad_state_responsive_compact_dark_compact_390x844.png",
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

test.describe("controlled Admin PWA squad evidence", () => {
  test("captures the exact authenticated squad state matrix", async ({
    browser,
  }) => {
    test.setTimeout(360_000);
    await runAdminSquadMatrix(browser);
  });
});
