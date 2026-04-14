import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";

function loadLocalEnv() {
  const envPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "../.env.local",
  );

  if (!fs.existsSync(envPath)) {
    return;
  }

  for (const line of fs.readFileSync(envPath, "utf8").split(/\n+/)) {
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    const rawValue = line.slice(separatorIndex + 1).trim();
    if (!key || process.env[key] != null) {
      continue;
    }

    process.env[key] = rawValue.replace(/^['"]|['"]$/g, "");
  }
}

loadLocalEnv();

const supabaseUrl =
  process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const clubId = Number.parseInt(process.env.AFRICLUB_QA_CLUB_ID ?? "24", 10);
const batchKey = process.env.AFRICLUB_QA_BATCH ?? "wallet_qa_uat";

if (!supabaseUrl || !serviceRoleKey) {
  console.error(
    "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required to seed QA personas.",
  );
  process.exit(2);
}

if (!Number.isFinite(clubId)) {
  console.error("AFRICLUB_QA_CLUB_ID must be a valid numeric club id.");
  process.exit(2);
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});
const authAdminBaseUrl = `${supabaseUrl.replace(/\/$/, "")}/auth/v1/admin`;
const managementApiBaseUrl = "https://api.supabase.com/v1/projects";
const supabaseProjectRef = new URL(supabaseUrl).hostname.split(".")[0] ?? "";

function loadSupabaseAccessToken() {
  if (process.env.SUPABASE_ACCESS_TOKEN?.trim()) {
    return process.env.SUPABASE_ACCESS_TOKEN.trim();
  }

  const tokenPath = path.join(process.env.HOME ?? "", ".supabase", ".access-token");
  if (!tokenPath || !fs.existsSync(tokenPath)) {
    return null;
  }

  const value = fs.readFileSync(tokenPath, "utf8").trim();
  return value.length > 0 ? value : null;
}

const supabaseAccessToken = loadSupabaseAccessToken();

const personas = [
  {
    key: "super_admin",
    phone: "+250788100001",
    name: "AFRICLUB Super Admin",
    publicUserId: "910001",
    isAdmin: true,
    balance: 0,
  },
  {
    key: "club_admin",
    phone: "+250788100002",
    name: "AFRICLUB Club Admin",
    publicUserId: "910002",
    isAdmin: true,
    balance: 0,
  },
  {
    key: "supporter_alpha",
    phone: "+250788100010",
    name: "UAT Supporter Alpha",
    publicUserId: "910010",
    isAdmin: false,
    balance: 1250,
  },
  {
    key: "supporter_beta",
    phone: "+250788100011",
    name: "UAT Supporter Beta",
    publicUserId: "910011",
    isAdmin: false,
    balance: 640,
  },
  {
    key: "supporter_gamma",
    phone: "+250788100012",
    name: "UAT Supporter Gamma",
    publicUserId: "910012",
    isAdmin: false,
    balance: 320,
  },
];

function normalizePhoneForLookup(value) {
  return String(value ?? "").replace(/\D/g, "");
}

async function authAdminRequest(pathname) {
  const response = await fetch(`${authAdminBaseUrl}${pathname}`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(body || `Auth admin request failed: ${response.status}`);
  }

  return response.json();
}

async function findExistingAuthUserViaSql(phone) {
  if (!supabaseAccessToken || !supabaseProjectRef) {
    return null;
  }

  const escapedPhone = phone.replace(/'/g, "''");
  const normalizedPhone = normalizePhoneForLookup(phone);
  const response = await fetch(
    `${managementApiBaseUrl}/${supabaseProjectRef}/database/query/read-only`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${supabaseAccessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        query: `select id, phone from auth.users where phone = '${escapedPhone}' or regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = '${normalizedPhone}' limit 1;`,
      }),
    },
  );

  if (!response.ok) {
    return null;
  }

  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }

  return rows[0];
}

