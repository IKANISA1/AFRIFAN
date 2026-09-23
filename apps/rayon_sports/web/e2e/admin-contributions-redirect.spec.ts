import { expect, test } from "@playwright/test";

test("retired contributions page opens the single community workspace with its club scope", async ({ page }) => {
  await page.route("**/api/admin/fan-clubs*", route => route.fulfill({
    status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }),
  }));
  await page.route("**/api/admin/contributions*", route => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({ data: { groups: [], contributions: [], monthlyTotal: 0 } }),
  }));
  await page.goto("/admin/contributions?club=26&evidence=redirect");
  await expect(page).toHaveURL(/\/admin\/community\?club=26&tab=groups$/);
  // The legacy link retains the production authorization boundary. Re-enter
  // the destination with the explicit localhost-only fixture flag to inspect its tab.
  await page.goto("/admin/community?club=26&tab=groups&evidence=redirect-target");
  await expect(page.getByRole("tab", { name: "groups", exact: true })).toHaveAttribute("aria-selected", "true");
  await expect(page.locator(".admin-contributions-state-surface")).toHaveCount(0);
});
