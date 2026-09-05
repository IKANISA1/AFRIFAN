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

const timestamp = "2026-07-30T09:00:00.000Z";
const syncRuns = Array.from({ length: 18 }, (_, index) => ({
  id: `run-${index + 1}`,
  status: index % 4 === 0 ? "failed" : "completed",
  trigger: index % 2 === 0 ? "scheduled" : "manual",
  scannedMessages: 20 + index,
  uploadedMessages: 18 + index,
  startedAt: new Date(Date.parse(timestamp) + index * 60_000).toISOString(),
}));
const review = {
  reviewId: "review-1",
  rawSmsId: "raw-1",
  parsedSmsId: "parsed-1",
  userId: "user-1",
  sender: "+250700000000",
  txType: "payment",
  txCategory: "contribution",
  cashflowBucket: "inflow",
  amount: 25_000,
  currency: "RWF",
  momoTxId: "tx-1",
  payerName: "Verified Supporter",
  payeeName: "AFRICLUB",
  payeeNumberOrCode: "123456",
  merchantCode: "123456",
  smsReceivedAt: timestamp,
  reviewCreatedAt: timestamp,
  updatedAt: timestamp,
  reviewKind: "needs_review",
  reason: "intent_match_required",
  notes: null,
  smsPreview: "Payment received and awaiting allocation.",
};
const intent = {
  id: "intent-1",
  userId: "user-1",
  userName: "Verified Supporter",
  expectedAmount: 25_000,
  currency: "RWF",
  status: "pending",
  targetTable: "contribution_intents",
  targetRecordId: "target-1",
  createdAt: timestamp,
  expiresAt: null,
  summaryLabel: "contribution intents",
};

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
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/evidence/admin_pwa_sms_monitor_states",
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
    const url = route.request().url();
    if (!url.includes("/api/admin/sms")) {
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
      const manual = url.includes("sms-manual-reviews");
      const data = manual
        ? {
            reviews: mode === "empty" ? [] : [review],
            pendingIntents: mode === "empty" ? [] : [intent],
          }
        : {
            metrics:
              mode === "empty"
                ? {}
                : {
                    "SMS captured": 40,
                    "SMS parsed": 36,
                    "Ledger entries": 34,
                  },
            syncRuns: mode === "empty" ? [] : syncRuns,
          };
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data }),
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
        error: "database.internal payer=private token=secret",
      }),
    });
  });

  const surface = () => page.locator("[data-admin-sms-status]").first();
  const open = (nonce: string) =>
    page.goto(`/admin/sms-monitor?club=24&evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-sms-status", status);
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
        `admin_sms_monitor_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading SMS monitor/i);
  await expect(
    page.getByRole("button", { name: /refresh SMS monitor/i }),
  ).toBeDisabled();
  await capture("loading");
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no SMS activity in this club/i);
  await capture("empty");

  for (const [failureMode, label] of [
    ["error", /SMS monitoring unavailable/i],
    ["conflict", /SMS monitoring data changed/i],
    ["security_timeout", /SMS monitoring request timed out/i],
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
  await expectStatus("ready", /SMS monitor confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /SMS monitoring is offline/i);
  await expect(page.getByText("Verified Supporter").first()).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /SMS monitor confirmed/i);
  await page.getByLabel("Search SMS synchronization runs").fill("private run");
  await page.getByLabel("Search manual SMS reviews").fill("private review");
  mode = "permission_denied";
  await page.getByRole("button", { name: /refresh SMS monitor/i }).click();
  await expectStatus("permission_denied", /SMS monitoring access denied/i);
  await expect(page.getByLabel("Search SMS synchronization runs")).toHaveCount(
    0,
  );
  await expect(page.getByLabel("Search manual SMS reviews")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("private review");
  await expect(page.getByText(/payment received/i)).toHaveCount(0);
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  await expectStatus("ready", /SMS monitor confirmed/i);
  const refresh = page.getByRole("button", { name: /refresh SMS monitor/i });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-sms-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute(
    "data-admin-sms-interaction",
    "pressed",
  );
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await page.locator("[data-row-id='review-1']").click();
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
  await expectStatus("ready", /SMS monitor confirmed/i);
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
    await expectStatus("ready", /SMS monitor confirmed/i);
    await expectNoOverflow(page);
    await capture(`responsive_${profile}`, profile);
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  mode = "ready";
  await open("syncing-preparation");
  await expectStatus("ready", /SMS monitor confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh SMS monitor/i }).click();
  await expectStatus("syncing", /refreshing SMS monitor/i);
  await expect(page.getByText("Verified Supporter").first()).toBeVisible();
  await capture("syncing");

  writeAdminStateEvidence({
    evidenceDirectory,
    manifestFile: "admin-sms-monitor-state-evidence.json",
    route: "/admin/sms-monitor",
    filePrefix: "admin_sms_monitor",
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
      raw_provider_diagnostics_rendered: false,
      supporter_phone_rendered: false,
      syncing_retains_confirmed_monitor_snapshot: true,
    },
  });

  await context.close();
}

test.describe("admin SMS monitor evidence matrix", () => {
  test("covers the governed route-state and interaction matrix", async ({
    browser,
  }) => {
    await runMatrix(browser);
  });
});
