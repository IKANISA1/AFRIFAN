import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence, stateEvidenceContextOptions, createStateEvidenceContext } from "./state-evidence-provenance";
import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import {
  expect,
  test,
  type Browser,
  type BrowserContext,
  type Page,
} from "@playwright/test";

type ResponseMode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

type RouteEvidenceConfig = {
  route: "/shop" | "/shop/home-shirt";
  key: "shop" | "shop_product";
  resource: "shop" | "shop-product";
  surfaceSelector: ".shop-surface" | ".shop-product-surface";
  statusAttribute: "data-shop-status" | "data-shop-product-status";
  interactionAttribute:
    | "data-shop-interaction"
    | "data-shop-product-interaction";
  disabledAttribute:
    | "data-shop-refresh-disabled"
    | "data-shop-product-refresh-disabled";
  refreshName: RegExp;
  selectedControlName: RegExp;
  targetSelector: string;
};

const confirmedProducts = [
  {
    id: "home-shirt",
    name: "Home shirt",
    subtitle: "Official confirmed home shirt.",
    description: "Confirmed public home shirt description for supporters.",
    category: "Jerseys",
    collection: "2026",
    price: 35_000,
    imageUrl: "/brand-surface.svg",
    sizes: ["S", "M", "L"],
    isAvailable: true,
    stockQuantity: 90,
    supplierCost: 1,
    customerId: "private-user",
    paymentReference: "private-payment",
  },
  {
    id: "club-scarf",
    name: "Club scarf",
    subtitle: "Official confirmed supporter scarf.",
    description: "Confirmed public supporter scarf description.",
    category: "Accessories",
    collection: "Supporters",
    price: 12_000,
    imageUrl: "/brand-surface.svg",
    sizes: ["One size"],
    isAvailable: false,
  },
];

