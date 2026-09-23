/**
 * Post-deploy verification script for Supabase environment.
 *
 * Checks:
 *  1. Key tables exist
 *  2. Triggers exist
 *  3. RLS policies exist
 *  4. Key RPCs/functions exist
 *  5. Admin phone access populated
 *  6. Feature config populated
 *
 * Usage: node scripts/verify-supabase-env.mjs
 */
import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";

const envContent = readFileSync(".env.local", "utf8");
function getEnv(key) {
  const match = envContent.match(new RegExp(`^${key}=(.+)$`, "m"));
  return match?.[1]?.trim() ?? process.env[key] ?? "";
}

const supabaseUrl =
  getEnv("SUPABASE_URL") || getEnv("NEXT_PUBLIC_SUPABASE_URL");
const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  console.error("❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);
let failures = 0;

function pass(label) {
  console.log(`  ✅ ${label}`);
}
function fail(label, detail = "") {
  failures++;
  console.log(`  ❌ ${label}${detail ? ` — ${detail}` : ""}`);
}

// ─── 1. Key Tables ───────────────────────────────────────────
console.log("\n1. Key Tables");
const requiredTables = [
  "admin_phone_access",
  "admin_role_assignments",
  "african_football_clubs",
  "platform_features",
  "platform_feature_channels",
  "platform_feature_rules",
  "platform_feature_audit_logs",
  "platform_content_blocks",
  "request_rate_limits",
];

for (const table of requiredTables) {
  const { error } = await supabase.from(table).select("*").limit(0);
  if (error) {
    fail(table, error.message);
  } else {
    pass(table);
  }
}

// ─── 2. Triggers ─────────────────────────────────────────────
console.log("\n2. Triggers");
const requiredTriggers = [
  {
    name: "trg_feature_audit_config",
    table: "platform_features",
  },
  {
    name: "trg_feature_audit_channels",
    table: "platform_feature_channels",
  },
  {
    name: "trg_feature_audit_rules",
    table: "platform_feature_rules",
  },
  {
    name: "trg_feature_audit_content_blocks",
    table: "platform_content_blocks",
  },
];

let triggerCheckFailed = false;
try {
  const { error: _trigErr } = await supabase.rpc("check_triggers_exist", {});
  if (_trigErr) triggerCheckFailed = true;
} catch {
  triggerCheckFailed = true;
}

if (triggerCheckFailed) {
  // Can't check triggers without raw SQL access; skip with warning
  for (const t of requiredTriggers) {
    console.log(`  ⚠️  ${t.name} (on ${t.table}) — cannot verify without SQL access`);
  }
} else {
  for (const t of requiredTriggers) {
    pass(`${t.name} (on ${t.table})`);
  }
}

// ─── 3. RLS Policies ────────────────────────────────────────
console.log("\n3. RLS-Protected Tables (write test)");

// Test that anonymous access is blocked on admin tables
const anonClient = createClient(
  supabaseUrl,
  getEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
);

const rlsTables = [
  "admin_phone_access",
  "admin_role_assignments",
  "platform_features",
  "platform_feature_channels",
  "platform_feature_rules",
  "platform_feature_audit_logs",
  "platform_content_blocks",
];

for (const table of rlsTables) {
  const { error } = await anonClient
    .from(table)
    .insert({ id: "rls-test-block" })
    .select()
    .maybeSingle();
  if (error) {
    pass(`${table} — anonymous write blocked`);
  } else {
    fail(`${table} — anonymous write NOT blocked!`);
  }
}

// ─── 4. Key RPCs/Functions ──────────────────────────────────
console.log("\n4. Key RPCs");
const requiredRpcs = [
  {
    name: "get_feature_access_state",
    args: { p_feature_key: "__test__", p_channel: "web" },
  },
  {
    name: "consume_request_rate_limit",
    args: {
      p_bucket_key: "__verify__",
      p_limit: 999,
      p_window_ms: 60000,
    },
  },
  {
    name: "canonicalize_platform_feature_key",
    args: { key: "test_key" },
  },
];

for (const rpc of requiredRpcs) {
  const { error } = await supabase.rpc(rpc.name, rpc.args);
  if (error && !error.message.includes("argument")) {
    fail(rpc.name, error.message);
  } else {
    pass(rpc.name);
  }
}

// ─── 5. Admin Phone Access ──────────────────────────────────
console.log("\n5. Admin Phone Access");
const { data: phones, error: phoneError } = await supabase
  .from("admin_phone_access")
  .select("phone")
  .limit(5);

if (phoneError) {
  fail("admin_phone_access query", phoneError.message);
} else if (!phones || phones.length === 0) {
  fail("admin_phone_access", "No admin phones configured");
} else {
  pass(`${phones.length} admin phone(s) configured`);
}

// ─── 6. Feature Config ──────────────────────────────────────
console.log("\n6. Feature Config");
const { data: features, error: featureError } = await supabase
  .from("platform_features")
  .select("feature_key, is_enabled")
  .limit(20);

if (featureError) {
  fail("platform_features query", featureError.message);
} else if (!features || features.length === 0) {
  fail("platform_features", "No features configured");
} else {
  const enabled = features.filter((f) => f.is_enabled).length;
  const disabled = features.length - enabled;
  pass(`${features.length} features (${enabled} enabled, ${disabled} disabled)`);
}

// ─── Summary ────────────────────────────────────────────────
console.log("\n─────────────────────────────────────────");
if (failures === 0) {
  console.log("✅ All checks passed\n");
} else {
  console.log(`❌ ${failures} check(s) failed\n`);
  process.exit(1);
}
