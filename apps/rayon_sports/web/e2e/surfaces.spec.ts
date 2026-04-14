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
  const supabaseUrl = env.SUPABASE_URL ?? env.NEXT_PUBLIC_SUPABASE_URL ?? "";
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
  await expect(
    page.getByRole("link", {
      name: /app y'abafana|open fan app|open supporter app/i,
    }),
  ).toBeVisible();
});

test("supporters handoff page renders on tablet", async ({ page }) => {
  await page.goto("/supporters", { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", {
      name: /urugendo rw'umufana rukomereza kuri mobile/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByText(/catalogue imwe ya Fan Engagement Token icungwa na admin/i),
  ).toBeVisible();
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

  // Admin auth heading
  await expect(page.getByText(/secure sign in/i)).toBeVisible();

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
    start_url: "/",
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

test("admin surfaces an offline indicator when network is disabled", async ({
  page,
  context,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit is unreliable for admin service worker control checks.",
  );

  // First visit the admin shell so the page has a mounted offline listener.
  await page.goto("/admin", { waitUntil: "domcontentloaded" });
  await expect(page.getByText(/secure sign in/i)).toBeVisible();

  // Go offline
  await context.setOffline(true);
  await expect(
    page.getByText(
      /admin shell stays available|live admin data and writes require the network/i,
    ),
  ).toBeVisible({ timeout: 5_000 });

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

    const assignment = await serviceClient
      .from("admin_role_assignments")
      .insert({
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

    // After sign-in, we should see the operations dashboard
    await expect(page.getByText(/operations dashboard/i)).toBeVisible({
      timeout: 20_000,
    });
    await expect(
      page.getByText(/signal first\. actions stay one click away\./i),
    ).toBeVisible();
    await expect(page.getByText(/secure session/i)).toBeVisible();
  } finally {
    if (userId) {
      await serviceClient
        .from("admin_role_assignments")
        .delete()
        .eq("user_id", userId);
      await serviceClient.auth.admin.deleteUser(userId);
    }
  }
});
