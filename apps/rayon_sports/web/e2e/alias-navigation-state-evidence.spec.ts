import fs from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";
import { localClub, localStateContextOptions } from "./fixtures/local-route-assertions.mjs";
import { captureStateScreenshot, createStateEvidenceContext, finalizeStateEvidence, prepareStateEvidence } from "./state-evidence-provenance";

test("actual contributions alias traverses canonical admin admission", async ({ browser }) => {
  test.setTimeout(360_000);
  const evidence = prepareStateEvidence(browser, test.info(), "admin_contributions_alias_navigation");
  const club = localClub(test.info());
  expect(club).toBeTruthy();
  const context = await createStateEvidenceContext(browser, {
    ...localStateContextOptions(test.info(), true),
    serviceWorkers: "block",
  });
  try {
    const page = await context.newPage();
    const responses: { path: string; status: number }[] = [];
    page.on("response", (response) => {
      const url = new URL(response.url());
      if (url.origin === "http://127.0.0.1:3200" &&
          ["/admin/contributions", "/admin/community"].includes(url.pathname)) {
        responses.push({ path: url.pathname, status: response.status() });
      }
    });
    // No evidence marker or auth/API substitutions: the real compatibility
    // response redirects, then the real shell denies absent session authority.
    await page.goto(`/admin/contributions?club=${club!.id}`, { waitUntil: "domcontentloaded" });
    await expect(page).toHaveURL(new RegExp(`/admin/community\\?club=${club!.id}&tab=groups$`));
    await expect(page.getByRole("heading", { name: "Secure sign in" })).toBeVisible();
    await expect(page.locator("#admin-main-content")).toHaveCount(0);
    expect(responses).toContainEqual({ path: "/admin/contributions", status: 307 });
    expect(responses).toContainEqual({ path: "/admin/community", status: 200 });
    fs.writeFileSync(path.join(evidence, "navigation.json"), JSON.stringify({
      requested: "/admin/contributions", destination: "/admin/community",
      club: club!.slug, responses, protectedContentRendered: false,
      scope: "Actual alias request and canonical admission; no alias DOM/a11y credit.",
    }, null, 2));
    console.log(JSON.stringify({ localRouteAssertion: 1, surface: "admin_pwa",
      route: "/admin/contributions", kind: "redirect", state: "permission_denied",
      club: club!.slug, assertions: ["finite controlled navigation outcome"],
    }));
    // This engineering screenshot records the canonical admission boundary;
    // its filename gives no alias visual-state credit.
    const file = "admin_contributions_alias_actual_admission.png";
    await captureStateScreenshot(page, { path: path.join(evidence, file), animations: "disabled" });
    fs.writeFileSync(path.join(evidence, "alias-navigation-state-evidence.json"), JSON.stringify({
      captures: [{ file }], renderedSurface: "/admin/community", aliasOwnedUI: false,
    }, null, 2));
    finalizeStateEvidence(evidence);
  } finally {
    await context.close();
  }
});
