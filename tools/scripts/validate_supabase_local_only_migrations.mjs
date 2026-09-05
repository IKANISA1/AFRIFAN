import { readdir, readFile } from 'node:fs/promises';

const fail = (message) => {
  throw new Error(message);
};

const assert = (condition, message) => {
  if (!condition) fail(message);
};

const migrationsUrl = new URL('../../supabase/migrations/', import.meta.url);
const migrationNames = (await readdir(migrationsUrl))
  .filter((name) => name.endsWith('.sql'))
  .sort();

assert(
  migrationNames.length >= 1,
  'The reproducible baseline is missing.',
);

const baselineName = '20260820080202_football_only_baseline.sql';
assert(
  migrationNames[0] === baselineName,
  `Unexpected baseline name: ${migrationNames[0] ?? '<missing>'}.`,
);

const versions = new Set();
for (const name of migrationNames) {
  assert(/^\d{14}_[a-z0-9_]+\.sql$/.test(name), `Invalid migration name: ${name}.`);
  const version = name.slice(0, 14);
  assert(!versions.has(version), `Duplicate migration version: ${version}.`);
  versions.add(version);
}

const baseline = await readFile(
  new URL(`../../supabase/migrations/${baselineName}`, import.meta.url),
  'utf8',
);
const seed = await readFile(
  new URL('../../supabase/seed.sql', import.meta.url),
  'utf8',
);

assert(
  !/\b(?:create|alter)\s+extension\b[^;]*\bversion\b/i.test(baseline),
  'Do not pin extension VERSION clauses in the baseline.',
);
assert(
  /create schema if not exists "football"/i.test(baseline),
  'The football schema is missing from the baseline.',
);
assert(
  /create table if not exists "football"\."predictions"/i.test(baseline) &&
    /create table if not exists "football"\."prediction_markets"/i.test(
      baseline,
    ) &&
    /create or replace function "public"\."prediction_place"/i.test(baseline),
  'Prediction storage or its authoritative placement function is missing.',
);
assert(
  (baseline.match(/enable row level security/gi) ?? []).length >= 50,
  'The baseline contains too few explicit RLS enablements.',
);
assert(
  /revoke truncate, references, trigger, maintain\s+on all tables in schema public, football\s+from anon, authenticated;/i.test(
    baseline,
  ),
  'The baseline must revoke inherited dangerous table privileges.',
);
assert(
  /alter default privileges for role postgres in schema public\s+revoke truncate, references, trigger, maintain/i.test(
    baseline,
  ) &&
    /alter default privileges for role postgres in schema football\s+revoke truncate, references, trigger, maintain/i.test(
      baseline,
    ),
  'The baseline must harden future public and football table privileges.',
);
assert(
  !/grant\s+all\s+on\s+(?:table\s+)?[^;]+\s+to\s+(?:anon|authenticated)\b/i.test(
    baseline,
  ),
  'Client roles must not receive table-level ALL privileges.',
);
assert(
  /revoke all on function "public"\."custom_access_token_hook"\("event" "jsonb"\) from public;/i.test(
    baseline,
  ) &&
    /grant all on function "public"\."custom_access_token_hook"\("event" "jsonb"\) to "supabase_auth_admin";/i.test(
      baseline,
    ),
  'The access-token hook execution boundary is missing.',
);

assert(seed.length > 1_000_000, 'The governed catalog seed is unexpectedly small.');
assert(!/^copy\s/imu.test(seed), 'Seed data must use replayable inserts, not COPY.');
assert(
  !/insert into\s+"auth"\."users"/i.test(seed),
  'Seed data must not create authentication users.',
);
assert(
  /insert into\s+"football"\."competitions"/i.test(seed) &&
    /insert into\s+"football"\."fixtures"/i.test(seed) &&
    /insert into\s+"football"\."prediction_markets"/i.test(seed),
  'The football catalog seed is incomplete.',
);
assert(
  /insert into storage\.buckets/i.test(seed),
  'Storage bucket configuration omitted by schema squashing is missing.',
);
for (const job of [
  'redact-momo-sms-artifacts-daily',
  'check-momo-sms-migration-safety-daily',
  'purge_edge_function_rate_events',
  'settle-prediction-notifications',
  'daily-fixture-sync',
]) {
  assert(seed.includes(job), `Scheduled job is missing from the seed: ${job}.`);
}

console.log(
  `Validated ${baselineName} and ${migrationNames.length - 1} forward migration filenames, baseline football/prediction preservation, RLS/ACL hardening, and replayable seed data. Run the full migration chain and pgTAP suite in an isolated database to validate resulting behavior.`,
);
