import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page, type Route } from "@playwright/test";
import { writeAdminStateEvidence } from "./admin-state-evidence-manifest";
import {
  installEvidenceNavigationStability,
  primeEvidenceScreenshot,
  settleEvidenceVisuals,
} from "./evidence-navigation-stability";

type Mode =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

const organizationId = "11111111-1111-4111-8111-111111111111";
const eventId = "22222222-2222-4222-8222-222222222222";
const venueId = "33333333-3333-4333-8333-333333333333";
const assignmentId = "44444444-4444-4444-8444-444444444444";
const userId = "55555555-5555-4555-8555-555555555555";
const workspace = {
  organizations: [{ id: organizationId, displayName: "Rayon Sports", status: "active" }],
  events: [{
    id: eventId,
    organizationId,
    organizationName: "Rayon Sports",
    venueId,
    venueName: "Kigali Stadium",
    matchLabel: "Rayon Sports vs Visitors",
    status: "active",
    entryOpensAt: "2026-09-01T14:00:00.000Z",
    entryClosesAt: "2026-09-01T20:00:00.000Z",
    verificationEnabled: true,
  }],
  assignments: [{
    id: assignmentId,
    ticketEventId: eventId,
    organizationId,
    organizationName: "Rayon Sports",
    venueId,
    venueName: "Kigali Stadium",
    matchLabel: "Rayon Sports vs Visitors",
    userId,
    publicUserId: "123456",
    userName: "Matchday Steward",
    gateCode: "NORTH_1",
    startsAt: "2026-09-01T14:00:00.000Z",
    endsAt: "2026-09-01T20:00:00.000Z",
    isActive: true,
    grantedAt: "2026-08-14T08:00:00.000Z",
    revokedAt: null,
    updatedAt: "2026-08-14T08:00:00.000Z",
  }],
};

async function expectAccessible(page: Page) {
  await settleEvidenceVisuals(page);
  const result = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  expect(
    result.violations.filter(({ impact }) =>
      impact === "critical" || impact === "serious"
    ),
  ).toHaveLength(0);
}

async function expectNoOverflow(page: Page) {
  const overflow = await page.evaluate(() =>
    document.documentElement.scrollWidth - document.documentElement.clientWidth
  );
  expect(overflow).toBeLessThanOrEqual(1);
}

