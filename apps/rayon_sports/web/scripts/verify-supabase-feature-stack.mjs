import { spawnSync } from "node:child_process";
import {
  getFirstEnvValue,
  loadLocalEnv,
  loadSupabaseAccessToken,
  resolveSupabaseProjectRef,
} from "./lib/env-utils.mjs";

loadLocalEnv();

const supabaseUrl = getFirstEnvValue(
  "SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_URL",
);
const siteUrl =
  getFirstEnvValue("NEXT_PUBLIC_SITE_URL") || "https://gikundiro.com";
const adminUrl =
  getFirstEnvValue("NEXT_PUBLIC_ADMIN_URL") || "https://admin.gikundiro.com";
const postgresUrl = getFirstEnvValue("POSTGRES_URL");
const supabaseAccessToken = loadSupabaseAccessToken();
const projectRef = supabaseUrl ? resolveSupabaseProjectRef(supabaseUrl) : "";

const issues = [];
const passes = [];

function recordPass(message) {
  passes.push(message);
}

function recordIssue(message) {
  issues.push(message);
}

function requireValue(label, value) {
  if (!value) {
    recordIssue(`${label} is not configured.`);
    return false;
  }

  return true;
}

function runPsql(query) {
  const result = spawnSync("psql", [postgresUrl, "-Atc", query], {
    encoding: "utf8",
    env: process.env,
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `psql exited with ${result.status}`);
  }

  return result.stdout.trim();
}

