#!/usr/bin/env node

import {
  existsSync,
  lstatSync,
  readFileSync,
} from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const decodeHex = (hex) => Buffer.from(hex, 'hex').toString('utf8');

const unsupportedTokens = [
  '61667269636c75625f67616d65',
  '7261796f6e5f73706f7274735f7476',
  '666561745f67616d655f6f7065726174696f6e73',
  '747269766961',
  '2f74762d646973706c6179',
  '2f706169722d7476',
  '2f6d792d747673',
  '2f67616d652d6f7065726174696f6e73',
  '2f61646d696e2f67616d6573',
  '2f66616e7a6f6e652f67616d65',
  '74765f646576696365',
  '67616d655f73657373696f6e',
  '6d616e616765645f67616d65',
  '646973706c61795f70616972696e67',
  '6c6976655f67616d65735f7632',
  '61646d696e5f67616d65',
  '6c6976655f67616d65',
  '6d617463685f7175697a',
  '7061727469636970616e745f67616d65',
  '73657373696f6e5f706c616e6e6572',
  '67616d655f636f6e74726f6c6c6572',
  '67616d65735f646973636f76657279',
  '67616d655f636f6e74656e74',
  '67616d655f636f6e74726f6c',
  '67616d655f6a6f696e',
].map((hex) => decodeHex(hex).replaceAll(/[\s-]+/g, '_'));

const standaloneUnsupportedPatterns = ['7476', '7175697a'].map(
  (hex) => new RegExp(`\\b${decodeHex(hex)}\\b`, 'i'),
);

const generatedDirectoryNames = new Set([
  '.dart_tool',
  '.firebase',
  '.gradle',
  '.next',
  '.open-next',
  '.symlinks',
  '.swiftpm',
  '.temp',
  '.turbo',
  '.wrangler',
  'DerivedData',
  'Pods',
  'build',
  'coverage',
  'dist',
  'ephemeral',
  'node_modules',
  'playwright-report',
  'test-results',
  'xcuserdata',
]);

const textExtensions = new Set([
  '',
  '.c',
  '.cc',
  '.cmake',
  '.conf',
  '.css',
  '.csv',
  '.dart',
  '.env',
  '.entitlements',
  '.gradle',
  '.graphql',
  '.h',
  '.html',
  '.java',
  '.js',
  '.json',
  '.jsonl',
  '.jsx',
  '.kt',
  '.kts',
  '.lock',
  '.md',
  '.mjs',
  '.plist',
  '.pbxproj',
  '.properties',
  '.py',
  '.rb',
  '.resolved',
  '.sh',
  '.sql',
  '.swift',
  '.toml',
  '.ts',
  '.tsx',
  '.txt',
  '.xml',
  '.xcconfig',
  '.xcprivacy',
  '.yaml',
  '.yml',
]);

// Exact snapshots reviewed by the implementer for REP-04. These are technical
// exceptions for historical inventory, not owner or independent approval. A
// changed snapshot requires renewed review; the deadline forces that review.
export const governedLegacyReferences = Object.freeze([
  Object.freeze({
    path: 'docs/architecture/cloudflare-backend-migration-plan-2026-09-24.md',
    sha256: '9f6cbd153b77ce312a8a0c81dd84baacc3033f13c95cade508f9a3aff456ced4',
    expiresAt: '2026-10-29T00:00:00.000Z',
  }),
  Object.freeze({
    path: 'docs/architecture/cloudflare-stage0-live-inventory-2026-09-24.md',
    sha256: 'a9e01fe1642392ddd1d1e1ae1f43f6e77d5ebef794f7f57567a6fac9856c2898',
    expiresAt: '2026-10-29T00:00:00.000Z',
  }),
  Object.freeze({
    path: 'tools/scripts/inventory_cloudflare_migration.py',
    sha256: '33cad14805f545962f7bb05bdf104ead7d98a276306abd33df27fd970b57a520',
    expiresAt: '2026-10-29T00:00:00.000Z',
  }),
]);

