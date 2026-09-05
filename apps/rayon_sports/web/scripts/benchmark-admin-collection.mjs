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
import { adminOperationalQueues } from "../src/lib/admin-operational-queues.ts";
import {
  normalizeAdminAuditLogs,
  projectAdminAuditDetail,
} from "../src/lib/data/admin/audit-projection.ts";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const workspace = resolve(scriptDirectory, "../../../..");
const outputPath = process.env.ADMIN_PERFORMANCE_OUTPUT_PATH
  ? resolve(process.env.ADMIN_PERFORMANCE_OUTPUT_PATH)
  : resolve(
      workspace,
      "output/evidence/admin-high-volume-performance.json",
    );
const recordCount = 50_000;
const iterations = 7;
const budgetsMs = {
  filter_50000_p95: 400,
  stable_sort_50000_p95: 1_000,
  page_50000_p95: 10,
  select_100_p95: 10,
  queue_sweep_per_queue_average_p95: 50,
  audit_normalize_50000_to_500_p95: 500,
  audit_project_500_details_p95: 500,
  audit_retained_heap_engineering_guardrail_mib: 96,
};

const records = Array.from({ length: recordCount }, (_, index) => ({
  id: `synthetic-${index.toString().padStart(5, "0")}`,
  name: `Synthetic supporter ${index % 997}`,
  status: ["pending", "valid", "used", "cancelled"][index % 4],
  amount: (recordCount - index) * 10,
  purchasedAt: new Date(1_700_000_000_000 + index * 1_000).toISOString(),
  queueId: adminOperationalQueues[index % adminOperationalQueues.length].id,
}));

const boundedAuditValue = Object.fromEntries(
  Array.from({ length: 50 }, (_, index) => [
    `field_${index.toString().padStart(2, "0")}`,
    `${"x".repeat(480)}-${index}`,
  ]),
);
const auditRows = Array.from({ length: recordCount }, (_, index) => ({
  id: `audit-${index.toString().padStart(5, "0")}`,
  user_id: `private-actor-${index}`,
  action: index % 2 === 0 ? "settings.update" : "membership.review",
  target_table: "governed_resource",
  target_id: `target-${index}`,
  old_data: boundedAuditValue,
  new_data: boundedAuditValue,
  metadata: boundedAuditValue,
  notes: "Deterministic synthetic audit record.",
  created_at: new Date(1_700_000_000_000 + index * 1_000).toISOString(),
  profiles: { full_name: `Synthetic administrator ${index % 31}` },
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
  all_queues_combined: measure(() => {
    for (const queue of adminOperationalQueues) {
      const filtered = filterAdminRecords(
        records,
        `${queue.id} pending`,
        (record) => [record.queueId, record.name, record.status],
      );
      const sorted = stableSortAdminRecords(
        filtered,
        (record) => record.purchasedAt,
        "descending",
      );
      paginateAdminRecords(sorted, 1, 25);
    }
  }),
  audit_normalize_50000_to_500: measure(() =>
    normalizeAdminAuditLogs(auditRows),
  ),
};

const normalizedAuditRows = normalizeAdminAuditLogs(auditRows);
results.all_queues_combined.p95_per_queue_ms = Number(
  (
    results.all_queues_combined.p95_ms / adminOperationalQueues.length
  ).toFixed(3),
);
results.audit_project_500_details = measure(() =>
  normalizedAuditRows.map(projectAdminAuditDetail),
);

globalThis.gc?.();
const heapBefore = process.memoryUsage().heapUsed;
const retainedAuditRows = normalizeAdminAuditLogs(auditRows);
const retainedAuditDetails = retainedAuditRows.map(projectAdminAuditDetail);
globalThis.gc?.();
const heapAfter = process.memoryUsage().heapUsed;
const auditRetainedHeap = {
  before_bytes: heapBefore,
  after_bytes: heapAfter,
  retained_bytes: Math.max(0, heapAfter - heapBefore),
  retained_mib: Number(
    (Math.max(0, heapAfter - heapBefore) / 1024 / 1024).toFixed(3),
  ),
  normalized_records: retainedAuditRows.length,
  projected_detail_records: retainedAuditDetails.length,
  collection_cap_honored: retainedAuditRows.length === 500,
  garbage_collection_available: typeof globalThis.gc === "function",
};

const checks = {
  filter_50000_p95:
    results.filter_50000.p95_ms <= budgetsMs.filter_50000_p95,
  stable_sort_50000_p95:
    results.stable_sort_50000.p95_ms <= budgetsMs.stable_sort_50000_p95,
  page_50000_p95: results.page_50000.p95_ms <= budgetsMs.page_50000_p95,
  select_100_p95: results.select_100.p95_ms <= budgetsMs.select_100_p95,
  queue_sweep_per_queue_average_p95:
    results.all_queues_combined.p95_per_queue_ms <=
    budgetsMs.queue_sweep_per_queue_average_p95,
  audit_normalize_50000_to_500_p95:
    results.audit_normalize_50000_to_500.p95_ms <=
    budgetsMs.audit_normalize_50000_to_500_p95,
  audit_project_500_details_p95:
    results.audit_project_500_details.p95_ms <=
    budgetsMs.audit_project_500_details_p95,
  audit_retained_heap_engineering_guardrail:
    auditRetainedHeap.garbage_collection_available &&
    auditRetainedHeap.collection_cap_honored &&
    auditRetainedHeap.retained_mib <=
      budgetsMs.audit_retained_heap_engineering_guardrail_mib,
};

const git = (args) =>
  execFileSync("git", args, { cwd: workspace, encoding: "utf8" }).trim();
const payload = {
  schema_version: "2.0",
  generated_at: new Date().toISOString(),
  workspace,
  commit_sha: git(["rev-parse", "HEAD"]),
  dirty_state: git(["status", "--porcelain"]).length > 0,
  runtime: process.version,
  data_source: "deterministic synthetic admin records; no customer data",
  record_count: recordCount,
  queue_count: adminOperationalQueues.length,
  queue_ids: adminOperationalQueues.map((queue) => queue.id),
  iterations,
  budgets_ms: budgetsMs,
  results,
  audit_retained_heap: auditRetainedHeap,
  checks,
  passed: Object.values(checks).every(Boolean),
  limitations: [
    "This is a Node collection benchmark, not a browser frame or device trace.",
    "The 36-queue sweep exercises the shared collection path with deterministic synthetic records; it does not substitute for each queue's authenticated browser rendering trace.",
    "The retained-heap threshold is a local engineering guardrail, not an approved product memory budget.",
    "Authenticated browser rendering, frame jank, physical-device traces, and assistive-technology performance remain open.",
  ],
};

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
if (!payload.passed) {
  process.exitCode = 1;
}