async function verifyAuthConfig() {
  if (
    !requireValue("SUPABASE_URL/NEXT_PUBLIC_SUPABASE_URL", supabaseUrl) ||
    !requireValue("SUPABASE_ACCESS_TOKEN", supabaseAccessToken)
  ) {
    return;
  }

  const response = await fetch(
    `https://api.supabase.com/v1/projects/${projectRef}/config/auth`,
    {
      headers: {
        Authorization: `Bearer ${supabaseAccessToken}`,
      },
    },
  );

  if (!response.ok) {
    recordIssue(
      `Could not fetch Supabase auth config: ${response.status} ${response.statusText}`,
    );
    return;
  }

  const authConfig = await response.json();
  const allowList = String(authConfig.uri_allow_list ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  const expectedEntries = [
    `${siteUrl}/**`,
    "https://www.gikundiro.com/**",
    `${adminUrl}/**`,
    "https://fans.gikundiro.com/**",
  ];

  if (authConfig.site_url !== siteUrl) {
    recordIssue(
      `Supabase auth site_url is ${JSON.stringify(authConfig.site_url)} instead of ${JSON.stringify(siteUrl)}.`,
    );
  } else {
    recordPass(`Supabase auth site_url matches ${siteUrl}.`);
  }

  for (const entry of expectedEntries) {
    if (!allowList.includes(entry)) {
      recordIssue(`Supabase auth redirect allow-list is missing ${entry}.`);
    } else {
      recordPass(`Supabase auth redirect allow-list contains ${entry}.`);
    }
  }
}

function verifyDatabaseObjects() {
  if (!requireValue("POSTGRES_URL", postgresUrl)) {
    return;
  }

  const triggerChecks = [
    {
      table: "platform_features",
      requiredTriggers: ["trg_feature_audit_features"],
    },
    {
      table: "platform_feature_channels",
      requiredTriggers: ["trg_feature_audit_channels"],
    },
    {
      table: "platform_feature_rules",
      requiredTriggers: ["trg_feature_audit_rules"],
    },
    {
      table: "platform_content_blocks",
      requiredTriggers: [
        "trg_audit_platform_content_blocks",
        "trg_feature_audit_content_blocks",
      ],
    },
  ];

  for (const check of triggerChecks) {
    const output = runPsql(`
      SELECT coalesce(string_agg(t.tgname, ',' ORDER BY t.tgname), '')
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = '${check.table}'
        AND NOT t.tgisinternal;
    `);
    const triggers = output
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean);

    for (const triggerName of check.requiredTriggers) {
      if (!triggers.includes(triggerName)) {
        recordIssue(
          `Table ${check.table} is missing trigger ${triggerName}.`,
        );
      } else {
        recordPass(`Table ${check.table} has trigger ${triggerName}.`);
      }
    }
  }

  const functionDefinition = runPsql(
    "SELECT pg_get_functiondef('public.log_feature_config_change()'::regprocedure);",
  );

  if (!functionDefinition.includes("platform_content_blocks")) {
    recordIssue(
      "log_feature_config_change() does not include platform_content_blocks handling.",
    );
  } else {
    recordPass(
      "log_feature_config_change() includes platform_content_blocks handling.",
    );
  }

  if (!functionDefinition.includes("NOT EXISTS")) {
    recordIssue(
      "log_feature_config_change() is missing the missing-feature FK guard.",
    );
  } else {
    recordPass("log_feature_config_change() includes the missing-feature FK guard.");
  }

  const functionExistenceChecks = [
    {
      label: "get_platform_config(text,bigint)",
      query:
        "SELECT to_regprocedure('public.get_platform_config(text,bigint)') IS NOT NULL;",
    },
    {
      label: "get_feature_access_state(text,text,bigint,boolean,text[])",
      query:
        "SELECT to_regprocedure('public.get_feature_access_state(text,text,bigint,boolean,text[])') IS NOT NULL;",
    },
    {
      label: "check_feature_enabled(text,text,bigint)",
      query:
        "SELECT to_regprocedure('public.check_feature_enabled(text,text,bigint)') IS NOT NULL;",
    },
  ];

  for (const check of functionExistenceChecks) {
    const output = runPsql(check.query);
    if (output !== "t") {
      recordIssue(`Database function ${check.label} is missing.`);
    } else {
      recordPass(`Database function ${check.label} exists.`);
    }
  }

  const notificationsContract = runPsql(`
    SELECT json_build_object(
      'match_id_nullable',
      EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'notifications'
          AND column_name = 'match_id'
          AND is_nullable = 'YES'
      ),
      'audience_group_id_exists',
      EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'notifications'
          AND column_name = 'audience_group_id'
      ),
      'status_constraint',
      coalesce(
        (
          SELECT pg_get_constraintdef(oid)
          FROM pg_constraint
          WHERE conrelid = 'public.notifications'::regclass
            AND conname = 'rs_notifications_status_check'
        ),
        ''
      )
    )::text;
  `);

  let parsedNotificationsContract = null;
  try {
    parsedNotificationsContract = JSON.parse(notificationsContract);
  } catch (_) {
    recordIssue("Could not parse notifications schema verification output.");
  }

  if (parsedNotificationsContract) {
    if (parsedNotificationsContract.match_id_nullable !== true) {
      recordIssue("public.notifications.match_id is still NOT NULL.");
    } else {
      recordPass("public.notifications.match_id allows non-match broadcasts.");
    }

    if (parsedNotificationsContract.audience_group_id_exists !== true) {
      recordIssue("public.notifications is missing audience_group_id.");
    } else {
      recordPass("public.notifications includes audience_group_id.");
    }

    const statusConstraint = String(
      parsedNotificationsContract.status_constraint ?? "",
    );
    const requiredStatuses = [
      "scheduled",
      "processing",
      "partial",
      "sent",
      "failed",
    ];

    for (const status of requiredStatuses) {
      if (!statusConstraint.includes(`'${status}'`)) {
        recordIssue(
          `public.notifications status constraint is missing ${status}.`,
        );
      } else {
        recordPass(
          `public.notifications status constraint includes ${status}.`,
        );
      }
    }
  }
}

try {
  await verifyAuthConfig();
  verifyDatabaseObjects();
} catch (error) {
  recordIssue(
    error instanceof Error ? error.message : "Unknown verification failure.",
  );
}

for (const message of passes) {
  process.stdout.write(`[verify] PASS ${message}\n`);
}

for (const message of issues) {
  process.stderr.write(`[verify] FAIL ${message}\n`);
}

if (issues.length > 0) {
  process.exit(1);
}

process.stdout.write("[verify] Supabase feature stack verification passed.\n");