function responseFor(
  mode: Exclude<ResponseMode, "loading">,
  resource: RouteEvidenceConfig["resource"],
) {
  const detail = resource === "shop-product";
  if (mode === "ready") {
    return {
      status: 200,
      body: detail
        ? {
            code: "PUBLIC_SHOP_PRODUCT_READY",
            item: confirmedProducts[0],
          }
        : { code: "PUBLIC_SHOP_READY", items: confirmedProducts },
    };
  }
  if (mode === "empty") {
    return {
      status: 200,
      body: detail
        ? { code: "PUBLIC_SHOP_PRODUCT_EMPTY", item: null }
        : { code: "PUBLIC_SHOP_EMPTY", items: [] },
    };
  }
  const namespace = detail ? "PUBLIC_SHOP_PRODUCT" : "PUBLIC_SHOP";
  if (mode === "permission_denied") {
    return {
      status: 403,
      body: {
        code: `${namespace}_ACCESS_DENIED`,
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
        code: `${namespace}_CONFLICT`,
        error: "The public catalog conflicts with the current record.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  if (mode === "security_timeout") {
    return {
      status: 504,
      body: {
        code: `${namespace}_TIMEOUT`,
        error: "The operation timed out.",
        retryable: true,
        change_confirmed: false,
      },
    };
  }
  return {
    status: 502,
    body: {
      code: `${namespace}_FAILED`,
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

async function runStateMatrix(
  browser: Browser,
  config: RouteEvidenceConfig,
) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), `consumer_web_${config.key}_states`);


  const context: BrowserContext = await createStateEvidenceContext(browser, {
    ...stateEvidenceContextOptions(test.info()),
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  await page.emulateMedia({ colorScheme: "dark" });
  let responseMode: ResponseMode = "ready";

  await page.route("**/api/public-content?resource=shop*", async (route) => {
    const requestUrl = new URL(route.request().url());
    if (requestUrl.searchParams.get("resource") !== config.resource) {
      await route.continue();
      return;
    }
    if (responseMode === "loading") {
      await new Promise<void>(() => {});
      return;
    }
    const response = responseFor(responseMode, config.resource);
    await route.fulfill({
      status: response.status,
      contentType: "application/json",
      body: JSON.stringify(response.body),
    });
  });

  const surface = () => page.locator(config.surfaceSelector).first();
  const open = async (nonce: string) => {
    await navigateStateEvidence(page, `${config.route}?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  };
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(config.statusAttribute, status);
    await expect(page.locator(".shop-status")).toContainText(label);
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
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `${config.key}_state_${state}_viewport.png`,
      ),
      fullPage: true,
      animations: "disabled",
    });
  };

  responseMode = "loading";
  await open("loading");
  await expectStatus("loading", /loading official products/i);
  await capture("loading_dark");
  await expect(
    page.getByRole("button", { name: config.refreshName }),
  ).toBeDisabled();
  await expect(surface()).toHaveAttribute(config.disabledAttribute, "true");
  await capture("disabled_dark");

  responseMode = "empty";
  await open("empty");
  await expectStatus("empty", /no public products/i);
  await expect(
    page.getByRole("heading", { name: /no public products/i }),
  ).toBeVisible();
  await capture("empty_dark");

  responseMode = "error";
  await open("error");
  await expectStatus("error", /shop catalog unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error_dark");

  responseMode = "ready";
  await open("offline");
  await expectStatus("ready", /official products confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /you are offline/i);
  await expect(page.getByText("Home shirt").first()).toBeVisible();
  await capture("offline_dark");
  await context.setOffline(false);

  responseMode = "permission_denied";
  await open("permission");
  await expectStatus("permission_denied", /shop access denied/i);
  await expect(page.getByText("Home shirt")).toHaveCount(0);
  await capture("permission_denied_dark");

  responseMode = "ready";
  await open("focused");
  await expectStatus("ready", /official products confirmed/i);
  const refresh = page.getByRole("button", { name: config.refreshName });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    config.interactionAttribute,
    "focused",
  );
  await expect(refresh).toBeFocused();
  await capture("focused_dark");

  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    config.interactionAttribute,
    "pressed",
  );
  await capture("pressed_dark");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
  });

  const selection = page.getByRole("button", {
    name: config.selectedControlName,
  });
  await selection.click();
  await expect(selection).toHaveAttribute("aria-pressed", "true");
  await expect(surface()).toHaveAttribute(
    config.interactionAttribute,
    "selected",
  );
  await capture("selected_dark");

  await open("large-text");
  await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
  });
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
  const clippedElements = await surface().evaluate((shopSurface) => {
    const viewportWidth = document.documentElement.clientWidth;
    return Array.from(shopSurface.querySelectorAll("*"))
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
  await expectStatus("loading", /loading official products/i);
  expect(
    await page
      .locator(".shop-status svg")
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
  await expectStatus("ready", /official products confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await expect(page.locator("body")).not.toContainText("private-user");
  await expect(page.locator("body")).not.toContainText("private-payment");
  await expect(page.locator("body")).not.toContainText("supplierCost");
  await expect(page.locator("body")).not.toContainText("stockQuantity");
  await expect(
    page.getByRole("button", { name: /buy|checkout|pay now/i }),
  ).toHaveCount(0);
  await capture("dark_dark");

  await page.emulateMedia({
    colorScheme: "light",
    reducedMotion: "no-preference",
  });
  await open("light");
  await expectStatus("ready", /official products confirmed/i);
  await expectNoSeriousAxeViolations(page);
  await capture("light_light");

  await page.emulateMedia({
    colorScheme: "dark",
    reducedMotion: "no-preference",
  });
  responseMode = "ready";
  await open("syncing");
  await expectStatus("ready", /official products confirmed/i);
  responseMode = "loading";
  await page.getByRole("button", { name: config.refreshName }).click();
  await expectStatus("syncing", /refreshing official products/i);
  await expect(page.getByText("Home shirt").first()).toBeVisible();
  await capture("syncing_dark");

  responseMode = "conflict";
  await open("conflict");
  await expectStatus("conflict", /shop catalog changed/i);
  await capture("conflict_dark");

  responseMode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /shop request timed out/i);
  await capture("security_timeout_dark");

  responseMode = "ready";
  await open("targets");
  await expectStatus("ready", /official products confirmed/i);
  const targetSizes = await page.locator(config.targetSelector).evaluateAll(
    (elements) =>
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
    path.join(evidenceDirectory, `${config.key}-state-evidence.json`),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: config.route,
        surface: "consumer_web",
        exact_profile: `${browser.browserType().name()}; viewport, DPR and input emulation are recorded per capture`,
        applicable_states: captures,
        not_applicable_states: [],
        assertions: {
          controlled_api_states: true,
          confirmed_data_retained_during_recovery: true,
          customer_or_order_identity_exposed: false,
          inventory_counts_or_supplier_cost_exposed: false,
          payment_or_receipt_data_exposed: false,
          web_checkout_or_payment_claimed: false,
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
          file: `${config.key}_state_${state}_${
            state === "light" ? "light" : "dark"
          }_viewport.png`,
        })),
      },
      null,
      2,
    )}\n`,
  );

  finalizeStateEvidence(evidenceDirectory);
  await context.close();
}

test("/shop proves all sixteen applicable rendered states", async ({
  browser,
}) => {
  test.setTimeout(360_000);
  await runStateMatrix(browser, {
    route: "/shop",
    key: "shop",
    resource: "shop",
    surfaceSelector: ".shop-surface",
    statusAttribute: "data-shop-status",
    interactionAttribute: "data-shop-interaction",
    disabledAttribute: "data-shop-refresh-disabled",
    refreshName: /refresh products/i,
    selectedControlName: /club scarf/i,
    targetSelector: ".shop-action, .shop-card",
  });
});

test("/shop/:productId proves all sixteen applicable rendered states", async ({
  browser,
}) => {
  test.setTimeout(360_000);
  await runStateMatrix(browser, {
    route: "/shop/home-shirt",
    key: "shop_product",
    resource: "shop-product",
    surfaceSelector: ".shop-product-surface",
    statusAttribute: "data-shop-product-status",
    interactionAttribute: "data-shop-product-interaction",
    disabledAttribute: "data-shop-product-refresh-disabled",
    refreshName: /refresh products/i,
    selectedControlName: /^m$/i,
    targetSelector: ".shop-product-action, .shop-size-action",
  });
});
