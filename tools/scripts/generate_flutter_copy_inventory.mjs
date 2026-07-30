#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";

const repoRoot = resolve(new URL("../..", import.meta.url).pathname);
const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  args.set(process.argv[index], process.argv[index + 1]);
}

const jsonOutput = resolve(
  repoRoot,
  args.get("--json") ??
    "output/implementation_goal_20260724/localization_copy_matrix/flutter-copy-inventory.json",
);
const markdownOutput = resolve(
  repoRoot,
  args.get("--markdown") ??
    "output/implementation_goal_20260724/localization_copy_matrix/flutter-copy-inventory.md",
);
const dispositionInput = resolve(
  repoRoot,
  args.get("--dispositions") ??
    "output/implementation_goal_20260724/localization_copy_matrix/copy-dispositions.json",
);

const roots = [
  "packages/features",
  "apps/rayon_sports/lib",
  "apps/rayon_sports_tv/lib",
].map((path) => resolve(repoRoot, path));

const namedFields = [
  "actionLabel",
  "description",
  "emptyLabel",
  "errorText",
  "helperText",
  "hint",
  "hintText",
  "label",
  "loadingLabel",
  "message",
  "retryLabel",
  "semanticLabel",
  "subtitle",
  "title",
  "tooltip",
];
const namedFieldPattern = new RegExp(
  `\\b(${namedFields.join("|")})\\s*:\\s*(?:const\\s+)?(["'])((?:\\\\.|[^"'\\\\]){1,500})\\2`,
  "g",
);
const directTextPattern =
  /\b(?:Text|SelectableText)\s*\(\s*(?:const\s+)?(["'])((?:\\.|[^"'\\]){1,500})\1/g;
const semanticVariablePattern =
  /\b(?:const|final|var)\s+(?:String\s+)?([A-Za-z0-9_]*(?:copy|description|empty|error|help|hint|label|message|subtitle|title|tooltip|trust)[A-Za-z0-9_]*)\s*=\s*(["'])((?:\\.|[^"'\\]){1,500})\2/gi;

const dartFiles = roots
  .flatMap((root) => collectDartFiles(root))
  .filter((path) => path.includes(`${sep}lib${sep}`))
  .sort();
const entries = [];

for (const absolutePath of dartFiles) {
  const source = readFileSync(absolutePath, "utf8");
  const commentRanges = rangesForComments(source);
  const relativePath = relative(repoRoot, absolutePath);
  collectMatches({
    source,
    relativePath,
    pattern: namedFieldPattern,
    commentRanges,
    fieldFromMatch: (match) => match[1],
    valueFromMatch: (match) => match[3],
  });
  collectMatches({
    source,
    relativePath,
    pattern: directTextPattern,
    commentRanges,
    fieldFromMatch: () => "text",
    valueFromMatch: (match) => match[2],
  });
  collectMatches({
    source,
    relativePath,
    pattern: semanticVariablePattern,
    commentRanges,
    fieldFromMatch: (match) => `variable:${match[1]}`,
    valueFromMatch: (match) => match[3],
  });
}

const detectedEntries = [
  ...new Map(
    entries.map((entry) => [
      `${entry.file}:${entry.line}:${entry.field}:${entry.value}`,
      entry,
    ]),
  ).values(),
].sort(
  (left, right) =>
    left.file.localeCompare(right.file) ||
    left.line - right.line ||
    left.field.localeCompare(right.field) ||
    left.value.localeCompare(right.value),
);

const dispositionRegistry = readDispositionRegistry(dispositionInput);
const registeredKeys = new Set();
const dispositionsByKey = new Map();
for (const disposition of dispositionRegistry.entries) {
  const key = dispositionKey(disposition);
  if (dispositionsByKey.has(key)) {
    throw new Error(`Duplicate copy disposition: ${key}`);
  }
  dispositionsByKey.set(key, disposition);
}
const uniqueEntries = detectedEntries.map((entry) => {
  const key = dispositionKey(entry);
  const disposition = dispositionsByKey.get(key);
  if (disposition == null) return entry;
  registeredKeys.add(key);
  return {
    ...entry,
    disposition: disposition.disposition,
    reason: disposition.rationale,
    review_authority: disposition.review_authority,
    reviewed_at: disposition.reviewed_at,
  };
});
const unusedDispositions = [...dispositionsByKey.keys()].filter(
  (key) => !registeredKeys.has(key),
);
if (unusedDispositions.length > 0) {
  throw new Error(
    `Copy dispositions do not match current source candidates:\n${unusedDispositions.join("\n")}`,
  );
}

const byPackage = new Map();
const pendingByPackage = new Map();
for (const entry of uniqueEntries) {
  const packageName = packageFor(entry.file);
  byPackage.set(packageName, (byPackage.get(packageName) ?? 0) + 1);
  if (entry.disposition === "pending_migration_or_explicit_review") {
    pendingByPackage.set(
      packageName,
      (pendingByPackage.get(packageName) ?? 0) + 1,
    );
  }
}
const pendingEntries = uniqueEntries.filter(
  (entry) => entry.disposition === "pending_migration_or_explicit_review",
);

const sourceDigest = createHash("sha256")
  .update(
    dartFiles
      .map((path) => `${relative(repoRoot, path)}\0${readFileSync(path)}`)
      .join("\0"),
  )
  .digest("hex");
const commit = safeGit(["rev-parse", "HEAD"]);
const dirty = safeGit(["status", "--porcelain"]) !== "";
const inventory = {
  schema_version: "1.0",
  task_id: "MOB-08",
  generated_at: new Date().toISOString(),
  workspace: repoRoot,
  source_commit: commit,
  dirty_state: dirty,
  source_sha256: sourceDigest,
  scope: roots.map((path) => relative(repoRoot, path)),
  methodology: {
    status: "candidate_inventory_requires_explicit_disposition",
    detected_patterns: [
      "literal named arguments used by visible copy fields",
      "literal Text and SelectableText values",
      "literal variables with copy-oriented names",
    ],
    exclusions: [
      "test and generated build trees",
      "comments",
      "non-letter values",
      "paths, URLs, package imports, and asset references",
    ],
    limitation:
      "This is a fail-open candidate inventory for human and code-owner disposition. Dynamic CMS/API copy and literals passed through unrecognized wrappers require separate review.",
    disposition_registry: relative(repoRoot, dispositionInput),
    disposition_registry_entries: dispositionRegistry.entries.length,
  },
  summary: {
    dart_files_scanned: dartFiles.length,
    candidate_literals: uniqueEntries.length,
    pending_candidate_literals: pendingEntries.length,
    explicitly_dispositioned_literals:
      uniqueEntries.length - pendingEntries.length,
    packages_with_candidates: byPackage.size,
    packages_with_pending_candidates: pendingByPackage.size,
    localized_search_literals_remaining: uniqueEntries.filter(
      (entry) =>
        isPending(entry) &&
        (entry.file.includes(
          "/feat_home/lib/src/screens/discovery_search",
        ) ||
          entry.file.includes("/feat_home/lib/src/search/")),
    ).length,
    localized_tv_literals_remaining: uniqueEntries.filter(
      (entry) =>
        isPending(entry) &&
        entry.file === "apps/rayon_sports_tv/lib/main.dart",
    ).length,
  },
  candidates_by_package: Object.fromEntries(
    [...byPackage.entries()].sort(([left], [right]) =>
      left.localeCompare(right),
    ),
  ),
  pending_candidates_by_package: Object.fromEntries(
    [...pendingByPackage.entries()].sort(([left], [right]) =>
      left.localeCompare(right),
    ),
  ),
  entries: uniqueEntries,
};

mkdirSync(dirname(jsonOutput), { recursive: true });
mkdirSync(dirname(markdownOutput), { recursive: true });
writeFileSync(jsonOutput, `${JSON.stringify(inventory, null, 2)}\n`);
writeFileSync(markdownOutput, renderMarkdown(inventory));

process.stdout.write(
  `${JSON.stringify({
    json: relative(repoRoot, jsonOutput),
    markdown: relative(repoRoot, markdownOutput),
    ...inventory.summary,
  })}\n`,
);

function collectMatches({
  source,
  relativePath,
  pattern,
  commentRanges,
  fieldFromMatch,
  valueFromMatch,
}) {
  pattern.lastIndex = 0;
  for (const match of source.matchAll(pattern)) {
    if (insideRange(match.index, commentRanges)) continue;
    const value = decodeLiteral(valueFromMatch(match)).trim();
    if (!isCandidate(value)) continue;
    const line = lineForOffset(source, match.index);
    entries.push({
      file: relativePath,
      line,
      field: fieldFromMatch(match),
      value,
      disposition: "pending_migration_or_explicit_review",
      reason:
        "Literal is connected to a visible-copy field or copy-oriented variable in production Dart.",
    });
  }
}

function collectDartFiles(root) {
  if (!statSync(root).isDirectory()) return [];
  const files = [];
  for (const name of readdirSync(root)) {
    if (name === ".dart_tool" || name === "build" || name === "test") continue;
    const path = join(root, name);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      files.push(...collectDartFiles(path));
    } else if (name.endsWith(".dart")) {
      files.push(path);
    }
  }
  return files;
}

function rangesForComments(source) {
  const ranges = [];
  const pattern = /\/\*[\s\S]*?\*\/|\/\/[^\n]*/g;
  for (const match of source.matchAll(pattern)) {
    ranges.push([match.index, match.index + match[0].length]);
  }
  return ranges;
}

function insideRange(index, ranges) {
  return ranges.some(([start, end]) => index >= start && index < end);
}

function decodeLiteral(value) {
  return value
    .replaceAll("\\n", " ")
    .replaceAll("\\'", "'")
    .replaceAll('\\"', '"')
    .replaceAll("\\$", "$")
    .replace(/\s+/g, " ");
}

function isCandidate(value) {
  if (!/\p{L}/u.test(value)) return false;
  if (
    /^(?:package:|https?:\/\/|assets\/|lib\/|test\/|[./][A-Za-z0-9_-])/i.test(
      value,
    )
  ) {
    return false;
  }
  if (/^[a-z0-9_.:/-]+$/i.test(value) && /[./:_-]/.test(value)) {
    return false;
  }
  return true;
}

function isPending(entry) {
  return entry.disposition === "pending_migration_or_explicit_review";
}

function readDispositionRegistry(path) {
  if (!existsSync(path)) {
    return { schema_version: "1.0", task_id: "MOB-08", entries: [] };
  }
  const value = JSON.parse(readFileSync(path, "utf8"));
  if (
    value?.schema_version !== "1.0" ||
    value?.task_id !== "MOB-08" ||
    !Array.isArray(value?.entries)
  ) {
    throw new Error(`Invalid copy-disposition registry: ${path}`);
  }
  for (const entry of value.entries) {
    if (
      typeof entry?.file !== "string" ||
      typeof entry?.field !== "string" ||
      typeof entry?.value !== "string" ||
      typeof entry?.disposition !== "string" ||
      typeof entry?.rationale !== "string" ||
      typeof entry?.review_authority !== "string" ||
      typeof entry?.reviewed_at !== "string"
    ) {
      throw new Error(`Invalid copy-disposition entry in ${path}`);
    }
    if (entry.disposition === "pending_migration_or_explicit_review") {
      throw new Error("Disposition registry cannot preserve pending state");
    }
  }
  return value;
}

function dispositionKey(entry) {
  return `${entry.file}\0${entry.field}\0${entry.value}`;
}

function lineForOffset(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function packageFor(path) {
  const parts = path.split("/");
  if (parts[0] === "packages" && parts[1] === "features") return parts[2];
  if (parts[0] === "apps") return parts[1];
  return parts.slice(0, 2).join("/");
}

function safeGit(args) {
  try {
    return execFileSync("git", args, {
      cwd: repoRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "unavailable";
  }
}

function renderMarkdown(inventoryValue) {
  const packageRows = Object.entries(inventoryValue.candidates_by_package)
    .map(([name, count]) => `| ${name} | ${count} |`)
    .join("\n");
  return `# MOB-08 Flutter copy inventory

This generated inventory is a source-grounded candidate register, not a claim
that every literal is user-facing. Each candidate remains
\`pending_migration_or_explicit_review\` until it is migrated to
\`core_l10n\` or explicitly dispositioned by the owning surface.

## Current snapshot

- Source commit: \`${inventoryValue.source_commit}\`
- Dirty worktree: \`${inventoryValue.dirty_state}\`
- Production Dart files scanned: ${inventoryValue.summary.dart_files_scanned}
- Detected candidate literals: ${inventoryValue.summary.candidate_literals}
- Pending migration or review: ${inventoryValue.summary.pending_candidate_literals}
- Explicitly dispositioned: ${inventoryValue.summary.explicitly_dispositioned_literals}
- Packages with candidates: ${inventoryValue.summary.packages_with_candidates}
- Packages with pending candidates: ${inventoryValue.summary.packages_with_pending_candidates}
- Search-surface candidate literals remaining after the current migration: ${inventoryValue.summary.localized_search_literals_remaining}
- Native-TV candidate literals remaining after the current migration: ${inventoryValue.summary.localized_tv_literals_remaining}
- Controlled disposition registry: \`${inventoryValue.methodology.disposition_registry}\`
- Source digest: \`${inventoryValue.source_sha256}\`

## Candidate count by package

| Package | Candidates |
|---|---:|
${packageRows}

## Interpretation

The JSON companion contains file, line, field, literal, and current
disposition for every candidate. The detector covers literal visible-copy
arguments, direct text widgets, and copy-oriented variables. Dynamic CMS/API
copy and unrecognized wrapper APIs still require separate review. A zero count
for one migrated screen does not close MOB-08: named French and Kinyarwanda
approval plus controlled localized visual evidence remain mandatory.
`;
}
