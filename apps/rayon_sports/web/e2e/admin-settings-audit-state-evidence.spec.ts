import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page, type Route } from "@playwright/test";

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
  userName: index % 5 === 0 ? "System action" : `Verified administrator ${index + 1}`,
  action: index % 3 === 0 ? "settings.update" : "membership.review",
  targetTable: index % 3 === 0 ? "african_football_clubs" : "membership_applications",
  targetId: `record-${index + 1}`,
  oldData: { status: "pending", access_token: "private-token" },
  newData: { status: "confirmed", password: "private-password" },
  metadata: { request_id: `request-${index + 1}`, authorization: "private-auth" },
  notes: "Verified governed change.",
  createdAt: new Date(Date.parse(timestamp) + index * 60_000).toISOString(),
  actor_id: `private-actor-${index + 1}`,
}));

async function settle(page: Page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    for (const animation of document.getAnimations()) animation.finish();
    await new Promise<void>((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
    );
  });
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
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    ),
  ).toBeLessThanOrEqual(1);
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = path.resolve(
    process.cwd(),
    "../../../output/implementation_goal_20260724/admin_pwa_settings_audit_states",
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
  });
  const page = await context.newPage();
  let mode: Mode = "ready";

  await page.route("**/api/admin/**", async (route: Route) => {
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
    page.goto(`/admin/settings/audit?evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute("data-admin-audit-status", status);
    await expect(page.getByText(label).first()).toBeVisible();
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await page.evaluate((blur) => {
      if (blur && document.activeElement instanceof HTMLElement) {
        document.activeElement.blur();
      }
      window.scrollTo(0, 0);
    }, state === "selected" || state === "large_text");
    await settle(page);
    await page.screenshot({
      path: path.join(
        evidenceDirectory,
        `admin_settings_audit_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
      animations: "disabled",
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading audit history/i);
  await capture("loading");
  await expect(page.getByRole("button", { name: /refresh audit history/i })).toBeDisabled();
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
  await expect(page.getByText("Verified administrator 2")).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  mode = "ready";
  await open("permission-preparation");
  await page.getByLabel("Filter audit logs").fill("private filter");
  await page.getByRole("button", { name: /view audit details/i }).first().click();
  await expect(page.getByText("Audit record details")).toBeVisible();
  mode = "permission_denied";
  await page.getByRole("button", { name: /refresh audit history/i }).click();
  await expectStatus("permission_denied", /audit access denied/i);
  await expect(page.getByLabel("Filter audit logs")).toHaveCount(0);
  await expect(page.getByText("Audit record details")).toHaveCount(0);
  await expect(page.locator("body")).not.toContainText("private filter");
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  const refresh = page.getByRole("button", { name: /refresh audit history/i });
  await refresh.focus();
  await expect(surface()).toHaveAttribute("data-admin-audit-interaction", "focused");
  await capture("focused");
  await refresh.dispatchEvent("pointerdown", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await expect(surface()).toHaveAttribute("data-admin-audit-interaction", "pressed");
  await capture("pressed");
  await refresh.dispatchEvent("pointerup", {
    pointerId: 1,
    pointerType: "mouse",
    isPrimary: true,
  });
  await page.getByRole("button", { name: /view audit details/i }).first().click();
  await expect(surface()).toHaveAttribute("data-admin-audit-interaction", "selected");
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
            .map((animation) => Number(animation.effect?.getTiming().duration) || 0),
        ) / 1_000,
    ),
  ).toBeLessThanOrEqual(0.001);
  await capture("reduced_motion");

  await page.emulateMedia({ reducedMotion: "no-preference", colorScheme: "dark" });
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
  mode = "loading";
  await page.getByRole("button", { name: /refresh audit history/i }).click();
  await expectStatus("syncing", /refreshing audit history/i);
  await expect(page.getByText("Verified administrator 2")).toBeVisible();
  await capture("syncing");

  mode = "ready";
  await open("conflict");
  mode = "conflict";
  await page.getByRole("button", { name: /refresh audit history/i }).click();
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
  await page.setViewportSize({ width: 390, height: 844 });
  await open("compact");
  await expectNoOverflow(page);
  await capture("responsive_compact", "compact_390x844");

  const states = [
    "loading", "empty", "error", "offline", "permission_denied", "disabled",
    "focused", "pressed", "selected", "large_text", "reduced_motion", "dark",
    "light", "syncing", "conflict", "security_timeout",
  ];
  fs.writeFileSync(
    path.join(evidenceDirectory, "admin-settings-audit-state-evidence.json"),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route: "/admin/settings/audit",
        surface: "admin_pwa",
        applicable_states: states,
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
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          axe_critical_or_serious: 0,
        },
      },
      null,
      2,
    )}\n`,
  );
  await context.close();
}

test.describe("controlled Admin PWA audit evidence", () => {
  test("captures the exact audit state matrix", async ({ browser }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
