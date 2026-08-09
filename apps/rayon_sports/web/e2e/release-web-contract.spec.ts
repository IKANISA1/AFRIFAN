import { expect, test } from "@playwright/test";

const expectedSecurityHeaders = [
  "content-security-policy",
  "referrer-policy",
  "x-content-type-options",
  "x-frame-options",
  "x-permitted-cross-domain-policies",
] as const;

test("store policy and support routes render actionable governed content", async ({
  page,
}) => {
  await page.goto("/privacy");
  await expect(page.locator('[data-legal-document="privacy"]')).toBeVisible();
  await expect(page.getByRole("heading", { name: "Information we process" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Request account deletion" })).toHaveAttribute(
    "href",
    "/account-deletion",
  );

  await page.goto("/terms");
  await expect(page.locator('[data-legal-document="terms"]')).toBeVisible();
  await expect(page.getByRole("heading", { name: "Community content and conduct" })).toBeVisible();

  await page.goto("/support");
  await expect(page.locator('[data-support-kind="support"]')).toBeVisible();
  await expect(page.getByRole("link", { name: "Email Gikundiro support" })).toHaveAttribute(
    "href",
    /mailto:support@ikanisa\.com/,
  );

  await page.goto("/account-deletion");
  await expect(page.locator('[data-support-kind="account-deletion"]')).toBeVisible();
  await expect(
    page.getByText(/will never ask for a password, one-time code/i),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: "Start a deletion request" })).toHaveAttribute(
    "href",
    /mailto:support@ikanisa\.com/,
  );
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth,
    ),
  ).toBe(false);
});

test("association documents are direct verifier-safe JSON responses", async ({
  request,
}) => {
  const android = await request.get("/.well-known/assetlinks.json", {
    maxRedirects: 0,
  });
  expect(android.status()).toBe(200);
  expect(android.headers()["location"]).toBeUndefined();
  expect(android.headers()["content-type"]).toContain("application/json");
  expect(android.headers()["access-control-allow-origin"]).toBe("*");
  expect(android.headers()["cache-control"]).toContain("s-maxage=");
  expect(android.headers()["cross-origin-resource-policy"]).toBe(
    "cross-origin",
  );
  expect(android.headers()["x-content-type-options"]).toBe("nosniff");
  const assetLinks = (await android.json()) as Array<{
    target: { package_name: string; sha256_cert_fingerprints: string[] };
  }>;
  expect(assetLinks[0]?.target.package_name).toBe("rw.gikundiro.app");
  expect(assetLinks[0]?.target.sha256_cert_fingerprints).not.toHaveLength(0);

  const apple = await request.get(
    "/.well-known/apple-app-site-association",
    { maxRedirects: 0 },
  );
  expect(apple.status()).toBe(200);
  expect(apple.headers()["location"]).toBeUndefined();
  expect(apple.headers()["content-type"]).toContain("application/json");
  expect(apple.headers()["access-control-allow-origin"]).toBe("*");
  expect(apple.headers()["cross-origin-resource-policy"]).toBe(
    "cross-origin",
  );
  const association = (await apple.json()) as {
    applinks: { details: Array<{ appIDs: string[] }> };
  };
  expect(association.applinks.details[0]?.appIDs).toContain(
    "63STJ5N27W.rw.ikanisa.rayonSports",
  );
});

test("policy endpoints bypass the admin-host rewrite and retain security headers", async ({
  page,
}) => {
  await page.setExtraHTTPHeaders({
    "x-forwarded-host": "admin.gikundiro.com",
  });
  const response = await page.goto("/privacy");
  expect(response?.status()).toBe(200);
  await expect(page.locator('[data-legal-document="privacy"]')).toBeVisible();

  const headers = response?.headers() ?? {};
  for (const header of expectedSecurityHeaders) {
    expect(headers[header], `${header} is present`).toBeTruthy();
  }
  expect(headers["x-frame-options"]).toBe("DENY");
  expect(headers["x-content-type-options"]).toBe("nosniff");
});

test("Worker preview aliases carry an explicit noindex response", async ({
  page,
}) => {
  await page.setExtraHTTPHeaders({
    "x-forwarded-host": "candidate-gikundiro-web.ikanisa.workers.dev",
  });
  const response = await page.goto("/support");

  expect(response?.status()).toBe(200);
  expect(response?.headers()["x-robots-tag"]).toBe(
    "noindex, nofollow, noarchive",
  );
});
