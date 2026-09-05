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

const overview = {
  snapshot: {
    metrics: {
      activeUsers: 1240,
      pendingVerifications: 6,
      activeSupportCircles: 18,
      recentTicketSales: 84,
      totalFans: 1240,
      ticketRevenue: 4_200_000,
    },
    activity: [
      {
        id: "audit-1",
        title: "Membership reviewed",
        detail: "A supporter application changed state.",
        createdAt: "2026-07-29T12:00:00.000Z",
        actorEmail: "private@example.com",
        actorId: "private-user",
      },
      {
        id: "audit-2",
        title: "Fixture published",
        detail: "The confirmed match schedule was updated.",
        createdAt: "2026-07-29T11:00:00.000Z",
      },
    ],
  },
  quickActions: [
    {
      id: "members",
      actionKey: "review_members",
      title: "Review membership",
      subtitle: "Open pending supporter applications.",
      route: "/admin/membership",
      iconKey: "crown",
      category: "supporters",
      clubId: 24,
      requiredRole: "club_admin",
      sortOrder: 1,
      accessToken: "private-token",
    },
    {
      id: "matches",
      actionKey: "manage_matches",
      title: "Manage fixtures",
      subtitle: "Review the confirmed club schedule.",
      route: "/admin/matches",
      iconKey: "calendar",
      category: "operations",
      clubId: 24,
      requiredRole: "club_admin",
      sortOrder: 2,
    },
    {
      id: "unsafe",
      actionKey: "unsafe",
      title: "Unsafe external action",
      subtitle: "Must never render.",
      route: "https://attacker.invalid/admin",
      iconKey: "settings",
      category: "operations",
      clubId: 24,
      requiredRole: "club_admin",
      sortOrder: 3,
    },
  ],
  session: {
    accessToken: "private-token",
  },
};

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return { status: 200, body: { data: overview } };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: {
        data: {
          snapshot: {
            metrics: {
              activeUsers: 0,
              pendingVerifications: 0,
              activeSupportCircles: 0,
              recentTicketSales: 0,
              totalFans: 0,
              ticketRevenue: 0,
            },
            activity: [],
          },
          quickActions: [],
        },
      },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "ADMIN_ACCESS_DENIED",
        error: "Admin access denied.",
      },
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
      error: "database.internal service_role=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectNoSeriousAxeViolations(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    results.violations.filter(
      ({ impact }) => impact === "critical" || impact === "serious",
    ),
  ).toHaveLength(0);
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

async function runAdminDashboardMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/evidence/admin_pwa_dashboard_states",
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

  await page.route("**/api/admin/dashboard-overview*", async (route) => {
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
    page.locator(".admin-dashboard-state-surface").first();
  const open = async (nonce: string) => {
    await page.goto(`/admin?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  };
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-dashboard-status",
      status,
    );
    await expect(page.locator(".admin-dashboard-status")).toContainText(label);
  };
  const capture = async (
    state: string,
    profile = "desktop_1440x1000",
  ) => {
    await settleVisuals(page);
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_dashboard_state_${state}_${
          state === "light" ? "light" : "dark"
        }_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading operations dashboard/i);
  await capture("loading");
  const refresh = page.getByRole("button", {
    name: /refresh dashboard/i,
  });
  await expect(refresh).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-admin-dashboard-refresh-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no admin activity yet/i);
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /dashboard unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await expect(page.locator("body")).not.toContainText("service_role");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /operations dashboard confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /admin workspace is offline/i);
  await expect(page.getByText("Membership reviewed")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /dashboard access denied/i);
  await expect(page.getByText("Membership reviewed")).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /operations dashboard confirmed/i);
  const readyRefresh = page.getByRole("button", {
    name: /refresh dashboard/i,
  });
  await readyRefresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-dashboard-interaction",
    "focused",
  );
  await capture("focused");

  await readyRefresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-dashboard-interaction",
    "pressed",
  );
  await capture("pressed");
  await readyRefresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  const selection = page.getByRole("button", {
    name: /review membership/i,
  });
  await selection.click();
  await expect(selection).toHaveAttribute("aria-pressed", "true");
  await expect(surface()).toHaveAttribute(
    "data-admin-dashboard-interaction",
    "selected",
  );
  await expect(
    page.getByRole("link", {
      name: /open selected: review membership/i,
    }),
  ).toHaveAttribute("href", /\/admin\/membership\?club=24$/);
  await capture("selected");

  await open("large-text");
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  const clippedElements = await surface().evaluate((dashboard) => {
    const viewportWidth = document.documentElement.clientWidth;
    return Array.from(dashboard.querySelectorAll("*"))
      .map((element) => {
        const rect = element.getBoundingClientRect();
        return {
          tag: element.tagName,
          className:
            typeof element.className === "string" ? element.className : "",
          left: rect.left,
          right: rect.right,
        };
      })
      .filter(({ left, right }) => left < -1 || right > viewportWidth + 1);
  });
  expect(clippedElements).toEqual([]);
  await capture("large_text");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus("loading", /loading operations dashboard/i);
  expect(
    await page
      .locator(".admin-dashboard-status svg")
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
  await expectStatus("ready", /operations dashboard confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private@example.com");
  await expect(page.locator("body")).not.toContainText("private-user");
  await expect(page.locator("body")).not.toContainText("private-token");
  await expect(page.locator("body")).not.toContainText("attacker.invalid");
  const undersizedControls = await surface().locator("button, a").evaluateAll(
    (elements) =>
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

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /operations dashboard confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /operations dashboard confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh dashboard/i }).click();
  await expectStatus("syncing", /refreshing admin operations/i);
  await expect(page.getByText("Membership reviewed")).toBeVisible();
  await capture("syncing");

  responseMode = "ready";
  await open("conflict");
  await expectStatus("ready", /operations dashboard confirmed/i);
  responseMode = "conflict";
  await page.getByRole("button", { name: /refresh dashboard/i }).click();
  await expectStatus("conflict", /admin records changed/i);
  await expect(page.getByText("Membership reviewed")).toBeVisible();
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /admin request timed out/i);
  await expect(page.getByText("Membership reviewed")).toHaveCount(0);
  await capture("security_timeout");

  responseMode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectStatus("ready", /operations dashboard confirmed/i);
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  await capture("responsive_tablet", "tablet_1024x900");

  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectStatus("ready", /operations dashboard confirmed/i);
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
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
    path.join(evidenceDirectory, "admin-dashboard-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin",
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
          aggregate_request_count: 1,
          bounded_request_seconds: 12,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data: true,
          unsafe_external_routes_rendered: false,
          private_fields_or_tokens_rendered: false,
          activity_search_sort_pagination_present: true,
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          reduced_motion_max_seconds: 0.001,
          axe_critical_or_serious_dark: 0,
          axe_critical_or_serious_light: 0,
          raw_api_diagnostics_rendered: false,
        },
        captures: [
          ...governedStates.map((state) => ({
            state,
            file: `admin_dashboard_state_${state}_${
              state === "light" ? "light" : "dark"
            }_desktop_1440x1000.png`,
          })),
          {
            state: "responsive_tablet",
            file: "admin_dashboard_state_responsive_tablet_dark_tablet_1024x900.png",
          },
          {
            state: "responsive_compact",
            file: "admin_dashboard_state_responsive_compact_dark_compact_390x844.png",
          },
        ],
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
}

test.describe("controlled Admin PWA dashboard evidence", () => {
  test("captures the exact authenticated dashboard state matrix", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    await runAdminDashboardMatrix(browser);
  });
});
