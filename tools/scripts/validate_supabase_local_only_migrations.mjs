import { readFile } from "node:fs/promises";

const migrationNames = [
  "20260703223439_dynamic_runtime_registries.sql",
  "20260718161000_runtime_copy_key_contract_repair.sql",
  "20260718162000_venue_operator_audit_workflows.sql",
  "20260718170000_tv_device_credentials.sql",
  "20260724143000_govern_runtime_media_rights.sql",
  "20260724190000_privacy_safe_analytics_opt_in.sql",
  "20260724203000_admin_ticket_status_audit.sql",
  "20260724220000_mutable_record_optimistic_concurrency.sql",
  "20260724233000_admin_destructive_action_audit.sql",
  "20260728150000_harden_venue_order_checkin_scope.sql",
  "20260730143000_live_games_v2_authoritative_runtime.sql",
  "20260730152000_game_content_provenance_preview_gate.sql",
  "20260801153000_native_tv_realtime_identity.sql",
  "20260801154500_preserve_authenticated_jwt_role.sql",
];

const fail = (message) => {
  throw new Error(message);
};

const assert = (condition, message) => {
  if (!condition) fail(message);
};

const escapeRegExp = (value) =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const migrationEntries = await Promise.all(
  migrationNames.map(async (name) => {
    const url = new URL(`../../supabase/migrations/${name}`, import.meta.url);
    return [name, await readFile(url, "utf8")];
  }),
);
const migrations = new Map(migrationEntries);
const allSql = migrationEntries.map(([, sql]) => sql).join("\n");

assert(
  migrationNames.every((name, index) =>
    index === 0 || name.localeCompare(migrationNames[index - 1]) > 0
  ),
  "The local-only migration manifest must remain strictly chronological.",
);

assert(
  !/\b(?:create|alter)\s+extension\b[^;]*\bversion\b/i.test(allSql),
  "Do not pin extension VERSION clauses in these migrations.",
);

assert(
  !/\b(?:create|alter|drop)\s+(?:table|function|policy|trigger|schema)\s+(?:if\s+(?:not\s+)?exists\s+)?(?:auth|storage|realtime)\./i.test(
    allSql,
  ) &&
    !/\b(?:insert\s+into|update|delete\s+from)\s+(?:auth|storage|realtime)\./i.test(
      allSql,
    ),
  "The local-only migrations must not mutate protected auth, storage, or realtime schemas.",
);

const functionPattern =
  /create\s+or\s+replace\s+function\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)\s*\([\s\S]*?\)\s*returns[\s\S]*?\bas\s+\$\$[\s\S]*?\n\$\$;/gi;
