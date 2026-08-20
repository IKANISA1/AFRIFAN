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

const defaultRepoRoot = resolve(new URL("../..", import.meta.url).pathname);
const args = readArgs(process.argv.slice(2));
const repoRoot = resolve(args.get("--repo-root") ?? defaultRepoRoot);
const sourceRoots = (
  args.get("--roots") ??
  "packages/core,packages/features,apps/rayon_sports/lib,apps/rayon_sports_tv/lib"
)
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean)
  .map((value) => resolve(repoRoot, value));
const jsonOutput = resolve(
  repoRoot,
  args.get("--json") ??
    "output/implementation_goal_20260724/localization_copy_matrix/dynamic-copy-inventory.json",
);
const markdownOutput = resolve(
  repoRoot,
  args.get("--markdown") ??
    "output/implementation_goal_20260724/localization_copy_matrix/dynamic-copy-inventory.md",
);
const dispositionInput = resolve(
  repoRoot,
  args.get("--dispositions") ??
    "output/implementation_goal_20260724/localization_copy_matrix/dynamic-copy-dispositions.json",
);

const copyKeys = [
  "answer",
  "author_name",
  "benefits",
  "bio",
  "body",
  "category",
  "club_name",
  "competition",
  "content",
  "country_name",
  "description",
  "display_name",
  "home_team",
  "label",
  "league",
  "match_access",
  "message",
  "name",
  "nationality",
  "nickname_brand_identity",
  "position",
  "prompt",
  "question",
  "question_prompt",
  "reward",
  "seating_access",
  "source_label",
  "subtitle",
  "text_value",
  "title",
  "venue",
  "away_team",
];
const dynamicMapAccessPattern = new RegExp(
  `\\b([A-Za-z_][A-Za-z0-9_]*)\\s*\\[\\s*(["'])(${copyKeys.join("|")})\\2\\s*\\]`,
  "g",
);
const excludedAccessors = new Set(["headers", "metadata"]);
const allowedDispositions = new Set([
  "locale_governed_runtime_copy",
  "editorial_content_requires_source_locale_approval",
  "proper_name_or_user_authored_content",
  "source_authored_or_proper_name_content",
  "client_localized_enum_or_failure_mapping",
  "internal_operational_or_admin_only",
  "client_localized_fallback_with_dynamic_override",
  "requires_localization_remediation",
]);

const dartFiles = sourceRoots
  .filter((root) => existsSync(root) && statSync(root).isDirectory())
  .flatMap(collectDartFiles)
  .filter((path) => path.includes(`${sep}lib${sep}`))
  .sort();
const detected = [];

for (const absolutePath of dartFiles) {
  const source = readFileSync(absolutePath, "utf8");
  const relativePath = relative(repoRoot, absolutePath);
  const commentRanges = rangesForComments(source);
  const baseOccurrences = new Map();
  dynamicMapAccessPattern.lastIndex = 0;
  for (const match of source.matchAll(dynamicMapAccessPattern)) {
    if (insideRange(match.index, commentRanges)) continue;
    const accessor = match[1];
    if (excludedAccessors.has(accessor)) continue;
    const sourceKey = match[3];
    const context = declarationContext(source, match.index);
    const baseKey = `${relativePath}\0${context}\0${accessor}\0${sourceKey}`;
    const occurrence = (baseOccurrences.get(baseKey) ?? 0) + 1;
    baseOccurrences.set(baseKey, occurrence);
    detected.push({
      file: relativePath,
      line: lineForOffset(source, match.index),
      context,
      accessor,
      source_key: sourceKey,
      occurrence,
      disposition: "pending_dynamic_copy_review",
      contract: "unreviewed",
      rationale:
        "Copy-oriented data enters production Dart through a dynamic map and requires an explicit locale/content contract.",
    });
  }
}

const registry = readDispositionRegistry(dispositionInput);
const dispositionsByKey = new Map();
for (const disposition of registry.entries) {
  const key = dispositionKey(disposition);
  if (dispositionsByKey.has(key)) {
    throw new Error(`Duplicate dynamic-copy disposition: ${key}`);
  }
  dispositionsByKey.set(key, disposition);
}

