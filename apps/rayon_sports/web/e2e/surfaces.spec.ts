import fs from "node:fs";
import path from "node:path";
import { expect, test, type Page } from "@playwright/test";
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

async function installSupabaseSessionCookies(
  page: Page,
  baseURL: string,
  email: string,
  password: string,
) {
  const env = loadLocalEnv();
  const supabaseUrl = env.SUPABASE_URL ?? env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const anonKey =
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? env.SUPABASE_ANON_KEY ?? "";
  if (!supabaseUrl || !anonKey) {
    throw new Error(
      "Public Supabase credentials are required for authenticated E2E.",
    );
  }

  const client = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const signedIn = await client.auth.signInWithPassword({ email, password });
  if (signedIn.error || signedIn.data.session == null) {
    throw signedIn.error ?? new Error("Supabase did not return a session.");
  }

  const projectRef = new URL(supabaseUrl).hostname.split(".")[0];
  const cookieKey = `sb-${projectRef}-auth-token`;
  const encoded = `base64-${Buffer.from(
    JSON.stringify(signedIn.data.session),
    "utf8",
  ).toString("base64url")}`;
  const chunks = encoded.match(/.{1,3180}/g) ?? [];
  await page.context().addCookies(
    chunks.map((value, index) => ({
      name: chunks.length === 1 ? cookieKey : `${cookieKey}.${index}`,
      value,
      url: baseURL,
      httpOnly: false,
      sameSite: "Lax" as const,
    })),
  );
}

/* ────────────────────────────────────────────────────────── */
/*  Public surfaces                                          */
/* ────────────────────────────────────────────────────────── */

test("public home preserves club identity and primary journeys", async ({ page }) => {
  await page.goto("/");

  await expect(
    page.getByRole("navigation").first().getByRole("img", {
      name: "Rayon Sports FC", exact: true,
    }),
  ).toBeVisible();
  const home = page.getByRole("main");
  await expect(home.getByRole("heading", { level: 1 })).toBeVisible();
  const tickets = home.getByRole("link", { name: "Get tickets", exact: true });
  await expect(tickets).toHaveAttribute("href", "/tickets");
  await expect(home.getByRole("link", { name: "Join Gikundiro", exact: true }))
    .toHaveAttribute("href", "/membership");
  await tickets.click();
  await expect(page).toHaveURL(/\/tickets(?:\?.*)?$/);
});

