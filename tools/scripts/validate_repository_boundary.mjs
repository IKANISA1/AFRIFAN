#!/usr/bin/env node

import {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
} from 'node:fs';
import { extname, join, relative } from 'node:path';

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

const ignoredDirectoryNames = new Set(['.git']);

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
let checkedFiles = 0;

function inspectText(relativePath, source) {
  const normalizedPath = relativePath.toLowerCase();
  const normalizedSource = source.toLowerCase();
  const ownershipPath = normalizedPath.replaceAll(/[\s-]+/g, '_');
  const ownershipSource = normalizedSource.replaceAll(/[\s-]+/g, '_');
  const isDependencyLock =
    normalizedPath.endsWith('.lock') ||
    normalizedPath.endsWith('-lock.json') ||
    normalizedPath.endsWith('.resolved');

  for (const token of unsupportedTokens) {
    if (ownershipPath.includes(token) || ownershipSource.includes(token)) {
      violations.push(`${relativePath}: unsupported ownership token`);
      return;
    }
  }

  if (
    !isDependencyLock &&
    standaloneUnsupportedPatterns.some(
      (pattern) =>
        pattern.test(normalizedPath) || pattern.test(normalizedSource),
    )
  ) {
    violations.push(`${relativePath}: unsupported standalone surface token`);
  }

}

function walk(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = join(directory, entry.name);
    const relativePath = relative(root, absolutePath);

    if (entry.isDirectory()) {
      if (ignoredDirectoryNames.has(entry.name)) continue;
      if (generatedDirectoryNames.has(entry.name)) {
        violations.push(`${relativePath}: generated directory remains`);
        continue;
      }
      walk(absolutePath);
      continue;
    }

    if (entry.isSymbolicLink()) {
      const stat = lstatSync(absolutePath);
      if (!stat.isSymbolicLink()) {
        violations.push(`${relativePath}: unreadable filesystem entry`);
      }
      continue;
    }

    inspectText(relativePath, '');
    if (!textExtensions.has(extname(entry.name).toLowerCase())) continue;

    const contents = readFileSync(absolutePath);
    if (contents.includes(0)) continue;

    checkedFiles += 1;
    inspectText(relativePath, contents.toString('utf8'));
  }
}

walk(root);

const requiredPaths = [
  'packages/features/feat_gamification/lib/src/fanzone_module.dart',
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
  'FanzoneModule()',
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