const registeredKeys = new Set();
const ruleMatchCounts = new Map(registry.rules.map((rule) => [rule.id, 0]));
const entries = detected.map((entry) => {
  const key = dispositionKey(entry);
  let disposition = dispositionsByKey.get(key);
  if (disposition != null) {
    registeredKeys.add(key);
  } else {
    const matchingRules = registry.rules.filter((rule) =>
      dispositionRuleMatches(rule, entry),
    );
    if (matchingRules.length > 1) {
      throw new Error(
        `Dynamic-copy candidate matches multiple disposition rules: ${key}\n${matchingRules.map((rule) => rule.id).join("\n")}`,
      );
    }
    disposition = matchingRules[0];
    if (disposition != null) {
      ruleMatchCounts.set(
        disposition.id,
        (ruleMatchCounts.get(disposition.id) ?? 0) + 1,
      );
    }
  }
  if (disposition == null) return entry;
  return {
    ...entry,
    disposition: disposition.disposition,
    contract: disposition.contract,
    rationale: disposition.rationale,
    review_authority: disposition.review_authority,
    reviewed_at: disposition.reviewed_at,
  };
});
for (const rule of registry.rules) {
  const actual = ruleMatchCounts.get(rule.id) ?? 0;
  if (actual !== rule.expected_match_count) {
    throw new Error(
      `Dynamic-copy rule ${rule.id} expected ${rule.expected_match_count} matches but found ${actual}`,
    );
  }
}
const unusedDispositions = [...dispositionsByKey.keys()].filter(
  (key) => !registeredKeys.has(key),
);
if (unusedDispositions.length > 0) {
  throw new Error(
    `Dynamic-copy dispositions do not match current source candidates:\n${unusedDispositions.join("\n")}`,
  );
}

const pendingEntries = entries.filter(
  (entry) =>
    entry.disposition === "pending_dynamic_copy_review" ||
    entry.disposition === "requires_localization_remediation",
);
const byDisposition = Object.fromEntries(
  [...new Set(entries.map((entry) => entry.disposition))]
    .sort()
    .map((disposition) => [
      disposition,
      entries.filter((entry) => entry.disposition === disposition).length,
    ]),
);
const sourceDigest = createHash("sha256")
  .update(
    dartFiles
      .map((path) => `${relative(repoRoot, path)}\0${readFileSync(path)}`)
      .join("\0"),
  )
  .digest("hex");
const inventory = {
  schema_version: "1.0",
  task_id: "MOB-08",
  generated_at: new Date().toISOString(),
  workspace: repoRoot,
  source_commit: safeGit(repoRoot, ["rev-parse", "HEAD"]),
  dirty_state: safeGit(repoRoot, ["status", "--porcelain"]) !== "",
  source_sha256: sourceDigest,
  scope: sourceRoots.map((path) => relative(repoRoot, path)),
  methodology: {
    status: "fail_closed_dynamic_api_cms_copy_inventory",
    detected_pattern:
      "copy-oriented values read from dynamic Dart map accessors in production library source",
    source_keys: copyKeys,
    exclusions: [
      "tests, generated files, build trees, comments, metadata maps and request headers",
      "typed values that do not enter through a dynamic map accessor",
    ],
    disposition_registry: relative(repoRoot, dispositionInput),
    limitation:
      "Source inventory proves reviewed dynamic ingestion boundaries, not route visibility, translation quality, live CMS content, or accountable linguistic approval.",
  },
  summary: {
    dart_files_scanned: dartFiles.length,
    dynamic_copy_candidates: entries.length,
    reviewed_dynamic_copy_candidates: entries.length - pendingEntries.length,
    pending_dynamic_copy_candidates: pendingEntries.length,
    disposition_registry_entries: registry.entries.length,
    disposition_registry_rules: registry.rules.length,
  },
  candidates_by_disposition: byDisposition,
  pending_entries: pendingEntries,
  entries,
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

function readArgs(values) {
  const result = new Map();
  for (let index = 0; index < values.length; index += 2) {
    const key = values[index];
    const value = values[index + 1];
    if (!key?.startsWith("--") || value == null) {
      throw new Error(`Invalid argument pair: ${key ?? "<missing>"}`);
    }
    result.set(key, value);
  }
  return result;
}

function collectDartFiles(root) {
  const files = [];
  for (const name of readdirSync(root)) {
    if (name === ".dart_tool" || name === "build" || name === "test") continue;
    const path = join(root, name);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      files.push(...collectDartFiles(path));
    } else if (
      name.endsWith(".dart") &&
      !name.endsWith(".g.dart") &&
      !name.endsWith(".freezed.dart") &&
      !name.includes("localizations")
    ) {
      files.push(path);
    }
  }
  return files;
}