test("supporters handoff page renders on tablet", async ({ page }) => {
  await page.goto("/supporters", { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", {
      name: /rayon sports rewards and public ranking/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", {
      name: /confirmed reward catalog|no public rewards listed/i,
    }),
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

test("admin surfaces an offline indicator when the browser reports offline", async ({
  page,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit is unreliable for admin service worker control checks.",
  );

  // First visit the admin shell so the page has a mounted offline listener.
  await page.goto("/admin", { waitUntil: "domcontentloaded" });
  await expect(page.getByText(/secure sign in/i)).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute(
    "data-africlub-network-observer",
    "ready",
  );

  // Dispatch the same browser event used by a real network transition. Keeping
  // the test page online avoids a race with Next.js auth bootstrap navigation;
  // the separately tested /admin-offline route covers navigation fallback.
  await page.evaluate(() => {
    window.dispatchEvent(new Event("offline"));
  });
  await expect(
    page.getByText(
      /admin shell stays available|live admin data and writes require the network/i,
    ),
  ).toBeVisible({ timeout: 5_000 });

  await page.evaluate(() => {
    window.dispatchEvent(new Event("online"));
  });
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
  test.skip(
    process.env.ALLOW_LIVE_ADMIN_E2E !== "1",
    "Live admin user and assignment mutations require ALLOW_LIVE_ADMIN_E2E=1.",
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
      app_metadata: { role: "club_admin", club_id: CLUB_ID },
    });
    if (created.error) {
      throw created.error;
    }
    userId = created.data.user.id;

    const assignment = await serviceClient
      .from("admin_role_assignments")
      .insert({
        user_id: userId,
        role: "club_admin",
        is_active: true,
        club_id: CLUB_ID,
        notes: "temporary playwright verification user",
      });
    if (assignment.error) {
      throw assignment.error;
    }

    // Use magic link as a bridge to bypass OTP in CI.
    // The WhatsApp Cloud API OTP delivery hook is exercised separately.
    const redirectTo = `${baseURL}/auth/callback?next=/admin`;
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
    await expect(
      page
        .locator("#admin-main-content")
        .getByRole("heading", { name: /operations dashboard/i })
        .first(),
    ).toBeVisible({
      timeout: 20_000,
    });
    await expect(
      page
        .locator("#admin-main-content")
        .getByRole("heading", { name: /quick actions/i })
        .first(),
    ).toBeVisible();
    await expect(
      page
        .locator("#admin-main-content")
        .getByRole("heading", { name: /recent activity/i })
        .first(),
    ).toBeVisible();

    const moreButton = page.getByRole("button", {
      name: /show more admin options/i,
    });
    await expect(moreButton).toBeVisible();
    await moreButton.click();

    const moreDialog = page.getByRole("dialog", {
      name: /more admin options/i,
    });
    await expect(moreDialog).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(moreDialog).toBeHidden();

    const horizontalOverflow = await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    );
    expect(horizontalOverflow).toBeLessThanOrEqual(1);
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

/* ────────────────────────────────────────────────────────── */
/*  Venue: assignment-backed workflows and revocation        */
/* ────────────────────────────────────────────────────────── */

test("venue manager session reaches every scoped workflow and revocation fails closed", async ({
  page,
  baseURL,
  browserName,
}) => {
  test.skip(
    browserName === "webkit",
    "Playwright WebKit is unreliable for live Supabase magic-link sessions.",
  );
  test.skip(
    process.env.ALLOW_LIVE_ADMIN_E2E !== "1",
    "Live venue, user, and membership mutations require ALLOW_LIVE_ADMIN_E2E=1.",
  );

  const serviceClient = createAdminServiceClient();
  if (serviceClient == null) {
    test.skip(true, "Live Supabase admin credentials are missing.");
    return;
  }

  const venueResult = await serviceClient
    .from("venues")
    .select("id, club_id")
    .eq("club_id", CLUB_ID)
    .eq("status", "approved")
    .limit(1)
    .maybeSingle();
  if (venueResult.error) throw venueResult.error;

  const email = `playwright-venue-${Date.now()}@example.com`;
  const password = `Venue-E2E-${crypto.randomUUID()}-Aa9!`;
  let userId = "";
  let membershipId = "";
  let venueId = venueResult.data?.id ?? "";
  let createdTemporaryVenue = false;

  try {
    if (!venueId) {
      const temporaryVenue = await serviceClient
        .from("venues")
        .insert({
          club_id: CLUB_ID,
          slug: `playwright-venue-${Date.now()}`,
          display_name: "Playwright Venue",
          status: "approved",
          venue_type: "partner_bar",
          city: "Kigali",
          country_code: "RW",
          timezone: "Africa/Kigali",
          approved_public_profile: false,
          metadata: { purpose: "temporary authenticated venue E2E" },
        })
        .select("id")
        .single();
      if (temporaryVenue.error) throw temporaryVenue.error;
      venueId = temporaryVenue.data.id;
      createdTemporaryVenue = true;
    }

    const created = await serviceClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { role: "venue_manager", club_id: CLUB_ID },
    });
    if (created.error) throw created.error;
    userId = created.data.user.id;

    const membership = await serviceClient
      .from("venue_staff_memberships")
      .insert({
        user_id: userId,
        club_id: CLUB_ID,
        venue_id: venueId,
        role: "manager",
        is_active: true,
        notes: "temporary authenticated venue Playwright verification user",
      })
      .select("id")
      .single();
    if (membership.error) throw membership.error;
    membershipId = membership.data.id;

    await installSupabaseSessionCookies(page, baseURL ?? "", email, password);

    const workflows = [
      ["/venue", /today at the venue/i],
      ["/venue/orders", /drinks orders/i],
      ["/venue/menu", /drinks menu/i],
      ["/venue/checkins", /^check-ins$/i],
      ["/venue/promotions", /^promotions$/i],
      ["/venue/staff", /venue staff/i],
    ] as const;
    const evidenceDir = path.resolve(
      process.cwd(),
      "../../../output/release_readiness_20260718/venue_authenticated_e2e",
    );
    fs.mkdirSync(evidenceDir, { recursive: true });

    for (const [route, heading] of workflows) {
      await page.goto(route, { waitUntil: "networkidle" });
      await expect(
        page.getByRole("heading", { name: heading }).first(),
      ).toBeVisible({
        timeout: 20_000,
      });
      await expect(page.getByText(/assigned venue/i).first()).toBeVisible();
      await expect(page.getByText(/manager/i).first()).toBeVisible();
      await page.screenshot({
        path: path.join(
          evidenceDir,
          `${route === "/venue" ? "today" : route.split("/").at(-1)}.png`,
        ),
        fullPage: true,
      });
    }

    const revoked = await serviceClient
      .from("venue_staff_memberships")
      .update({ is_active: false, revoked_at: new Date().toISOString() })
      .eq("id", membershipId);
    if (revoked.error) throw revoked.error;

    await page.goto("/venue", { waitUntil: "networkidle" });
    await expect(
      page.getByRole("heading", { name: /no active venue assignment/i }),
    ).toBeVisible({ timeout: 20_000 });
    await page.screenshot({
      path: path.join(evidenceDir, "revoked-access.png"),
      fullPage: true,
    });
  } finally {
    if (membershipId) {
      await serviceClient
        .from("venue_staff_memberships")
        .delete()
        .eq("id", membershipId);
    }
    if (userId) await serviceClient.auth.admin.deleteUser(userId);
    if (createdTemporaryVenue && venueId) {
      await serviceClient.from("venues").delete().eq("id", venueId);
    }
  }
});
