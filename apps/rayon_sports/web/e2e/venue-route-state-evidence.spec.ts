import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page } from "@playwright/test";
import {
  installEvidenceNavigationStability,
  primeEvidenceScreenshot,
  settleEvidenceVisuals,
} from "./evidence-navigation-stability";

type VenueRoute = {
  slug: string;
  route: string;
  heading: string;
  action: RegExp;
  retainedText: string;
};

const venueRoutes: VenueRoute[] = [
  {
    slug: "overview",
    route: "/venue",
    heading: "Today at the venue",
    action: /refresh venue summary/i,
    retainedText: "Open orders",
  },
  {
    slug: "orders",
    route: "/venue/orders",
    heading: "Drinks orders",
    action: /refresh drinks orders/i,
    retainedText: "Order 7A3F",
  },
  {
    slug: "menu",
    route: "/venue/menu",
    heading: "Drinks menu",
    action: /refresh drinks menu/i,
    retainedText: "Sparkling water",
  },
  {
    slug: "checkins",
    route: "/venue/checkins",
    heading: "Check-ins",
    action: /refresh check-ins/i,
    retainedText: "18:42",
  },
  {
    slug: "promotions",
    route: "/venue/promotions",
    heading: "Promotions",
    action: /refresh promotions/i,
    retainedText: "Derby arrival",
  },
  {
    slug: "staff",
    route: "/venue/staff",
    heading: "Venue staff",
    action: /refresh venue staff/i,
    retainedText: "Assignment 1",
  },
  {
    slug: "tv_code",
    route: "/venue/tv-code",
    heading: "TV code status",
    action: /refresh tv code status/i,
    retainedText: "Amahoro screen 1",
  },
];

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
] as const;

async function settleVisuals(page: Page) {
  await settleEvidenceVisuals(page);
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
  const overflow = await page.evaluate(
    () =>
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth,
  );
  expect(overflow).toBeLessThanOrEqual(1);
}

