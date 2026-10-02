#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function validateSupabaseEdgeContract(root = process.cwd()) {
  const functionsRoot = path.join(root, "supabase", "functions");
  const configPath = path.join(root, "supabase", "config.toml");

  const authContracts = new Map([
    ["admin-upload-image", [/requireClubAdminCaller\(/]],
    ["admin-send-notification", [/validateRequest\(/, /requireAdmin:\s*true/]],
    ["admin-settle-fixture", [/requireGlobalAdminCaller\(/]],
    ["delete-account", [/\.auth\.getUser\(/, /requestAccountClosure\(/, /requireCronSecret\(/, /requireGlobalAdminCaller\(/, /get_account_erasure_status/]],
    ["dispatch-scheduled-notifications", [/requireCronSecret\(/]],
    ["generate-admin-image", [/validateRequest\(/, /hasActiveAdminAssignment\(/]],
    ["generate-product-image", [/validateRequest\(/, /requireClubAdmin:/]],
    ["get-platform-config", [/createAnonClient\(/]],
    ["google-wallet-ticket-pass", [/requireAuthenticatedCaller\(/, /enforceRateLimit\(/]],
    ["football-sync", [/requireCronSecret\(/, /requireGlobalAdminCaller\(/]],
    ["livescore-openai-sync", [/requireGlobalAdminCaller\(/, /x-cron-secret/]],
    ["parse-momo-sms", [/requireSmsProcessor\(/]],
    ["record-operational-health", [/validateRequest\(/]],
    ["send-notification", [/getSecretKeys:\s*getSupabaseSecretKeys/]],
    ["send-sms", [/createSendSmsHandler\(/]],
    ["settle-prediction-notifications", [/requireCronSecret\(/]],
    ["sms-ingest", [/readGatewaySignature\(/, /verifySignedGatewayJson\(/, /validateProjection\(/, /validateRefundProjection\(/]],
    ["sync-google-wallet-ticket-state", [/requireCronSecret\(/]],
  ]);

  function fail(message) {
    throw new Error(`Supabase Edge contract: ${message}`);
  }

  // Generation reserves its budget inside the original database claim. Follow
  // the actual caller and latest forward definition instead of requiring a
  // second, detached limiter in each Edge entrypoint. SQL replay proves behavior.
  function validateImageAdmission(name, source) {
    if (!/import\s*\{[^}]*\bexecuteImageGeneration\b[^}]*\}\s*from\s*["']\.\.\/_shared\/admin_image_generation\.ts["']/s.test(source)
      || !/await\s+deps\.executeImageGeneration\(/.test(source)) {
      fail(`${name} must use the original image command admission`);
    }
    const shared = fs.readFileSync(path.join(functionsRoot, "_shared", "admin_image_generation.ts"), "utf8");
    const admission = shared.indexOf('await user.rpc("admit_admin_image_generation"');
    const claim = shared.indexOf('await admin.rpc("claim_admin_image_generation"');
    const provider = shared.indexOf("await fetchBoundedJson(");
    if (admission < 0 || claim <= admission || provider <= claim) {
      fail(`${name} must claim original admission before provider work`);
    }
    const migrations = path.join(root, "supabase", "migrations");
    let claimBody;
    for (const file of fs.readdirSync(migrations).filter((file) => file.endsWith(".sql")).sort()) {
      const sql = fs.readFileSync(path.join(migrations, file), "utf8");
      const definitions = sql.matchAll(/\bcreate\s+(?:or\s+replace\s+)?function\s+public\.claim_admin_image_generation\s*\([^;]*?\bas\s+(\$[A-Za-z0-9_]*\$)([\s\S]*?)\1\s*;/gi);
      for (const definition of definitions) claimBody = definition[2];
    }
    const budget = claimBody?.indexOf("select * into budget from public.consume_edge_rate_limit(") ?? -1;
    const denied = claimBody?.indexOf("if not budget.allowed then return", budget) ?? -1;
    const start = claimBody?.indexOf("provider_started_at=coalesce", denied) ?? -1;
    const finalProof = claimBody?.lastIndexOf("perform public.assert_verified_staff_provider_proof(") ?? -1;
    if (budget < 0 || denied <= budget || start <= denied || finalProof <= start
      || !/jsonb_build_array\(g\.actor_id,[\s\S]*?g\.club_id\)/.test(claimBody)
      || !/if not budget\.allowed then return[^;]*'claimed',false[^;]*'retry_after_seconds',budget\.retry_after_seconds/.test(claimBody)) {
      fail(`${name} must admit provider work through the atomic rate limiter and post-wait original proof`);
    }
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
    if (!/(?:Deno\.)?serve\(\s*withEdgeBoundary\(/s.test(source)) {
      fail(`${name} must register its deployed handler through withEdgeBoundary`);
    }
    if (/\b(?:req|request)\s*\.\s*(?:json|text|arrayBuffer|blob|formData)\s*\(/.test(source)) {
      fail(`${name} must bound inbound bytes and time before parsing`);
    }
    if (/["']Access-Control-Allow-Origin["']\s*[:,]\s*["']\*["']/i.test(source)) {
      fail(`${name} must not bypass the configured exact-origin boundary`);
    }
    if (["admin-settle-fixture", "football-sync", "livescore-openai-sync"].includes(name) && /requireAdminCaller\(/.test(source)) {
      fail(`${name} must not use club-capable authority for a global operation`);
    }
    if (["generate-admin-image", "generate-product-image"].includes(name)) {
      validateImageAdmission(name, source);
    }
    if (["admin-send-notification", "send-notification", "dispatch-scheduled-notifications", "settle-prediction-notifications"].includes(name) && !/enforceRateLimit\(/.test(source)) {
      fail(`${name} must admit provider work through the atomic rate limiter`);
    }
    if (/new Response\([^)]*\.body,\s*\{\s*\.\.\.(?:response|res)/s.test(source)) {
      fail(`${name} must preserve status explicitly when adding CORS headers`);
    }
    for (const pattern of authContracts.get(name)) {
      if (!pattern.test(source)) {
        fail(`${name} is missing required in-function control ${pattern}`);
      }
    }
    if (["sms-ingest", "parse-momo-sms"].includes(name) && /\b(?:validateRequest|requireAuthenticatedCaller)\(/.test(source)) {
      fail(`${name} must use the separate management/processor capability rather than supporter authentication`);
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

  const sendSmsHandler = fs.readFileSync(path.join(functionsRoot, "send-sms", "handler.ts"), "utf8");
  if (!/readBoundedText\(/.test(sendSmsHandler) || /\b(?:req|request)\s*\.\s*(?:json|text)\s*\(/.test(sendSmsHandler)) {
    fail("the signed Send SMS hook must bound the original body before signature verification");
  }
  const boundary = fs.readFileSync(path.join(functionsRoot, "_shared", "response.ts"), "utf8");
  for (const pattern of [/EDGE_ALLOWED_ORIGINS/, /configured\.includes\(origin\)/, /private, no-store/, /function withEdgeBoundary\(/]) {
    if (!pattern.test(boundary)) fail(`shared response boundary is missing ${pattern}`);
  }
  if (/["']Access-Control-Allow-Origin["']\s*[:,]\s*["']\*["']/i.test(boundary)) {
    fail("shared response boundary must not allow wildcard browser origins");
  }
  const http = fs.readFileSync(path.join(functionsRoot, "_shared", "http.ts"), "utf8");
  for (const pattern of [/function readBoundedBytes\(/, /\.getReader\(\)/, /size > maxBytes/, /timeoutMs = 5000/, /function fetchBoundedJson/, /controller\.abort\(error\)/]) {
    if (!pattern.test(http)) fail(`shared request/provider bounds are missing ${pattern}`);
  }
  return `Supabase Edge contract passed: ${expectedFunctions.length} governed functions, global/club capabilities, bounded bodies, exact browser origins, private responses and provider admission.`;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(validateSupabaseEdgeContract());
}
