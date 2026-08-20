#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const functionsRoot = path.join(root, "supabase", "functions");
const configPath = path.join(root, "supabase", "config.toml");

const authContracts = new Map([
  ["admin-upload-image", [/requireClubAdminCaller\(/]],
  ["admin-send-notification", [/validateRequest\(/, /requireAdmin:\s*true/]],
  ["admin-settle-fixture", [/requireAdminCaller\(/]],
  ["delete-account", [/validateRequest\(/]],
  ["dispatch-scheduled-notifications", [/requireCronSecret\(/]],
  ["game-session-action", [/requireAuthenticatedCaller\(/, /requireClubAdminCaller\(/]],
  ["generate-admin-image", [/validateRequest\(/, /ensureClubAdminAccess\(/]],
  ["generate-product-image", [/validateRequest\(/, /requireClubAdmin:/]],
  ["generate-question-drafts", [/requireClubAdminCaller\(/]],
  ["get-platform-config", [/createAnonClient\(/]],
  ["google-wallet-ticket-pass", [/requireAuthenticatedCaller\(/, /enforceRateLimit\(/]],
  ["football-sync", [/requireCronSecret\(/, /requireAdminCaller\(/]],
  ["livescore-openai-sync", [/requireAdminCaller\(/, /x-cron-secret/]],
  ["parse-momo-sms", [/validateRequest\(/]],
  ["record-operational-health", [/validateRequest\(/]],
  ["send-notification", [/getSecretKeys:\s*getSupabaseSecretKeys/]],
  ["send-sms", [/createSendSmsHandler\(/]],
  ["settle-prediction-notifications", [/requireCronSecret\(/]],
  ["sms-ingest", [/validateRequest\(/]],
  ["sync-google-wallet-ticket-state", [/requireCronSecret\(/]],
  ["verify-ticket", [/requireAuthenticatedCaller\(/, /enforceRateLimit\(/]],
]);

function fail(message) {
  throw new Error(`Supabase Edge contract: ${message}`);
}

const localFunctions = fs.readdirSync(functionsRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && entry.name !== "_shared")
  .map((entry) => entry.name)
  .sort();
const expectedFunctions = [...authContracts.keys()].sort();

if (JSON.stringify(localFunctions) !== JSON.stringify(expectedFunctions)) {
  fail(
    `function inventory mismatch; expected ${expectedFunctions.join(", ")}; got ${localFunctions.join(", ")}`,
  );
}

const config = fs.readFileSync(configPath, "utf8");
for (const name of expectedFunctions) {
  const section = new RegExp(
    `\\[functions\\.${name.replaceAll("-", "\\-")}\\]\\s+verify_jwt\\s*=\\s*false(?:\\s|$)`,
    "m",
  );
  if (!section.test(config)) {
    fail(`${name} must explicitly set verify_jwt=false`);
  }

  const indexPath = path.join(functionsRoot, name, "index.ts");
  if (!fs.existsSync(indexPath)) fail(`${name} is missing index.ts`);
  const source = fs.readFileSync(indexPath, "utf8");
  if (/new Response\([^)]*\.body,\s*\{\s*\.\.\.(?:response|res)/s.test(source)) {
    fail(`${name} must preserve status explicitly when adding CORS headers`);
  }
  for (const pattern of authContracts.get(name)) {
    if (!pattern.test(source)) {
      fail(`${name} is missing required in-function control ${pattern}`);
    }
  }
}

if (!/\[auth\.hook\.send_sms\]\s+enabled\s*=\s*true/s.test(config)) {
  fail("the Send SMS Auth hook must be enabled in source configuration");
}
if (!config.includes('secrets = "env(AUTH_HOOK_SEND_SMS_SECRET)"')) {
  fail("the Send SMS Auth hook must use the governed signing secret");
}

const sharedClient = fs.readFileSync(
  path.join(functionsRoot, "_shared", "supabase.ts"),
  "utf8",
);
for (const variableName of [
  "SUPABASE_PUBLISHABLE_KEYS",
  "SUPABASE_SECRET_KEYS",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
]) {
  if (!sharedClient.includes(variableName)) {
    fail(`shared client must support ${variableName}`);
  }
}

const validation = fs.readFileSync(
  path.join(functionsRoot, "_shared", "validation.ts"),
  "utf8",
);
if (validation.includes("user_metadata")) {
  fail("tenant scope must not use user_metadata");
}
if (!validation.includes("extractTrustedClubId(appMetadata)")) {
  fail("tenant scope must be derived from trusted app_metadata");
}

const sendSms = fs.readFileSync(
  path.join(functionsRoot, "send-sms", "index.ts"),
  "utf8",
);
if (!sendSms.includes('Deno.env.get("AUTH_HOOK_SEND_SMS_SECRET")')) {
  fail("send-sms must verify Auth hook signatures with the governed secret");
}

console.log(
  `Supabase Edge contract passed: ${expectedFunctions.length} governed functions, explicit in-function auth, modern-key preference, trusted tenant scope.`,
);
