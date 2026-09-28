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

const legacyText = Buffer.from('61667269636c75625f67616d65', 'hex').toString();
async function exceptions(f, entries) {
  const { createHash } = await import('node:crypto');
  f.write('docs/governance/legacy-reference-exceptions.json', JSON.stringify({
    schemaVersion: 1,
    entries: entries.map(({path, source = legacyText, ...overrides}) => ({
      path, sha256: createHash('sha256').update(source).digest('hex'),
      owner: 'migration-test', reason: 'Archived schema inventory only',
      reviewBy: '2099-12-31', ...overrides,
    })),
  }));
}

test('exact hash-bound migration evidence is allowed without permitting runtime code', async (t) => {
  const f = fixture(t);
  const path = 'docs/architecture/migration-inventory.md';
  f.write(path, legacyText);
  await exceptions(f, [{path}]);
  assert.equal(f.run().status, 0);
  f.write('packages/new_surface.dart', legacyText);
  assert.notEqual(f.run().status, 0);
});

test('editing exception content requires a reviewed new hash', async (t) => {
  const f = fixture(t); const path = 'docs/architecture/migration-inventory.md';
  f.write(path, legacyText); await exceptions(f, [{path}]);
  f.write(path, legacyText + '\nchanged');
  assert.match(f.run().stderr, /exception hash changed/);
});

for (const path of ['packages/core/feature.dart', 'supabase/migrations/new.sql',
  'tools/scripts/not-approved.py', 'docs/architecture/../runtime.md']) {
  test(`cannot exempt runtime, schema or arbitrary script path: ${path}`, async (t) => {
    const f = fixture(t); f.write(path, legacyText); await exceptions(f, [{path}]);
    assert.notEqual(f.run().status, 0);
    assert.match(f.run().stderr, /invalid, duplicate or expired exception/);
  });
}

test('an expired exception fails closed', async (t) => {
  const f = fixture(t); const path='docs/architecture/migration-inventory.md';
  f.write(path, legacyText); await exceptions(f, [{path, reviewBy:'2000-01-01'}]);
  assert.notEqual(f.run().status, 0);
});

test('a duplicate exception fails closed', async (t) => {
  const f = fixture(t); const path='docs/architecture/migration-inventory.md';
  f.write(path, legacyText); await exceptions(f, [{path}, {path}]);
  assert.notEqual(f.run().status, 0);
});

test('unregistered documentation is still checked', (t) => {
  const f = fixture(t); f.write('docs/architecture/migration-inventory.md', legacyText);
  assert.notEqual(f.run().status, 0);
});

test('corrupt exception registry is rejected', (t) => {
  const f = fixture(t); f.write('docs/governance/legacy-reference-exceptions.json', '{');
  assert.notEqual(f.run().status, 0);
});

test('exact current migration documents and inventory source pass together', async (t) => {
  const {readFileSync} = await import('node:fs');
  const f = fixture(t); const repo = resolve(dirname(script), '../..');
  const entries = [
    'docs/architecture/cloudflare-backend-migration-plan-2026-09-24.md',
    'docs/architecture/cloudflare-stage0-live-inventory-2026-09-24.md',
    'tools/scripts/inventory_cloudflare_migration.py',
  ].map(path => ({path, source:readFileSync(join(repo,path),'utf8')}));
  for(const e of entries) f.write(e.path,e.source);
  await exceptions(f,entries);
  const result=f.run(); assert.equal(result.status,0,result.stderr);
});

for (const reviewBy of ['2099-02-31','2099-13-01','2099-1-01','2099-01-01T00:00:00Z']) {
 test(`invalid calendar review date rejected: ${reviewBy}`,async t=>{
  const f=fixture(t),path='docs/architecture/migration-inventory.md';f.write(path,legacyText);
  await exceptions(f,[{path,reviewBy}]);assert.notEqual(f.run().status,0);
 });
}
test('unknown registry permission field cannot broaden exemptions',async t=>{
 const f=fixture(t),path='docs/architecture/migration-inventory.md';f.write(path,legacyText);
 await exceptions(f,[{path,allowRuntime:true}]);assert.notEqual(f.run().status,0);
});
test('symlinked exception file is rejected',async t=>{
 const {symlinkSync}=await import('node:fs');const f=fixture(t),path='docs/architecture/migration-inventory.md';
 f.write('content.txt',legacyText);f.write(path,legacyText);await exceptions(f,[{path}]);
 rmSync(join(f.root,path));symlinkSync(join(f.root,'content.txt'),join(f.root,path));assert.notEqual(f.run().status,0);
});
test('symlinked parent cannot grant an exception',async t=>{
 const {symlinkSync}=await import('node:fs');const f=fixture(t),path='docs/architecture/migration-inventory.md';
 f.write(path,legacyText);await exceptions(f,[{path}]);rmSync(join(f.root,'docs/architecture'),{recursive:true});
 f.write('linked/migration-inventory.md',legacyText);symlinkSync(join(f.root,'linked'),join(f.root,'docs/architecture'),'dir');
 assert.notEqual(f.run().status,0);
});
