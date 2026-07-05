#!/usr/bin/env node
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const repoRoot = new URL("../../", import.meta.url).pathname;

const roots = [
  "apps/rayon_sports/web/src",
  "apps/rayon_sports_tv/lib",
  "packages/core/core_feature_config/lib",
  "packages/features/feat_gamification/lib",
  "packages/features/feat_home/lib",
];

const ignoredPathParts = [
  "/__fixtures__/",
  "/test/",
  "/tests/",
  "/test-results/",
  "/.dart_tool/",
  "/node_modules/",
];

const bannedPatterns = [
  /fallbackMatches\b/,
  /fallbackNewsArticles\b/,
  /fallbackProducts\b/,
  /fallbackMembershipPackages\b/,
  /fallbackFanClubs\b/,
  /fallbackContributionGroups\b/,
  /fallbackSquad\b/,
  /fallbackStandings\b/,
  /staticSearchItems\b/,
  /export const siteNavigation\b/,
  /export const utilityNavigation\b/,
  /import \{[^}]*\bsiteNavigation\b/,
  /import \{[^}]*\butilityNavigation\b/,
  /HomeQuickAction\.fallbackItems\b/,
  /_fallbackHomeBlocks\b/,
  /reward_store_catalog\.json\b/,
  /reward-fallback-/,
  /RAYON-42\b/,
];

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const normalized = fullPath.replaceAll("\\", "/");
    if (ignoredPathParts.some((part) => normalized.includes(part))) {
      continue;
    }
    const stats = statSync(fullPath);
    if (stats.isDirectory()) {
      walk(fullPath, files);
    } else if (/\.(dart|ts|tsx|js|jsx|mjs)$/.test(entry)) {
      files.push(fullPath);
    }
  }
  return files;
}

const findings = [];

for (const root of roots) {
  const files = walk(join(repoRoot, root));
  for (const file of files) {
    const text = readFileSync(file, "utf8");
    const lines = text.split(/\r?\n/);
    for (const pattern of bannedPatterns) {
      lines.forEach((line, index) => {
        if (pattern.test(line)) {
          findings.push(
            `${relative(repoRoot, file)}:${index + 1}: ${line.trim()}`,
          );
        }
      });
    }
  }
}

if (findings.length > 0) {
  console.error("Runtime fallback guardrail failed:");
  for (const finding of findings) {
    console.error(`  ${finding}`);
  }
  process.exit(1);
}

console.log("Runtime fallback guardrail passed.");
