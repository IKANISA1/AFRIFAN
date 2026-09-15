import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./validate_repository_boundary.mjs', import.meta.url));
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'africlub-boundary-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  execFileSync('git', ['init', '-q'], { cwd: root });
  const write = (path, content = '') => {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  };
  for (const path of [
    'packages/features/feat_gamification/lib/src/fanzone_module.dart',
    'packages/features/feat_gamification/lib/src/repositories/prediction_repository.dart',
    'supabase/migrations/20260820080202_football_only_baseline.sql',
    'supabase/tests/repository_boundary_contract.sql',
  ]) write(path);
  write('packages/app_registry/lib/src/module_registry.dart',
    'ClubModule() FanzoneModule() LiveModule() MembershipModule() TicketingModule() ShopModule()');
  write('.gitignore', 'build/\nnode_modules/\noutput/\n');
  return {
    root, write,
    run: () => spawnSync(process.execPath, [script], { cwd: root, encoding: 'utf8' }),
  };
}

test('ordinary ignored build caches do not block source validation', (t) => {
  const f = fixture(t);
  f.write('build/cache.txt', Buffer.from('747269766961', 'hex').toString());
  f.write('node_modules/dependency/index.js', 'generated');
  f.write('output/evidence/report.json', '{}');
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
});

test('force-tracked generated output is rejected even when ignored', (t) => {
  const f = fixture(t);
  f.write('build/cache.txt', 'generated');
  execFileSync('git', ['add', '-f', 'build/cache.txt'], { cwd: f.root });
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /generated output must not be tracked/);
});

test('new unsupported source is rejected before staging', (t) => {
  const f = fixture(t);
  f.write('packages/new_surface.dart', Buffer.from('747269766961', 'hex').toString());
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unsupported ownership token/);
});

for (const path of ['supabase/migrations/club_source.sql', 'supabase/seed-clubs.sql']) {
test(`published club channel attribution in ${path} requires its source URL`, (t) => {
  const f = fixture(t);
  const label = Buffer.from('5261796f6e2053706f727473205456', 'hex').toString();
  f.write(path, `select '${label}', 'https://www.youtube.com/@rayon_sports';`);
  assert.equal(f.run().status, 0);
  f.write(path, `select '${label}', 'https://example.com/';`);
  assert.notEqual(f.run().status, 0);
});
}

test('removing an active football capability fails validation', (t) => {
  const f = fixture(t);
  rmSync(resolve(f.root, 'packages/features/feat_gamification/lib/src/fanzone_module.dart'));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /required football capability is missing/);
});