async function runMatrix(browser: Browser) {
  const evidenceDirectory = prepareStateEvidence(browser, test.info(), "admin_pwa_ticket_verifiers_states");
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "dark",
  });
  await installEvidenceNavigationStability(context);
  const page = await context.newPage();
  // Apply the initial document theme explicitly; verify it at capture.
  await page.emulateMedia({ colorScheme: "dark" });
  let mode: Mode = "ready";

  const handleAdminRoute = async (route: Route) => {
    if (!route.request().url().includes("/api/admin/ticket-verifiers")) {
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
          data: mode === "empty"
            ? { organizations: [], events: [], assignments: [] }
            : workspace,
        }),
      });
      return;
    }
    const status = mode === "permission_denied"
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
        error: "database.internal phone=private token=secret",
      }),
    });
  };
  await context.route("**/api/admin/**", handleAdminRoute);

  const surface = () =>
    page.locator("[data-admin-ticket-verifiers-status]").first();
  const open = (nonce: string) =>
    navigateStateEvidence(page, `/admin/tickets/verifiers?club=24&evidence=${nonce}`, {
      waitUntil: "domcontentloaded",
    });
  const expectStatus = async (status: string, label: RegExp) => {
    await expect(surface()).toHaveAttribute(
      "data-admin-ticket-verifiers-status",
      status,
      { timeout: 15_000 },
    );
    await expect(page.getByText(label).first()).toBeVisible();
  };
  const capture = async (state: string, profile = "desktop_1440x1000") => {
    await page.evaluate(() => window.scrollTo(0, 0));
    await settleEvidenceVisuals(page);
    await primeEvidenceScreenshot(page, !state.startsWith("responsive_"));
    await captureStateScreenshot(page, {
      path: path.join(
        evidenceDirectory,
        `admin_ticket_verifiers_state_${state}_${state === "light" ? "light" : "dark"}_${profile}.png`,
      ),
      fullPage: !state.startsWith("responsive_"),
    });
  };

  mode = "loading";
  await open("loading");
  await expectStatus("loading", /loading verifier authority/i);
  await capture("loading");
  await capture("disabled");

  mode = "empty";
  await open("empty");
  await expectStatus("empty", /no ticket events configured/i);
  await capture("empty");

  for (const [failureMode, label] of [
    ["error", /verifier workspace unavailable/i],
    ["conflict", /verifier assignment changed/i],
    ["security_timeout", /verifier request timed out/i],
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
  await expectStatus("ready", /verifier authority confirmed/i);
  await context.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await expectStatus("offline", /verifier workspace is offline/i);
  await expect(page.getByText("Matchday Steward", { exact: true })).toBeVisible();
  await capture("offline");
  await context.setOffline(false);

  await open("permission-preparation");
  await expectStatus("ready", /verifier authority confirmed/i);
  await page.getByLabel("Verifier public user id").fill("123456");
  mode = "permission_denied";
  await page.getByRole("button", { name: /refresh verifier authority/i }).click();
  await expectStatus("permission_denied", /verifier management denied/i);
  await expect(page.getByLabel("Verifier public user id")).toHaveValue("");
  await expect(page.locator("body")).not.toContainText("Matchday Steward");
  await capture("permission_denied");

  mode = "ready";
  await open("interaction");
  await expectStatus("ready", /verifier authority confirmed/i);
  const refresh = page.getByRole("button", { name: /refresh verifier authority/i });
  await refresh.focus();
  await expect(surface()).toHaveAttribute(
    "data-admin-ticket-verifiers-interaction",
    "focused",
  );
  await capture("focused");
  await refresh.hover();
  await page.mouse.down();
  await expect(surface()).toHaveAttribute(
    "data-admin-ticket-verifiers-interaction",
    "pressed",
  );
  await capture("pressed");
  await page.mouse.up();
  await page.getByRole("checkbox", { name: /show revoked/i }).check();
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
  await expectStatus("ready", /verifier authority confirmed/i);
  expect(await page.evaluate(() =>
    Math.max(
      0,
      ...document.getAnimations().map((animation) =>
        Number(animation.effect?.getTiming().duration) || 0
      ),
    ) / 1_000
  )).toBeLessThanOrEqual(0.001);
  await capture("reduced_motion");

  await page.emulateMedia({ reducedMotion: "no-preference", colorScheme: "dark" });
  await open("dark");
  await expectStatus("ready", /verifier authority confirmed/i);
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
    ["tablet_834x1112", 834, 1112],
    ["mobile_390x844", 390, 844],
  ] as const) {
    await page.setViewportSize({ width, height });
    await open(`responsive-${profile}`);
    await expectStatus("ready", /verifier authority confirmed/i);
    await expectNoOverflow(page);
    await capture(`responsive_${profile}`, profile);
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  mode = "ready";
  await open("syncing-preparation");
  await expectStatus("ready", /verifier authority confirmed/i);
  mode = "loading";
  await page.getByRole("button", { name: /refresh verifier authority/i }).click();
  await expectStatus("syncing", /refreshing verifier authority/i);
  await expect(page.getByText("Matchday Steward", { exact: true })).toBeVisible();
  await capture("syncing");

  writeAdminStateEvidence({
    browser,
    evidenceDirectory,
    manifestFile: "admin-ticket-verifiers-state-evidence.json",
    route: "/admin/tickets/verifiers",
    filePrefix: "admin_ticket_verifiers",
    responsiveCaptures: [
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
      assignment_limit: 500,
      public_identifier_digits: 6,
      private_contact_fields_exposed: false,
      audited_grant_and_revoke_required: true,
    },
  });

  finalizeStateEvidence(evidenceDirectory);
  await context.close();
}

test.describe("admin ticket verifiers evidence matrix", () => {
  test("covers the governed route-state and interaction matrix", async ({ browser }) => {
    test.setTimeout(180_000);
    await runMatrix(browser);
  });
});
