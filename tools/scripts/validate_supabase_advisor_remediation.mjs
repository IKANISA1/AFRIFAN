import { readFileSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const DEFAULT_MIGRATION = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../supabase/migrations/20260808210441_harden_advisor_paths_and_recent_fk_indexes.sql",
);
const FIXTURE_BASELINE_MIGRATION = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../supabase/migrations/20260415130000_fixtures_unique_constraint_and_calendar.sql",
);

export const EXPECTED_FUNCTION_PATHS = new Map([
  ["africlub_game.current_club_id()", []],
  ["africlub_game.normalize_question_prompt(text)", []],
  [
    "football._seed_fixture(text,text,text,text,timestamp with time zone,text,text)",
    [],
  ],
  ["football._seed_season(text,text,integer,integer)", []],
  ["football._seed_team(text,text,text,integer,text)", []],
  ["football.auto_lock_fixture_markets()", []],
  ["football.kickoff_date(timestamp with time zone)", []],
  ["football.prediction_fixture_club_id(uuid)", []],
  ["football.prediction_seed_outcomes(text,jsonb)", []],
  ["public.canonicalize_platform_feature_key(text)", []],
  ["public.compat_parse_partner_id(text)", []],
  ["public.fixtures_calendar(date,date,text,text,integer)", ["public", "pg_temp"]],
  ["public.fixtures_date_summary(date,date,text)", ["public", "pg_temp"]],
  ["public.populate_event_club_scope()", []],
  // This 27th entry was not one of the 26 live advisor findings. It repairs
  // local baseline replay drift so a full reset reaches the same fixed-path
  // invariant already present in production.
  ["public.populate_group_message_defaults()", []],
  ["public.refresh_match_ticket_sales()", []],
  ["public.resolve_fan_tier(integer)", []],
  ["public.set_updated_at()", []],
  ["public.sync_fan_club_member_scope()", []],
  ["public.sync_fan_membership_defaults()", []],
  ["public.sync_group_member_count()", []],
  ["public.sync_initiative_contribution_scope()", []],
  ["public.sync_partner_club_columns()", []],
  ["public.sync_ticket_scope()", []],
  ["public.update_fan_club_member_count()", []],
  ["public.update_group_member_count()", []],
  ["public.update_group_totals()", []],
]);

export const EXPECTED_FK_INDEXES = new Map([
  [
    "idx_display_assignments_assigned_by",
    ["africlub_game.display_assignments", "assigned_by"],
  ],
  [
    "idx_display_assignments_club_id",
    ["africlub_game.display_assignments", "club_id"],
  ],
  [
    "idx_display_bootstrap_challenges_consumed_by",
    ["africlub_game.display_bootstrap_challenges", "consumed_by"],
  ],
  [
    "idx_display_bootstrap_challenges_display_id",
    ["africlub_game.display_bootstrap_challenges", "display_id"],
  ],
  [
    "idx_display_pairing_challenges_club_id",
    ["africlub_game.display_pairing_challenges", "club_id"],
  ],
  [
    "idx_display_pairing_challenges_consumed_by",
    ["africlub_game.display_pairing_challenges", "consumed_by"],
  ],
  [
    "idx_display_pairing_challenges_display_id",
    ["africlub_game.display_pairing_challenges", "display_id"],
  ],
  ["idx_game_events_actor_id", ["africlub_game.game_events", "actor_id"]],
  ["idx_game_events_club_id", ["africlub_game.game_events", "club_id"]],
  [
    "idx_operation_requests_club_id",
    ["africlub_game.operation_requests", "club_id"],
  ],
  ["idx_role_grants_granted_by", ["africlub_game.role_grants", "granted_by"]],
  ["idx_role_grants_user_id", ["africlub_game.role_grants", "user_id"]],
  ["idx_role_grants_venue_id", ["africlub_game.role_grants", "venue_id"]],
  [
    "idx_session_eligibility_club_id",
    ["africlub_game.session_eligibility", "club_id"],
  ],
  [
    "idx_session_eligibility_created_by",
    ["africlub_game.session_eligibility", "created_by"],
  ],
  [
    "idx_session_invitations_club_id",
    ["africlub_game.session_invitations", "club_id"],
  ],
  [
    "idx_session_invitations_invited_by",
    ["africlub_game.session_invitations", "invited_by"],
  ],
  [
    "idx_session_invitations_user_id",
    ["africlub_game.session_invitations", "user_id"],
  ],
  [
    "idx_session_organizers_assigned_by",
    ["africlub_game.session_organizers", "assigned_by"],
  ],
  [
    "idx_session_organizers_club_id",
    ["africlub_game.session_organizers", "club_id"],
  ],
  [
    "idx_session_organizers_user_id",
    ["africlub_game.session_organizers", "user_id"],
  ],
  [
    "idx_transition_requests_actor_id",
    ["africlub_game.transition_requests", "actor_id"],
  ],
  [
    "idx_transition_requests_club_id",
    ["africlub_game.transition_requests", "club_id"],
  ],
  ["idx_tv_devices_owner_user_id", ["africlub_game.tv_devices", "owner_user_id"]],
  ["idx_tv_devices_venue_id", ["africlub_game.tv_devices", "venue_id"]],
  [
    "idx_venue_staff_audit_events_venue_id",
    ["public.venue_staff_audit_events", "venue_id"],
  ],
]);