async function findExistingAuthUser(phone) {
  const directMatch = await findExistingAuthUserViaSql(phone);
  if (directMatch) {
    return directMatch;
  }

  const perPage = 10;
  const normalizedPhone = normalizePhoneForLookup(phone);

  for (let page = 1; page <= 13; page += 1) {
    try {
      const data = await authAdminRequest(`/users?page=${page}&per_page=${perPage}`);
      const users = Array.isArray(data?.users) ? data.users : [];
      const existing =
        users.find(
          (user) =>
            user.phone === phone ||
            normalizePhoneForLookup(user.phone) === normalizedPhone,
        ) ?? null;
      if (existing) {
        return existing;
      }
      if (users.length < perPage) {
        break;
      }
    } catch (error) {
      if (page > 1) {
        break;
      }
      throw error;
    }
  }

  return null;
}

async function ensureAuthUser(persona) {
  const existing = await findExistingAuthUser(persona.phone);

  if (existing) {
    const { data, error } = await admin.auth.admin.updateUserById(existing.id, {
      phone: persona.phone,
      phone_confirm: true,
      user_metadata: { club_id: clubId, batch_key: batchKey },
      app_metadata: { club_id: clubId },
    });
    if (error) {
      throw error;
    }
    return data.user;
  }

  const { data, error } = await admin.auth.admin.createUser({
    phone: persona.phone,
    phone_confirm: true,
    user_metadata: { club_id: clubId, batch_key: batchKey },
    app_metadata: { club_id: clubId },
  });
  if (error) {
    if (String(error.message).includes("Phone number already registered")) {
      const duplicate = await findExistingAuthUser(persona.phone);
      if (duplicate?.id) {
        const updated = await admin.auth.admin.updateUserById(duplicate.id, {
          phone: persona.phone,
          phone_confirm: true,
          user_metadata: { club_id: clubId, batch_key: batchKey },
          app_metadata: { club_id: clubId },
        });
        if (updated.error) {
          throw updated.error;
        }
        return updated.data.user;
      }
    }
    throw error;
  }
  return data.user;
}

async function requireClub() {
  const { data, error } = await admin
    .from("african_football_clubs")
    .select("id, club_name")
    .eq("id", clubId)
    .maybeSingle();

  if (error) {
    throw error;
  }
  if (!data) {
    throw new Error(
      `Club ${clubId} does not exist. Set AFRICLUB_QA_CLUB_ID to a valid club.`,
    );
  }
  return data;
}

async function ensureWalletLedgerTable() {
  const { error } = await admin
    .from("fet_wallet_ledger_entries")
    .select("id")
    .limit(1);

  if (error) {
    throw new Error(
      "fet_wallet_ledger_entries is not available yet. Apply the pending wallet migration before seeding QA personas.",
    );
  }
}

async function upsertPublicRows(seededUsers) {
  const usersPayload = seededUsers.map(({ authUser, persona }) => ({
    id: authUser.id,
    phone: persona.phone,
    full_name: persona.name,
    country: "RW",
    language_code: "en",
    momo_number: persona.isAdmin ? null : persona.phone,
    momo_provider: "",
    is_admin: persona.isAdmin,
    is_mock: true,
    mock_batch: batchKey,
    public_user_id: persona.publicUserId,
    momo_route_type: persona.isAdmin ? null : "phone_number",
  }));

  const profilesPayload = seededUsers.map(({ authUser, persona }) => ({
    id: authUser.id,
    club_id: clubId,
    phone: persona.phone,
    full_name: persona.name,
    public_user_id: persona.publicUserId,
    country: "RW",
    language_code: "en",
    is_admin: persona.isAdmin,
    momo_number: persona.isAdmin ? null : persona.phone,
    display_name: persona.name,
    is_active: true,
  }));

  const { error: usersError } = await admin
    .from("users")
    .upsert(usersPayload, { onConflict: "id" });
  if (usersError) {
    throw usersError;
  }

  const { error: profilesError } = await admin
    .from("profiles")
    .upsert(profilesPayload, { onConflict: "id" });
  if (profilesError) {
    throw profilesError;
  }
}

