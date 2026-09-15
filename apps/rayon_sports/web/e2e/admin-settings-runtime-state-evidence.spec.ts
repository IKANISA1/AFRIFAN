import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";
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
const base = {
  clubId: 24,
  scope: "club",
  isActive: true,
  metadata: { owner: "platform" },
  createdAt: timestamp,
  updatedAt: timestamp,
};
const snapshot = {
  routes: Array.from({ length: 30 }, (_, index) => ({
    ...base,
    id: `route-${index + 1}`,
    routeKey: `runtime.route_${index + 1}`,
    pathPattern: `/runtime-${index + 1}`,
    surface: index % 2 === 0 ? "mobile" : "web",
    featureKey: "runtime_registry",
    label: `Runtime route ${index + 1}`,
    authRequired: true,
    requiredRoles: ["member"],
    presentation: "screen",
    showInNavigation: index % 3 === 0,
    showOnHome: index % 4 === 0,
    sortOrder: index,
  })),
  optionSets: [
    {
      ...base,
      id: "option-set-1",
      optionSetKey: "ticket_payment_method",
      label: "Ticket payment method",
      description: "Allowed payment methods.",
      valueType: "text",
      surface: "both",
    },
  ],
  optionValues: [
    {
      id: "option-value-1",
      optionSetId: "option-set-1",
      optionKey: "mobile_money",
      label: "Mobile money",
      value: "momo",
      sortOrder: 1,
      isDefault: true,
      isActive: true,
      metadata: { owner: "commerce" },
      createdAt: timestamp,
      updatedAt: timestamp,
    },
  ],
  runtimeCopy: [
    {
      ...base,
      id: "copy-1",
      copyKey: "tickets.checkout.title",
      surface: "both",
      locale: "en",
      textValue: "Complete your ticket purchase",
      description: "Checkout heading.",
    },
  ],
  navigation: [
    {
      ...base,
      id: "navigation-1",
      navKey: "tickets",
      label: "Tickets",
      href: "/tickets",
      navGroup: "primary",
      surface: "web",
      featureKey: "ticketing",
      sortOrder: 10,
    },
  ],
  search: [
    {
      ...base,
      id: "search-1",
      searchKey: "tickets",
      title: "Tickets",
      description: "Browse match tickets.",
      href: "/tickets",
      category: "Page",
      metaLabel: "Matchday",
      surface: "web",
      featureKey: "ticketing",
      sortOrder: 10,
    },
  ],
  venueControls: [
    {
      ...base,
      id: "venue-control-1",
      controlKey: "orders.review",
      label: "Order review",
      detail: "Review pending venue orders.",
      statusLabel: "review_required",
      actionLabel: "Review",
      controlGroup: "orders",
      venueId: "venue-1",
      sortOrder: 10,
    },
  ],
};
const emptySnapshot = Object.fromEntries(
  Object.keys(snapshot).map((key) => [key, []]),
);

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
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_settings_runtime_states");
  const context = await browser.newContext({
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
    if (!route.request().url().includes("/api/admin/runtime-")) {
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
        body: JSON.stringify({
          data: mode === "empty" ? emptySnapshot : snapshot,
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
        error: "database.internal actor_email=private token=secret",
      }),
    });
  });

  const surface = () => page.locator(".admin-runtime-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/settings/runtime?club=24&evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-runtime-status",
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
    await primeEvidenceScreenshot(page, !state.startsWith("responsive_"));
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_settings_runtime_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading runtime registries/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh runtime registries/i }),
  ).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-runtime-mutation-locked",
    "true",
  );
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no runtime records in this scope/i);
  await expect(
    page.getByText(/no records are available in this collection/i),
  ).toBeVisible();
  await capture("empty");

  mode = "error";
  await open("error");
  await expectStatus("error", /runtime registries unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  mode = "conflict";
  await open("conflict");
  await expectStatus("conflict", /runtime registry changed/i);
  await capture("conflict");

  mode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /runtime registry request timed out/i);
  await capture("security_timeout");

  mode = "ready";
  await open("offline");
  await expectStatus("ready", /runtime registries confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /runtime registries are offline/i);
  await expect(
    page.getByText("runtime.route_1", { exact: true }),
  ).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /runtime registries confirmed/i);
  await page.getByLabel("Search Routes").fill("private filter");
  mode = "permission_denied";
  await page
    .getByRole("button", { name: /refresh runtime registries/i })
    .click();
  await expectStatus("permission_denied", /runtime registry access denied/i);
  await expect(page.getByLabel("Search Routes")).toHaveCount(0);
  await expect(page.getByLabel("Routes structured record")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("private filter");
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  await expectStatus("ready", /runtime registries confirmed/i);
  const refresh = page.getByRole("button", {
    name: /refresh runtime registries/i,
  });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-runtime-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-runtime-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();
  await page.getByText("runtime.route_1", { exact: true }).click();
  await expect(surface()).toHaveAttribute(
    "data-admin-runtime-interaction",
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

  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
  await open("reduced-motion");
  await expectStatus("ready", /runtime registries confirmed/i);
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
  await expectStatus("ready", /runtime registries confirmed/i);
  await expectAccessible(page);
  await expectNoOverflow(page);
  await capture("dark");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /runtime registries confirmed/i);
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
    await expectStatus("ready", /runtime registries confirmed/i);
    await expectNoOverflow(page);
    await capture(`responsive_${profile}`, profile);
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  mode = "ready";
  await open("syncing-preparation");
  await expectStatus("ready", /runtime registries confirmed/i);
  await expect(
    page.getByText("runtime.route_1", { exact: true }),
  ).toBeVisible();
  mode = "loading";
  await page
    .getByRole("button", { name: /refresh runtime registries/i })
    .click();
  await expectStatus("syncing", /refreshing runtime registries/i);
  await expect(
    page.getByText("runtime.route_1", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  writeAdminStateEvidence({
    browser,
    evidenceDirectory,
    manifestFile: "admin-settings-runtime-state-evidence.json",
    route: "/admin/settings/runtime",
    filePrefix: "admin_settings_runtime",
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
      maximum_records_per_registry: 500,
      page_size: 25,
      syncing_retains_confirmed_registry: true,
    },
  });

  finalizeStateEvidence(evidenceDirectory);
  await context.close();
}

test.describe("admin runtime-registry evidence matrix", () => {
  test("covers the governed route-state and interaction matrix", async ({
    browser,
  }) => {
    await runMatrix(browser);
  });
});