let securityDefinerCount = 0;
for (const [migrationName, sql] of migrationEntries) {
  functionPattern.lastIndex = 0;
  for (const match of sql.matchAll(functionPattern)) {
    const [definition, qualifiedName] = match;
    if (!/\bsecurity\s+definer\b/i.test(definition)) continue;
    securityDefinerCount += 1;

    const header = definition.slice(0, definition.search(/\bas\s+\$\$/i));
    const searchPath = header.match(
      /\bset\s+search_path\s*(?:=|to)\s*([^\r\n]+)/i,
    );
    assert(
      searchPath != null,
      `${migrationName}: ${qualifiedName} needs a fixed search_path.`,
    );
    const pathEntries = searchPath[1]
      .replace(/["']/g, "")
      .split(",")
      .map((entry) => entry.trim().toLowerCase())
      .filter(Boolean);
    assert(
      pathEntries.at(-1) === "pg_temp",
      `${migrationName}: ${qualifiedName} must put pg_temp last in search_path.`,
    );

    const revokePattern = new RegExp(
      `revoke\\s+(?:all|execute)\\s+on\\s+function\\s+${escapeRegExp(qualifiedName)}` +
        `\\s*\\([^;]*\\)\\s*from\\s+public\\s*,\\s*anon\\s*,\\s*authenticated\\s*,\\s*service_role\\s*;`,
      "i",
    );
    assert(
      revokePattern.test(sql),
      `${migrationName}: ${qualifiedName} must reset PUBLIC, anon, authenticated, and service_role execute grants.`,
    );
  }
}
assert(securityDefinerCount > 0, "No SECURITY DEFINER functions were inspected.");

const governedContent = migrations.get(
  "20260730152000_game_content_provenance_preview_gate.sql",
);
assert(
  /alter\s+function\s+africlub_game\.admin_publish_question_pack\s*\(\s*bigint\s*,\s*text\s*,\s*uuid\[\]\s*,\s*text\s*,\s*uuid\s*\)\s+set\s+search_path\s*=\s*public\s*,\s*africlub_game\s*,\s*pg_temp\s*;/i.test(
    governedContent,
  ) &&
    /revoke\s+all\s+on\s+function\s+africlub_game\.admin_publish_question_pack\s*\(\s*bigint\s*,\s*text\s*,\s*uuid\[\]\s*,\s*text\s*,\s*uuid\s*\)\s+from\s+public\s*,\s*anon\s*,\s*authenticated\s*,\s*service_role\s*;/i.test(
      governedContent,
    ),
  "The legacy publication overload must put pg_temp last and remain revoked from every API role.",
);

const analytics = migrations.get(
  "20260724190000_privacy_safe_analytics_opt_in.sql",
);
assert(
  /alter\s+column\s+analytics_enabled\s+set\s+default\s+false/i.test(
    analytics,
  ),
  "Analytics must default to opt-out for new rows.",
);
assert(
  !/\bupdate\s+public\.user_privacy_settings\b/i.test(analytics),
  "The analytics migration must preserve existing consent choices.",
);
assert(
  /existing choices are preserved/i.test(analytics) &&
    /affirmative user action/i.test(analytics),
  "The analytics consent semantics must remain explicit in schema documentation.",
);

const lifecycle = migrations.get(
  "20260730143000_live_games_v2_authoritative_runtime.sql",
);
assert(
  /add\s+column\s+if\s+not\s+exists\s+lifecycle_phase\s+text\s*,/i.test(
    lifecycle,
  ) &&
    !/add\s+column\s+if\s+not\s+exists\s+lifecycle_phase\s+text\s+not\s+null\s+default/i.test(
      lifecycle,
    ),
  "Lifecycle phase must be nullable until the legacy-only backfill completes.",
);
assert(
  /update\s+africlub_game\.game_sessions\s+set\s+lifecycle_phase\s*=\s*case[\s\S]*?end\s+where\s+lifecycle_phase\s+is\s+null\s*;/i.test(
    lifecycle,
  ),
  "Lifecycle backfill must update only null legacy rows so replay preserves V2 phases.",
);
assert(
  /alter\s+column\s+lifecycle_phase\s+set\s+default\s+'draft'\s*,\s*alter\s+column\s+lifecycle_phase\s+set\s+not\s+null/i.test(
    lifecycle,
  ),
  "Lifecycle default and NOT NULL must be applied after the guarded backfill.",
);

const hook = migrations.get(
  "20260801154500_preserve_authenticated_jwt_role.sql",
);
assert(
  !/claims\s*->\s*'user_metadata'/i.test(hook) &&
    !/\buser_meta\b/i.test(hook),
  "The access-token hook must not derive authorization from user_metadata.",
);
assert(
  /app_meta\s*->>\s*'club_id'/i.test(hook) &&
    /app_meta\s*->>\s*'role'/i.test(hook),
  "The access-token hook must derive club_id and user_role from app_metadata.",
);
assert(
  /revoke\s+execute\s+on\s+function\s+public\.custom_access_token_hook\s*\(jsonb\)[\s\S]*?from\s+public\s*,\s*anon\s*,\s*authenticated\s*,\s*service_role\s*;/i.test(
    hook,
  ) &&
    /grant\s+execute\s+on\s+function\s+public\.custom_access_token_hook\s*\(jsonb\)[\s\S]*?to\s+supabase_auth_admin\s*;/i.test(
      hook,
    ),
  "The access-token hook must be executable only by supabase_auth_admin.",
);
assert(
  !/jsonb_set\s*\(\s*claims\s*,\s*'\{role\}'/i.test(hook),
  "The access-token hook must preserve the PostgreSQL JWT role claim.",
);

const requiredAclResetRelations = [
  "public.platform_route_registry",
  "public.platform_option_sets",
  "public.platform_option_values",
  "public.runtime_copy",
  "public.site_navigation_items",
  "public.site_search_items",
  "public.venue_governance_controls",
  "public.venue_staff_audit_events",
  "africlub_game.role_grants",
  "africlub_game.session_organizers",
  "africlub_game.display_assignments",
  "africlub_game.session_eligibility",
  "africlub_game.session_invitations",
  "africlub_game.transition_requests",
  "africlub_game.operation_requests",
  "africlub_game.game_events",
  "africlub_game.display_pairing_challenges",
  "africlub_game.display_bootstrap_challenges",
];
const relationResetBlocks = [
  ...allSql.matchAll(
    /revoke\s+all\s+on\s+(?:table\s+)?([\s\S]*?)\s+from\s+public\s*,\s*anon\s*,\s*authenticated\s*,\s*service_role\s*;/gi,
  ),
].map((match) => match[1].toLowerCase());
for (const relation of requiredAclResetRelations) {
  assert(
    relationResetBlocks.some((block) => block.includes(relation)),
    `${relation} must reset inherited Data API relation privileges.`,
  );
}

assert(
  /grant\s+select\s+on\s+table[\s\S]*?public\.venue_governance_controls[\s\S]*?to\s+anon\s*,\s*authenticated\s*;/i.test(
    migrations.get("20260703223439_dynamic_runtime_registries.sql"),
  ) &&
    /grant\s+select\s*,\s*insert\s*,\s*update\s*,\s*delete\s+on\s+table[\s\S]*?public\.venue_governance_controls[\s\S]*?to\s+service_role\s*;/i.test(
      migrations.get("20260703223439_dynamic_runtime_registries.sql"),
    ),
  "Runtime registries must grant scoped client access and the exact server-admin DML set.",
);
assert(
  /grant\s+select\s+on\s+table[\s\S]*?africlub_game\.display_pairing_challenges[\s\S]*?to\s+authenticated\s*;/i.test(
    lifecycle,
  ) &&
    !/grant\s+(?:all|insert|update|delete)[^;]*africlub_game\.display_bootstrap_challenges/i.test(
      lifecycle,
    ),
  "Live-game Data API relations must be read-scoped and bootstrap storage RPC-only.",
);

console.log(
  `Validated ${migrationNames.length} local-only migrations, ${securityDefinerCount} SECURITY DEFINER functions, consent preservation, replay safety, protected-schema boundaries, and explicit ACL resets.`,
);