const archivePrefix = 'docs/drive-import/';
const runtimePrefixes = ['apps/', 'packages/', 'supabase/', 'cloudflare/', '.github/workflows/'];
const rootBuildConfigurationPaths = new Set(['pubspec.yaml', 'pubspec.yml', 'package.json']);

// This reviewed audit control names the excluded archive namespace and writes
// synthetic negative fixtures. It never promotes archived source or media into
// a runtime dependency. This is not a general test-file or legacy-token waiver.
export const governedArchiveControlTests = Object.freeze([
  Object.freeze({
    path: 'packages/core/core_theme/test/ui_source_guardrails_test.dart',
    sha256: '73505819a41024a86218782639034a33ad67770467cac10dade0780b3d9b9034',
    expiresAt: '2026-10-29T00:00:00.000Z',
    reviewedBy: 'implementation technical review; no owner or release approval',
  }),
]);

export function governedArchiveControlStatus(relativePath, contents, now = new Date()) {
  const entry = governedArchiveControlTests.find((value) => value.path === relativePath);
  if (!entry) return 'none';
  if (!Number.isFinite(now.getTime()) || now.getTime() >= Date.parse(entry.expiresAt)) return 'expired';
  return createHash('sha256').update(contents).digest('hex') === entry.sha256 ? 'valid' : 'wrong-hash';
}

export function governedReferenceStatus(relativePath, contents, now = new Date()) {
  const exception = governedLegacyReferences.find((entry) => entry.path === relativePath);
  if (!exception) return 'none';
  if (!Number.isFinite(now.getTime()) || now.getTime() >= Date.parse(exception.expiresAt)) {
    return 'expired';
  }
  return createHash('sha256').update(contents).digest('hex') === exception.sha256
    ? 'valid' : 'wrong-hash';
}