const FIXTURE_FUNCTIONS = new Set([
  "public.fixtures_calendar(date,date,text,text,integer)",
  "public.fixtures_date_summary(date,date,text)",
]);
const REQUIRED_EXECUTE_REVOKE_ROLES = new Set([
  "public",
  "anon",
  "authenticated",
  "service_role",
]);

const fail = (message) => {
  throw new Error(message);
};

const normalizeIdentifier = (value) =>
  value
    .trim()
    .split(".")
    .map((part) => part.trim().replace(/^"|"$/g, "").toLowerCase())
    .join(".");

const normalizeType = (value) =>
  value
    .trim()
    .replace(/\s+/g, " ")
    .toLowerCase()
    .replace(/^"|"$/g, "")
    .replace(/\btimestamptz\b/g, "timestamp with time zone")
    .replace(/\b(?:int|int4)$/, "integer");

const splitCommaList = (value) => {
  const parts = [];
  let start = 0;
  let depth = 0;
  let quote = null;
  for (let index = 0; index < value.length; index += 1) {
    const char = value[index];
    if (quote != null) {
      if (char === quote && value[index + 1] === quote) {
        index += 1;
      } else if (char === quote) {
        quote = null;
      }
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
    } else if (char === "(") {
      depth += 1;
    } else if (char === ")") {
      depth -= 1;
    } else if (char === "," && depth === 0) {
      parts.push(value.slice(start, index).trim());
      start = index + 1;
    }
  }
  parts.push(value.slice(start).trim());
  return parts.filter(Boolean);
};

const normalizeIdentityArguments = (value) =>
  splitCommaList(value).map(normalizeType).join(",");

const normalizeSearchPath = (value) => {
  const expression = value.trim();
  if (expression === "''") return [];
  return splitCommaList(expression).map((entry) =>
    entry.trim().replace(/^"|"$/g, "").toLowerCase()
  );
};

const sameList = (left, right) =>
  left.length === right.length && left.every((entry, index) => entry === right[index]);

