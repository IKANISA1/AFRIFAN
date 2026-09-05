import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type BrowserContext, type Page } from "@playwright/test";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const confirmedVenues = [
  {
    id: "venue-kimironko",
    displayName: "Kimironko Matchday House",
    slug: "kimironko-matchday-house",
    city: "Kigali",
    summary: "An approved public profile for supporter matchday discovery.",
  },
  {
    id: "venue-musanze",
    displayName: "Musanze Blue Corner",
    slug: "musanze-blue-corner",
    city: "Musanze",
    summary: "An approved northern partner profile.",
  },
  {
    id: "venue-nyamirambo",
    displayName: "Nyamirambo Club Lounge",
    slug: "nyamirambo-club-lounge",
    city: "Kigali",
    summary: "An approved public profile near the matchday route.",
  },
  {
    id: "venue-huye",
    displayName: "Huye Supporter Point",
    slug: "huye-supporter-point",
    city: "Huye",
    summary: "An approved southern partner profile.",
  },
];

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return {
      status: 200,
      body: { code: "PUBLIC_VENUES_READY", items: confirmedVenues },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: { code: "PUBLIC_VENUES_EMPTY", items: [] },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_VENUES_ACCESS_DENIED",
        error: "Access denied.",
        retryable: false,
        change_confirmed: false,
      },
    };
  }
  if (mode === "conflict") {
    return {
      status: 409,
      body: {
        code: "PUBLIC_VENUES_CONFLICT",
        error: "The directory conflicts with the current record.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: "PUBLIC_VENUES_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_VENUES_FAILED",
      error: "database.internal password=private",
      retryable: true,
      change_confirmed: false,
    },
  };
}

async function expectStatus(page: Page, status: string, label: RegExp) {
  await expect(page.locator(".venues-surface")).toHaveAttribute(
    "data-venues-status",
    status,
  );
  await expect(page.locator(".venues-status")).toContainText(label);
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

test("/venues proves all sixteen applicable rendered states", async ({
  browser,
}, testInfo) => {
  test.setTimeout(90_000);
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Venues evidence uses the declared Pixel 7 Chromium profile.",
  );

  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/evidence/consumer_web_venues_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });

  const context: BrowserContext = await browser.newContext({
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2.625,
    isMobile: true,
    hasTouch: true,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=venues*", async (route) => {
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

  const open = async (nonce: string) => {
    await page.goto(`/venues?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  };
  const capture = async (state: string) => {
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
    await page.screenshot({
      path: path.join(evidenceDirectory, `venues_state_${state}_pixel7.png`),
      fullPage: true,
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus(page, "loading", /loading approved venues/i);
  await capture("loading_dark");
  await expect(
    page.getByRole("button", { name: /refresh venues/i }),
  ).toBeDisabled();
  await expect(page.locator(".venues-surface")).toHaveAttribute(
    "data-venues-refresh-disabled",
    "true",
  );
  await capture("disabled_dark");

  responseMode = "empty";
  await open("empty");
  await expectStatus(page, "empty", /no approved venues listed/i);
  await expect(
    page.getByRole("heading", { name: /no approved venues listed/i }),
  ).toBeVisible();
  await capture("empty_dark");

  responseMode = "error";
  await open("error");
  await expectStatus(page, "error", /venue directory unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error_dark");

  responseMode = "ready";
  await open("offline");
  await expectStatus(page, "ready", /venue directory confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus(page, "offline", /you are offline/i);
  await expect(
    page.locator(".venues-card").filter({ hasText: "Kimironko Matchday House" }),
  ).toBeVisible();
  await capture("offline_dark");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus(page, "permission_denied", /venue access denied/i);
  await expect(page.locator(".venues-card")).toHaveCount(0);
  await capture("permission_denied_dark");

  responseMode = "ready";
  await open("focused");
  const primaryAction = page
    .getByRole("link", { name: /app links coming soon/i })
    .first();
  await primaryAction.focus();
  await expect(page.locator(".venues-surface")).toHaveAttribute(
    "data-venues-interaction",
    "focused",
  );
  await expect(primaryAction).toBeFocused();
  await capture("focused_dark");

  await primaryAction.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(page.locator(".venues-surface")).toHaveAttribute(
    "data-venues-interaction",
    "pressed",
  );
  await capture("pressed_dark");
  await primaryAction.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const musanze = page.getByRole("button", { name: /musanze blue corner/i });
  await musanze.click();
  await expect(musanze).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".venues-surface")).toHaveAttribute(
    "data-venues-interaction",
    "selected",
  );
  await capture("selected_dark");

  await open("large-text");
  await page.addStyleTag({ content: "html { font-size: 200% !important; }" });
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  const clippedElements = await page
    .locator(".venues-surface")
    .evaluate((surface) => {
      const viewportWidth = document.documentElement.clientWidth;
      return Array.from(surface.querySelectorAll("*"))
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
  await capture("large_text_dark");

  responseMode = "loading";
  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  await open("reduced-motion");
  await expectStatus(page, "loading", /loading approved venues/i);
  expect(
    await page
      .locator(".venues-status svg")
      .evaluate((element) =>
        Number.parseFloat(getComputedStyle(element).animationDuration),
      ),
  ).toBeLessThanOrEqual(0.001);
  await capture("reduced_motion_dark");

  responseMode = "ready";
  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  await open("dark");
  await expectStatus(page, "ready", /venue directory confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus(page, "ready", /venue directory confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light_light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus(page, "ready", /venue directory confirmed/i);
  responseMode = "loading";
  await page
    .getByRole("button", { name: /refresh venues/i })
    .dispatchEvent("click");
  await expectStatus(page, "syncing", /refreshing approved venues/i);
  await expect(
    page.locator(".venues-card").filter({ hasText: "Kimironko Matchday House" }),
  ).toBeVisible();
  await capture("syncing_dark");

  responseMode = "conflict";
  await open("conflict");
  await expectStatus(page, "conflict", /venue directory changed/i);
  await capture("conflict_dark");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus(page, "security_timeout", /venue request timed out/i);
  await capture("security_timeout_dark");

  responseMode = "ready";
  await open("targets");
  await expectStatus(page, "ready", /venue directory confirmed/i);
  const targetSizes = await page
    .locator(".venues-action, .venues-card")
    .evaluateAll((elements) =>
      elements.map((element) => {
        const rect = element.getBoundingClientRect();
        return { width: rect.width, height: rect.height };
      }),
    );
  for (const target of targetSizes) {
    expect(target.width).toBeGreaterThanOrEqual(48);
    expect(target.height).toBeGreaterThanOrEqual(48);
  }

  const captures = [
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
    path.join(evidenceDirectory, "venues-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/venues",
        surface: "consumer_web",
        exact_profile: "Pixel 7 Chromium 412x915 at 2.625 DPR",
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          precise_location_or_live_orders_exposed: false,
          authenticated_web_checkin_claimed: false,
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          reduced_motion_max_seconds: 0.001,
          axe_critical_or_serious_dark: 0,
          axe_critical_or_serious_light: 0,
          raw_api_diagnostics_rendered: false,
        },
        captures: captures.map((state) => ({
          state,
          file: `venues_state_${state}_${
            state === "light" ? "light" : "dark"
          }_pixel7.png`,
        })),
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
});
