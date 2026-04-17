/**
 * Apply a SQL migration to live Supabase using the Management API.
 * Usage: node scripts/apply-sql.mjs <path-to-sql-file>
 *
 * Requires POSTGRES_URL in .env.local (direct Postgres connection string)
 * Uses fetch to hit the Supabase SQL endpoint directly.
 */
import { readFileSync } from "node:fs";

const sqlPath = process.argv[2];
if (!sqlPath) {
  console.error("Usage: node scripts/apply-sql.mjs <path-to-sql>");
  process.exit(1);
}

const envContent = readFileSync(".env.local", "utf8");
function getEnv(key) {
  const match = envContent.match(new RegExp(`^${key}=(.+)$`, "m"));
  return match?.[1]?.trim() ?? process.env[key] ?? "";
}

const supabaseUrl = getEnv("SUPABASE_URL") || getEnv("NEXT_PUBLIC_SUPABASE_URL");
const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  console.error("❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const sql = readFileSync(sqlPath, "utf8");
console.log(`Applying: ${sqlPath}`);
console.log(`SQL length: ${sql.length} chars\n`);

// Use the Supabase REST RPC endpoint to execute SQL via a helper function
// First create exec_sql if it doesn't exist, then use it
const createExecSqlFn = `
CREATE OR REPLACE FUNCTION public._exec_migration_sql(p_sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  EXECUTE p_sql;
END;
$$;
`;

// Try to create the helper function first
const createRes = await fetch(`${supabaseUrl}/rest/v1/rpc/_exec_migration_sql`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "apikey": serviceRoleKey,
    "Authorization": `Bearer ${serviceRoleKey}`,
    "Prefer": "return=minimal",
  },
  body: JSON.stringify({ p_sql: "SELECT 1" }),
});

if (createRes.status === 404) {
  // Function doesn't exist yet, we need another approach
  // Use the postgREST /rpc endpoint won't work for DDL
  // Fall back to printing the SQL for manual application
  console.log("⚠️  Cannot execute DDL via REST API.");
  console.log("Please apply the following SQL in Supabase Dashboard → SQL Editor:\n");
  console.log("─".repeat(60));
  console.log(sql);
  console.log("─".repeat(60));
  console.log("\nThen run: node scripts/verify-supabase-env.mjs");
  process.exit(0);
}

// If the function exists, use it
const res = await fetch(`${supabaseUrl}/rest/v1/rpc/_exec_migration_sql`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "apikey": serviceRoleKey,
    "Authorization": `Bearer ${serviceRoleKey}`,
    "Prefer": "return=minimal",
  },
  body: JSON.stringify({ p_sql: sql }),
});

if (!res.ok) {
  const body = await res.text();
  console.error(`❌ Migration failed (${res.status}): ${body}`);
  process.exit(1);
}

console.log("✅ Migration applied successfully.");
console.log("Run: node scripts/verify-supabase-env.mjs");