export function splitSqlStatements(sql) {
  const statements = [];
  let current = "";
  let state = "normal";
  let blockDepth = 0;
  let dollarTag = null;

  for (let index = 0; index < sql.length; index += 1) {
    const char = sql[index];
    const next = sql[index + 1];

    if (state === "line-comment") {
      if (char === "\n") {
        current += "\n";
        state = "normal";
      }
      continue;
    }
    if (state === "block-comment") {
      if (char === "/" && next === "*") {
        blockDepth += 1;
        index += 1;
      } else if (char === "*" && next === "/") {
        blockDepth -= 1;
        index += 1;
        if (blockDepth === 0) state = "normal";
      } else if (char === "\n") {
        current += "\n";
      }
      continue;
    }
    if (state === "single-quote" || state === "double-quote") {
      current += char;
      const quote = state === "single-quote" ? "'" : '"';
      if (char === quote && next === quote) {
        current += next;
        index += 1;
      } else if (char === quote) {
        state = "normal";
      }
      continue;
    }
    if (state === "dollar-quote") {
      if (sql.startsWith(dollarTag, index)) {
        current += dollarTag;
        index += dollarTag.length - 1;
        state = "normal";
      } else {
        current += char;
      }
      continue;
    }

    if (char === "-" && next === "-") {
      state = "line-comment";
      index += 1;
    } else if (char === "/" && next === "*") {
      state = "block-comment";
      blockDepth = 1;
      index += 1;
    } else if (char === "'") {
      current += char;
      state = "single-quote";
    } else if (char === '"') {
      current += char;
      state = "double-quote";
    } else if (char === "$") {
      const tag = sql.slice(index).match(/^\$(?:[a-z_][a-z0-9_]*)?\$/i)?.[0];
      if (tag == null) {
        current += char;
      } else {
        current += tag;
        index += tag.length - 1;
        dollarTag = tag;
        state = "dollar-quote";
      }
    } else if (char === ";") {
      if (current.trim() !== "") statements.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }

  if (state !== "normal" && state !== "line-comment") {
    fail(`Migration contains an unterminated ${state.replaceAll("-", " ")}.`);
  }
  if (current.trim() !== "") statements.push(current.trim());
  return statements;
}

const assertNoProtectedSchemaDdl = (statement) => {
  const protectedSchema = String.raw`(?:"?(?:auth|storage|realtime)"?)`;
  const qualifiedTarget = `${protectedSchema}\\s*\\.`;
  const objectTarget = new RegExp(
    String.raw`^(?:create(?:\s+or\s+replace)?|alter|drop)\s+(?:table|view|materialized\s+view|function|procedure|type|domain|sequence|index)\s+(?:if\s+(?:not\s+)?exists\s+)?(?:only\s+)?${qualifiedTarget}`,
    "i",
  );
  const schemaTarget = new RegExp(
    String.raw`^(?:create|alter|drop)\s+schema\s+(?:if\s+(?:not\s+)?exists\s+)?${protectedSchema}(?:\s|$)`,
    "i",
  );
  const onTarget = new RegExp(
    String.raw`^(?:create|alter|drop|comment|grant|revoke)[\s\S]*\bon\s+(?:table\s+|function\s+|sequence\s+|type\s+)?${qualifiedTarget}`,
    "i",
  );
  const truncateTarget = new RegExp(
    String.raw`^truncate\s+(?:table\s+)?(?:only\s+)?${qualifiedTarget}`,
    "i",
  );
  if (
    objectTarget.test(statement) ||
    schemaTarget.test(statement) ||
    onTarget.test(statement) ||
    truncateTarget.test(statement)
  ) {
    fail("Migration must not apply DDL or privilege mutations to protected auth, storage, or realtime schemas.");
  }
};

const parseAlterFunction = (statement) => {
  const match = statement.match(
    /^alter\s+function\s+((?:"[^"]+"|[a-z_][a-z0-9_]*)\s*\.\s*(?:"[^"]+"|[a-z_][a-z0-9_]*))\s*\(([\s\S]*?)\)\s+set\s+search_path\s*(?:=|to)\s*([\s\S]+)$/i,
  );
  if (match == null) fail(`Unexpected ALTER FUNCTION declaration: ${statement}`);
  return {
    signature: `${normalizeIdentifier(match[1])}(${normalizeIdentityArguments(match[2])})`,
    searchPath: normalizeSearchPath(match[3]),
  };
};

const parseIndex = (statement) => {
  const match = statement.match(
    /^create\s+index\s+if\s+not\s+exists\s+((?:"[^"]+"|[a-z_][a-z0-9_]*))\s+on\s+((?:"[^"]+"|[a-z_][a-z0-9_]*)\s*\.\s*(?:"[^"]+"|[a-z_][a-z0-9_]*))\s*\(\s*((?:"[^"]+"|[a-z_][a-z0-9_]*))\s*\)$/i,
  );
  if (match == null) {
    fail(`Every advisor FK index must use the exact CREATE INDEX IF NOT EXISTS single-column form: ${statement}`);
  }
  return {
    name: normalizeIdentifier(match[1]),
    relation: normalizeIdentifier(match[2]),
    column: normalizeIdentifier(match[3]),
  };
};

