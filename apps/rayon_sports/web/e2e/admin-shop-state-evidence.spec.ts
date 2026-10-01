import { localStateContextOptions } from "./fixtures/local-route-assertions.mjs";
import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, createStateEvidenceContext } from "./state-evidence-provenance";
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

const timestamp = "2026-07-30T09:00:00.000Z";
const products = Array.from({ length: 24 }, (_, index) => ({
  id: `product-${index + 1}`,
  clubId: 24,
  name: `Verified product ${index + 1}`,
  subtitle: "Official supporter merchandise",
  description: "A governed, club-scoped catalogue record.",
  category: index % 2 === 0 ? "Merch" : "Accessories",
  price: 15_000 + index * 1_000,
  imageUrl: null,
  sizes: ["S", "M", "L"],
  isActive: index % 4 !== 0,
  collection: index % 2 === 0 ? "Home" : "Supporters",
  sortOrder: index,
  createdAt: timestamp,
  updatedAt: new Date(Date.parse(timestamp) + index * 60_000).toISOString(),
}));

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
  const result = await page.evaluate(() => {
    const clientWidth = document.documentElement.clientWidth;
    return {
      overflow: document.documentElement.scrollWidth - clientWidth,
      offenders: Array.from(document.querySelectorAll<HTMLElement>("body *"))
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return {
            tag: element.tagName.toLowerCase(),
            className: element.className,
            left: Math.round(rect.left),
            right: Math.round(rect.right),
          };
        })
        .filter(({ left, right }) => left < -1 || right > clientWidth + 1)
        .slice(0, 20),
    };
  });
  expect(result.overflow, JSON.stringify(result.offenders)).toBeLessThanOrEqual(
    1,
  );
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_shop_states");
  const context = await createStateEvidenceContext(browser, {
    ...localStateContextOptions(test.info(), true),
    // API fixtures must bypass worker interception; PWA lifecycle has its own tests.
    serviceWorkers: "block",
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
  });
  await installEvidenceNavigationStability(context);
  let page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  let mode: Mode = "ready";

  await context.route("**/api/admin/**", async (route: Route) => {
    if (!route.request().url().includes("/api/admin/shop")) {
      await route.continue();
      return;
    }
    if (route.request().method() !== "GET") {
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
        body: JSON.stringify({ data: mode === "empty" ? [] : products }),
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

  const surface = () => page.locator("[data-admin-shop-status]").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/shop?club=24&evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-shop-status", status);
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
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_shop_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading shop catalogue/i);
  await expect(
    page.getByRole("button", { name: /refresh catalogue/i }),
  ).toBeDisabled();
  await capture("loading");
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no products in this club/i);
  await expect(page.getByText(/no products found/i)).toBeVisible();
  await capture("empty");

  for (const [failureMode, label] of [
    ["error", /shop catalogue unavailable/i],
    ["conflict", /shop catalogue changed/i],
    ["security_timeout", /shop request timed out/i],
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
  await expectStatus("ready", /shop catalogue confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /shop catalogue is offline/i);
  await expect(
    page.getByText("Verified product 1", { exact: true }),
  ).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /shop catalogue confirmed/i);
  await page.getByLabel("Search shop catalogue").fill("private filter");
  mode = "permission_denied";
  await page.getByRole("button", { name: /refresh catalogue/i }).click();
  await expectStatus("permission_denied", /shop access denied/i);
  await expect(page.getByLabel("Search shop catalogue")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("private filter");
  await expect(
    page.getByText("Verified product 1", { exact: true }),
  ).toHaveCount(0);
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  await expectStatus("ready", /shop catalogue confirmed/i);
  const refresh = page.getByRole("button", { name: /refresh catalogue/i });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-shop-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-shop-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();
  await page
    .getByRole("button", { name: /edit verified product/i })
    .first()
    .click();
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
  await expectStatus("ready", /shop catalogue confirmed/i);
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
      // Apply the initial document theme explicitly; verify it at capture.
      await page.emulateMedia({ colorScheme: "dark" });
    }
    await page.setViewportSize({ width, height });
    await open(`responsive-${profile}`);
    await expectStatus("ready", /shop catalogue confirmed/i);
    await expectNoOverflow(page);
    await capture(`responsive_${profile}`, profile);
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  mode = "ready";
  await open("syncing-preparation");
  await expectStatus("ready", /shop catalogue confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh catalogue/i }).click();
  await expectStatus("syncing", /refreshing shop catalogue/i);
  await expect(
    page.getByText("Verified product 1", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  writeAdminStateEvidence({
    browser,
    evidenceDirectory,
    manifestFile: "admin-shop-state-evidence.json",
    route: "/admin/shop",
    filePrefix: "admin_shop",
    responsiveCaptures: [
      {
        state: "responsive_desktop_1280x800",
        profile: "desktop_1280x800",
        description: `${browser.browserType().name()} desktop 1280x800 at 1 DPR`,
      },
      {
        state: "responsive_tablet_834x1112",
        profile: "tablet_834x1112",
        description: `${browser.browserType().name()} tablet 834x1112 at 1 DPR`,
      },
      {
        state: "responsive_mobile_390x844",
        profile: "mobile_390x844",
        description: `${browser.browserType().name()} mobile 390x844 at 1 DPR`,
      },
    ],
    assertions: {
      maximum_product_records: 500,
      page_size: 25,
      syncing_retains_confirmed_catalogue: true,
    },
  });

  finalizeStateEvidence(evidenceDirectory);
  await context.close();
}

test.describe("admin shop evidence matrix", () => {
  test("covers the governed route-state and interaction matrix", async ({
    browser,
  }) => {
    // Nineteen captures, axe checks and viewport changes share one test.
    // Match the other full state matrices; action/assertion budgets stay intact.
    test.setTimeout(360_000);
    await runMatrix(browser);
  });
});
