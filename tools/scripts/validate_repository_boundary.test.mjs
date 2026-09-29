import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { governedArchiveControlTests, governedArchiveControlStatus, governedLegacyReferences, governedReferenceStatus, validateRepositoryBoundary } from './validate_repository_boundary.mjs';

const script = fileURLToPath(new URL('./validate_repository_boundary.mjs', import.meta.url));
const repositoryRoot = resolve(dirname(script), '../..');
const decode = (hex) => Buffer.from(hex, 'hex').toString();
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'africlub-boundary-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  execFileSync('git', ['init', '-q'], { cwd: root });
  const write = (path, content = '') => {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  };
  for (const path of [
    'packages/features/feat_gamification/lib/src/predict/predict_module.dart',
    'packages/features/feat_gamification/lib/src/repositories/prediction_repository.dart',
    'supabase/migrations/20260820080202_football_only_baseline.sql',
    'supabase/tests/repository_boundary_contract.sql',
  ]) write(path);
  write('packages/app_registry/lib/src/module_registry.dart',
    'ClubModule() PredictModule() LiveModule() MembershipModule() TicketingModule() ShopModule()');
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
  rmSync(resolve(f.root, 'packages/features/feat_gamification/lib/src/predict/predict_module.dart'));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /required football capability is missing/);
});

test('minimal valid source passes independently of ignored caches', (t) => {
  const f = fixture(t);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /football preservation checks passed/);
});

test('archived Drive snapshots remain evidence rather than live source', (t) => {
  const f = fixture(t);
  f.write('docs/drive-import/2026-09-28/mirror/output/historical.sql',
    decode('63726561746520736368656d612061667269636c75625f67616d653b'));
  execFileSync('git', ['add', '-f', 'docs/drive-import'], { cwd: f.root });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /1 evidence files excluded/);
});

for (const path of ['packages/runtime.dart', 'apps/rayon_sports/web/src/runtime.ts',
  'supabase/migrations/new.sql', 'cloudflare/worker/src/index.ts',
  '.github/workflows/deploy.yml', 'pubspec.yaml', 'packages/runtime.csv', 'packages/new/test/archive_test.dart']) {
  test(`archival evidence cannot become a runtime reference in ${path}`, (t) => {
    const f = fixture(t);
    f.write(path, "import '../../../docs/drive-import/2026-09-28/candidates/runtime.ts';");
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /runtime source must not reference archived Drive evidence/);
  });
}

test('reviewed archive-classification audit fixture is exact-path and exact-hash bounded', (t) => {
  const f = fixture(t), date = new Date('2026-09-30T00:00:00.000Z');
  const entry = governedArchiveControlTests[0];
  const contents = readFileSync(join(repositoryRoot, entry.path));
  assert.equal(governedArchiveControlStatus(entry.path, contents, date), 'valid');
  f.write(entry.path, contents);
  assert.deepEqual(validateRepositoryBoundary(f.root, {now: date}).violations, []);
  f.write('packages/new/test/copied_control.dart', contents);
  assert.ok(validateRepositoryBoundary(f.root, {now: date}).violations.some(
    message => message.startsWith('packages/new/test/copied_control.dart: runtime source')));
});

test('changed audit control cannot import archive code using its reviewed path', (t) => {
  const f = fixture(t), entry = governedArchiveControlTests[0];
  const changed = Buffer.concat([readFileSync(join(repositoryRoot, entry.path)),
    Buffer.from("\nimport '../../../docs/drive-import/runtime.dart';\n")]);
  f.write(entry.path, changed);
  const result = validateRepositoryBoundary(f.root, {now: new Date('2026-09-30T00:00:00.000Z')});
  assert.ok(result.violations.some(message => message.includes('governed archive audit control wrong-hash')));
  assert.ok(result.violations.some(message => message.includes('runtime source must not reference archived')));
});

test('archive audit control expires at its exact review deadline', (t) => {
  const f = fixture(t), entry = governedArchiveControlTests[0];
  const contents = readFileSync(join(repositoryRoot, entry.path));
  f.write(entry.path, contents);
  const result = validateRepositoryBoundary(f.root, {now: new Date(entry.expiresAt)});
  assert.ok(result.violations.some(message => message.includes('governed archive audit control expired')));
  assert.ok(result.violations.some(message => message.includes('runtime source must not reference archived')));
});

