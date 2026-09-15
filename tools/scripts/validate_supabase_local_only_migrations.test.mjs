import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { appendFileSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const baseline = '20260820080202_football_only_baseline.sql';
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'africlub-migrations-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(join(root, 'tools/scripts'), { recursive: true });
  mkdirSync(join(root, 'supabase/migrations'), { recursive: true });
  const script = 'tools/scripts/validate_supabase_local_only_migrations.mjs';
  for (const file of [script, 'supabase/seed.sql', `supabase/migrations/${baseline}`]) {
    copyFileSync(join(repo, file), join(root, file));
  }
  return {
    root,
    add: (name) => writeFileSync(join(root, 'supabase/migrations', name), '-- fixture\n'),
    run: () => spawnSync(process.execPath, [join(root, script)], { encoding: 'utf8' }),
  };
}

test('a forward migration can follow the preserved baseline', (t) => {
  const f = fixture(t);
  f.add('20260905090000_fixture.sql');
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /1 forward migration filenames/);
});

test('a forward migration cannot substitute for the baseline', (t) => {
  const f = fixture(t);
  rmSync(join(f.root, 'supabase/migrations', baseline));
  f.add('20260905090000_fixture.sql');
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unexpected baseline name/);
});

test('duplicate migration versions are rejected', (t) => {
  const f = fixture(t);
  f.add('20260905090000_one.sql');
  f.add('20260905090000_two.sql');
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Duplicate migration version/);
});

for (const table of ['admin_role_assignments', 'admin_audit_log']) {
  test(`catalog seed rejects exported ${table} records`, (t) => {
    const f = fixture(t);
    appendFileSync(join(f.root, 'supabase/seed.sql'), `\nINSERT INTO public.${table} (id) VALUES ('synthetic');\n`);
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /must not restore operational admin/);
  });
}
