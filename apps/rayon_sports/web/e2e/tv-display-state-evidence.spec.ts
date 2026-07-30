import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

const evidenceDirectory = path.resolve(
  process.cwd(),
  "../../../output/implementation_goal_20260724/consumer_web_tv_display_states",
);
const sessionId = "00000000-0000-4000-8000-000000000001";

type ResponseMode =
  | "loading"
  | "live"
  | "empty"
  | "error"
  | "permission_denied"
  | "disabled"
  | "syncing"
  | "conflict"
  | "security_timeout";

const liveState = {
  sessionId,
  clubId: 24,
  title: "Matchday Quiz Display",
  phase: "open",
  joinCode: "RAYON24",
  questionIndex: 4,
  questionTotal: 20,
  updatedAt: "2026-07-29T09:45:00.000Z",
  currentQuestion: {
    id: "00000000-0000-4000-8000-000000000101",
    order: 4,
    phase: "open",
    prompt: "Which season delivered the first league title of the modern era?",
    category: "Club history",
    difficulty: "medium",
    timeLimitSeconds: 20,
    openedAt: "2026-07-29T09:44:40.000Z",
    claim: null,
    options: [
      { key: "a", label: "1995" },
      { key: "b", label: "1998" },
      { key: "c", label: "2002" },
      { key: "d", label: "2004" },
    ],
  },
  leaderboard: [
    { rank: 1, teamName: "East Stand", score: 820 },
    { rank: 2, teamName: "Blue Zone", score: 760 },
    { rank: 3, teamName: "Away Corner", score: 610 },
  ],
};

const emptyState = {
  ...liveState,
  phase: "lobby",
  questionIndex: 0,
  questionTotal: 0,
  currentQuestion: null,
  leaderboard: [],
};

function responseFor(mode: ResponseMode) {
  if (mode === "empty") {
    return { status: 200, body: { success: true, data: emptyState } };
  }
  if (mode === "disabled") {
    return {
      status: 200,
      body: {
        success: true,
        data: { ...emptyState, phase: "closed", title: "Matchday round closed" },
      },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        success: false,
        code: "EDGE_FUNCTION_PERMISSION_DENIED",
        error: "Display access denied.",
      },
    };
  }
  if (mode === "conflict") {
    return {
      status: 409,
      body: {
        success: false,
        code: "EDGE_FUNCTION_CONFLICT",
        error: "Session state changed.",
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        success: false,
        code: "EDGE_FUNCTION_TIMEOUT",
        error: "The session update timed out.",
      },
    };
  }
  if (mode === "error") {
    return {
      status: 500,
      body: {
        success: false,
        code: "EDGE_FUNCTION_FAILURE",
        error: "The session is temporarily unavailable.",
      },
    };
  }
  return { status: 200, body: { success: true, data: liveState } };
}

async function capture(page: Page, state: string) {
  await page.screenshot({
    path: path.join(
      evidenceDirectory,
      `tv_display_state_${state}_1280x720.png`,
    ),
    fullPage: true,
    animations: "disabled",
  });
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator("main[data-tv-display-status]")).toHaveAttribute(
    "data-tv-display-status",
    status,
  );
  await expect(page.locator("[data-tv-status]")).toContainText(label);
}

async function openLiveRoute(page: Page, nonce: string) {
  await page.goto(`/tv-display?session_id=${sessionId}&evidence=${nonce}`, {
    waitUntil: "domcontentloaded",
  });
}

async function expectNoSeriousAxeViolations(page: Page) {
  const axeResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    axeResults.violations.filter(
      (violation) =>
        violation.impact === "critical" || violation.impact === "serious",
    ),
  ).toHaveLength(0);
}

test.beforeAll(() => {
  fs.mkdirSync(evidenceDirectory, { recursive: true });
});

