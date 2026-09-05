import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { writeAdminStateEvidence } from "./admin-state-evidence-manifest";
import {
  installEvidenceNavigationStability,
  primeEvidenceScreenshot,
  settleEvidenceVisuals,
} from "./evidence-navigation-stability";
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

async function settle(page: Page) {
  await settleEvidenceVisuals(page);
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
    "../../../output/evidence/admin_pwa_venues_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
  });
  await installEvidenceNavigationStability(context);
  let page = await context.newPage();
  let mode: Mode = "ready";

  await context.route("**/api/admin/**", async (route: Route) => {
    if (!route.request().url().includes("/api/admin/venues-overview")) {
      await route.continue();
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
        body: JSON.stringify({
          data:
            mode === "empty"
              ? {
                  venueCount: 0,
                  activeCampaigns: 0,
                  openOrders: 0,
                  checkinsToday: 0,
                }
              : {
                  venueCount: 4,
                  activeCampaigns: 2,
                  openOrders: 8,
                  checkinsToday: 36,
                },
        }),
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
        error: "database.internal venue_owner=private token=secret",
      }),
    });
  });

  const surface = () => page.locator("[data-admin-venues-status]").first();
  const open = (nonce: string) =>
    page.goto(`/admin/venues?club=24&evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-venues-status", status, {
      timeout: 15_000,
    });
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
    await primeEvidenceScreenshot(page, !state.startsWith("responsive_"));
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_venues_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading venue oversight/i);
  await expect(
    page.getByRole("button", { name: /refresh venue oversight/i }),
  ).toBeDisabled();
  await capture("loading");
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no venue activity in this club/i);
  await expect(page.getByText("Club scope confirmed")).toBeVisible();
  await capture("empty");

  for (const [failureMode, label] of [
    ["error", /venue oversight unavailable/i],
    ["conflict", /venue oversight changed/i],
    ["security_timeout", /venue oversight request timed out/i],
  ] as const) {
    mode = failureMode;
    await open(failureMode);
    await expectStatus(failureMode, label);
    await expect(page.locator("body")).not.toContainText("database.internal");
    await expect(page.locator("body")).not.toContainText("token=secret");
    await capture(failureMode);
  }

  mode = "ready";
  await open("offline");
  await expectStatus("ready", /venue oversight confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /venue oversight is offline/i);
  await expect(page.getByText("36").first()).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "permission_denied";
  await open("permission-denied");
  await expectStatus("permission_denied", /venue oversight access denied/i);
  await expect(page.getByText("Scope unconfirmed")).toBeVisible();
  await expect(page.getByRole("link", { name: /export csv/i })).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  await expectStatus("ready", /venue oversight confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh venue oversight/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-venues-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-venues-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  const exportLink = page.getByRole("link", { name: /export csv/i });
  await exportLink.click();
  await expect(surface()).toHaveAttribute(
    "data-admin-venues-interaction",
    "selected",
  );
  await capture("selected");

  await page.evaluate(() => {
    document.documentElement.style.fontSize = "200%";
  });
  await expectNoOverflow(page);
  await capture("large_text");
  await page.evaluate(() => {
    document.documentElement.style.fontSize = "";
  });

  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
  await open("reduced-motion");
  await expectStatus("ready", /venue oversight confirmed/i);
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
  await expectAccessible(page);
  await expectNoOverflow(page);
  await capture("dark");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectAccessible(page);
  await expectNoOverflow(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  for (const [profile, width, height] of [
    ["desktop_1280x800", 1280, 800],
    ["tablet_834x1112", 834, 1112],
    ["mobile_390x844", 390, 844],
  ] as const) {
    if (width === 390) {
      await page.close();
      page = await context.newPage();
    }
    await page.setViewportSize({ width, height });
    await open(`responsive-${profile}`);
    await expectStatus("ready", /venue oversight confirmed/i);
    await expectNoOverflow(page);
    await capture(`responsive_${profile}`, profile);
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  mode = "ready";
  await open("syncing-preparation");
  await expectStatus("ready", /venue oversight confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh venue oversight/i }).click();
  await expectStatus("syncing", /refreshing venue oversight/i);
  await expect(page.getByText("Club scope confirmed")).toBeVisible();
  await capture("syncing");

  writeAdminStateEvidence({
    evidenceDirectory,
    manifestFile: "admin-venues-state-evidence.json",
    route: "/admin/venues",
    filePrefix: "admin_venues",
    responsiveCaptures: [
      {
        state: "responsive_desktop_1280x800",
        profile: "desktop_1280x800",
        description: "Chromium desktop 1280x800 at 1 DPR",
      },
      {
        state: "responsive_tablet_834x1112",
        profile: "tablet_834x1112",
        description: "Chromium tablet 834x1112 at 1 DPR",
      },
      {
        state: "responsive_mobile_390x844",
        profile: "mobile_390x844",
        description: "Chromium mobile 390x844 at 1 DPR",
      },
    ],
    assertions: {
      club_scope_required: true,
      supporter_identity_rendered: false,
      syncing_retains_confirmed_venue_snapshot: true,
    },
  });

  await context.close();
}

test.describe("admin venues evidence matrix", () => {
  test("covers the governed route-state and interaction matrix", async ({
    browser,
  }) => {
    await runMatrix(browser);
  });
});
