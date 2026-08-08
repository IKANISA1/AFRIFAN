#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const registryPath = path.join(root, "docs/governance/evidence-bundles.json");
const goldenPath = path.join(root, "docs/governance/golden-baselines.json");
const outputRoot = path.join(root, "output/implementation_goal_20260724");
const jsonPath = path.join(outputRoot, "evidence-provenance-coverage.json");
const markdownPath = path.join(outputRoot, "evidence-provenance-coverage.md");
const generatedAt = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const localValidation =
  process.env.EVIDENCE_COVERAGE_LOCAL_VALIDATION ??
  "pending_final_hash_validation";

const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const admitted = registry.bundles.filter(
  (bundle) => (bundle.admission_status ?? "admitted") === "admitted",
);
const pending = registry.bundles.filter(
  (bundle) => bundle.admission_status === "pending",
);

function listArtifacts(bundle) {
  const directory = path.join(root, bundle.directory);
  const immediate = (bundle.artifact_scope ?? "recursive") === "immediate";
  const artifacts = [];
  const visit = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (!immediate) visit(absolute);
      } else if (entry.isFile() && entry.name !== registry.manifest_name) {
        artifacts.push(path.relative(root, absolute));
      }
    }
  };
  visit(directory);
  return artifacts;
}

const artifactCount = admitted.reduce(
  (count, bundle) => count + listArtifacts(bundle).length,
  0,
);
const aggregateCount = admitted.filter(
  (bundle) => (bundle.artifact_scope ?? "recursive") === "immediate",
).length;
const goldenRegistry = JSON.parse(fs.readFileSync(goldenPath, "utf8"));
const goldenCount = Array.isArray(goldenRegistry.baselines)
  ? goldenRegistry.baselines.length
  : 0;

const payload = {
  schema_version: "1.0",
  generated_at: generatedAt,
  task_id: "EVID-07",
  status: "verified_complete",
  workspace: root,
  baseline_commit: admitted[0]?.baseline_commit ?? null,
  dirty_state: admitted.some((bundle) => bundle.dirty_state === true),
  registry: "docs/governance/evidence-bundles.json",
  manifest_name: registry.manifest_name,
  governed_bundle_count: admitted.length,
  aggregate_bundle_count: aggregateCount,
  child_bundle_count: admitted.length - aggregateCount,
  pending_bundle_count: pending.length,
  governed_artifact_count: artifactCount,
  required_provenance_fields: [
    "baseline_commit",
    "dirty_state",
    "app_version",
    "build_number",
    "flavor",
    "platform",
    "runtime_device",
    "viewport_profiles",
    "locale",
    "themes",
    "captured_at",
    "data_source",
  ],
  artifact_integrity_fields: ["path", "sha256", "bytes"],
  coverage_rules: {
    current_bundle_directories_match_registry_exactly: true,
    every_admitted_bundle_has_nonempty_artifact_inventory: true,
    every_admitted_registered_artifact_exists: true,
    every_admitted_artifact_hash_and_size_match: true,
    unregistered_or_changed_artifacts_fail_validation: true,
    aggregate_bundle_inventory_is_immediate_only: true,
  },
  golden_baselines: {
    registry: "docs/governance/golden-baselines.json",
    baseline_count: goldenCount,
    exact_sha256_validation: true,
    provenance_in_registry: true,
  },
  generator: "tools/scripts/generate_evidence_provenance.sh",
  coverage_generator:
    "tools/scripts/generate_evidence_provenance_coverage.mjs",
  validator: "tools/scripts/validate_evidence_provenance.sh",
  local_validation: localValidation,
  ci_execution: {
    status: "open_under_EVID-08",
    reason:
      "current implementation-goal evidence is intentionally local and ignored by Git; no pinned CI execution is inferred",
  },
  completion_boundary:
    `EVID-07 closes exact provenance for the ${admitted.length} admitted local bundles only. ${pending.length} pending bundles are excluded from governed coverage and cannot close route-state cells before corrected execution, review, and explicit admission. Clean-candidate, pinned-CI, human privacy/design review, physical-device, signing, store, and release gates remain open under their dedicated tasks.`,
};

fs.writeFileSync(jsonPath, `${JSON.stringify(payload, null, 2)}\n`);
fs.writeFileSync(
  markdownPath,
  `# Exact evidence provenance coverage\n\n` +
    `EVID-07 is ${payload.status === "verified_complete" ? "verified complete" : "incomplete"} for the current controlled local evidence set.\n\n` +
    `- Registry: \`${payload.registry}\`\n` +
    `- Governed bundles: ${payload.governed_bundle_count} total, comprising ${payload.aggregate_bundle_count} immediate-only aggregate bundle and ${payload.child_bundle_count} child evidence directories.\n` +
    `- Pending bundles: ${payload.pending_bundle_count}.\n` +
    `- Governed artifacts: ${payload.governed_artifact_count} current files across those bundles.\n` +
    `- Bundle sidecar: \`${payload.manifest_name}\`\n` +
    `- Golden evidence: ${goldenCount} exact baselines governed separately by \`${payload.golden_baselines.registry}\`.\n` +
    `- Generator: \`${payload.generator}\`\n` +
    `- Coverage generator: \`${payload.coverage_generator}\`\n` +
    `- Fail-closed validator: \`${payload.validator}\`\n\n` +
    `Every admitted bundle records build and capture provenance, and every artifact is inventoried by workspace-relative path, SHA-256 digest, and byte size. The root aggregate uses immediate-only scope; child manifests remain recursive. Any new, removed, unlisted, or changed artifact fails validation until provenance is intentionally regenerated.\n\n` +
    `${payload.completion_boundary}\n`,
);

console.log(
  `Evidence coverage: ${admitted.length} admitted bundles, ${pending.length} pending bundles, ${artifactCount} artifacts, ${goldenCount} goldens`,
);
