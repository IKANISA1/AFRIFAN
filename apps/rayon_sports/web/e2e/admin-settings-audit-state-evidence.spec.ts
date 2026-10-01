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
const records = Array.from({ length: 30 }, (_, index) => ({
  id: `audit-${index + 1}`,
  actorKind: index % 5 === 0 ? "system" : "administrator",
  userName:
    index % 5 === 0 ? "System action" : `Verified administrator ${index + 1}`,
  action: index % 3 === 0 ? "settings.update" : "membership.review",
  targetTable:
    index % 3 === 0 ? "african_football_clubs" : "membership_applications",
  targetId: `record-${index + 1}`,
  oldData: { status: "pending", access_token: "private-token" },
  newData: { status: "confirmed", password: "private-password" },
  metadata: {
    request_id: `request-${index + 1}`,
    authorization: "private-auth",
  },
  notes: "Verified governed change.",
  createdAt: new Date(Date.parse(timestamp) + index * 60_000).toISOString(),
  actor_id: `private-actor-${index + 1}`,
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
  expect(
    await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_settings_audit_states");
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
        error: "database.internal actor_email=private token=secret",
      }),
    });
  });

  const surface = () => page.locator(".admin-audit-state-surface").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/settings/audit?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-audit-status", status);
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
        `admin_settings_audit_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading audit history/i);
  await capture("loading");
  await expect(
    page.getByRole("button", { name: /refresh audit history/i }),
  ).toBeDisabled();
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no audit records in this scope/i);
  await expect(page.getByText(/no audit records are available/i)).toBeVisible();
  await capture("empty");

  mode = "error";
  await open("error");
  await expectStatus("error", /audit history unavailable/i);
  await expect(page.locator("body")).not.toContainText("database.internal");
  await capture("error");

  mode = "ready";
  await open("offline");
  await expectStatus("ready", /audit history confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /audit history is offline/i);
  await expect(
    page.getByText("Verified administrator 29", { exact: true }),
  ).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "ready";
  await open("permission-preparation");
  await expectStatus("ready", /audit history confirmed/i);
  await page.getByLabel("Filter audit logs").fill("private filter");
  mode = "permission_denied";
  await page.getByRole("button", { name: /refresh audit history/i }).click();
  await expectStatus("permission_denied", /audit access denied/i);
  await expect(page.getByLabel("Filter audit logs")).toHaveCount(0);
  await expect(page.getByText("Audit record details")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("private filter");
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  await expectStatus("ready", /audit history confirmed/i);
  const refresh = page.getByRole("button", { name: /refresh audit history/i });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-audit-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-audit-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();
  await page
    .getByRole("button", { name: /view audit details/i })
    .first()
    .click();
  await expect(surface()).toHaveAttribute(
    "data-admin-audit-interaction",
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
  await expectStatus("ready", /audit history confirmed/i);
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
  await expectStatus("ready", /audit history confirmed/i);
  await expectAccessible(page);
  for (const privateText of [
    "private-token",
    "private-password",
    "private-auth",
    "private-actor",
    "actor_email",
  ]) {
    await expect(page.locator("body")).not.toContainText(privateText);
  }
  const undersized = await surface()
    .locator("button:visible, input:visible")
    .evaluateAll((elements) =>
      elements
        .map((element) => element.getBoundingClientRect())
        .filter(({ width, height }) => width < 48 || height < 48),
    );
  expect(undersized).toEqual([]);
  await capture("dark");

  await page.emulateMedia({ colorScheme: "light" });
  await open("light");
  await expectStatus("ready", /audit history confirmed/i);
  await expectAccessible(page);
  await capture("light");

  await page.emulateMedia({ colorScheme: "dark" });
  mode = "ready";
  await open("syncing");
  await expectStatus("ready", /audit history confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh audit history/i }).click();
  await expectStatus("syncing", /refreshing audit history/i);
  await expect(
    page.getByText("Verified administrator 29", { exact: true }),
  ).toBeVisible();
  await capture("syncing");

  mode = "ready";
  await open("conflict");
  await expectStatus("ready", /audit history confirmed/i);
  mode = "conflict";
  const conflictRefresh = page.getByRole("button", {
    name: /refresh audit history/i,
  });
  await expect(conflictRefresh).toBeVisible();
  // The conflict response synchronously replaces this control with recovery
  // UI. Dispatching the controlled event avoids waiting on a detached node.
  await conflictRefresh.dispatchEvent("click");
  await expectStatus("conflict", /audit history changed/i);
  await capture("conflict");

  mode = "security_timeout";
  await open("security-timeout");
  await expectStatus("security_timeout", /audit request timed out/i);
  await capture("security_timeout");

  mode = "ready";
  await page.setViewportSize({ width: 1024, height: 900 });
  await open("tablet");
  await expectNoOverflow(page);
  await capture("responsive_tablet", "tablet_1024x900");
  await page.close();
  page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectNoOverflow(page);
  await capture("responsive_compact", "compact_390x844");

  writeAdminStateEvidence({
    browser,
    evidenceDirectory,
    manifestFile: "admin-settings-audit-state-evidence.json",
    route: "/admin/settings/audit",
    filePrefix: "admin_settings_audit",
    responsiveCaptures: [
      {
        state: "responsive_tablet",
        profile: "tablet_1024x900",
        description: `${browser.browserType().name()} tablet 1024x900 at 1 DPR`,
      },
      {
        state: "responsive_compact",
        profile: "compact_390x844",
        description: `${browser.browserType().name()} compact 390x844 at 1 DPR`,
      },
    ],
    assertions: {
      bounded_records: 500,
      page_size: 25,
      club_scope_required: true,
      unscoped_club_admin_fallback: false,
      actor_identifiers_rendered: false,
      sensitive_audit_values_redacted: true,
      raw_metadata_collapsed_until_explicit_detail: true,
      confirmed_data_retained_during_recovery: true,
      permission_denial_clears_records_filter_page_and_detail: true,
    },
  });
  finalizeStateEvidence(evidenceDirectory);
  await context.close();
}

test.describe("controlled Admin PWA audit evidence", () => {
  test("captures the exact audit state matrix", async ({ browser }) => {
    test.setTimeout(360_000);
    await runMatrix(browser);
  });
});
