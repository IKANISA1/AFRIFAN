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

type Mode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const timestamp = "2026-07-30T09:00:00.000Z";
const records = Array.from({ length: 30 }, (_, index) => ({
  id: `feature-${index + 1}`,
  clubId: 24,
  scope: "club",
  featureKey: `feature_${index + 1}`,
  displayName: `Verified feature ${index + 1}`,
  description: "Governed feature configuration.",
  category: index % 2 === 0 ? "content" : "operations",
  isEnabled: index % 3 !== 0,
  visibilityState:
    index % 7 === 0 ? "maintenance" : index % 5 === 0 ? "hidden" : "visible",
  updatedAt: new Date(Date.parse(timestamp) + index * 60_000).toISOString(),
  channels: [
    {
      id: `mobile-${index + 1}`,
      channel: "mobile",
      isEnabled: index % 3 !== 0,
      isVisible: true,
      showInNavigation: index % 2 === 0,
      showOnHome: index % 4 === 0,
      sortOrder: index,
      routeKey: `/feature-${index + 1}`,
      placementKey: "main_nav",
    },
    {
      id: `web-${index + 1}`,
      channel: "web",
      isEnabled: index % 4 !== 0,
      isVisible: true,
      showInNavigation: index % 2 !== 0,
      showOnHome: index % 5 === 0,
      sortOrder: index,
      routeKey: `/feature-${index + 1}`,
      placementKey: "home_top",
    },
  ],
  rules: {
    authRequired: index % 2 === 0,
    roleRestrictions: index % 2 === 0 ? ["member"] : [],
    dependencyRules: { minimum_version: 4 },
    rolloutRules: { percentage: 50 },
    metadata: { owner: "platform" },
    scheduleStartAt: null,
    scheduleEndAt: null,
  },
}));

async function settle(page: Page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    for (const animation of document.getAnimations()) animation.finish();
    await new Promise<void>((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
    );
  });
}

async function expectAccessible(page: Page) {
  await settle(page);
  const result = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    result.violations.filter(
      ({ impact }) => impact === "critical" || impact === "serious",
    ),
  ).toHaveLength(0);
}

async function expectNoOverflow(page: Page) {
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/implementation_goal_20260724/admin_pwa_settings_features_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
  });
  const page = await context.newPage();
  let mode: Mode = "ready";

  await page.route("**/api/admin/**", async (route: Route) => {
    if (!route.request().url().includes("/api/admin/features")) {
      await route.continue();
      return;
    }
    if (route.request().method() === "POST") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: { success: true } }),
      });
      return;
    }
    if (mode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    if (mode === "ready" || mode === "empty") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: mode === "empty" ? [] : records }),
      });
      return;
    }
    const status =
      mode === "permission_denied"
        ? 403
        : mode === "conflict"
          ? 409
          : mode === "security_timeout"
            ? 504
            : 500;
    await route.fulfill({
      status,
      contentType: "application/json",
      body: JSON.stringify({
        code: mode === "conflict" ? "STALE_RECORD" : "ADMIN_REQUEST_FAILED",
        error: "database.internal actor_email=private token=secret",
      }),
    });
  });

  const surface = () => page.locator(".admin-features-state-surface").first();
  const open = (nonce: string) =>
    page.goto(`/admin/settings/features?club=24&evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-features-status",
      status,
    );
    await expect(page.getByText(label).first()).toBeVisible();
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await page.evaluate(
      (blur) => {
        if (blur && document.activeElement instanceof HTMLElement) {
          document.activeElement.blur();
        }
        window.scrollTo(0, 0);
      },
      state === "selected" || state === "large_text",
    );
    await settle(page);
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_settings_features_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading feature registry/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh feature registry/i }),
  ).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-features-mutation-locked",
    "true",
  );
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no features in this scope/i);
  await expect(
    page.getByText(/no platform features are available/i),
  ).toBeVisible();
  await capture("empty");

  mode = "error";
  await open("error");
  await expectStatus("error", /feature registry unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("token=secret");
  await capture("error");

  mode = "conflict";
  await open("conflict");
  await expectStatus("conflict", /feature configuration changed/i);
  await capture("conflict");

  mode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /feature request timed out/i);
  await capture("security_timeout");

  mode = "ready";
  await open("offline");
  await expectStatus("ready", /feature registry confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /feature registry is offline/i);
  await expect(page.getByText("Verified feature 1")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "ready";
  await open("permission-preparation");
  await page.getByLabel("Search platform features").fill("private filter");
  await page
    .getByRole("button", { name: /configure verified feature/i })
    .first()
    .click();
  await expect(
    page.getByText(/configure verified feature/i).first(),
  ).toBeVisible();
  mode = "permission_denied";
  await page.getByRole("button", { name: /refresh feature registry/i }).click();
  await expectStatus("permission_denied", /feature access denied/i);
  await expect(page.getByLabel("Search platform features")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("private filter");
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  const refresh = page.getByRole("button", {
    name: /refresh feature registry/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-features-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-features-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await page
    .getByRole("button", { name: /configure verified feature/i })
    .first()
    .click();
  await expect(surface()).toHaveAttribute(
    "data-admin-features-interaction",
    "selected",
  );
  await expectAccessible(page);
  await capture("selected");

  await page.evaluate(() => {
    document.documentElement.style.fontSize = "200%";
  });
  await expectNoOverflow(page);
  await capture("large_text");
  await page.evaluate(() => {
    document.documentElement.style.fontSize = "";
  });
  await page.getByRole("button", { name: /cancel/i }).click();

  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
  await open("reduced-motion");
  await expectStatus("ready", /feature registry confirmed/i);
  expect(
    await page.evaluate(
      () =>
        Math.max(
          0,
          ...document
            .getAnimations()
            .map(
              (animation) =>
                Number(animation.effect?.getTiming().duration) || 0,
            ),
        ) / 1_000,
    ),
  ).toBeLessThanOrEqual(0.001);
  await capture("reduced_motion");

  await page.emulateMedia({
    reducedMotion: "no-preference",
    colorScheme: "dark",
  });
  await open("dark");
  await expectStatus("ready", /feature registry confirmed/i);
  await expectAccessible(page);
  await expectNoOverflow(page);
  await capture("dark");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /feature registry confirmed/i);
  await expectAccessible(page);
  await expectNoOverflow(page);
  await capture("light");

  for (const [profile, width, height] of [
    ["desktop_1280x800", 1280, 800],
    ["tablet_834x1112", 834, 1112],
    ["mobile_390x844", 390, 844],
  ] as const) {
    await page.setViewportSize({ width, height });
    await open(`responsive-${profile}`);
    await expectStatus("ready", /feature registry confirmed/i);
    await expectNoOverflow(page);
    await capture(`responsive_${profile}`, profile);
  }

  await context.close();
}

test.describe("admin settings feature evidence matrix", () => {
  test("covers the governed route-state and interaction matrix", async ({
    browser,
  }) => {
    await runMatrix(browser);
  });
});