test("tv display proves all thirteen applicable display-only states", async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "The display-only evidence uses one declared 1280 × 720 Chromium profile.",
  );

  const context: BrowserContext = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  let mode: ResponseMode = "live";
  let requestCount = 0;

  await page.route("**/api/game-session-action", async (route) => {
    requestCount += 1;
    if (mode === "loading" || (mode === "syncing" && requestCount > 1)) {
      await new Promise<void>(() => {});
      return;
    }
    const response = responseFor(mode);
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(response.body),
    });
  });

  mode = "loading";
  requestCount = 0;
  await openLiveRoute(page, "loading");
  await expectStatus(page, "loading", /connecting/i);
  await expect(page.getByText(/modern era/i)).toHaveCount(0);
  await capture(page, "loading_dark");

  mode = "empty";
  requestCount = 0;
  await openLiveRoute(page, "empty");
  await expectStatus(page, "empty", /waiting room/i);
  await expect(page.getByText("Waiting for question")).toBeVisible();
  await capture(page, "empty_dark");

  mode = "error";
  requestCount = 0;
  await openLiveRoute(page, "error");
  await expectStatus(page, "error", /connection paused/i);
  await expect(page.getByText(/ask the host to retry/i).last()).toBeVisible();
  await capture(page, "error_dark");

  mode = "live";
  requestCount = 0;
  await openLiveRoute(page, "offline");
  await expectStatus(page, "live", /live session/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /offline/i);
  await expect(page.getByText(/modern era/i)).toBeVisible();
  await capture(page, "offline_dark");
  await context.setOffline(false);

  mode = "permission_denied";
  requestCount = 0;
  await openLiveRoute(page, "permission");
  await expectStatus(page, "permission_denied", /display access denied/i);
  await expect(page.locator("main aside[role='alert']")).toContainText(
    /new display link/i,
  );
  await expect(page.getByText(/modern era/i)).toHaveCount(0);
  await capture(page, "permission_denied_dark");

  mode = "disabled";
  requestCount = 0;
  await openLiveRoute(page, "disabled");
  await expectStatus(page, "disabled", /session closed/i);
  await expect(page.getByText(/no longer accepting updates/i)).toBeVisible();
  await capture(page, "disabled_dark");

  mode = "live";
  requestCount = 0;
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await page.goto("/tv-display?evidence=large-text", {
    waitUntil: "domcontentloaded",
  });
  await page.addStyleTag({
    content: "html { font-size: 200% !important; }",
  });
  await expect(page.getByText(/demo mode/i)).toBeVisible();
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  await capture(page, "large_text_dark");

  mode = "loading";
  requestCount = 0;
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await openLiveRoute(page, "reduced-motion");
  await expectStatus(page, "loading", /connecting/i);
  expect(
    await page
      .locator("[data-tv-status] svg")
      .evaluate((element) => Number.parseFloat(getComputedStyle(element).animationDuration)),
  ).toBeLessThanOrEqual(0.001);
  await capture(page, "reduced_motion_dark");

  mode = "live";
  requestCount = 0;
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await page.goto("/tv-display?evidence=dark", {
    waitUntil: "domcontentloaded",
  });
  expect(
    await page
      .locator("main")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(248, 250, 252)");
  await capture(page, "dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await page.goto("/tv-display?evidence=light", {
    waitUntil: "domcontentloaded",
  });
  expect(
    await page
      .locator("main")
      .evaluate((element) => getComputedStyle(element).color),
  ).toBe("rgb(15, 23, 42)");
  await capture(page, "light_light");
  await expectNoSeriousAxeViolations(page);

  mode = "syncing";
  requestCount = 0;
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await openLiveRoute(page, "syncing");
  await expectStatus(page, "live", /live session/i);
  await page.waitForTimeout(5100);
  await expectStatus(page, "syncing", /updating/i);
  await expect(page.getByText(/modern era/i)).toBeVisible();
  await capture(page, "syncing_dark");

  mode = "conflict";
  requestCount = 0;
  await openLiveRoute(page, "conflict");
  await expectStatus(page, "conflict", /session changed/i);
  await expect(page.getByText(/reload current state/i).last()).toBeVisible();
  await capture(page, "conflict_dark");

  mode = "security_timeout";
  requestCount = 0;
  await openLiveRoute(page, "timeout");
  await expectStatus(page, "security_timeout", /update timed out/i);
  await expect(page.getByText(/no change is assumed/i).last()).toBeVisible();
  await capture(page, "security_timeout_dark");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await page.goto("/tv-display?evidence=accessibility", {
    waitUntil: "domcontentloaded",
  });
  await expect(page.locator("main a, main button, main input, main select")).toHaveCount(
    0,
  );
  await expectNoSeriousAxeViolations(page);

  await context.close();
});