function declarationContext(source, offset) {
  const prefix = source.slice(0, offset);
  const factories = [...prefix.matchAll(/\bfactory\s+([A-Za-z0-9_.]+)\s*\(/g)];
  const classes = [...prefix.matchAll(/\bclass\s+([A-Za-z0-9_]+)/g)];
  const factory = factories.at(-1)?.[1];
  const className = classes.at(-1)?.[1] ?? "top_level";
  if (factory != null && factories.at(-1).index > (classes.at(-1)?.index ?? -1)) {
    return factory;
  }
  return className;
}

function rangesForComments(source) {
  return [...source.matchAll(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g)].map(
    (match) => [match.index, match.index + match[0].length],
  );
}

function insideRange(index, ranges) {
  return ranges.some(([start, end]) => index >= start && index < end);
}

function readDispositionRegistry(path) {
  if (!existsSync(path)) {
    return {
      schema_version: "1.0",
      task_id: "MOB-08",
      entries: [],
      rules: [],
    };
  }
  const value = JSON.parse(readFileSync(path, "utf8"));
  if (
    value?.schema_version !== "1.0" ||
    value?.task_id !== "MOB-08" ||
    !Array.isArray(value?.entries) ||
    !Array.isArray(value?.rules ?? [])
  ) {
    throw new Error(`Invalid dynamic-copy disposition registry: ${path}`);
  }
  for (const entry of value.entries) {
    if (
      typeof entry?.file !== "string" ||
      typeof entry?.context !== "string" ||
      typeof entry?.accessor !== "string" ||
      typeof entry?.source_key !== "string" ||
      !Number.isInteger(entry?.occurrence) ||
      !allowedDispositions.has(entry?.disposition) ||
      typeof entry?.contract !== "string" ||
      typeof entry?.rationale !== "string" ||
      typeof entry?.review_authority !== "string" ||
      typeof entry?.reviewed_at !== "string"
    ) {
      throw new Error(`Invalid dynamic-copy disposition entry in ${path}`);
    }
  }
  const rules = value.rules ?? [];
  const ruleIds = new Set();
  for (const rule of rules) {
    if (
      typeof rule?.id !== "string" ||
      rule.id.length === 0 ||
      ruleIds.has(rule.id) ||
      !Number.isInteger(rule?.expected_match_count) ||
      rule.expected_match_count < 0 ||
      !allowedDispositions.has(rule?.disposition) ||
      typeof rule?.contract !== "string" ||
      typeof rule?.rationale !== "string" ||
      typeof rule?.review_authority !== "string" ||
      typeof rule?.reviewed_at !== "string" ||
      (rule.file_prefix != null && typeof rule.file_prefix !== "string") ||
      (rule.file != null && typeof rule.file !== "string") ||
      (rule.contexts != null && !isStringArray(rule.contexts)) ||
      (rule.accessors != null && !isStringArray(rule.accessors)) ||
      (rule.source_keys != null && !isStringArray(rule.source_keys))
    ) {
      throw new Error(`Invalid dynamic-copy disposition rule in ${path}`);
    }
    ruleIds.add(rule.id);
  }
  return { ...value, rules };
}

function dispositionRuleMatches(rule, entry) {
  if (rule.file != null && entry.file !== rule.file) return false;
  if (rule.file_prefix != null && !entry.file.startsWith(rule.file_prefix)) {
    return false;
  }
  if (rule.contexts != null && !rule.contexts.includes(entry.context)) {
    return false;
  }
  if (rule.accessors != null && !rule.accessors.includes(entry.accessor)) {
    return false;
  }
  if (rule.source_keys != null && !rule.source_keys.includes(entry.source_key)) {
    return false;
  }
  return true;
}

function isStringArray(value) {
  return (
    Array.isArray(value) &&
    value.length > 0 &&
    value.every((entry) => typeof entry === "string" && entry.length > 0)
  );
}

function dispositionKey(entry) {
  return `${entry.file}\0${entry.context}\0${entry.accessor}\0${entry.source_key}\0${entry.occurrence}`;
}

function lineForOffset(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function safeGit(root, commandArgs) {
  try {
    return execFileSync("git", commandArgs, {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "unavailable";
  }
}

function renderMarkdown(value) {
  const rows = Object.entries(value.candidates_by_disposition)
    .map(([disposition, count]) => `| ${disposition} | ${count} |`)
    .join("\n");
  return `# MOB-08 dynamic/API/CMS copy inventory

This generated fail-closed register covers copy-oriented values entering
production Dart through dynamic map accessors. Every candidate must have an
exact source-matched contract or remain pending.

## Current snapshot

- Production Dart files scanned: ${value.summary.dart_files_scanned}
- Dynamic copy candidates: ${value.summary.dynamic_copy_candidates}
- Reviewed candidates: ${value.summary.reviewed_dynamic_copy_candidates}
- Pending or remediation-required candidates: ${value.summary.pending_dynamic_copy_candidates}
- Controlled disposition entries: ${value.summary.disposition_registry_entries}
- Controlled disposition rules: ${value.summary.disposition_registry_rules}
- Source digest: \`${value.source_sha256}\`

| Disposition | Count |
|---|---:|
${rows}

## Boundary

Zero pending candidates proves current-source ingestion review only. It does
not prove live CMS wording, route visibility, translation quality, approved
localized screenshots, or named French and Kinyarwanda linguistic approval.
`;
}
