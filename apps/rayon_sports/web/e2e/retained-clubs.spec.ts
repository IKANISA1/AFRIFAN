import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

for (const [host, name, rayon] of [
  ["vitalo.example.test", "Vital'O FC", false],
  ["rayon-sports.example.test", "Rayon Sports FC", true],
  ["nkana.example.test", "Nkana FC", false],
  ["as-vita.example.test", "AS Vita Club", false],
] as const) {
  test(`${name} keeps support, deletion and metadata bound to its own identity`, async ({ page }) => {
    const brand = rayon ? "Gikundiro" : name;
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

  test(`${name} keeps its website identity and header controls`, async ({ page }) => {
    await page.setExtraHTTPHeaders({ "x-forwarded-host": host });
    await page.goto("/", { waitUntil: "domcontentloaded" });
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(`${name}. Matchday starts here.`);
    await expect(page.locator(".blue-wall-score")).toHaveCount(0);
    await expect(page.locator(".circles-content")).toHaveAttribute("aria-busy", "false");
    if (!rayon) {
      await expect(page.locator('img[src*="youtube"]')).toHaveCount(0);
      await expect(page.locator("footer")).not.toContainText(/Rayon|Rwandan|Gikundiro/);
    }
    const mark = await page.request.get("/brand-mark.svg", { headers: { "x-forwarded-host": host } });
    expect(mark.ok()).toBe(true);
    expect(await mark.text()).toContain(name.replaceAll("'", "&apos;"));
    const result = await new AxeBuilder({ page }).include("nav.site-primary-navigation")
      .withRules(["color-contrast"]).analyze();
    expect(result.violations).toEqual([]);
    await expect(page.getByRole("link", { name: "Fan Portal", exact: true }).first()).toBeInViewport();
  });
}
