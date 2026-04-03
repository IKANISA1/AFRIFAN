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

test("public home renders on a phone viewport", async ({ page }) => {
  await page.goto("/");

  await expect(
    page.getByRole("heading", { name: /gikundiro for the browser/i }),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: /open fan portal/i })).toBeVisible();
});

test("fan portal boots the anonymous supporter workspace on tablet", async ({
  page,
}) => {
  await page.goto("/app");

  await expect(page.getByText(/fan portal/i)).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /welcome supporter/i }),
  ).toBeVisible();
  await expect(page.getByText(/membership tier/i)).toBeVisible();
});

test("admin route renders the magic-link sign-in surface", async ({ page }) => {
  await page.goto("/admin", { waitUntil: "domcontentloaded" });

  await expect(page.getByText(/club admin access/i)).toBeVisible();
  await expect(
    page.getByRole("heading", {
      name: /manage rayon sports from phone, tablet, or desktop/i,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /send magic link/i }),
  ).toBeVisible();
});

test("pwa manifest and offline route are reachable", async ({
  page,
  request,
}) => {
  const manifestResponse = await request.get("/manifest.webmanifest");
  expect(manifestResponse.ok()).toBeTruthy();
  const manifest = await manifestResponse.json();
  expect(manifest).toMatchObject({
    name: "Gikundiro | Rayon Sports web app and fan portal",
    display: "standalone",
  });

  await page.goto("/offline", { waitUntil: "domcontentloaded" });
  await expect(page.getByText(/offline/i)).toBeVisible();
});

test("admin auth callback exchanges a live scoped admin session", async ({
  page,
  baseURL,
}) => {
  const serviceClient = createAdminServiceClient();
  if (serviceClient == null) {
    test.skip(true, "Live Supabase admin credentials are missing.");
    return;
  }

  const email = `codex-e2e-admin-${Date.now()}@example.com`;
  let userId = "";

  try {
    const created = await serviceClient.auth.admin.createUser({
      email,
      password: "TempPass!123456",
      email_confirm: true,
      user_metadata: { role: "rayon_sport", club_id: CLUB_ID },
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

    const redirectTo = `${baseURL}/admin`;
    const link = await serviceClient.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: { redirectTo },
    });
    if (link.error) {
      throw link.error;
    }

    await page.goto(link.data.properties.action_link, {
      waitUntil: "networkidle",
      timeout: 120_000,
    });

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
