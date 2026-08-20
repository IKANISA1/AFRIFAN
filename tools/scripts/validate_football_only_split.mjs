#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";

const root = process.cwd();
const forbiddenPaths = [
  "apps/rayon_sports_tv",
  "packages/features/feat_game_operations",
];
const scanRoots = ["apps", "packages", "supabase/functions"];
const ignoredSegments = new Set([
  ".dart_tool",
  ".next",
  "build",
  "coverage",
  "node_modules",
  "test",
  "tests",
]);
const sourceExtensions = new Set([
  ".dart",
  ".gradle",
  ".java",
  ".js",
  ".jsx",
  ".kts",
  ".mjs",
  ".swift",
  ".ts",
  ".tsx",
  ".xml",
]);
const retiredPatterns = [
  /\bafriclub_game\b/i,
  /\bfeat_game_operations\b/i,
  /\brayon_sports_tv\b/i,
  /\/admin\/games(?:\/|\b)/i,
  /\/fanzone\/game(?:\/|\b)/i,
  /\/game-operations(?:\/|\b)/i,
  /\/my-tvs(?:\/|\b)/i,
  /\/pair-tv(?:\/|\b)/i,
  /\/tv-display(?:\/|\b)/i,
  /\b(?:create|exchange)_display_pairing_challenge_v2\b/i,
  /\bget_(?:admin|organizer|participant|tv)_game_projection_v2\b/i,
  /\bsubmit_participant_answer_v2\b/i,
  /\btrivia\b/i,
];

const violations = [];
let checkedFiles = 0;

for (const path of forbiddenPaths) {
  if (existsSync(join(root, path))) {
    violations.push(`${path}: retired source path still exists`);
  }
}

function walk(directory) {
  if (!existsSync(directory)) return;
  for (const entry of readdirSync(directory)) {
    if (ignoredSegments.has(entry)) continue;
    const path = join(directory, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      walk(path);
      continue;
    }
    if (!sourceExtensions.has(extname(path))) continue;

    checkedFiles += 1;
    const source = readFileSync(path, "utf8");
    const lines = source.split(/\r?\n/);
    for (let index = 0; index < lines.length; index += 1) {
      for (const pattern of retiredPatterns) {
        if (pattern.test(lines[index])) {
          violations.push(
            `${relative(root, path)}:${index + 1}: ${pattern.source}`,
          );
        }
      }
    }
  }
}

for (const scanRoot of scanRoots) walk(join(root, scanRoot));

const workspaceManifest = readFileSync(join(root, "pubspec.yaml"), "utf8");
for (const path of forbiddenPaths) {
  if (workspaceManifest.includes(path)) {
    violations.push(`pubspec.yaml: retired workspace entry ${path}`);
  }
}

console.log(
  `AFRICLUB football-only ownership scan checked ${checkedFiles} active source files.`,
);
if (violations.length > 0) {
  console.error("Retired TV/trivia ownership remains in active source:");
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}
console.log("No retired TV/trivia source, package, route, or RPC identifier found.");
