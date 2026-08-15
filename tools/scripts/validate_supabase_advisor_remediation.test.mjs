import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  EXPECTED_FK_INDEXES,
  EXPECTED_FUNCTION_PATHS,
  splitSqlStatements,
  validateAdvisorRemediationSql,
} from "./validate_supabase_advisor_remediation.mjs";

const migrationUrl = new URL(
  "../../supabase/migrations/20260808210441_harden_advisor_paths_and_recent_fk_indexes.sql",
  import.meta.url,
);
const validSql = await readFile(migrationUrl, "utf8");
const validStatements = splitSqlStatements(validSql);
const fixtureBaselineSql = await readFile(
  new URL(
    "../../supabase/migrations/20260415130000_fixtures_unique_constraint_and_calendar.sql",
    import.meta.url,
  ),
  "utf8",
);

const render = (statements) => `${statements.join(";\n\n")};\n`;
const expectFailure = (sql, expectedMessage) => {
  assert.throws(
    () => validateAdvisorRemediationSql(sql),
    (error) => {
      assert.match(error.message, expectedMessage);
      return true;
    },
  );
};
const functionName = (signature) => signature.slice(0, signature.indexOf("("));
const functionStatement = (name) =>
  validStatements.find((statement) =>
    statement.toLowerCase().startsWith(`alter function ${name.toLowerCase()}(`)
  );
const indexStatement = (name) =>
  validStatements.find((statement) =>
    new RegExp(`^create\\s+index\\s+if\\s+not\\s+exists\\s+${name}\\b`, "i").test(
      statement,
    )
  );

test("accepts the exact checked-in remediation contract", () => {
  assert.deepEqual(validateAdvisorRemediationSql(validSql), {
    statementCount: 54,
    functionCount: 25,
    indexCount: 1,
    executeRevokeCount: 1,
    qualifiedFixtureBodyCount: 0,
    retiredSchemaFunctionCount: 2,
    retiredSchemaIndexCount: 25,
  });
});

test("requires every active function path repair", () => {
  assert.equal(EXPECTED_FUNCTION_PATHS.size, 25);
  for (const signature of EXPECTED_FUNCTION_PATHS.keys()) {
    const name = functionName(signature);
    const declaration = functionStatement(name);
    assert.ok(declaration, `test fixture is missing ${signature}`);
    expectFailure(
      render(validStatements.filter((statement) => statement !== declaration)),
      /Missing advisor function declaration/,
    );
  }
});

test("rejects duplicate, unexpected, and mutable function path declarations", () => {
  const declaration = functionStatement("public.set_updated_at");
  expectFailure(render([...validStatements, declaration]), /Duplicate advisor function declaration/);
  expectFailure(
    `${validSql}\nalter function public.unexpected_advisor_function() set search_path = '';\n`,
    /Unexpected advisor function declaration/,
  );
  expectFailure(
    validSql.replace(
      /alter function public\.set_updated_at\(\)\s+set search_path = '';/i,
      "alter function public.set_updated_at() set search_path = public, pg_temp;",
    ),
    /public\.set_updated_at\(\) has search_path/,
  );
});

test("keeps pg_temp last for fixture RPCs with their current unqualified public body", () => {
  expectFailure(
    validSql.replace(
      /alter function public\.fixtures_calendar\(([^;]+?)\)\s+set search_path = public, pg_temp;/i,
      "alter function public.fixtures_calendar($1) set search_path = pg_temp, public;",
    ),
    /public\.fixtures_calendar.*has search_path/,
  );
  expectFailure(
    validSql.replace(
      /alter function public\.fixtures_date_summary\(([^;]+?)\)\s+set search_path = public, pg_temp;/i,
      "alter function public.fixtures_date_summary($1) set search_path = public;",
    ),
    /public\.fixtures_date_summary.*has search_path/,
  );
});

