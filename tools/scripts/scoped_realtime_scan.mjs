#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const scanRoots = [
  "apps/rayon_sports/web/src",
  "packages",
  "supabase/functions",
];
const ignoredSegments = new Set([
  "node_modules",
  ".next",
  "build",
  ".dart_tool",
  "coverage",
  "test",
  "tests",
]);
const sourceExtensions = new Set([
  ".dart",
  ".js",
  ".jsx",
  ".mjs",
  ".ts",
  ".tsx",
]);

const violations = [];
const publicationViolations = [];
let checkedSubscriptions = 0;
const migrationPublicationSource = readFileSync(
  join(root, "supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql"),
  "utf8",
);

function extensionOf(path) {
  const dot = path.lastIndexOf(".");
  return dot === -1 ? "" : path.slice(dot);
}

function walk(dir) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return;
  }

  for (const entry of entries) {
    if (ignoredSegments.has(entry)) continue;
    const fullPath = join(dir, entry);
    let stat;
    try {
      stat = statSync(fullPath);
    } catch {
      continue;
    }
    if (stat.isDirectory()) {
      walk(fullPath);
      continue;
    }
    if (sourceExtensions.has(extensionOf(fullPath))) {
      inspectFile(fullPath);
    }
  }
}

function hasScopedFilter(window) {
  return /\bfilter\s*:/.test(window) ||
    /\.eq\(\s*["'`](id|club_id|venue_id|screen_id|session_id|game_session_id|user_id|fixture_id|pool_id)["'`]/.test(window) ||
    /\.match\(\s*\{[^}]+(id|club_id|venue_id|screen_id|session_id|game_session_id|user_id|fixture_id|pool_id)/s.test(window);
}

function subscribedAfriclubGameTables(window) {
  if (!/\bschema\s*:\s*["'`]africlub_game["'`]/.test(window)) {
    return [];
  }

  const tables = [];
  const tablePattern = /\btable\s*:\s*["'`]([a-zA-Z0-9_]+)["'`]/g;
  let match;
  while ((match = tablePattern.exec(window)) !== null) {
    tables.push(match[1]);
  }
  return tables;
}

function isPublishedRealtimeTable(tableName) {
  const pattern = new RegExp(
    `alter\\s+publication\\s+supabase_realtime\\s+add\\s+table\\s+africlub_game\\.${tableName}\\b`,
    "i",
  );
  return pattern.test(migrationPublicationSource);
}

function inspectFile(filePath) {
  const source = readFileSync(filePath, "utf8");
  const lines = source.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const isSupabaseJsRealtime = line.includes("'postgres_changes'") ||
      line.includes('"postgres_changes"');
    const isSupabaseDartRealtime = line.includes(".onPostgresChanges(");
    const isChannelSubscribe = /\.channel\(/.test(line) &&
      /realtime|game|session|screen|order|leaderboard|fixture|pool/i.test(line);
    if (!isSupabaseJsRealtime && !isSupabaseDartRealtime && !isChannelSubscribe) {
      continue;
    }

    checkedSubscriptions += 1;
    const window = lines.slice(index, index + 18).join("\n");
    if (!hasScopedFilter(window)) {
      violations.push({
        filePath,
        line: index + 1,
        detail: "missing visible id/tenant/session realtime filter",
      });
    }

    for (const tableName of subscribedAfriclubGameTables(window)) {
      if (!isPublishedRealtimeTable(tableName)) {
        publicationViolations.push({
          filePath,
          line: index + 1,
          detail: `subscribes to africlub_game.${tableName}, but the game migration does not publish it to supabase_realtime`,
        });
      }
    }
  }
}

for (const scanRoot of scanRoots) {
  const fullRoot = join(root, scanRoot);
  try {
    if (statSync(fullRoot).isDirectory()) walk(fullRoot);
  } catch {
    // Optional workspaces may be absent in smaller checkouts.
  }
}

console.log("AFRICLUB scoped realtime scan");
console.log(`Checked ${checkedSubscriptions} realtime subscription candidate(s).`);

if (violations.length > 0) {
  console.error("\nUnscoped realtime subscription candidates found:");
  for (const violation of violations) {
    console.error(
      `- ${relative(root, violation.filePath)}:${violation.line} ${violation.detail}`,
    );
  }
  process.exit(1);
}

if (publicationViolations.length > 0) {
  console.error("\nRealtime publication mismatches found:");
  for (const violation of publicationViolations) {
    console.error(
      `- ${relative(root, violation.filePath)}:${violation.line} ${violation.detail}`,
    );
  }
  process.exit(1);
}

console.log("Scoped realtime scan passed.");
