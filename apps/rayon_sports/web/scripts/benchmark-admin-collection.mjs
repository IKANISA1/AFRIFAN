import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  filterAdminRecords,
  paginateAdminRecords,
  setAdminPageSelection,
  stableSortAdminRecords,
} from "../src/lib/admin-collection.ts";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const workspace = resolve(scriptDirectory, "../../../..");
const outputPath = resolve(
  workspace,
  "output/implementation_goal_20260724/admin-high-volume-performance.json",
);
const recordCount = 50_000;
const iterations = 7;
const budgetsMs = {
  filter_50000_p95: 400,
  stable_sort_50000_p95: 1_000,
  page_50000_p95: 10,
  select_100_p95: 10,
};

const records = Array.from({ length: recordCount }, (_, index) => ({
  id: `synthetic-${index.toString().padStart(5, "0")}`,
  name: `Synthetic supporter ${index % 997}`,
  status: ["pending", "valid", "used", "cancelled"][index % 4],
  amount: (recordCount - index) * 10,
  purchasedAt: new Date(1_700_000_000_000 + index * 1_000).toISOString(),
}));

function measure(operation) {
  const samples = [];
  for (let index = 0; index < iterations; index += 1) {
    const startedAt = performance.now();
    operation();
    samples.push(Number((performance.now() - startedAt).toFixed(3)));
  }
  samples.sort((left, right) => left - right);
  return {
    samples_ms: samples,
    median_ms: samples[Math.floor(samples.length / 2)],
    p95_ms: samples[Math.ceil(samples.length * 0.95) - 1],
  };
}

const results = {
  filter_50000: measure(() =>
    filterAdminRecords(records, "supporter 42 pending", (record) => [
      record.name,
      record.status,
    ]),
  ),
  stable_sort_50000: measure(() =>
    stableSortAdminRecords(records, (record) => record.amount, "ascending"),
  ),
  page_50000: measure(() => paginateAdminRecords(records, 1_000, 50)),
  select_100: measure(() =>
    setAdminPageSelection(
      new Set(),
      records.slice(0, 100).map((record) => record.id),
      true,
    ),
  ),
};

const checks = {
  filter_50000_p95:
    results.filter_50000.p95_ms <= budgetsMs.filter_50000_p95,
  stable_sort_50000_p95:
    results.stable_sort_50000.p95_ms <= budgetsMs.stable_sort_50000_p95,
  page_50000_p95: results.page_50000.p95_ms <= budgetsMs.page_50000_p95,
  select_100_p95: results.select_100.p95_ms <= budgetsMs.select_100_p95,
};

const git = (args) =>
  execFileSync("git", args, { cwd: workspace, encoding: "utf8" }).trim();
const payload = {
  schema_version: "1.0",
  generated_at: new Date().toISOString(),
  workspace,
  commit_sha: git(["rev-parse", "HEAD"]),
  dirty_state: git(["status", "--porcelain"]).length > 0,
  runtime: process.version,
  data_source: "deterministic synthetic admin records; no customer data",
  record_count: recordCount,
  iterations,
  budgets_ms: budgetsMs,
  results,
  checks,
  passed: Object.values(checks).every(Boolean),
  limitations: [
    "This is a Node collection benchmark, not a browser frame or device trace.",
    "Authenticated browser rendering, memory pressure, jank, and assistive-technology performance remain open.",
  ],
};

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
if (!payload.passed) {
  process.exitCode = 1;
}