const parseFixtureFunctionDefinition = (statement) => {
  const match = statement.match(
    /^create\s+or\s+replace\s+function\s+((?:"[^"]+"|[a-z_][a-z0-9_]*)\s*\.\s*(?:"[^"]+"|[a-z_][a-z0-9_]*))\s*\(([\s\S]*?)\)\s*returns\b/i,
  );
  if (match == null) fail(`Unexpected function definition: ${statement}`);
  const functionName = normalizeIdentifier(match[1]);
  const expectedSignature = [...FIXTURE_FUNCTIONS].find((entry) =>
    entry.startsWith(`${functionName}(`)
  );
  if (expectedSignature == null) {
    fail(`Unexpected function definition: ${functionName}.`);
  }
  const expectedTypes = expectedSignature
    .slice(expectedSignature.indexOf("(") + 1, -1)
    .split(",");
  const declaredArguments = splitCommaList(match[2]);
  if (declaredArguments.length !== expectedTypes.length) {
    fail(`${functionName} qualified-body replacement has the wrong function identity arguments.`);
  }
  for (const [index, declaredArgument] of declaredArguments.entries()) {
    const withoutDefault = declaredArgument
      .replace(/\s+default\s+[\s\S]*$/i, "")
      .replace(/\s*=\s*[\s\S]*$/, "")
      .trim();
    const normalizedArgument = normalizeType(withoutDefault);
    const expectedType = expectedTypes[index];
    const namedArgumentPattern = new RegExp(
      `^(?:"[^"]+"|[a-z_][a-z0-9_]*)\\s+${expectedType.replaceAll(" ", "\\s+")}$`,
      "i",
    );
    if (normalizedArgument !== expectedType && !namedArgumentPattern.test(normalizedArgument)) {
      fail(`${functionName} qualified-body replacement changes argument ${index + 1} from ${expectedType}.`);
    }
  }
  return { functionName, signature: expectedSignature };
};