test("accepts the stricter empty fixture path only with the exact qualified body installed first", () => {
  const qualifiedCalendarBody = splitSqlStatements(fixtureBaselineSql)
    .find((statement) =>
      /^create\s+or\s+replace\s+function\s+public\.fixtures_calendar\s*\(/i.test(
        statement,
      )
    )
    .replace(
      /\b(from|join)\s+prediction_supported_fixtures_catalog\b/gi,
      "$1 public.prediction_supported_fixtures_catalog",
    );
  const statements = validStatements.map((statement) =>
    statement === functionStatement("public.fixtures_calendar")
      ? statement.replace(/public\s*,\s*pg_temp$/i, "''")
      : statement
  );
  const alterIndex = statements.findIndex((statement) =>
    statement.toLowerCase().startsWith("alter function public.fixtures_calendar(")
  );
  statements.splice(alterIndex, 0, qualifiedCalendarBody);
  const result = validateAdvisorRemediationSql(render(statements));
  assert.equal(result.qualifiedFixtureBodyCount, 1);

  expectFailure(
    render(statements.filter((statement) => statement !== qualifiedCalendarBody)),
    /may use an empty search_path only when this migration installs its schema-qualified body/,
  );
  expectFailure(
    render(
      statements.map((statement) =>
        statement === qualifiedCalendarBody
          ? statement.replace(
              "public.prediction_supported_fixtures_catalog f",
              "prediction_supported_fixtures_catalog f",
            )
          : statement
      ),
    ),
    /schema-qualified public\.prediction_supported_fixtures_catalog body/,
  );
  expectFailure(
    render(
      statements.map((statement) =>
        statement === qualifiedCalendarBody
          ? statement.replace("p_limit      int", "p_limit      bigint")
          : statement
      ),
    ),
    /qualified-body replacement changes argument 5 from integer|must preserve the exact repository body/,
  );
  expectFailure(
    render(
      statements.map((statement) =>
        statement === qualifiedCalendarBody
          ? statement.replace("ORDER BY f.kickoff_at ASC", "ORDER BY f.kickoff_at DESC")
          : statement
      ),
    ),
    /must preserve the exact repository body/,
  );
});

test("requires one exact execute revoke and rejects a later grant", () => {
  const revoke = validStatements.find((statement) => /^revoke\s/i.test(statement));
  expectFailure(
    render(validStatements.filter((statement) => statement !== revoke)),
    /Missing football\.auto_lock_fixture_markets EXECUTE revoke/,
  );
  expectFailure(
    validSql.replace(/,\s*service_role\s*;/i, ";"),
    /must be revoked from exactly PUBLIC, anon, authenticated, and service_role/,
  );
  expectFailure(render([...validStatements, revoke]), /Duplicate.*EXECUTE revoke/);
  expectFailure(
    `${validSql}\ngrant execute on function football.auto_lock_fixture_markets() to authenticated;\n`,
    /must not grant football\.auto_lock_fixture_markets/,
  );
});

test("requires every active IF NOT EXISTS FK index", () => {
  assert.equal(EXPECTED_FK_INDEXES.size, 1);
  for (const indexName of EXPECTED_FK_INDEXES.keys()) {
    const declaration = indexStatement(indexName);
    assert.ok(declaration, `test fixture is missing ${indexName}`);
    expectFailure(
      render(validStatements.filter((statement) => statement !== declaration)),
      /Missing advisor FK index declaration/,
    );
  }

  const firstIndexName = EXPECTED_FK_INDEXES.keys().next().value;
  const firstIndex = indexStatement(firstIndexName);
  expectFailure(render([...validStatements, firstIndex]), /Duplicate advisor FK index/);
  expectFailure(
    `${validSql}\ncreate index if not exists idx_unexpected on public.venue_staff_audit_events (venue_id);\n`,
    /Unexpected advisor FK index declaration/,
  );
  expectFailure(
    validSql.replace(
      "create index if not exists idx_venue_staff_audit_events_venue_id",
      "create index idx_venue_staff_audit_events_venue_id",
    ),
    /must use the exact CREATE INDEX IF NOT EXISTS single-column form/,
  );
  expectFailure(
    validSql.replace(
      "on public.venue_staff_audit_events (venue_id);",
      "on public.venue_staff_audit_events (club_id);",
    ),
    /targets public\.venue_staff_audit_events\(club_id\)/,
  );
});

test("rejects protected-schema DDL and ignores commented-out text", () => {
  for (const protectedStatement of [
    "alter table auth.users add column unsafe text",
    "create index if not exists unsafe_storage_idx on storage.objects (owner_id)",
    "drop schema realtime",
  ]) {
    expectFailure(
      `${validSql}\n${protectedStatement};\n`,
      /must not apply DDL or privilege mutations to protected auth, storage, or realtime schemas/,
    );
  }

  const result = validateAdvisorRemediationSql(
    `${validSql}\n-- alter table auth.users add column ignored text;\n/* create index ignored on storage.objects (id); */\n`,
  );
  assert.equal(result.functionCount, 25);
  assert.equal(result.indexCount, 1);
});

test("rejects arbitrary statements and malformed SQL instead of silently skipping them", () => {
  expectFailure(`${validSql}\nselect 1;\n`, /Unexpected SQL statement/);
  expectFailure(`${validSql}\n/* unterminated`, /unterminated block comment/);
});