async function seedAdminAccess(seededUsers) {
  const superAdmin = seededUsers.find((entry) => entry.persona.key === "super_admin");
  const clubAdmin = seededUsers.find((entry) => entry.persona.key === "club_admin");

  if (!superAdmin || !clubAdmin) {
    throw new Error("Required admin personas are missing from the seed set.");
  }

  const adminUserIds = [superAdmin.authUser.id, clubAdmin.authUser.id];
  const { error: deleteError } = await admin
    .from("admin_role_assignments")
    .delete()
    .in("user_id", adminUserIds)
    .in("role", ["super_admin", "admin", "club_admin", "club_moderator"]);
  if (deleteError) {
    throw deleteError;
  }

  const { error: insertError } = await admin
    .from("admin_role_assignments")
    .insert([
      {
        user_id: superAdmin.authUser.id,
        role: "super_admin",
        club_id: null,
        granted_by: superAdmin.authUser.id,
        is_active: true,
        notes: `Seeded by ${batchKey}`,
      },
      {
        user_id: clubAdmin.authUser.id,
        role: "club_admin",
        club_id: clubId,
        granted_by: superAdmin.authUser.id,
        is_active: true,
        notes: `Seeded by ${batchKey}`,
      },
    ]);
  if (insertError) {
    throw insertError;
  }

  for (const userId of adminUserIds) {
    const { error } = await admin.rpc("refresh_admin_phone_access_for_user", {
      p_user_id: userId,
    });
    if (error) {
      throw error;
    }
  }
}

async function resetSeedWalletData(seededUsers) {
  const supporterIds = seededUsers
    .filter((entry) => entry.persona.balance > 0)
    .map((entry) => entry.authUser.id);

  if (supporterIds.length === 0) {
    return;
  }

  const deletions = [
    admin
      .from("fet_wallet_ledger_entries")
      .delete()
      .in("user_id", supporterIds)
      .eq("club_id", clubId),
    admin
      .from("cool_events")
      .delete()
      .in("user_id", supporterIds)
      .eq("club_id", clubId)
      .eq("event_type", "qa_seed_initial_balance"),
    admin
      .from("fan_memberships")
      .delete()
      .in("user_id", supporterIds)
      .eq("club_id", clubId),
  ];

  for (const deletion of deletions) {
    const { error } = await deletion;
    if (error) {
      throw error;
    }
  }

  for (const entry of seededUsers.filter((item) => item.persona.balance > 0)) {
    const { error } = await admin.rpc("add_fan_points", {
      p_user_id: entry.authUser.id,
      p_partner_id: String(clubId),
      p_points: entry.persona.balance,
      p_reason: "qa_seed_initial_balance",
    });
    if (error) {
      throw error;
    }
  }
}

async function readSeededWalletState(seededUsers) {
  const supporterIds = seededUsers
    .filter((entry) => entry.persona.balance > 0)
    .map((entry) => entry.authUser.id);

  if (supporterIds.length === 0) {
    return new Map();
  }

  const { data, error } = await admin
    .from("fan_memberships")
    .select("user_id, points, tier")
    .eq("club_id", clubId)
    .in("user_id", supporterIds);

  if (error) {
    throw error;
  }

  return new Map(
    (data ?? []).map((row) => [
      row.user_id,
      {
        balance: Number(row.points ?? 0),
        tier: String(row.tier ?? "fan"),
      },
    ]),
  );
}

async function main() {
  const club = await requireClub();
  await ensureWalletLedgerTable();
  const seededUsers = [];

  for (const persona of personas) {
    const authUser = await ensureAuthUser(persona);
    seededUsers.push({ persona, authUser });
  }

  await upsertPublicRows(seededUsers);
  await seedAdminAccess(seededUsers);
  await resetSeedWalletData(seededUsers);
  const walletState = await readSeededWalletState(seededUsers);

  console.log("");
  console.log(`Seeded wallet QA personas for club ${clubId} (${club.club_name}).`);
  console.table(
    seededUsers.map(({ persona, authUser }) => ({
      persona: persona.key,
      user_id: authUser.id,
      phone: persona.phone,
      public_user_id: persona.publicUserId,
      role: persona.isAdmin
        ? persona.key === "super_admin"
          ? "super_admin"
          : "club_admin"
        : "supporter",
      balance_fet:
        walletState.get(authUser.id)?.balance ?? persona.balance,
      tier: walletState.get(authUser.id)?.tier ?? (persona.isAdmin ? "-" : "fan"),
    })),
  );
  console.log(
    "Next step: run tools/scripts/run_wallet_qa_uat.sh and follow docs/fet_wallet_qa_uat_2026-04-12.md for manual evidence capture.",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