const validateQualifiedFixtureBody = (statement, functionName) => {
  const bodyMatch = statement.match(/\bas\s+(\$(?:[a-z_][a-z0-9_]*)?\$)([\s\S]*)\1\s*$/i);
  if (bodyMatch == null) {
    fail(`${functionName} needs a dollar-quoted SQL body before it can use an empty search_path.`);
  }
  const body = bodyMatch[2];
  if (!/\b(?:from|join)\s+public\.prediction_supported_fixtures_catalog\b/i.test(body)) {
    fail(`${functionName} may use an empty search_path only with a schema-qualified public.prediction_supported_fixtures_catalog body.`);
  }
  if (/\b(?:from|join)\s+prediction_supported_fixtures_catalog\b/i.test(body)) {
    fail(`${functionName} contains an unqualified prediction_supported_fixtures_catalog reference.`);
  }

  const baselineDefinition = splitSqlStatements(
    readFileSync(FIXTURE_BASELINE_MIGRATION, "utf8"),
  ).find((candidate) =>
    new RegExp(
      `^create\\s+or\\s+replace\\s+function\\s+${functionName.replace(".", "\\.")}\\s*\\(`,
      "i",
    ).test(candidate)
  );
  if (baselineDefinition == null) {
    fail(`${functionName} has no repository baseline body to validate.`);
  }
  const expectedQualifiedDefinition = baselineDefinition.replace(
    /\b(from|join)\s+prediction_supported_fixtures_catalog\b/gi,
    "$1 public.prediction_supported_fixtures_catalog",
  );
  const canonicalizeDefinition = (value) => {
    let result = "";
    let quote = null;
    for (let index = 0; index < value.length; index += 1) {
      const char = value[index];
      if (quote != null) {
        result += char;
        if (char === quote && value[index + 1] === quote) {
          result += value[index + 1];
          index += 1;
        } else if (char === quote) {
          quote = null;
        }
      } else if (char === "'" || char === '"') {
        quote = char;
        result += char;
      } else if (!/\s/.test(char)) {
        result += char.toLowerCase();
      }
    }
    return result;
  };
  if (
    canonicalizeDefinition(statement) !==
    canonicalizeDefinition(expectedQualifiedDefinition)
  ) {
    fail(`${functionName} empty-path replacement must preserve the exact repository body while qualifying its public relation.`);
  }
};

const validateExecuteRevoke = (statement) => {
  const match = statement.match(
    /^revoke\s+(execute|all(?:\s+privileges)?)\s+on\s+function\s+football\.auto_lock_fixture_markets\s*\(\s*\)\s+from\s+([\s\S]+)$/i,
  );
  if (match == null) {
    fail(`Unexpected REVOKE declaration: ${statement}`);
  }
  const roles = splitCommaList(match[2]).map(normalizeIdentifier);
  if (new Set(roles).size !== roles.length) {
    fail("football.auto_lock_fixture_markets EXECUTE revoke contains duplicate roles.");
  }
  const actualRoles = new Set(roles);
  if (
    actualRoles.size !== REQUIRED_EXECUTE_REVOKE_ROLES.size ||
    [...REQUIRED_EXECUTE_REVOKE_ROLES].some((role) => !actualRoles.has(role))
  ) {
    fail("football.auto_lock_fixture_markets EXECUTE must be revoked from exactly PUBLIC, anon, authenticated, and service_role.");
  }
};

