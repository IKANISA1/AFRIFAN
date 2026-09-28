#!/usr/bin/env node

import {
  existsSync,
  lstatSync,
  readFileSync,
} from 'node:fs';
import { execFileSync } from 'node:child_process';
import { extname, join } from 'node:path';

const root = process.cwd();

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
].map(decodeHex);

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
  '.conf',
  '.css',
  '.csv',
  '.dart',
  '.env',
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
  '.properties',
  '.py',
  '.rb',
  '.sh',
  '.sql',
  '.swift',
  '.toml',
  '.ts',
  '.tsx',
  '.txt',
  '.xml',
  '.yaml',
  '.yml',
]);

const violations = [];

// Legacy product identifiers may be named only in governed migration/disposition
// evidence. Runtime source, schemas, routes and ordinary docs remain strict.
const governedLegacyReferencePaths = [
  /^docs\/architecture\/cloudflare-(?:backend-migration-plan|stage0-live-inventory)-\d{4}-\d{2}-\d{2}\.md$/,
  /^tools\/scripts\/(?:inventory|export)_cloudflare_migration[^/]*\.(?:py|ts|mjs)$/,
  /^tools\/scripts\/inventory_cloudflare_migration\.py$/,
];

function permitsGovernedLegacyReferences(relativePath) {
  const normalized = relativePath.replaceAll('\\', '/');
  return governedLegacyReferencePaths.some((pattern) => pattern.test(normalized));
}
let checkedFiles = 0;

function inspectText(relativePath, source) {
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
    if (ownershipPath.includes(token) ||
        (ownershipSource.includes(token) && !permitsGovernedLegacyReferences(relativePath))) {
      violations.push(`${relativePath}: unsupported ownership token`);
      return;
    }
  }

  if (
    !isDependencyLock &&
    !permitsGovernedLegacyReferences(relativePath) &&
    standaloneUnsupportedPatterns.some(
      (pattern) =>
        pattern.test(normalizedPath) || pattern.test(normalizedSource),
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
  const absolutePath = join(root, relativePath);
  if (!existsSync(absolutePath)) continue; // Deleted in the current worktree.
  if (relativePath.split('/').slice(0, -1).some(
    (name) => generatedDirectoryNames.has(name) || name === 'output',
  )) {
    violations.push(`${relativePath}: generated output must not be tracked`);
    continue;
  }
  inspectText(relativePath, '');
  const stat = lstatSync(absolutePath);
  if (!stat.isFile() || !textExtensions.has(extname(relativePath).toLowerCase())) continue;
  const contents = readFileSync(absolutePath);
  if (contents.includes(0)) continue;
  checkedFiles += 1;
  inspectText(relativePath, contents.toString('utf8'));
}

const requiredPaths = [
  'packages/features/feat_gamification/lib/src/predict/predict_module.dart',
  'packages/features/feat_gamification/lib/src/repositories/prediction_repository.dart',
  'supabase/migrations/20260820080202_football_only_baseline.sql',
  'supabase/tests/repository_boundary_contract.sql',
];

for (const requiredPath of requiredPaths) {
  if (!existsSync(join(root, requiredPath))) {
    violations.push(`${requiredPath}: required football capability is missing`);
  }
}

const registryPath = join(
  root,
  'packages/app_registry/lib/src/module_registry.dart',
);
const registry = readFileSync(registryPath, 'utf8');
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

console.log(`Repository boundary scan checked ${checkedFiles} text files.`);

if (violations.length > 0) {
  console.error('Repository boundary violations:');
  for (const violation of [...new Set(violations)].sort()) {
    console.error(`- ${violation}`);
  }
  process.exit(1);
}

console.log('Repository boundary and football preservation checks passed.');
