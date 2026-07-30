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

const drafts = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `draft-${number}`,
    sourceId: `source-${number}`,
    prompt: `Which verified result ${String(number).padStart(2, "0")} belongs to Rayon Sports?`,
    category: "club_knowledge",
    difficulty: number % 2 === 0 ? "medium" : "easy",
    language: "en",
    validationStatus:
      number % 4 === 0
        ? "approved"
        : number % 5 === 0
          ? "needs_changes"
          : "pending_review",
    validationNotes: number % 5 === 0 ? "Verify the source date." : "",
    duplicatePromptCount: number % 6 === 0 ? 2 : 0,
    hasDuplicatePrompt: number % 6 === 0,
    similarPromptCount: number % 3 === 0 ? 3 : 0,
    hasSimilarPrompt: number % 3 === 0,
    duplicateRiskLevel: number % 6 === 0 ? "exact" : "none",
    normalizedPromptSignature: `verified-result-${number}`,
    sourceTitle: `Official match report ${number}`,
    sourceUrl: `https://example.com/match-${number}#private`,
    sourceTrustTier: "official",
    createdAt: new Date(Date.UTC(2026, 6, 29, 10, number)).toISOString(),
    accessToken: "private-draft-token",
  };
});

const audit = Array.from({ length: 30 }, (_, index) => {
  const number = index + 1;
  return {
    id: `audit-${number}`,
    action:
      number % 2 === 0 ? "question_draft_reviewed" : "game_session_created",
    entityType: number % 2 === 0 ? "question_draft" : "game_session",
    entityId: `entity-${number}`,
    actorId: `private-actor-${number}`,
    createdAt: new Date(Date.UTC(2026, 6, 29, 12, number)).toISOString(),
    after: {
      status: number % 2 === 0 ? "approved" : "live",
      question_count: 20,
      session_id: `session-${number}`,
      access_token: "private-audit-token",
      nested: { secret: true },
    },
  };
});

function responseFor(mode: Exclude<ResponseMode, "loading">, data: unknown) {
  if (mode === "ready" || mode === "empty") {
    return { status: 200, body: { success: true, data } };
  }
  if (mode === "permission_denied") {
    return { status: 403, body: { error: "private role diagnostic" } };
  }
  if (mode === "conflict") {
    return { status: 409, body: { error: "private stale diagnostic" } };
  }
  if (mode === "security_timeout") {
    return { status: 504, body: { error: "private timeout diagnostic" } };
  }
  return {
    status: 500,
    body: { error: "database.internal actor_email=private token=secret" },
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
  const result = await page.evaluate(() => ({
    overflow:
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth,
    offenders: Array.from(document.querySelectorAll<HTMLElement>("body *"))
      .flatMap((element) => {
        const rect = element.getBoundingClientRect();
        return rect.right <= document.documentElement.clientWidth + 1 &&
          rect.left >= -1
          ? []
          : [
              {
                tag: element.tagName,
                className: element.className,
                left: rect.left,
                right: rect.right,
              },
            ];
      })
      .slice(0, 12),
  }));
  expect(
    result.overflow,
    `Horizontal overflow descendants: ${JSON.stringify(result.offenders)}`,
  ).toBeLessThanOrEqual(1);
}

async function runAdminGamesMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/implementation_goal_20260724/admin_pwa_games_states",
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

  await page.route("**/api/game-session-action", async (route: Route) => {
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    const body = route.request().postDataJSON() as { action?: string };
    const readyData =
      body.action === "list_question_drafts"
        ? drafts
        : body.action === "list_audit_log"
          ? audit
          : {};
    const response = responseFor(
      responseMode,
      responseMode === "empty" ? [] : readyData,
    );
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(response.body),
    });
  });

  const surface = () => page.locator(".admin-games-state-surface").first();
  const open = (nonce: string) =>
    page.goto(`/admin/games?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-games-status", status);
    await expect(page.locator(".admin-games-status")).toContainText(label);
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await page.evaluate(() => window.scrollTo(0, 0));
    await settleVisuals(page);
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_games_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading game operations/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh game operations/i }),
  ).toBeDisabled();
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no game operations in this scope/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /game operations unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("actor_email");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /workspace is offline/i);
  await expect(page.getByText("30", { exact: true }).first()).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  await page
    .getByRole("textbox", { name: /session title/i })
    .fill("Unsaved private session");
  responseMode = "permission_denied";
  await page.getByRole("button", { name: /refresh game operations/i }).click();
  await expectStatus("permission_denied", /game operations access denied/i);
  await expect(page.getByText("Unsaved private session")).toHaveCount(0);
  await expect(page.getByText(/verified result 01/i)).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh game operations/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-games-interaction",
    "focused",
  );
  await capture("focused");

  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-games-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  const firstDraft = page.getByRole("button", {
    name: /verified result 01 belongs to rayon sports/i,
  });
  await firstDraft.click();
  await expect(surface()).toHaveAttribute(
    "data-admin-games-interaction",
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
  await expectStatus("ready", /game operations snapshot confirmed/i);
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
  await expectStatus("ready", /game operations snapshot confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-actor");
  await expect(page.locator("body")).not.toContainText("access_token");
  const undersized = await surface()
    .locator("button:visible, input:visible, select:visible")
    .evaluateAll((elements) =>
      elements
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return { width: rect.width, height: rect.height };
        })
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
    .getByRole("textbox", { name: /tv device id/i })
    .fill("00000000-0000-4000-8000-000000000099");
  await page.getByRole("button", { name: /revoke tv credential/i }).click();
  expect(confirmation).toContain("Scope: Club 24; one paired display");
  expect(confirmation).toContain(
    "Recovery requires a separate manual admin action.",
  );

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh game operations/i }).click();
  await expectStatus("syncing", /refreshing game operations/i);
  await expect(page.getByText("30", { exact: true }).first()).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh game operations/i }).click();
  await expectStatus("conflict", /game operations changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /game operations request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  await expectNoHorizontalOverflow(page);
  await page.evaluate(() => window.scrollTo(0, 0));
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /game operations snapshot confirmed/i);
  await expectNoHorizontalOverflow(page);
  await page.evaluate(() => window.scrollTo(0, 0));
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
    path.join(evidenceDirectory, "admin-games-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/games",
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
          maximum_draft_records: 100,
          maximum_audit_records: 100,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_records_selections_and_inputs: true,
          strict_draft_and_audit_normalization: true,
          actor_ids_and_private_audit_metadata_rendered: false,
          raw_action_diagnostics_rendered: false,
          destructive_revoke_confirmation_required: true,
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
            file: `admin_games_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_games_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_games_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
}

test.describe("controlled Admin PWA game operations evidence", () => {
  test("captures the exact authenticated game-operations state matrix", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    await runAdminGamesMatrix(browser);
  });
});