export function validateAdvisorRemediationSql(sql) {
  const statements = splitSqlStatements(sql);
  const functions = new Map();
  const indexes = new Map();
  const fixtureDefinitions = new Map();
  let executeRevokeCount = 0;

  for (const [statementIndex, statement] of statements.entries()) {
    assertNoProtectedSchemaDdl(statement);

    if (/^alter\s+function\b/i.test(statement)) {
      const declaration = parseAlterFunction(statement);
      if (!EXPECTED_FUNCTION_PATHS.has(declaration.signature)) {
        fail(`Unexpected advisor function declaration: ${declaration.signature}.`);
      }
      if (functions.has(declaration.signature)) {
        fail(`Duplicate advisor function declaration: ${declaration.signature}.`);
      }
      const requiredPath = EXPECTED_FUNCTION_PATHS.get(declaration.signature);
      const fixtureUsesStrictEmptyPath =
        FIXTURE_FUNCTIONS.has(declaration.signature) && declaration.searchPath.length === 0;
      if (!sameList(declaration.searchPath, requiredPath) && !fixtureUsesStrictEmptyPath) {
        fail(
          `${declaration.signature} has search_path ${JSON.stringify(declaration.searchPath)}; expected ${JSON.stringify(requiredPath)}.`,
        );
      }
      functions.set(declaration.signature, {
        ...declaration,
        statementIndex,
      });
      continue;
    }

    if (/^create\s+(?:unique\s+)?index\b/i.test(statement)) {
      const declaration = parseIndex(statement);
      const expected = EXPECTED_FK_INDEXES.get(declaration.name);
      if (expected == null) {
        fail(`Unexpected advisor FK index declaration: ${declaration.name}.`);
      }
      if (indexes.has(declaration.name)) {
        fail(`Duplicate advisor FK index declaration: ${declaration.name}.`);
      }
      if (declaration.relation !== expected[0] || declaration.column !== expected[1]) {
        fail(
          `${declaration.name} targets ${declaration.relation}(${declaration.column}); expected ${expected[0]}(${expected[1]}).`,
        );
      }
      indexes.set(declaration.name, declaration);
      continue;
    }

    if (/^revoke\b/i.test(statement)) {
      executeRevokeCount += 1;
      if (executeRevokeCount > 1) {
        fail("Duplicate football.auto_lock_fixture_markets EXECUTE revoke declaration.");
      }
      validateExecuteRevoke(statement);
      continue;
    }

    if (/^grant\b/i.test(statement)) {
      if (/\bfootball\.auto_lock_fixture_markets\s*\(\s*\)/i.test(statement)) {
        fail("Migration must not grant football.auto_lock_fixture_markets to an API role after revocation.");
      }
      fail(`Unexpected GRANT declaration: ${statement}`);
    }

    if (/^create\s+or\s+replace\s+function\b/i.test(statement)) {
      const { functionName } = parseFixtureFunctionDefinition(statement);
      if (fixtureDefinitions.has(functionName)) {
        fail(`Duplicate qualified fixture function definition: ${functionName}.`);
      }
      validateQualifiedFixtureBody(statement, functionName);
      fixtureDefinitions.set(functionName, statementIndex);
      continue;
    }

    fail(`Unexpected SQL statement in advisor remediation: ${statement}`);
  }

  for (const signature of EXPECTED_FUNCTION_PATHS.keys()) {
    if (!functions.has(signature)) fail(`Missing advisor function declaration: ${signature}.`);
  }
  for (const [signature, declaration] of functions) {
    if (!FIXTURE_FUNCTIONS.has(signature) || declaration.searchPath.length !== 0) continue;
    const functionName = signature.slice(0, signature.indexOf("("));
    const definitionIndex = fixtureDefinitions.get(functionName);
    if (definitionIndex == null) {
      fail(`${signature} may use an empty search_path only when this migration installs its schema-qualified body.`);
    }
    if (definitionIndex > declaration.statementIndex) {
      fail(`${functionName} must install its qualified body before the final empty search_path ALTER FUNCTION declaration.`);
    }
  }
  for (const functionName of fixtureDefinitions.keys()) {
    const signature = [...FIXTURE_FUNCTIONS].find((entry) => entry.startsWith(`${functionName}(`));
    if (functions.get(signature)?.searchPath.length !== 0) {
      fail(`${functionName} has an unexpected body replacement without the stricter empty search_path.`);
    }
  }
  for (const indexName of EXPECTED_FK_INDEXES.keys()) {
    if (!indexes.has(indexName)) fail(`Missing advisor FK index declaration: ${indexName}.`);
  }
  if (executeRevokeCount !== 1) {
    fail("Missing football.auto_lock_fixture_markets EXECUTE revoke declaration.");
  }

  return {
    statementCount: statements.length,
    functionCount: functions.size,
    indexCount: indexes.size,
    executeRevokeCount,
    qualifiedFixtureBodyCount: fixtureDefinitions.size,
  };
}

async function main() {
  const migrationPath = process.argv[2] == null
    ? DEFAULT_MIGRATION
    : path.resolve(process.cwd(), process.argv[2]);
  const sql = await readFile(migrationPath, "utf8");
  const result = validateAdvisorRemediationSql(sql);
  console.log(
    `Validated 26 live advisor function paths plus ${result.functionCount - 26} baseline-replay drift repair, ${result.executeRevokeCount} trigger execute ACL reset, ${result.indexCount} exact FK indexes, and zero protected-schema or unexpected declarations in ${migrationPath}.`,
  );
}

if (process.argv[1] != null && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  await main();
}
