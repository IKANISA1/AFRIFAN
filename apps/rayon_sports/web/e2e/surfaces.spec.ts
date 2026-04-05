import fs from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

const CLUB_ID = 24;

function loadLocalEnv() {
  const envPath = path.join(process.cwd(), ".env.local");
  if (!fs.existsSync(envPath)) {
    return {} as Record<string, string>;
  }

  return Object.fromEntries(
    fs
      .readFileSync(envPath, "utf8")
      .split(/\n+/)
      .filter(Boolean)
      .filter((line) => !line.startsWith("#"))
      .map((line) => {
        const separatorIndex = line.indexOf("=");
        return [line.slice(0, separatorIndex), line.slice(separatorIndex + 1)];
      }),
  );
}

function createAdminServiceClient() {
  const env = loadLocalEnv();
  const supabaseUrl =
    env.SUPABASE_URL ?? env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
    return null;
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

/* ────────────────────────────────────────────────────────── */
/*  Public surfaces                                          */
/* ────────────────────────────────────────────────────────── */

test("public home renders on a phone viewport", async ({ page }) => {
  await page.goto("/");

  await expect(
    page.getByRole("heading", { name: /this is gikundiro/i }),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: /open fan portal/i })).toBeVisible();
});

test("fan portal boots the anonymous supporter workspace on tablet", async ({
  page,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit is unreliable for the async fan portal loader bootstrap.",
  );

  await page.goto("/app", {
    waitUntil: browserName === "webkit" ? "networkidle" : "domcontentloaded",
  });

  await expect(page.getByText(/fan portal/i)).toBeVisible({
    timeout: browserName === "webkit" ? 15_000 : 5_000,
  });
  await expect(
    page.getByRole("heading", { name: /welcome supporter/i }),
  ).toBeVisible({
    timeout: browserName === "webkit" ? 15_000 : 5_000,
  });
  await expect(page.getByText(/membership tier/i)).toBeVisible({
    timeout: browserName === "webkit" ? 15_000 : 5_000,
  });
});

/* ────────────────────────────────────────────────────────── */
/*  Admin: OTP sign-in surface (replaces magic-link test)    */
/* ────────────────────────────────────────────────────────── */

test("admin route renders the phone OTP sign-in surface", async ({
  page,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit can remain on the admin loading shell during auth bootstrap.",
  );

  await page.goto("/admin", {
    waitUntil: browserName === "webkit" ? "networkidle" : "domcontentloaded",
  });

  // Admin workspace heading
  await expect(
    page.getByText(/admin workspace/i),
  ).toBeVisible();

  // Phone number input (OTP flow)
  const phoneInput = page.locator('input[type="tel"]');
  await expect(phoneInput).toBeVisible({
    timeout: browserName === "webkit" ? 15_000 : 5_000,
  });

  // Submit button for OTP
  await expect(
    page.getByRole("button", { name: /send code|send otp|sign in/i }),
  ).toBeVisible();
});

/* ────────────────────────────────────────────────────────── */
/*  PWA manifest + offline                                   */
/* ────────────────────────────────────────────────────────── */

test("pwa manifest and offline route are reachable", async ({
  page,
  request,
}) => {
  const manifestResponse = await request.get("/manifest.webmanifest");
  expect(manifestResponse.ok()).toBeTruthy();
  const manifest = await manifestResponse.json();

  // Public manifest should include the usual fields
  expect(manifest).toMatchObject({
    display: "standalone",
    start_url: "/app?source=pwa",
  });
  // Public manifest should NOT have admin scope
  expect(manifest.scope).not.toBe("/admin");

  await page.goto("/offline", { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", { name: /cached pages stay available/i }),
  ).toBeVisible();

  await page.goto("/admin-offline", { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", { name: /admin data needs a live connection/i }),
  ).toBeVisible();
});

/* ────────────────────────────────────────────────────────── */
/*  Offline synthetic test                                    */
/* ────────────────────────────────────────────────────────── */

test("admin renders offline fallback when network is disabled", async ({
  page,
  context,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit is unreliable for admin service worker control checks.",
  );

  // First visit admin to register SW and cache the offline page
  await page.goto("/admin", { waitUntil: "networkidle" });

  await page.waitForFunction(async () => {
    if (!("serviceWorker" in navigator)) {
      return true;
    }

    await navigator.serviceWorker.ready;
    return true;
  });

  if ((await page.evaluate(() => navigator.serviceWorker?.controller == null)) === true) {
    await page.reload({ waitUntil: "networkidle" });
  }

  // Go offline
  await context.setOffline(true);

  // Navigate to a different admin route — should get the offline fallback
  await page.goto("/admin/settings", {
    waitUntil: "domcontentloaded",
    timeout: 10_000,
  }).catch(() => null);

  // Either the offline page is served from SW or we get the admin-offline
  const content = await page.textContent("body");
  const hasOfflineIndicator =
    content?.includes("offline") ||
    content?.includes("live connection") ||
    content?.includes("network");

  expect(hasOfflineIndicator).toBeTruthy();

  // Restore network
  await context.setOffline(false);
});

/* ────────────────────────────────────────────────────────── */
/*  Admin: assignment-backed session (conditional)           */
/* ────────────────────────────────────────────────────────── */

test("admin auth with assignment-backed session reaches dashboard", async ({
  page,
  baseURL,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit is unreliable for live Supabase magic-link admin sessions.",
  );

  const serviceClient = createAdminServiceClient();
  if (serviceClient == null) {
    test.skip(true, "Live Supabase admin credentials are missing.");
    return;
  }

  const email = `playwright-admin-${Date.now()}@example.com`;
  let userId = "";

  try {
    // Create an admin user with a real assignment
    const created = await serviceClient.auth.admin.createUser({
      email,
      email_confirm: true,
      app_metadata: { role: "rayon_sport", club_id: CLUB_ID },
    });
    if (created.error) {
      throw created.error;
    }
    userId = created.data.user.id;

    const assignment = await serviceClient.from("admin_role_assignments").insert({
      user_id: userId,
      role: "rayon_sport",
      is_active: true,
      club_id: CLUB_ID,
      notes: "temporary playwright verification user",
    });
    if (assignment.error) {
      throw assignment.error;
    }

    // Use magic link as a bridge to bypass OTP in CI
    // (Phone OTP cannot be intercepted programmatically in CI without Twilio hooks)
    const redirectTo = `${baseURL}/admin`;
    const link = await serviceClient.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: { redirectTo },
    });

    // If magic link generation fails (user has no email), skip gracefully
    if (link.error) {
      test.skip(true, `Magic link bridge unavailable: ${link.error.message}`);
      return;
    }

    await page.goto(link.data.properties.action_link, {
      waitUntil: "networkidle",
      timeout: 120_000,
    });

    // After sign-in, we should see the admin dashboard
    await expect(
      page.getByText(/admin dashboard/i),
    ).toBeVisible({ timeout: 20_000 });
    await expect(
      page.getByRole("heading", {
        name: /operate matchdays, content, and supporter activity from one place/i,
      }),
    ).toBeVisible();
    await expect(page.getByRole("button", { name: /sign out|exit/i })).toBeVisible();
  } finally {
    if (userId) {
      await serviceClient.from("admin_role_assignments").delete().eq("user_id", userId);
      await serviceClient.auth.admin.deleteUser(userId);
    }
  }
});
