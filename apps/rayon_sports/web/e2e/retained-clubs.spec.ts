import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import fs from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { captureStateScreenshot, finalizeStateEvidence, prepareStateEvidence } from "./state-evidence-provenance";

for (const [host, name, rayon, crest] of [
  ["vitalo.example.test", "Vital'O FC", false, "vitalo.png"],
  ["rayon-sports.example.test", "Rayon Sports FC", true, "rayon-sports.png"],
  ["nkana.example.test", "Nkana FC", false, "nkana.png"],
  ["as-vita.example.test", "AS Vita Club", false, "as-vita.png"],
  ["costa-do-sol.example.test", "CD Costa do Sol", false, null],
] as const) {
  test(`${name} keeps support, deletion and metadata bound to its own identity`, async ({ page }) => {
    const brand = rayon ? "Gikundiro" : host.startsWith("vitalo.") ? "Vital'O" : host.startsWith("costa-do-sol.") ? "Costa do Sol" : name;
    await page.setExtraHTTPHeaders({ "x-forwarded-host": host });
    for (const route of ["/support", "/account-deletion", "/share-target"]) {
      await page.goto(route, { waitUntil: "domcontentloaded" });
      await expect(page).toHaveTitle(new RegExp(brand));
      await expect(page.locator('meta[property="og:site_name"]')).toHaveAttribute("content", brand);
      const jsonLd = JSON.parse(await page.locator('script[type="application/ld+json"]').first().innerText());
      expect(jsonLd["@graph"][0].name).toBe(brand);
      if (!rayon) {
        expect(await page.title()).not.toMatch(/Gikundiro|Rayon/);
        await expect(page.locator('link[rel="canonical"]')).toHaveCount(0);
      }
      if (route !== "/share-target") {
        const link = page.getByRole("link", { name: route === "/support" ? `Email ${brand} support` : "Start a deletion request", exact: true });
        const href = await link.getAttribute("href");
        expect(new URL(href!).searchParams.get("subject")).toBe(`${brand} ${route === "/support" ? "support" : "account deletion"} request`);
      }
    }
  });

  test(`${name} keeps its website identity and header controls`, async ({ page, browser }, testInfo) => {
    const evidence = process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE === "1"
      ? prepareStateEvidence(browser, testInfo, `retained_club_${host.split(".")[0].replaceAll("-", "_")}`) : null;
    await page.setExtraHTTPHeaders({ "x-forwarded-host": host });
    await page.goto("/", { waitUntil: "domcontentloaded" });
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(`${rayon ? "Rayon Sports" : host.startsWith("vitalo.") ? "Vital'O" : host.startsWith("costa-do-sol.") ? "Costa do Sol" : name}. Matchday starts here.`);
    await expect(page.locator(".blue-wall-score")).toHaveCount(0);
    await expect(page.locator(".circles-content")).toHaveAttribute("aria-busy", "false");
    if (!rayon) {
      await expect(page.locator('img[src*="youtube"]')).toHaveCount(0);
      await expect(page.locator("footer")).not.toContainText(/Rayon|Rwandan|Gikundiro/);
    }
    const mark = await page.request.get("/brand-mark.svg", { headers: { "x-forwarded-host": host }, maxRedirects: 0 });
    if (crest) {
      expect(mark.status()).toBe(307);
      expect(mark.headers().location).toBe(`/crests/${crest}`);
      const artwork = await page.request.get(mark.headers().location);
      expect(artwork.ok()).toBe(true);
      expect(artwork.headers()["content-type"]).toContain("image/png");
      const digest = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");
      expect(digest(await artwork.body())).toBe(digest(fs.readFileSync(path.join(process.cwd(), "public/crests", crest))));
    } else {
      expect(mark.status()).toBe(200);
      expect(mark.headers()["content-type"]).toContain("image/svg+xml");
      expect(await mark.text()).toContain("CDS");
    }
    const result = await new AxeBuilder({ page }).include("nav.site-primary-navigation")
      .withRules(["color-contrast"]).analyze();
    expect(result.violations).toEqual([]);
    await expect(page.getByRole("link", { name: "Fan Portal", exact: true }).first()).toBeInViewport();
    if (evidence) {
      await captureStateScreenshot(page, { path: path.join(evidence, "club_home_default.png"), fullPage: true });
      fs.writeFileSync(path.join(evidence, "retained-club-state-evidence.json"), JSON.stringify({
        schema_version: "1.0", route: "/", surface: "consumer_web", club: name,
        applicable_states: ["default"], not_applicable_states: [],
        scope: "Club identity and frontend layout at the recorded browser viewport. The controlled runtime has no production data access; complete Home states are captured by the shared Home suite.",
        captures: [{ route: "/", state: "default", file: "club_home_default.png", club: name }],
      }, null, 2));
      finalizeStateEvidence(evidence);
    }
  });
}