export function validateRepositoryBoundary(root, { now = new Date() } = {}) {
  const violations = [];
  let checkedFiles = 0;
  let archivedFiles = 0;

  function inspectText(relativePath, source, permitsLegacyReferences = false) {
    const normalizedPath = relativePath.toLowerCase();
    // A published club channel citation is data provenance, not ownership of
    // the separate display app. Keep the exception paired with its source URL.
    const clubChannelAttribution = `'${decodeHex('7261796f6e2073706f727473207476')}', 'https://www.youtube.com/@rayon_sports'`;
    const normalizedSource = (normalizedPath.startsWith('supabase/migrations/') ||
      normalizedPath === 'supabase/seed-clubs.sql')
      ? source.toLowerCase().replaceAll(clubChannelAttribution, "'official club source'")
      : source.toLowerCase();
    const ownershipPath = normalizedPath.replaceAll(/[\s-]+/g, '_');
    const ownershipSource = normalizedSource.replaceAll(/[\s-]+/g, '_');
    const isDependencyLock =
      normalizedPath.endsWith('.lock') ||
      normalizedPath.endsWith('-lock.json') ||
      normalizedPath.endsWith('.resolved');

    for (const token of unsupportedTokens) {
      if (ownershipPath.includes(token) || (!permitsLegacyReferences && ownershipSource.includes(token))) {
        violations.push(`${relativePath}: unsupported ownership token`);
        return;
      }
    }

    if (
      !isDependencyLock &&
      standaloneUnsupportedPatterns.some(
        (pattern) =>
          pattern.test(normalizedPath) || (!permitsLegacyReferences && pattern.test(normalizedSource)),
      )
    ) {
      violations.push(`${relativePath}: unsupported standalone surface token`);
    }

  }

  // Inspect tracked and new source, including tracked files covered by ignores.
  // Normal ignored dependencies and build caches are not repository contents.
  const sourcePaths = execFileSync(
    'git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'],
    { cwd: root, encoding: 'utf8' },
  ).split('\0').filter(Boolean);

  for (const relativePath of new Set(sourcePaths)) {
    // Imported snapshots are recoverable evidence only. Paths outside this exact
    // namespace retain all source checks, including force-tracked ignored output.
    if (relativePath.startsWith(archivePrefix)) {
      archivedFiles += 1;
      continue;
    }
    const absolutePath = join(root, relativePath);
    let stat;
    try {
      stat = lstatSync(absolutePath);
    } catch (error) {
      if (error.code === 'ENOENT') continue; // Deleted in the current worktree.
      throw error;
    }
    if (stat.isSymbolicLink()) {
      violations.push(`${relativePath}: source symlinks must not bypass boundary scanning`);
      continue;
    }
    if (relativePath.split('/').slice(0, -1).some(
      (name) => generatedDirectoryNames.has(name) || name === 'output',
    )) {
      violations.push(`${relativePath}: generated output must not be tracked`);
      continue;
    }
    inspectText(relativePath, '');
    if (!stat.isFile() || !textExtensions.has(extname(relativePath).toLowerCase())) continue;
    const contents = readFileSync(absolutePath);
    const referenceStatus = governedReferenceStatus(relativePath, contents, now);
    const archiveControlStatus = governedArchiveControlStatus(relativePath, contents, now);
    if (referenceStatus === 'expired' || referenceStatus === 'wrong-hash') {
      violations.push(`${relativePath}: governed legacy reference exception ${referenceStatus}`);
    }
    if (archiveControlStatus === 'expired' || archiveControlStatus === 'wrong-hash') {
      violations.push(`${relativePath}: governed archive audit control ${archiveControlStatus}`);
    }
    if (contents.includes(0)) {
      violations.push(`${relativePath}: binary content must not bypass text source scanning`);
      continue;
    }
    checkedFiles += 1;
    const source = contents.toString('utf8');
    // Archived code/data must never become a runtime dependency merely because its
    // original snapshot is excluded above. Documentation links remain evidence.
    if ((runtimePrefixes.some((prefix) => relativePath.startsWith(prefix)) ||
         rootBuildConfigurationPaths.has(relativePath)) &&
        archiveControlStatus !== 'valid' &&
        extname(relativePath).toLowerCase() !== '.md' &&
        /docs\/(?:\.\/)*drive-import\//.test(source.toLowerCase().replaceAll('\\', '/'))) {
      violations.push(`${relativePath}: runtime source must not reference archived Drive evidence`);
    }
    inspectText(relativePath, source, referenceStatus === 'valid');
  }

  const requiredPaths = [
    'packages/features/feat_gamification/lib/src/predict/predict_module.dart',
    'packages/features/feat_gamification/lib/src/repositories/prediction_repository.dart',
    'supabase/migrations/20260820080202_football_only_baseline.sql',
    'supabase/tests/repository_boundary_contract.sql',
  ];

  for (const requiredPath of requiredPaths) {
    if (!existsSync(join(root, requiredPath)) || !lstatSync(join(root, requiredPath)).isFile()) {
      violations.push(`${requiredPath}: required football capability is missing`);
    }
  }

  const registryPath = join(
    root,
    'packages/app_registry/lib/src/module_registry.dart',
  );
  const registry = existsSync(registryPath) && lstatSync(registryPath).isFile()
    ? readFileSync(registryPath, 'utf8') : '';
  for (const requiredModule of [
    'ClubModule()',
    'PredictModule()',
    'LiveModule()',
    'MembershipModule()',
    'TicketingModule()',
    'ShopModule()',
  ]) {
    if (!registry.includes(requiredModule)) {
      violations.push(`module_registry.dart: missing ${requiredModule}`);
    }
  }

  return { checkedFiles, archivedFiles, violations: [...new Set(violations)].sort() };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = validateRepositoryBoundary(process.cwd());
  console.log(`Repository boundary scan checked ${result.checkedFiles} text files; ${result.archivedFiles} evidence files excluded from live source.`);
  if (result.violations.length > 0) {
    console.error('Repository boundary violations:');
    for (const violation of result.violations) console.error(`- ${violation}`);
    process.exitCode = 1;
  } else {
    console.log('Repository boundary and football preservation checks passed.');
  }
}
