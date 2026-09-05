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

const snapshot = {
  matches: [
    {
      id: "opening-day",
      homeTeam: "Rayon Sports",
      awayTeam: "APR FC",
      competition: "Premier League",
      venue: "Amahoro Stadium",
      matchDate: "2026-08-02T15:00:00.000Z",
      kickoffTime: "17:00",
      matchStatus: "scheduled",
      privateLineup: "private-lineup",
    },
  ],
  news: [
    {
      id: "club-update",
      title: "Confirmed club update",
      excerpt: "A confirmed public update for supporters.",
      category: "Club",
      publishedAt: "2026-07-29T12:00:00.000Z",
      author: "Club Media",
      internalDraft: "private-draft",
    },
  ],
  products: [
    {
      id: "home-shirt",
      name: "Home shirt",
      subtitle: "Official confirmed home shirt.",
      category: "Jerseys",
      price: 35_000,
      isAvailable: true,
      stockQuantity: 90,
      supplierCost: 1,
      paymentReference: "private-payment",
    },
  ],
  memberships: [
    {
      id: "bronze",
      tier: "bronze",
      title: "Bronze",
      description: "Confirmed public membership tier.",
      annualPrice: 10_000,
      perks: ["Ticket priority"],
      supporterId: "private-user",
    },
  ],
};

function responseFor(mode: Exclude<ResponseMode, "loading">) {
  if (mode === "ready") {
    return { status: 200, body: { code: "PUBLIC_HOME_READY", ...snapshot } };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: {
        code: "PUBLIC_HOME_EMPTY",
        matches: [],
        news: [],
        products: [],
        memberships: [],
      },
    };
  }
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: "PUBLIC_HOME_ACCESS_DENIED",
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
        code: "PUBLIC_HOME_CONFLICT",
        error: "The public snapshot conflicts with the current record.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: "PUBLIC_HOME_TIMEOUT",
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: "PUBLIC_HOME_FAILED",
      error: "database.internal password=private",
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

async function runHomeMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/evidence/consumer_web_home_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2.625,
    isMobile: true,
    hasTouch: true,
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=home", async (route) => {
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

  const surface = () => page.locator(".home-surface").first();
  const open = async (nonce: string) => {
    await page.goto(`/?evidence=${nonce}`, { waitUntil: "domcontentloaded" });
  };
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-home-status", status);
    await expect(page.locator(".home-status")).toContainText(label);
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
      path: path.join(
        evidenceDirectory,
        `home_state_${state}_${
          state === "light" ? "light" : "dark"
        }_pixel7.png`,
      ),
      fullPage: true,
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading the official club home/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh highlights/i }),
  ).toBeDisabled();
  await expect(surface()).toHaveAttribute(
    "data-home-refresh-disabled",
    "true",
  );
  await capture("disabled");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no public highlights/i);
  await expect(
    page.getByRole("heading", { name: /no public highlights/i }),
  ).toBeVisible();
  await capture("empty");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /club home unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /club home confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /you are offline/i);
  await expect(page.getByText("Confirmed club update")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /home access denied/i);
  await expect(page.getByText("Confirmed club update")).toHaveCount(0);
  await capture("permission_denied");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /club home confirmed/i);
  const refresh = page.getByRole("button", { name: /refresh highlights/i });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-home-interaction",
    "focused",
  );
  await capture("focused");

  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-home-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const selection = page.getByRole("button", { name: /shop preview/i });
  await selection.click();
  await expect(selection).toHaveAttribute("aria-pressed", "true");
  await expect(surface()).toHaveAttribute(
    "data-home-interaction",
    "selected",
  );
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
  const clippedElements = await surface().evaluate((homeSurface) => {
    const viewportWidth = document.documentElement.clientWidth;
    return Array.from(homeSurface.querySelectorAll("*"))
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
  await expectStatus("loading", /loading the official club home/i);
  expect(
    await page
      .locator(".home-status svg")
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
  await expectStatus("ready", /club home confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-user");
  await expect(page.locator("body")).not.toContainText("private-payment");
  await expect(page.locator("body")).not.toContainText("supplierCost");
  await expect(page.locator("body")).not.toContainText("stockQuantity");
  await expect(
    page.getByRole("button", { name: /buy|checkout|pay now|join now/i }),
  ).toHaveCount(0);
  await capture("dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /club home confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /club home confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: /refresh highlights/i }).click();
  await expectStatus("syncing", /refreshing club highlights/i);
  await expect(page.getByText("Confirmed club update")).toBeVisible();
  await capture("syncing");

  responseMode = "conflict";
  await open("conflict");
  await expectStatus("conflict", /club highlights changed/i);
  await capture("conflict");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /home request timed out/i);
  await capture("security_timeout");

  responseMode = "ready";
  await open("targets");
  await expectStatus("ready", /club home confirmed/i);
  const targetSizes = await page
    .locator(
      ".home-action, .home-action-choice, .home-preview-section > header > a, .home-preview-card a",
    )
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
    path.join(evidenceDirectory, "home-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/",
        surface: "consumer_web",
        exact_profile: "Pixel 7 Chromium 412x915 at 2.625 DPR",
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          bounded_allowlisted_public_snapshot: true,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_confirmed_data: true,
          supporter_or_membership_identity_exposed: false,
          booking_order_or_payment_data_exposed: false,
          authenticated_mutation_exposed: false,
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
          file: `home_state_${state}_${
            state === "light" ? "light" : "dark"
          }_pixel7.png`,
        })),
      },
      null,
      2,
    )}\n`,
  );

  await context.close();
}

test("/ proves all sixteen applicable rendered states", async ({
  browser,
}, testInfo) => {
  test.setTimeout(90_000);
  test.skip(
    testInfo.project.name !== "mobile-chromium",
    "Home evidence uses the declared Pixel 7 Chromium profile.",
  );
  await runHomeMatrix(browser);
});