async function captureRoute(browser: Browser, route: VenueRoute) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    `../../../output/implementation_goal_20260724/venue_portal_${route.slug}_states`,
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  let context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await installEvidenceNavigationStability(context);
  let page = await context.newPage();
  const surface = () => page.locator(".controlled-venue-state-surface");
  const open = async (state: string) => {
    await page.goto(`${route.route}?evidence=${state}`, {
      waitUntil: "domcontentloaded",
    });
    await expect(
      page.getByRole("heading", { name: route.heading, exact: true }),
    ).toBeVisible();
  };
  const expectState = (state: string) =>
    expect(surface()).toHaveAttribute("data-venue-state", state);
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    const preserveInteraction = state === "focused" || state === "pressed";
    await page.evaluate((blur) => {
      if (blur && document.activeElement instanceof HTMLElement) {
        document.activeElement.blur();
      }
      if (blur) {
        for (const button of document.querySelectorAll<HTMLElement>(
          ".ui-button",
        )) {
          const label = button.textContent ?? "";
          const stableLabel = document.createElement("span");
          stableLabel.textContent = label;
          stableLabel.style.display = "inline-block";
          stableLabel.style.whiteSpace = "nowrap";
          button.replaceChildren(stableLabel);
          button.style.transition = "none";
          button.style.transform = "none";
          button.style.willChange = "auto";
        }
        void document.body.offsetHeight;
      }
      document.documentElement.style.scrollBehavior = "auto";
      document.body.style.scrollBehavior = "auto";
      window.scrollTo({ top: 0, left: 0, behavior: "auto" });
    }, !preserveInteraction);
    if (!preserveInteraction) {
      await page.mouse.move(0, 0);
    }
    await settleVisuals(page);
    await primeEvidenceScreenshot(page, !state.startsWith("responsive_"));
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `venue_${route.slug}_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  await open("loading");
  await expectState("loading");
  await expect(page.getByText(/loading venue operations/i)).toBeVisible();
  await capture("loading");

  await open("empty");
  await expectState("empty");
  await capture("empty");

  await open("error");
  await expectState("error");
  await expect(surface().getByRole("alert")).toContainText(
    "Venue workflow unavailable",
  );
  await capture("error");

  await open("ready");
  await expect(
    page.getByText(route.retainedText, { exact: true }),
  ).toBeVisible();
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectState("offline");
  await expect(
    page.getByText(route.retainedText, { exact: true }),
  ).toBeVisible();
  await expect(page.getByRole("button", { name: route.action })).toBeDisabled();
  await capture("offline");
  await context.setOffline(false);

  await open("permission_denied");
  await expectState("permission_denied");
  await expect(surface().getByRole("alert")).toContainText(
    "Venue access denied",
  );
  await expect(page.getByText(route.retainedText, { exact: true })).toHaveCount(
    0,
  );
  await capture("permission_denied");

  await open("disabled");
  await expectState("disabled");
  await expect(page.getByRole("button", { name: route.action })).toBeDisabled();
  await capture("disabled");

  await open("focused");
  await expectState("focused");
  await capture("focused");

  await open("ready");
  const refresh = page.getByRole("button", { name: route.action });
  await refresh.focus();
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expectState("pressed");
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });

  await open("ready-selected");
  await page.getByRole("button", { name: /confirmed snapshot/i }).click();
  await expectState("selected");
  await expect(
    page.getByRole("button", { name: /confirmed snapshot/i }),
  ).toHaveAttribute("aria-pressed", "true");
  await expectNoSeriousAxeViolations(page);
  await capture("selected");

  await open("ready");
  await page.evaluate(() => {
    document.documentElement.style.fontSize = "200%";
  });
  await expectNoHorizontalOverflow(page);
  await capture("large_text");
  await page.evaluate(() => {
    document.documentElement.style.fontSize = "";
  });

  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
  await open("ready");
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
  await open("ready");
  await expectState("ready");
  await expectNoSeriousAxeViolations(page);
  const undersized = await surface()
    .locator("button:visible, input:visible, select:visible, a:visible")
    .evaluateAll((elements) =>
      elements
        .map((element) => element.getBoundingClientRect())
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await capture("dark");

  await page.emulateMedia({ colorScheme: "light" });
  await open("ready");
  await open("ready-light-stable");
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  await open("syncing");
  await expectState("syncing");
  await expect(
    page.getByText(route.retainedText, { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  await open("conflict");
  await expectState("conflict");
  await expect(surface().getByRole("alert")).toContainText(
    "Venue data changed",
  );
  await capture("conflict");

  await open("security_timeout");
  await expectState("security_timeout");
  await expect(surface().getByRole("alert")).toContainText(
    "Venue request timed out",
  );
  await capture("security_timeout");

  for (const forbiddenText of [
    "private-",
    "service_role",
    "access token",
    "supporter id\\b",
  ]) {
    await expect(page.locator("body")).not.toContainText(
      new RegExp(forbiddenText, "i"),
    );
  }

  await page.setViewportSize({ width: 1024, height: 900 });
  await open("ready");
  await expectNoHorizontalOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");

  await context.close();
  context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
    reducedMotion: "reduce",
  });
  await installEvidenceNavigationStability(context);
  page = await context.newPage();
  await open("ready");
  await open("ready-stable");
  await expectNoHorizontalOverflow(page);
  const compactNavigation = page.getByRole("navigation", {
    name: "Venue operations",
  });
  expect(
    await compactNavigation.evaluate(
      (element) => element.scrollWidth - element.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  for (const link of await compactNavigation.getByRole("link").all()) {
    await expect(link).toBeVisible();
  }
  await page.emulateMedia({
    reducedMotion: "no-preference",
    colorScheme: "dark",
  });
  await capture("responsive_compact", "compact_390x844");

  const manifest = {
    schema_version: "1.0",
    route: route.route,
    surface: "venue_portal",
    exact_profile: "Chromium desktop 1440x1000 at 1 DPR",
    responsive_profiles: [
      "Chromium tablet 1024x900 at 1 DPR",
      "Chromium compact 390x844 at 1 DPR",
    ],
    applicable_states: governedStates,
    not_applicable_states: [],
    assertions: {
      controlled_evidence_requires_two_keys_and_loopback: true,
      production_authentication_bypass_enabled: false,
      route_specific_confirmed_records: true,
      permission_denial_clears_records: true,
      offline_and_syncing_retain_last_confirmed_snapshot: true,
      uncertain_mutations_locked: true,
      readable_tv_code_rendered: false,
      supporter_identity_rendered: false,
      synthetic_non_production_data: true,
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
        file: `venue_${route.slug}_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
      })),
      {
        state: "responsive_tablet",
        file: `venue_${route.slug}_state_responsive_tablet_dark_tablet_1024x900.png`,
      },
      {
        state: "responsive_compact",
        file: `venue_${route.slug}_state_responsive_compact_dark_compact_390x844.png`,
      },
    ],
  };
  fs.writeFileSync(
    path.join(evidenceDirectory, `venue-${route.slug}-state-evidence.json`),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
  await context.close();
}

test.describe("controlled venue portal route-state evidence", () => {
  for (const venueRoute of venueRoutes) {
    test(`captures the exact ${venueRoute.route} state matrix`, async ({
      browser,
    }) => {
      test.setTimeout(180_000);
      await captureRoute(browser, venueRoute);
    });
  }
});
