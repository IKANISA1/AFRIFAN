import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";
import { createClient } from "@supabase/supabase-js";
import { getFirstEnvValue, loadLocalEnv } from "./lib/env-utils.mjs";

loadLocalEnv();

const defaultAdminUrl =
  getFirstEnvValue("NEXT_PUBLIC_ADMIN_URL") || "https://admin.gikundiro.com";
const supabaseUrl = getFirstEnvValue(
  "SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_URL",
);
const serviceRoleKey = getFirstEnvValue("SUPABASE_SERVICE_ROLE_KEY");
const clubId = Number.parseInt(
  getFirstEnvValue("AFRICLUB_QA_CLUB_ID") || "24",
  10,
);

function parseArgs(argv) {
  const options = {
    baseUrl: defaultAdminUrl,
    reportPath: "",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--base-url") {
      options.baseUrl = argv[index + 1] ?? options.baseUrl;
      index += 1;
    } else if (arg === "--report") {
      options.reportPath = argv[index + 1] ?? "";
      index += 1;
    }
  }

  return options;
}

const options = parseArgs(process.argv.slice(2));

if (!supabaseUrl || !serviceRoleKey) {
  process.stderr.write(
    "SUPABASE_URL/NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.\n",
  );
  process.exit(2);
}

if (!Number.isFinite(clubId)) {
  process.stderr.write("AFRICLUB_QA_CLUB_ID must be a valid club id.\n");
  process.exit(2);
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const accessiblePages = [
  { path: "/admin", heading: /operations dashboard/i },
  { path: "/admin/matches", heading: /^matches$/i },
  { path: "/admin/notifications", heading: /notifications/i },
  { path: "/admin/membership", heading: /membership operations/i },
  { path: "/admin/community", heading: /community hub/i },
  { path: "/admin/shop", heading: /^shop$/i },
  { path: "/admin/tickets", heading: /ticket operations/i },
  { path: "/admin/cms", heading: /^content$/i },
  { path: "/admin/cms/banners", heading: /home banners/i },
  { path: "/admin/cms/content", heading: /content blocks/i },
  { path: "/admin/cms/content-blocks", heading: /placements\s*&\s*blocks/i },
  { path: "/admin/cms/config", heading: /app configuration/i },
  { path: "/admin/contributions", heading: /^contributions$/i },
  { path: "/admin/standings", heading: /^standings$/i },
  { path: "/admin/squad", heading: /squad management/i },
  { path: "/admin/gamification", heading: /fan engagement tokens/i },
  { path: "/admin/gamification/wallet", heading: /supporter wallet operations/i },
  { path: "/admin/sms-monitor", heading: /momo sms ingestion health/i },
  { path: "/admin/settings", heading: /platform settings/i },
  { path: "/admin/settings/features", heading: /feature flags/i },
  { path: "/admin/settings/audit", heading: /audit logs/i },
];

const expectedDeniedPages = [
  {
    path: "/admin/access",
    text: /platform admin access is required/i,
  },
];

function createEmptyReport() {
  return {
    baseUrl: options.baseUrl,
    clubId,
    checks: [],
    success: false,
    startedAt: new Date().toISOString(),
    finishedAt: null,
  };
}

const report = createEmptyReport();

function recordCheck(name, passed, detail) {
  report.checks.push({
    name,
    passed,
    detail,
  });
}

function writeReportFile() {
  if (!options.reportPath) {
    return;
  }

  const targetPath = path.resolve(process.cwd(), options.reportPath);
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, `${JSON.stringify(report, null, 2)}\n`);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function ensurePublicUserRows({
  userId,
  clubId,
  fullName,
  phone,
  publicUserId,
  attempts = 8,
}) {
  const usersPayload = {
    id: userId,
    phone,
    full_name: fullName,
    country: "RW",
    language_code: "en",
    momo_number: phone,
    momo_provider: "",
    is_admin: true,
    is_mock: true,
    mock_batch: `admin-live-uat-${Date.now()}`,
    public_user_id: publicUserId,
    momo_route_type: "phone_number",
  };

  const profilesPayload = {
    id: userId,
    club_id: clubId,
    phone,
    full_name: fullName,
    public_user_id: publicUserId,
    country: "RW",
    language_code: "en",
    is_admin: true,
    momo_number: phone,
    display_name: fullName,
    is_active: true,
  };

  for (let index = 0; index < attempts; index += 1) {
    const userInsert = await admin
      .from("users")
      .upsert(usersPayload, { onConflict: "id" });

    if (userInsert.error) {
      if (userInsert.error.code === "23503") {
        await sleep(500 * (index + 1));
        continue;
      }
      throw userInsert.error;
    }

    const profileInsert = await admin
      .from("profiles")
      .upsert(profilesPayload, { onConflict: "id" });

    if (!profileInsert.error) {
      return;
    }

    if (profileInsert.error.code !== "23503") {
      throw profileInsert.error;
    }

    await sleep(500 * (index + 1));
  }

  throw new Error(
    `Temporary user ${userId} did not become insertable into public.users/profiles.`,
  );
}

async function waitForTicketStatus(ticketId, expectedStatus, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const ticketLookup = await admin
      .from("tickets")
      .select("status")
      .eq("id", ticketId)
      .single();

    if (!ticketLookup.error && ticketLookup.data?.status === expectedStatus) {
      return ticketLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(
    `Ticket ${ticketId} did not reach status ${expectedStatus}.`,
  );
}

async function waitForMembershipApplicationStatus(
  applicationId,
  expectedStatus,
  attempts = 10,
) {
  for (let index = 0; index < attempts; index += 1) {
    const applicationLookup = await admin
      .from("membership_applications")
      .select("status")
      .eq("id", applicationId)
      .single();

    if (
      !applicationLookup.error &&
      applicationLookup.data?.status === expectedStatus
    ) {
      return applicationLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(
    `Membership application ${applicationId} did not reach status ${expectedStatus}.`,
  );
}

async function waitForFanMembership(userId, clubId, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const membershipLookup = await admin
      .from("fan_memberships")
      .select("id, tier, status")
      .eq("user_id", userId)
      .eq("club_id", clubId)
      .maybeSingle();

    if (!membershipLookup.error && membershipLookup.data?.id) {
      return membershipLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(
    `Fan membership for user ${userId} and club ${clubId} was not created.`,
  );
}

async function waitForMembershipBalance(
  userId,
  clubId,
  expectedPoints,
  attempts = 10,
) {
  for (let index = 0; index < attempts; index += 1) {
    const membershipLookup = await admin
      .from("fan_memberships")
      .select("id, points, tier, status")
      .eq("user_id", userId)
      .eq("club_id", clubId)
      .maybeSingle();

    if (
      !membershipLookup.error &&
      membershipLookup.data?.id &&
      Number(membershipLookup.data.points ?? 0) === expectedPoints
    ) {
      return membershipLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(
    `Fan membership for user ${userId} and club ${clubId} did not reach balance ${expectedPoints}.`,
  );
}

async function waitForNotification(title, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const notificationLookup = await admin
      .from("notifications")
      .select(
        "id, status, requested_recipient_count, sent_count, failed_count, last_error",
      )
      .eq("club_id", clubId)
      .eq("title", title)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!notificationLookup.error && notificationLookup.data?.id) {
      return notificationLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(`Notification ${title} was not created.`);
}

async function waitForWalletLedgerEntry(userId, note, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const ledgerLookup = await admin
      .from("fet_wallet_ledger_entries")
      .select("id, amount, direction, balance_after, note, entry_type")
      .eq("club_id", clubId)
      .eq("user_id", userId)
      .eq("entry_type", "admin_adjustment")
      .eq("note", note)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!ledgerLookup.error && ledgerLookup.data?.id) {
      return ledgerLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(`Wallet ledger entry for ${note} was not created.`);
}

async function resolveAccessibleTable(candidates) {
  for (const table of candidates) {
    const { error } = await admin.from(table).select("id").limit(1);
    if (!error) {
      return table;
    }
  }

  return candidates[0];
}

async function waitForProduct(table, name, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const productLookup = await admin
      .from(table)
      .select("id, is_active, price")
      .eq("club_id", clubId)
      .eq("name", name)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!productLookup.error && productLookup.data?.id) {
      return productLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(`Product ${name} was not created.`);
}

async function waitForFanClub(name, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const chapterLookup = await admin
      .from("fan_clubs")
      .select("id, is_active, region, member_count")
      .eq("club_id", clubId)
      .eq("name", name)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!chapterLookup.error && chapterLookup.data?.id) {
      return chapterLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(`Fan club ${name} was not created.`);
}

async function waitForContributionGroup(name, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const groupLookup = await admin
      .from("contribution_groups")
      .select("id, is_closed, member_count, current_total")
      .eq("club_id", clubId)
      .eq("name", name)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!groupLookup.error && groupLookup.data?.id) {
      return groupLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(`Contribution group ${name} was not created.`);
}

async function waitForCmsContent(title, attempts = 10) {
  for (let index = 0; index < attempts; index += 1) {
    const contentLookup = await admin
      .from("ai_content")
      .select("id, is_active, distribution, content_type")
      .eq("club_id", clubId)
      .eq("title", title)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!contentLookup.error && contentLookup.data?.id) {
      return contentLookup.data;
    }

    await sleep(400 * (index + 1));
  }

  throw new Error(`CMS content ${title} was not created.`);
}

async function expectRecordMissing(queryFactory, message) {
  const lookup = await queryFactory();
  if (lookup.error) {
    throw lookup.error;
  }
  if (lookup.data != null) {
    throw new Error(message);
  }
}

function toDateTimeLocal(date) {
  const offsetMs = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16);
}

async function waitForFeatureAccessState(featureKey, expectedReason, attempts = 8) {
  for (let index = 0; index < attempts; index += 1) {
    const stateLookup = await admin.rpc("get_feature_access_state", {
      p_feature_key: featureKey,
      p_channel: "web",
      p_club_id: clubId,
      p_is_authenticated: true,
      p_roles: ["club_admin"],
    });

    if (!stateLookup.error && stateLookup.data?.reason === expectedReason) {
      return stateLookup.data;
    }

    await sleep(250 * (index + 1));
  }

  throw new Error(
    `Feature ${featureKey} did not reach expected reason ${expectedReason}.`,
  );
}

async function resolveEffectiveFeature(featureKey, channel = "web") {
  const featureLookup = await admin
    .from("platform_features")
    .select("id, club_id, is_enabled")
    .eq("feature_key", featureKey)
    .or(`club_id.eq.${clubId},club_id.is.null`);

  if (featureLookup.error) {
    throw featureLookup.error;
  }

  const feature =
    (featureLookup.data ?? []).find((row) => Number(row.club_id) === clubId) ??
    (featureLookup.data ?? []).find((row) => row.club_id == null) ??
    null;

  if (!feature?.id) {
    throw new Error(`Feature ${featureKey} is not registered in Supabase.`);
  }

  const channelLookup = await admin
    .from("platform_feature_channels")
    .select("id, is_enabled, is_visible")
    .eq("feature_id", feature.id)
    .eq("channel", channel)
    .maybeSingle();

  if (channelLookup.error && channelLookup.error.code !== "PGRST116") {
    throw channelLookup.error;
  }

  return {
    feature,
    channel:
      channelLookup.error?.code === "PGRST116" ? null : channelLookup.data ?? null,
  };
}

const featureStateRestores = new Map();

async function rememberFeatureState(featureKey) {
  if (featureStateRestores.has(featureKey)) {
    return;
  }

  const resolved = await resolveEffectiveFeature(featureKey);
  featureStateRestores.set(featureKey, {
    featureId: resolved.feature.id,
    featureEnabled: resolved.feature.is_enabled !== false,
    channelId: resolved.channel?.id ?? null,
    channelEnabled:
      resolved.channel == null ? null : resolved.channel.is_enabled !== false,
    channelVisible:
      resolved.channel == null ? null : resolved.channel.is_visible !== false,
  });
}

async function setFeatureState(
  featureKey,
  { featureEnabled, channelEnabled, channelVisible },
) {
  await rememberFeatureState(featureKey);
  const resolved = await resolveEffectiveFeature(featureKey);

  if (typeof featureEnabled === "boolean") {
    const featureUpdate = await admin
      .from("platform_features")
      .update({ is_enabled: featureEnabled })
      .eq("id", resolved.feature.id);
    if (featureUpdate.error) {
      throw featureUpdate.error;
    }
  }

  if (
    typeof channelEnabled === "boolean" ||
    typeof channelVisible === "boolean"
  ) {
    if (!resolved.channel?.id) {
      throw new Error(
        `Feature ${featureKey} is missing the web channel configuration.`,
      );
    }

    const payload = {};
    if (typeof channelEnabled === "boolean") {
      payload.is_enabled = channelEnabled;
    }
    if (typeof channelVisible === "boolean") {
      payload.is_visible = channelVisible;
    }

    const channelUpdate = await admin
      .from("platform_feature_channels")
      .update(payload)
      .eq("id", resolved.channel.id);
    if (channelUpdate.error) {
      throw channelUpdate.error;
    }
  }
}

async function restoreFeatureStates() {
  for (const [_featureKey, snapshot] of featureStateRestores.entries()) {
    const featureUpdate = await admin
      .from("platform_features")
      .update({ is_enabled: snapshot.featureEnabled })
      .eq("id", snapshot.featureId);
    if (featureUpdate.error) {
      throw featureUpdate.error;
    }

    if (snapshot.channelId) {
      const channelUpdate = await admin
        .from("platform_feature_channels")
        .update({
          is_enabled: snapshot.channelEnabled,
          is_visible: snapshot.channelVisible,
        })
        .eq("id", snapshot.channelId);
      if (channelUpdate.error) {
        throw channelUpdate.error;
      }
    }
  }
}

async function waitForMainHeading(page, heading) {
  await page
    .locator("#admin-main-content")
    .getByRole("heading", { name: heading })
    .first()
    .waitFor({ timeout: 20_000 });
}

async function waitForButtonEnabled(page, locator, timeout = 20_000) {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    const isVisible = await locator.isVisible().catch(() => false);
    if (isVisible) {
      const isEnabled = await locator.isEnabled().catch(() => false);
      const ariaDisabled = await locator
        .getAttribute("aria-disabled")
        .catch(() => null);
      if (isEnabled && ariaDisabled !== "true") {
        return;
      }
    }

    await sleep(250);
  }

  await page.waitForTimeout(0);
  throw new Error("Button did not become enabled in time.");
}

async function describeFormState(locator) {
  return locator.evaluate((form) => {
    const invalidFields = Array.from(
      form.querySelectorAll("input:invalid, textarea:invalid, select:invalid"),
    ).map((field) => ({
      name: field.getAttribute("name"),
      type: field instanceof HTMLInputElement ? field.type : field.tagName,
      value:
        field instanceof HTMLInputElement ||
        field instanceof HTMLTextAreaElement ||
        field instanceof HTMLSelectElement
          ? field.value
          : "",
      validationMessage:
        field instanceof HTMLInputElement ||
        field instanceof HTMLTextAreaElement ||
        field instanceof HTMLSelectElement
          ? field.validationMessage
          : "",
    }));

    return {
      valid:
        form instanceof HTMLFormElement ? form.checkValidity() : null,
      action: form.getAttribute("action"),
      method: form.getAttribute("method"),
      invalidFields,
    };
  });
}

async function openAuthedPage(context, pathname) {
  const page = await context.newPage();
  await page.goto(`${options.baseUrl}${pathname}`, {
    waitUntil: "domcontentloaded",
    timeout: 120_000,
  });
  return page;
}

async function verifyAccessiblePage(context, entry) {
  const page = await openAuthedPage(context, entry.path);
  await waitForMainHeading(page, entry.heading);
  await page.close();
}

async function verifyDeniedPage(context, entry) {
  const page = await openAuthedPage(context, entry.path);
  await page.getByText(entry.text).waitFor({ timeout: 20_000 });
  await page.close();
}

function sanitizeError(error) {
  if (error instanceof Error) {
    return error.stack ?? error.message;
  }

  if (error && typeof error === "object") {
    try {
      return JSON.stringify(error, null, 2);
    } catch {
      // Fall through to generic string conversion.
    }
  }

  return String(error);
}

let browser = null;
let userId = null;
let featureId = null;
let contentBlockId = null;
let profileId = null;
let ticketId = null;
let ticketMatchId = null;
let membershipApplicationId = null;
let notificationId = null;
let productId = null;
let fanClubId = null;
let contributionGroupId = null;
let cmsContentId = null;
const fanMembershipKeys = new Set();
let currentStep = "initializing";

try {
  const stamp = Date.now();
  const email = `live-uat-admin-${stamp}@example.com`;
  const featureKey = `uat_live_admin_${stamp}`;
  const featureDisplayName = `UAT Live Feature ${stamp}`;
  const blockKey = `uat_live_block_${stamp}`;
  const blockTitle = `UAT Live Block ${stamp}`;
  const tempUserName = `UAT Admin ${stamp}`;
  const tempUserPhone = `+250788${String(stamp).slice(-6)}`;
  const tempPublicUserId = String((stamp % 900000) + 100000).padStart(6, "0");
  const tempMomoReference = `UAT-TICKET-${stamp}`;
  const tempMembershipAppliedAt = new Date(stamp + 60_000).toISOString();
  const productName = `UAT Live Product ${stamp}`;
  const chapterName = `UAT Live Chapter ${stamp}`;
  const circleName = `UAT Live Circle ${stamp}`;
  const cmsTitle = `UAT Live CMS ${stamp}`;
  const notificationTitle = `UAT Notification ${stamp}`;
  const blockedNotificationTitle = `UAT Notification Blocked ${stamp}`;
  const walletReason = `UAT wallet adjustment ${stamp}`;
  const blockedWalletReason = `UAT wallet blocked ${stamp}`;

  process.stdout.write("[admin-uat] Creating temporary admin user and fixtures.\n");

  currentStep = "create-temp-user";
  const created = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    app_metadata: { role: "club_admin", club_id: clubId },
  });
  if (created.error) {
    throw created.error;
  }
  userId = created.data.user.id;

  currentStep = "assign-admin-role";
  const assignment = await admin.from("admin_role_assignments").insert({
    user_id: userId,
    role: "club_admin",
    is_active: true,
    club_id: clubId,
    notes: "temporary live admin UAT user",
  });
  if (assignment.error) {
    throw assignment.error;
  }

  currentStep = "upsert-temp-domain-user";
  await ensurePublicUserRows({
    userId,
    clubId,
    fullName: tempUserName,
    phone: tempUserPhone,
    publicUserId: tempPublicUserId,
  });
  profileId = userId;

  currentStep = "seed-wallet-balance";
  const seedWalletResult = await admin.rpc("add_fan_points", {
    p_user_id: userId,
    p_partner_id: String(clubId),
    p_points: 120,
    p_reason: `live_admin_uat_wallet_seed_${stamp}`,
  });
  if (seedWalletResult.error) {
    throw seedWalletResult.error;
  }
  if (seedWalletResult.data?.id) {
    fanMembershipKeys.add(seedWalletResult.data.id);
  }

  currentStep = "load-ticket-source-match";
  const sourceMatch = await admin
    .from("matches")
    .select("id")
    .eq("club_id", clubId)
    .order("match_date", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (sourceMatch.error) {
    throw sourceMatch.error;
  }
  let sourceMatchId = sourceMatch.data?.id ?? null;

  if (!sourceMatchId) {
    const fallbackMatch = await admin
      .from("matches")
      .select("id")
      .order("match_date", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (fallbackMatch.error) {
      throw fallbackMatch.error;
    }
    sourceMatchId = fallbackMatch.data?.id ?? null;
  }

  if (!sourceMatchId) {
    throw new Error("Live admin UAT could not find any match for ticket testing.");
  }
  ticketMatchId = sourceMatchId;

  currentStep = "insert-temp-ticket";
  const ticketInsert = await admin
    .from("tickets")
    .insert({
      match_id: ticketMatchId,
      user_id: userId,
      seat_type: "general",
      amount_paid: 1500,
      momo_reference: tempMomoReference,
      status: "pending",
      club_id: clubId,
      is_mock: true,
      mock_batch: `admin-live-uat-${stamp}`,
    })
    .select("id")
    .single();
  if (ticketInsert.error) {
    throw ticketInsert.error;
  }
  ticketId = ticketInsert.data.id;

  currentStep = "insert-temp-membership-application";
  const applicationInsert = await admin
    .from("membership_applications")
    .insert({
      user_id: userId,
      club_id: clubId,
      tier: "gold",
      status: "pending",
      payment_status: "paid",
      application_date: tempMembershipAppliedAt,
      metadata: {
        chapter: "Central",
        source: "live_admin_uat",
        stamp,
      },
    })
    .select("id")
    .single();
  if (applicationInsert.error) {
    throw applicationInsert.error;
  }
  membershipApplicationId = applicationInsert.data.id;

  currentStep = "insert-temp-feature";
  const featureInsert = await admin
    .from("platform_features")
    .insert({
      feature_key: featureKey,
      display_name: featureDisplayName,
      description: "Temporary feature for admin live UAT",
      category: "uat",
      club_id: clubId,
      is_enabled: true,
      visibility_state: "visible",
    })
    .select("id")
    .single();
  if (featureInsert.error) {
    throw featureInsert.error;
  }
  featureId = featureInsert.data.id;

  currentStep = "insert-temp-feature-channels";
  const channelInsert = await admin.from("platform_feature_channels").insert([
    { feature_id: featureId, channel: "mobile", is_enabled: true, is_visible: true },
    { feature_id: featureId, channel: "web", is_enabled: true, is_visible: true },
  ]);
  if (channelInsert.error) {
    throw channelInsert.error;
  }

  currentStep = "generate-magic-link";
  const magicLink = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
    options: { redirectTo: `${options.baseUrl}/admin` },
  });
  if (magicLink.error) {
    throw magicLink.error;
  }

  currentStep = "launch-browser";
  browser = await chromium.launch({
    headless: true,
    args: ["--disable-dev-shm-usage", "--no-sandbox"],
  });
  const context = await browser.newContext();

  process.stdout.write("[admin-uat] Authenticating on the live admin host.\n");
  currentStep = "authenticate-browser-session";
  let page = await context.newPage();
  await page.goto(magicLink.data.properties.action_link, {
    waitUntil: "networkidle",
    timeout: 120_000,
  });
  try {
    await waitForMainHeading(page, /operations dashboard/i);
  } catch {
    await page.goto(`${options.baseUrl}/admin`, {
      waitUntil: "networkidle",
      timeout: 120_000,
    });
    await waitForMainHeading(page, /operations dashboard/i);
  }
  await page
    .locator("#admin-main-content")
    .getByRole("heading", { name: /quick actions/i })
    .waitFor({ timeout: 20_000 });
  await page
    .locator("#admin-main-content")
    .getByRole("heading", { name: /recent activity/i })
    .waitFor({ timeout: 20_000 });
  recordCheck("dashboard-session", true, "Authenticated admin dashboard loaded.");
  await page.close();

  page = await openAuthedPage(context, "/admin/settings/features");
  await waitForMainHeading(page, /feature flags/i);
  let featureRow = page.locator("tr", { hasText: featureDisplayName });
  await featureRow.waitFor({ timeout: 20_000 });
  recordCheck("features-page", true, "Feature flags page loaded and temporary feature was visible.");

  await featureRow.getByRole("button", { name: /^disable$/i }).click();
  await page.getByText(/feature disabled\./i).waitFor({ timeout: 20_000 });
  const featureDisabled = await admin
    .from("platform_features")
    .select("is_enabled")
    .eq("id", featureId)
    .single();
  if (featureDisabled.error || featureDisabled.data.is_enabled !== false) {
    throw new Error("Feature disable action did not persist.");
  }
  recordCheck("feature-disable", true, "Feature disable action persisted to Supabase.");

  featureRow = page.locator("tr", { hasText: featureDisplayName });
  await featureRow.getByRole("button", { name: /^enable$/i }).click();
  await page.getByText(/feature enabled\./i).waitFor({ timeout: 20_000 });
  const featureEnabled = await admin
    .from("platform_features")
    .select("is_enabled")
    .eq("id", featureId)
    .single();
  if (featureEnabled.error || featureEnabled.data.is_enabled !== true) {
    throw new Error("Feature enable action did not persist.");
  }
  recordCheck("feature-enable", true, "Feature enable action persisted to Supabase.");

  const featureAudit = await admin
    .from("platform_feature_audit_logs")
    .select("id, action")
    .eq("feature_id", featureId)
    .eq("action", "update_platform_features")
    .order("created_at", { ascending: false })
    .limit(10);
  if (featureAudit.error || (featureAudit.data ?? []).length < 2) {
    throw new Error("Feature audit logging did not capture both toggle operations.");
  }
  recordCheck("feature-audit", true, "Feature toggle actions were written to platform_feature_audit_logs.");
  await page.close();

  page = await openAuthedPage(context, "/admin/cms/content-blocks");
  await waitForMainHeading(page, /placements\s*&\s*blocks/i);
  const newBlockButton = page.getByRole("button", { name: /new block/i });
  await waitForButtonEnabled(page, newBlockButton);
  await newBlockButton.click();
  const blockDialog = page.getByRole("dialog", { name: /new content block/i });
  await blockDialog.waitFor({ timeout: 20_000 });
  await blockDialog.getByLabel(/block key/i).fill(blockKey);
  await blockDialog.getByLabel(/^placement key$/i).fill("uat_live");
  await blockDialog.getByLabel(/^title$/i).fill(blockTitle);
  await blockDialog.getByRole("button", { name: /save block/i }).click();
  await page.getByText(/block saved\./i).waitFor({ timeout: 20_000 });

  let blockRow = page.locator("tr", { hasText: blockTitle });
  await blockRow.waitFor({ timeout: 20_000 });

  const savedBlock = await admin
    .from("platform_content_blocks")
    .select("id, is_active")
    .eq("block_key", blockKey)
    .eq("club_id", clubId)
    .single();
  if (savedBlock.error || savedBlock.data.is_active !== true) {
    throw new Error("Content block create action did not persist.");
  }
  contentBlockId = savedBlock.data.id;
  recordCheck("content-block-create", true, "Content block create action persisted to Supabase.");

  page.once("dialog", (dialog) => dialog.accept());
  await blockRow.locator("button").last().click();
  await page.getByText(/block deleted\./i).waitFor({ timeout: 20_000 });
  const deletedBlock = await admin
    .from("platform_content_blocks")
    .select("id")
    .eq("block_key", blockKey)
    .eq("club_id", clubId)
    .maybeSingle();
  if (deletedBlock.error || deletedBlock.data != null) {
    throw new Error("Content block delete action did not persist.");
  }
  contentBlockId = null;
  recordCheck("content-block-delete", true, "Content block delete action persisted to Supabase.");

  const blockAudit = await admin
    .from("platform_feature_audit_logs")
    .select("id, action, before_state, after_state")
    .order("created_at", { ascending: false })
    .limit(200);
  if (blockAudit.error) {
    throw blockAudit.error;
  }
  const blockAuditHits = (blockAudit.data ?? []).filter((entry) => {
    const beforeKey = entry.before_state?.block_key;
    const afterKey = entry.after_state?.block_key;
    return beforeKey === blockKey || afterKey === blockKey;
  });
  if (blockAuditHits.length < 2) {
    throw new Error("Content block audit logging did not capture create/delete.");
  }
  recordCheck("content-block-audit", true, "Content block actions were written to platform_feature_audit_logs.");
  await page.close();

  currentStep = "notifications-success";
  await setFeatureState("notifications", {
    featureEnabled: true,
    channelEnabled: true,
    channelVisible: true,
  });
  page = await openAuthedPage(context, "/admin/notifications");
  await waitForMainHeading(page, /notifications/i);
  const notificationForm = page.locator("form", { hasText: /compose broadcast/i }).first();
  const initialNotificationSubmitButton = notificationForm.getByRole("button", {
    name: /send notification|schedule notification/i,
  });
  await waitForButtonEnabled(page, initialNotificationSubmitButton);
  await notificationForm.locator("input").first().fill(notificationTitle);
  await notificationForm.locator("textarea").first().fill(
    `Live UAT broadcast scheduled at ${new Date(stamp).toISOString()}.`,
  );
  const deliveryModeSelect = notificationForm.locator("select").nth(1);
  await deliveryModeSelect.waitFor({ timeout: 20_000 });
  await deliveryModeSelect.selectOption("schedule");
  const scheduledAtInput = notificationForm.locator('input[type="datetime-local"]');
  await scheduledAtInput.waitFor({ timeout: 20_000 });
  await scheduledAtInput.fill(
    toDateTimeLocal(new Date(Date.now() + 60 * 60 * 1000)),
  );
  const scheduleButton = notificationForm.getByRole("button", {
    name: /schedule notification/i,
  });
  await waitForButtonEnabled(page, scheduleButton);
  const notificationResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/notifications") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await scheduleButton.click();
  const notificationResponse = await notificationResponsePromise;
  if (notificationResponse.status() !== 200) {
    throw new Error(
      `Notification request failed with status ${notificationResponse.status()}: ${await notificationResponse.text()}`,
    );
  }
  await page.getByText(/notification scheduled\./i).waitFor({ timeout: 20_000 });
  const notificationRecord = await waitForNotification(notificationTitle);
  notificationId = notificationRecord.id;
  if (notificationRecord.status !== "scheduled") {
    throw new Error(
      `Notification persisted with unexpected status ${notificationRecord.status}.`,
    );
  }
  recordCheck(
    "notifications-schedule",
    true,
    "Notification scheduling action persisted to Supabase.",
  );

  currentStep = "notifications-blocked";
  await setFeatureState("notifications", { featureEnabled: false });
  await waitForFeatureAccessState("notifications", "global_disabled");
  await notificationForm.locator("input").first().fill(blockedNotificationTitle);
  await notificationForm.locator("textarea").first().fill(
    "This notification should be blocked.",
  );
  await deliveryModeSelect.selectOption("schedule");
  await scheduledAtInput.waitFor({ timeout: 20_000 });
  await scheduledAtInput.fill(
    toDateTimeLocal(new Date(Date.now() + 2 * 60 * 60 * 1000)),
  );
  await waitForButtonEnabled(page, scheduleButton);
  const blockedNotificationResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/notifications") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await scheduleButton.click();
  const blockedNotificationResponse = await blockedNotificationResponsePromise;
  if (blockedNotificationResponse.status() !== 403) {
    throw new Error(
      `Blocked notification request returned ${blockedNotificationResponse.status()}: ${await blockedNotificationResponse.text()}`,
    );
  }
  await page
    .getByText(/feature is currently disabled|feature is currently unavailable/i)
    .waitFor({ timeout: 20_000 });
  await expectRecordMissing(
    () =>
      admin
        .from("notifications")
        .select("id")
        .eq("club_id", clubId)
        .eq("title", blockedNotificationTitle)
        .maybeSingle(),
    "Blocked notification request still created a notification row.",
  );
  recordCheck(
    "notifications-blocked",
    true,
    "Notification submission was rejected when the feature was disabled.",
  );
  await setFeatureState("notifications", { featureEnabled: true });
  await page.close();

  currentStep = "wallet-success";
  await setFeatureState("predict", {
    featureEnabled: true,
    channelEnabled: true,
    channelVisible: true,
  });
  page = await openAuthedPage(context, "/admin/gamification/wallet");
  await waitForMainHeading(page, /supporter wallet operations/i);
  await page.getByPlaceholder(/483912, Mukamana, transfer-ref/i).fill(
    tempPublicUserId,
  );
  await page.getByRole("button", { name: /apply filter/i }).click();
  const walletSupporterCard = page
    .getByRole("button", { name: new RegExp(tempUserName, "i") })
    .first();
  await walletSupporterCard.waitFor({ timeout: 20_000 });
  await walletSupporterCard.click();
  await page.getByLabel(/adjustment amount/i).fill("25");
  await page.getByLabel(/audit reason/i).fill(walletReason);
  const walletResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/gamification-wallet") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await page.getByRole("button", { name: /apply adjustment/i }).click();
  const walletResponse = await walletResponsePromise;
  if (walletResponse.status() !== 200) {
    throw new Error(
      `Wallet adjustment request failed with status ${walletResponse.status()}: ${await walletResponse.text()}`,
    );
  }
  await page.getByText(/wallet adjustment saved\./i).waitFor({ timeout: 20_000 });
  const updatedMembership = await waitForMembershipBalance(userId, clubId, 145);
  fanMembershipKeys.add(updatedMembership.id);
  const walletEntry = await waitForWalletLedgerEntry(userId, walletReason);
  if (
    Number(walletEntry.balance_after ?? 0) !== 145 ||
    walletEntry.direction !== "credit" ||
    Number(walletEntry.amount ?? 0) !== 25
  ) {
    throw new Error("Wallet adjustment did not persist the expected ledger delta.");
  }
  recordCheck(
    "wallet-adjustment",
    true,
    "Wallet adjustment persisted to the membership balance and ledger.",
  );

  currentStep = "wallet-blocked";
  await setFeatureState("predict", { featureEnabled: false });
  await waitForFeatureAccessState("predict", "global_disabled");
  await page.getByLabel(/adjustment amount/i).fill("5");
  await page.getByLabel(/audit reason/i).fill(blockedWalletReason);
  const blockedWalletResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/gamification-wallet") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await page.getByRole("button", { name: /apply adjustment/i }).click();
  const blockedWalletResponse = await blockedWalletResponsePromise;
  if (blockedWalletResponse.status() !== 403) {
    throw new Error(
      `Blocked wallet request returned ${blockedWalletResponse.status()}: ${await blockedWalletResponse.text()}`,
    );
  }
  await page
    .getByText(/feature is currently disabled|feature is currently unavailable/i)
    .waitFor({ timeout: 20_000 });
  await expectRecordMissing(
    () =>
      admin
        .from("fet_wallet_ledger_entries")
        .select("id")
        .eq("club_id", clubId)
        .eq("user_id", userId)
        .eq("entry_type", "admin_adjustment")
        .eq("note", blockedWalletReason)
        .maybeSingle(),
    "Blocked wallet request still created a ledger entry.",
  );
  const blockedMembership = await waitForMembershipBalance(userId, clubId, 145);
  fanMembershipKeys.add(blockedMembership.id);
  recordCheck(
    "wallet-blocked",
    true,
    "Wallet adjustment was rejected when the feature was disabled.",
  );
  await setFeatureState("predict", { featureEnabled: true });
  await page.close();

  const productTable = await resolveAccessibleTable([
    "shop_products",
    "rs_shop_products",
  ]);
  currentStep = "shop-create";
  page = await openAuthedPage(context, "/admin/shop");
  await waitForMainHeading(page, /^shop$/i);
  await page.getByLabel(/^name$/i).fill(productName);
  await page.getByLabel(/^category$/i).fill("UAT");
  await page.getByLabel(/^subtitle$/i).fill("Limited live UAT product.");
  await page.getByLabel(/^description$/i).fill(
    "Temporary product for admin live UAT coverage.",
  );
  await page.getByLabel(/price/i).fill("24000");
  await page.getByLabel(/sort order/i).fill("7");
  const saveProductButton = page.getByRole("button", { name: /add product/i });
  await waitForButtonEnabled(page, saveProductButton);
  const productForm = page.locator("form").first();
  const saveProductResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/shop") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await saveProductButton.click();
  let saveProductResponse;
  try {
    saveProductResponse = await saveProductResponsePromise;
  } catch (error) {
    const formState = await describeFormState(productForm).catch(() => null);
    const buttonState = await saveProductButton
      .evaluate((button) => ({
        disabled: button instanceof HTMLButtonElement ? button.disabled : null,
        text: button.textContent?.trim() ?? "",
      }))
      .catch(() => null);
    throw new Error(
      `Shop create request was not observed. url=${page.url()} form=${JSON.stringify(formState)} button=${JSON.stringify(buttonState)} cause=${sanitizeError(error)}`,
    );
  }
  if (saveProductResponse.status() !== 200) {
    throw new Error(
      `Shop create request failed with status ${saveProductResponse.status()}: ${await saveProductResponse.text()}`,
    );
  }
  await page.getByText(/product saved\./i).waitFor({ timeout: 20_000 });
  const savedProduct = await waitForProduct(productTable, productName);
  productId = savedProduct.id;
  recordCheck(
    "shop-create",
    true,
    "Shop product creation persisted to Supabase.",
  );

  const productRow = page.locator("article", { hasText: productName });
  await productRow.waitFor({ timeout: 20_000 });
  currentStep = "shop-delete";
  page.once("dialog", (dialog) => dialog.accept());
  const deleteProductResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/shop?") &&
      response.request().method() === "DELETE",
    { timeout: 20_000 },
  );
  await productRow.getByTitle(/remove/i).click();
  const deleteProductResponse = await deleteProductResponsePromise;
  if (deleteProductResponse.status() !== 200) {
    throw new Error(
      `Shop delete request failed with status ${deleteProductResponse.status()}: ${await deleteProductResponse.text()}`,
    );
  }
  await page.getByText(/removed\./i).waitFor({ timeout: 20_000 });
  await expectRecordMissing(
    () =>
      admin
        .from(productTable)
        .select("id")
        .eq("club_id", clubId)
        .eq("name", productName)
        .maybeSingle(),
    "Deleted product still exists in the shop catalogue.",
  );
  productId = null;
  recordCheck(
    "shop-delete",
    true,
    "Shop product deletion persisted to Supabase.",
  );
  await page.close();

  currentStep = "community-chapter-create";
  page = await openAuthedPage(context, "/admin/community");
  await waitForMainHeading(page, /community hub/i);
  const newChapterButton = page.getByRole("button", { name: /new chapter/i });
  await waitForButtonEnabled(page, newChapterButton);
  await newChapterButton.click();
  const chapterDialog = page.getByRole("dialog", { name: /new chapter/i });
  await chapterDialog.waitFor({ timeout: 20_000 });
  await chapterDialog.getByLabel(/chapter name/i).fill(chapterName);
  await chapterDialog.getByLabel(/^region$/i).fill("Kigali");
  await chapterDialog.getByLabel(/^description$/i).fill(
    "Temporary chapter for live admin UAT coverage.",
  );
  await chapterDialog.getByLabel(/^members$/i).fill("42");
  await chapterDialog.getByLabel(/^events$/i).fill("3");
  await chapterDialog.getByLabel(/^rating$/i).fill("4.5");
  const saveChapterResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/fan-clubs") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await chapterDialog.getByRole("button", { name: /add chapter/i }).click();
  const saveChapterResponse = await saveChapterResponsePromise;
  if (saveChapterResponse.status() !== 200) {
    throw new Error(
      `Fan club create request failed with status ${saveChapterResponse.status()}: ${await saveChapterResponse.text()}`,
    );
  }
  const savedFanClub = await waitForFanClub(chapterName);
  fanClubId = savedFanClub.id;
  recordCheck(
    "community-chapter-create",
    true,
    "Community chapter creation persisted to Supabase.",
  );
  const chapterRow = page.locator("tr", { hasText: chapterName });
  await chapterRow.waitFor({ timeout: 20_000 });

  currentStep = "community-chapter-delete";
  page.once("dialog", (dialog) => dialog.accept());
  const deleteChapterResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/fan-clubs?") &&
      response.request().method() === "DELETE",
    { timeout: 20_000 },
  );
  await chapterRow.getByRole("button", { name: /^remove$/i }).click();
  const deleteChapterResponse = await deleteChapterResponsePromise;
  if (deleteChapterResponse.status() !== 200) {
    throw new Error(
      `Fan club delete request failed with status ${deleteChapterResponse.status()}: ${await deleteChapterResponse.text()}`,
    );
  }
  await expectRecordMissing(
    () =>
      admin
        .from("fan_clubs")
        .select("id")
        .eq("club_id", clubId)
        .eq("name", chapterName)
        .maybeSingle(),
    "Deleted fan club still exists.",
  );
  fanClubId = null;
  recordCheck(
    "community-chapter-delete",
    true,
    "Community chapter deletion persisted to Supabase.",
  );

  currentStep = "community-circle-create";
  await page.getByRole("button", { name: /^groups$/i }).click();
  const newGroupButton = page.getByRole("button", { name: /new public group/i });
  await waitForButtonEnabled(page, newGroupButton);
  await newGroupButton.click();
  const circleDialog = page.getByRole("dialog", {
    name: /new public group|new group|new circle/i,
  }).last();
  await circleDialog.waitFor({ timeout: 20_000 });
  const groupNameInput = circleDialog.locator('input[name="name"]').first();
  const groupDescriptionInput = circleDialog.locator('textarea[name="description"]').first();
  const targetAmountInput = circleDialog.locator('input[name="targetAmount"]').first();
  const currentTotalInput = circleDialog.locator('input[name="currentTotal"]').first();
  const memberCountInput = circleDialog.locator('input[name="memberCount"]').first();
  await groupNameInput.waitFor({ timeout: 20_000 });
  await groupNameInput.fill(circleName);
  await groupDescriptionInput.fill(
    "Temporary support circle for live UAT coverage.",
  );
  await targetAmountInput.fill("100000");
  await currentTotalInput.fill("15000");
  await memberCountInput.fill("12");
  const createInitiativeButton = circleDialog.getByRole("button", {
    name: /create initiative|create group/i,
  }).first();
  await createInitiativeButton.waitFor({ timeout: 20_000 });
  const circleForm = circleDialog.locator("form").first();
  const saveCircleResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/contributions") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await createInitiativeButton.click();
  let saveCircleResponse;
  try {
    saveCircleResponse = await saveCircleResponsePromise;
  } catch (error) {
    const formState = await describeFormState(circleForm).catch(() => null);
    const buttonState = await createInitiativeButton
      .evaluate((button) => ({
        disabled: button instanceof HTMLButtonElement ? button.disabled : null,
        text: button.textContent?.trim() ?? "",
      }))
      .catch(() => null);
    throw new Error(
      `Contribution initiative create request was not observed. url=${page.url()} form=${JSON.stringify(formState)} button=${JSON.stringify(buttonState)} cause=${sanitizeError(error)}`,
    );
  }
  if (saveCircleResponse.status() !== 200) {
    const requestBody = saveCircleResponse.request().postData();
    throw new Error(
      `Contribution group create request failed with status ${saveCircleResponse.status()}: body=${requestBody} response=${await saveCircleResponse.text()}`,
    );
  }
  const savedContributionGroup = await waitForContributionGroup(circleName);
  contributionGroupId = savedContributionGroup.id;
  recordCheck(
    "community-circle-create",
    true,
    "Community support circle creation persisted to Supabase.",
  );
  const circleRow = page.locator("tr", { hasText: circleName });
  await circleRow.waitFor({ timeout: 20_000 });

  currentStep = "community-circle-delete";
  page.once("dialog", (dialog) => dialog.accept());
  const deleteCircleResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/contributions?") &&
      response.request().method() === "DELETE",
    { timeout: 20_000 },
  );
  await circleRow.getByRole("button", { name: /^remove$/i }).click();
  const deleteCircleResponse = await deleteCircleResponsePromise;
  if (deleteCircleResponse.status() !== 200) {
    throw new Error(
      `Contribution group delete request failed with status ${deleteCircleResponse.status()}: ${await deleteCircleResponse.text()}`,
    );
  }
  await expectRecordMissing(
    () =>
      admin
        .from("contribution_groups")
        .select("id")
        .eq("club_id", clubId)
        .eq("name", circleName)
        .maybeSingle(),
    "Deleted contribution group still exists.",
  );
  contributionGroupId = null;
  recordCheck(
    "community-circle-delete",
    true,
    "Community support circle deletion persisted to Supabase.",
  );
  await page.close();

  currentStep = "cms-content-create";
  page = await openAuthedPage(context, "/admin/cms/content");
  await waitForMainHeading(page, /content blocks/i);
  await page.getByLabel(/content type/i).selectOption("general");
  await page.getByLabel(/^title$/i).fill(cmsTitle);
  await page.getByLabel(/subtitle/i).fill("Temporary CMS content.");
  await page.getByLabel(/^body$/i).fill(
    "Temporary CMS content block created by live admin UAT.",
  );
  await page.getByLabel(/cta label/i).fill("Learn more");
  await page.getByLabel(/cta action\/route/i).fill("/uat");
  await page.getByLabel(/sort order/i).fill("11");
  const saveCmsButton = page.getByRole("button", { name: /add block/i });
  await waitForButtonEnabled(page, saveCmsButton);
  const cmsForm = page.locator("form").first();
  const saveCmsResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/cms-content") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await saveCmsButton.click();
  let saveCmsResponse;
  try {
    saveCmsResponse = await saveCmsResponsePromise;
  } catch (error) {
    const formState = await describeFormState(cmsForm).catch(() => null);
    const buttonState = await saveCmsButton
      .evaluate((button) => ({
        disabled: button instanceof HTMLButtonElement ? button.disabled : null,
        text: button.textContent?.trim() ?? "",
      }))
      .catch(() => null);
    throw new Error(
      `CMS content create request was not observed. url=${page.url()} form=${JSON.stringify(formState)} button=${JSON.stringify(buttonState)} cause=${sanitizeError(error)}`,
    );
  }
  if (saveCmsResponse.status() !== 200) {
    throw new Error(
      `CMS content create request failed with status ${saveCmsResponse.status()}: ${await saveCmsResponse.text()}`,
    );
  }
  await page.getByText(/content saved\./i).waitFor({ timeout: 20_000 });
  const savedCmsContent = await waitForCmsContent(cmsTitle);
  cmsContentId = savedCmsContent.id;
  recordCheck(
    "cms-content-create",
    true,
    "CMS content block creation persisted to Supabase.",
  );
  const deleteCmsButton = page.getByRole("button", {
    name: new RegExp(`^Delete content block ${escapeRegExp(cmsTitle)}$`, "i"),
  });
  await deleteCmsButton.waitFor({ timeout: 20_000 });

  currentStep = "cms-content-delete";
  page.once("dialog", (dialog) => dialog.accept());
  const deleteCmsResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/cms-content?") &&
      response.request().method() === "DELETE",
    { timeout: 20_000 },
  );
  await deleteCmsButton.click();
  const deleteCmsResponse = await deleteCmsResponsePromise;
  if (deleteCmsResponse.status() !== 200) {
    throw new Error(
      `CMS content delete request failed with status ${deleteCmsResponse.status()}: ${await deleteCmsResponse.text()}`,
    );
  }
  await page.getByText(/block removed\./i).waitFor({ timeout: 20_000 });
  await expectRecordMissing(
    () =>
      admin
        .from("ai_content")
        .select("id")
        .eq("club_id", clubId)
        .eq("title", cmsTitle)
        .maybeSingle(),
    "Deleted CMS content block still exists.",
  );
  cmsContentId = null;
  recordCheck(
    "cms-content-delete",
    true,
    "CMS content block deletion persisted to Supabase.",
  );
  await page.close();

  page = await openAuthedPage(context, "/admin/tickets");
  await waitForMainHeading(page, /ticket operations/i);
  await page
    .getByPlaceholder(/search by fan, match, or momo ref/i)
    .fill(tempMomoReference);
  let ticketRow = page.locator("tr", { hasText: tempMomoReference });
  await ticketRow.waitFor({ timeout: 20_000 });
  currentStep = "ticket-validate";
  const validateResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/tickets/status") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await ticketRow.getByRole("button", { name: /^validate$/i }).click();
  const validateResponse = await validateResponsePromise;
  if (validateResponse.status() !== 200) {
    throw new Error(
      `Ticket validation request failed with status ${validateResponse.status()}: ${await validateResponse.text()}`,
    );
  }
  await page.getByText(/ticket valid\./i).waitFor({ timeout: 4_000 }).catch(() => {});
  await waitForTicketStatus(ticketId, "valid");
  recordCheck("ticket-validate", true, "Ticket validation action persisted to Supabase.");

  ticketRow = page.locator("tr", { hasText: tempMomoReference });
  await ticketRow.waitFor({ timeout: 20_000 });
  currentStep = "ticket-mark-used";
  const markUsedResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/tickets/status") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await ticketRow.getByRole("button", { name: /mark used/i }).click();
  const markUsedResponse = await markUsedResponsePromise;
  if (markUsedResponse.status() !== 200) {
    throw new Error(
      `Ticket mark-used request failed with status ${markUsedResponse.status()}: ${await markUsedResponse.text()}`,
    );
  }
  await page.getByText(/ticket used\./i).waitFor({ timeout: 4_000 }).catch(() => {});
  await waitForTicketStatus(ticketId, "used");
  recordCheck("ticket-mark-used", true, "Ticket mark-used action persisted to Supabase.");
  await page.close();

  currentStep = "membership-approve";
  page = await openAuthedPage(context, "/admin/membership");
  await waitForMainHeading(page, /membership operations/i);
  await page.getByRole("button", { name: /applications/i }).click();
  const membershipApplicationRow = page.locator("tr", {
    hasText: new RegExp(
      `${escapeRegExp(tempUserName)}|${escapeRegExp(tempUserPhone)}`,
      "i",
    ),
  }).first();
  await membershipApplicationRow.waitFor({ timeout: 20_000 });
  const approveButton = membershipApplicationRow.getByRole("button", {
    name: /^approve$/i,
  });
  await approveButton.waitFor({ timeout: 20_000 });
  const membershipReviewResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/admin/membership-applications/review") &&
      response.request().method() === "POST",
    { timeout: 20_000 },
  );
  await approveButton.click();
  const membershipReviewResponse = await membershipReviewResponsePromise;
  if (membershipReviewResponse.status() !== 200) {
    throw new Error(
      `Membership review request failed with status ${membershipReviewResponse.status()}: ${await membershipReviewResponse.text()}`,
    );
  }
  await page
    .getByText(/application approved\./i)
    .waitFor({ timeout: 4_000 })
    .catch(() => {});
  await waitForMembershipApplicationStatus(membershipApplicationId, "approved");
  recordCheck("membership-approve", true, "Membership application approval persisted to Supabase.");

  const fanMembership = await waitForFanMembership(userId, clubId);
  if (fanMembership.tier !== "gold" || fanMembership.status !== "active") {
    throw new Error("Membership approval did not create/update the supporter membership row.");
  }
  fanMembershipKeys.add(fanMembership.id);
  recordCheck("membership-upsert", true, "Membership approval created or updated the supporter membership row.");
  await page.close();

  for (const entry of accessiblePages) {
    await verifyAccessiblePage(context, entry);
    recordCheck(
      `page:${entry.path}`,
      true,
      `Loaded ${entry.path} and found ${entry.heading}.`,
    );
  }

  for (const entry of expectedDeniedPages) {
    await verifyDeniedPage(context, entry);
    recordCheck(
      `page:${entry.path}`,
      true,
      `Loaded ${entry.path} and confirmed the expected restricted-access state.`,
    );
  }

  page = await openAuthedPage(context, "/admin/settings/audit");
  const apiChecks = await page.evaluate(async () => {
    const [featuresRes, blocksRes] = await Promise.all([
      fetch("/api/admin/features", { credentials: "same-origin" }),
      fetch("/api/admin/content-blocks", { credentials: "same-origin" }),
    ]);
    return {
      featuresStatus: featuresRes.status,
      blocksStatus: blocksRes.status,
    };
  });
  if (apiChecks.featuresStatus !== 200 || apiChecks.blocksStatus !== 200) {
    throw new Error(
      `Authenticated admin API checks failed: ${JSON.stringify(apiChecks)}`,
    );
  }
  recordCheck(
    "authenticated-admin-apis",
    true,
    `Authenticated admin APIs returned ${JSON.stringify(apiChecks)}.`,
  );
  await page.close();

  await browser.close();
  browser = null;

  report.success = true;
  report.finishedAt = new Date().toISOString();
  writeReportFile();
  process.stdout.write(
    `[admin-uat] Live admin UAT passed with ${report.checks.length} checks.\n`,
  );
} catch (error) {
  report.success = false;
  report.finishedAt = new Date().toISOString();
  recordCheck(
    "fatal",
    false,
    `step=${currentStep}\n${sanitizeError(error)}`,
  );
  writeReportFile();
  process.stderr.write(
    `[admin-uat] step=${currentStep}\n${sanitizeError(error)}\n`,
  );
  process.exitCode = 1;
} finally {
  try {
    await restoreFeatureStates();
  } catch (error) {
    process.stderr.write(
      `[admin-uat] feature state restore failed\n${sanitizeError(error)}\n`,
    );
  }

  if (browser) {
    try {
      await browser.close();
    } catch {
      // Ignore best-effort browser cleanup.
    }
  }

  if (contentBlockId) {
    await admin.from("platform_content_blocks").delete().eq("id", contentBlockId);
  }

  if (cmsContentId) {
    await admin.from("ai_content").delete().eq("id", cmsContentId);
  }

  if (contributionGroupId) {
    await admin
      .from("contribution_groups")
      .delete()
      .eq("id", contributionGroupId);
  }

  if (fanClubId) {
    await admin.from("fan_clubs").delete().eq("id", fanClubId);
  }

  if (productId) {
    const cleanupProductTable = await resolveAccessibleTable([
      "shop_products",
      "rs_shop_products",
    ]);
    await admin.from(cleanupProductTable).delete().eq("id", productId);
  }

  if (notificationId) {
    await admin.from("notifications").delete().eq("id", notificationId);
  }

  if (membershipApplicationId) {
    await admin
      .from("membership_applications")
      .delete()
      .eq("id", membershipApplicationId);
  }

  if (ticketId) {
    await admin.from("tickets").delete().eq("id", ticketId);
  }

  if (fanMembershipKeys.size > 0) {
    await admin
      .from("fan_memberships")
      .delete()
      .in("id", [...fanMembershipKeys]);
  }

  if (profileId) {
    await admin.from("profiles").delete().eq("id", profileId);
  }

  if (featureId) {
    await admin.from("platform_features").delete().eq("id", featureId);
  }

  if (userId) {
    await admin
      .from("admin_role_assignments")
      .delete()
      .eq("user_id", userId);
    await admin.auth.admin.deleteUser(userId);
  }
}
