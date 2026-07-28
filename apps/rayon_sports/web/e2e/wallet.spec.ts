import fs from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

const CLUB_ID = 24;
const SEEDED_SUPPORTER_NAME = "UAT Supporter Alpha";

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

test("admin wallet operations loads seeded supporters and applies an adjustment", async ({
  page,
  baseURL,
  browserName,
}) => {
  test.setTimeout(120_000);

  test.skip(
    browserName === "webkit",
    "WebKit remains flaky on the live admin auth bootstrap path.",
  );
  test.skip(
    process.env.ALLOW_LIVE_WALLET_E2E !== "1",
    "Live wallet mutations require ALLOW_LIVE_WALLET_E2E=1.",
  );

  const serviceClient = createAdminServiceClient();
  if (serviceClient == null) {
    test.skip(true, "Live Supabase admin credentials are missing.");
    return;
  }

  const existingSupporter = await serviceClient
    .from("users")
    .select("id")
    .eq("full_name", SEEDED_SUPPORTER_NAME)
    .limit(1)
    .maybeSingle();

  if (existingSupporter.error) {
    throw existingSupporter.error;
  }

  if (!existingSupporter.data?.id) {
    test.skip(
      true,
      "Wallet QA personas have not been seeded. Run the wallet seed script first.",
    );
    return;
  }

  const email = `wallet-admin-${Date.now()}@example.com`;
  let userId = "";

  try {
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
        notes: "temporary playwright wallet verification user",
      });
    if (assignment.error) {
      throw assignment.error;
    }

    const link = await serviceClient.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: { redirectTo: `${baseURL}/admin/gamification/wallet` },
    });
    if (link.error) {
      throw link.error;
    }

    await page.goto(link.data.properties.action_link, {
      waitUntil: "networkidle",
      timeout: 120_000,
    });

    await expect(
      page.getByRole("heading", { name: /supporter points operations/i }),
    ).toBeVisible({ timeout: 20_000 });

    const seededRow = page.getByRole("button", {
      name: new RegExp(SEEDED_SUPPORTER_NAME, "i"),
    });
    await expect(seededRow).toBeVisible();
    await seededRow.click();

    await page.getByLabel(/adjustment amount/i).fill("25");
    await page.getByLabel(/audit reason/i).fill("Wallet e2e top-up");
    await page.getByRole("button", { name: /apply adjustment/i }).click();

    await expect(page.getByText(/wallet adjustment saved\./i)).toBeVisible({
      timeout: 15_000,
    });
    await expect(page.getByText(/wallet e2e top-up/i).first()).toBeVisible({
      timeout: 15_000,
    });
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