test('an active source symlink cannot import archived code', (t) => {
  const f = fixture(t);
  f.write('docs/drive-import/snapshot.dart', decode('747269766961'));
  symlinkSync('../docs/drive-import/snapshot.dart', join(f.root, 'packages/linked.dart'));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /source symlinks must not bypass boundary scanning/);
});

for (const [path, payload] of [
  ['supabase/migrations/new.sql', '63726561746520736368656d612061667269636c75625f67616d653b'],
  ['apps/rayon_sports/web/src/routes.ts', '6578706f727420636f6e737420726f757465203d20222f706169722d7476223b'],
  ['packages/runtime.dart', '636f6e7374207461626c65203d202767616d655f73657373696f6e273b'],
]) {
  test(`prohibited runtime definitions stay rejected in ${path}`, (t) => {
    const f = fixture(t);
    f.write(path, decode(payload));
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /unsupported ownership token/);
  });
}

test('only the exact reviewed legacy inventory snapshots receive an exception', (t) => {
  const f = fixture(t);
  const reviewDate = new Date('2026-09-29T00:00:00.000Z');
  for (const exception of governedLegacyReferences) {
    const contents = readFileSync(join(repositoryRoot, exception.path));
    assert.equal(governedReferenceStatus(exception.path, contents, reviewDate), 'valid');
    f.write(exception.path, contents);
  }
  assert.deepEqual(validateRepositoryBoundary(f.root, { now: reviewDate }).violations, []);
  const exception = governedLegacyReferences[0];
  const contents = readFileSync(join(repositoryRoot, exception.path));
  f.write(exception.path, Buffer.concat([contents, Buffer.from('\nChanged snapshot.\n')]));
  const result = validateRepositoryBoundary(f.root, { now: reviewDate });
  assert.ok(result.violations.some((message) => message.includes('exception wrong-hash')));
  assert.ok(result.violations.some((message) => message.includes('unsupported ownership token')));
});

test('governed legacy exceptions expire at their exact deadline', (t) => {
  const f = fixture(t);
  const exception = governedLegacyReferences[0];
  f.write(exception.path, readFileSync(join(repositoryRoot, exception.path)));
  const result = validateRepositoryBoundary(f.root, { now: new Date(exception.expiresAt) });
  assert.ok(result.violations.some((message) => message.includes('exception expired')));
  assert.ok(result.violations.some((message) => message.includes('unsupported ownership token')));
});

test('a similar historical filename cannot inherit an exception', (t) => {
  const f = fixture(t);
  const exception = governedLegacyReferences[0];
  f.write(exception.path.replace('2026-09-24', '2026-09-25'),
    readFileSync(join(repositoryRoot, exception.path)));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unsupported ownership token/);
});

test('a missing module registry produces actionable violations', (t) => {
  const f = fixture(t);
  rmSync(join(f.root, 'packages/app_registry/lib/src/module_registry.dart'));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /module_registry.dart: missing ClubModule/);
  assert.doesNotMatch(result.stderr, /ENOENT/);
});

test('the complete active source and actual migration inventory pass', () => {
  const result = spawnSync(process.execPath, [script], { cwd: repositoryRoot, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /football preservation checks passed/);
});


for (const route of [
  '2f74762d646973706c6179', '2f706169722d7476', '2f6d792d747673',
  '2f67616d652d6f7065726174696f6e73', '2f61646d696e2f67616d6573',
  '2f66616e7a6f6e652f67616d65',
]) {
  test(`prohibited route ${route} is rejected after separator normalization`, (t) => {
    const f = fixture(t);
    f.write('apps/rayon_sports/web/src/routes.ts', `export const route = '${decode(route)}';`);
    const result = f.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /unsupported ownership token/);
  });
}

test('a dangling source symlink cannot bypass boundary checks', (t) => {
  const f = fixture(t);
  symlinkSync('../docs/drive-import/missing.dart', join(f.root, 'packages/linked.dart'));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /source symlinks must not bypass boundary scanning/);
});

test('binary text source cannot hide prohibited runtime definitions', (t) => {
  const f = fixture(t);
  f.write('supabase/migrations/new.sql', Buffer.concat([Buffer.from([0]), Buffer.from(decode('747269766961'))]));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /binary content must not bypass text source scanning/);
});

test('normalized archival paths cannot be imported into runtime source', (t) => {
  const f = fixture(t);
  f.write('packages/runtime.dart', "import '../../../docs/./drive-import/snapshot.dart';");
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /runtime source must not reference archived Drive evidence/);
});
