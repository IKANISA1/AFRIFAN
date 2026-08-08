import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const scriptName = "reconcile_implementation_goal_checkpoint.mjs";
const sourceScript = path.join(repoRoot, "tools/scripts", scriptName);

const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};

function runFixture(t, preflightOverrides = {}) {
  const fixtureRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "africlub-reconcile-test-"),
  );
  t.after(() => fs.rmSync(fixtureRoot, { recursive: true, force: true }));

  const fixtureScript = path.join(fixtureRoot, "tools/scripts", scriptName);
  const output = path.join(
    fixtureRoot,
    "output/implementation_goal_20260724",
  );
  fs.mkdirSync(path.dirname(fixtureScript), { recursive: true });
  fs.copyFileSync(sourceScript, fixtureScript);

  writeJson(
    path.join(output, "route_inventory_current/route-inventory.json"),
    {
      route_count: 176,
      state_closure: {
        state_count: 16,
        cell_count: 2816,
        evidenced_cell_count: 2137,
        open_cell_count: 0,
        closure_complete: true,
      },
    },
  );
  writeJson(
    path.join(output, "design_compliance_current/VALIDATION.json"),
    {
      status: "pass",
      route_evidence_complete: true,
      design_complete: false,
      violation_count: 0,
      warning_count: 1,
    },
  );
  fs.writeFileSync(
    path.join(output, "design_compliance_current/report.md"),
    "# fixture report\n",
  );

  const preflight = {
    checked_at: "2026-08-08T13:18:10Z",
    candidate: {
      git_head: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      branch: "release/control-integrity",
      dirty: true,
      exact_candidate: true,
      candidate_commit_verified_remote: true,
      working_tree_dirty_boundary: "preserved unrelated local files",
      ...(preflightOverrides.candidate ?? {}),
    },
    github_actions: {
      repository: "example/africlub",
      exact_head_run: {
        id: 42,
        head_sha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        status: "completed",
        conclusion: "success",
        job_count: 7,
        log_available: true,
        ...(preflightOverrides.exact_head_run ?? {}),
      },
      pinned_runtime_execution_proven: false,
      interpretation: "Fixture CI interpretation.",
    },
    physical_devices: {
      ios: [
        { name: "Fixture One", model: "iPhone A", state: "available" },
        { name: "Fixture Two", model: "iPhone B", state: "unavailable" },
      ],
      android_attached_count: 3,
      native_tv_attached_count: 2,
      voiceover_execution_proven: true,
      talkback_execution_proven: false,
      physical_tv_remote_or_soak_proven: true,
      ...(preflightOverrides.physical_devices ?? {}),
    },
    browser_evidence: { pending_bundle_count: 0 },
    closure_effect: { release_ready: false },
  };
  writeJson(
    path.join(output, "external-execution-preflight-20260802.json"),
    preflight,
  );
  writeJson(path.join(output, "validation-manifest.json"), {
    tasks: [],
    summary: {},
    current_checkpoint: {},
    football_club_first_implementation: {
      post_plan_design_compliance: {},
    },
    r66_mandatory_deliverables: {
      deliverables: [],
      all_deliverables_complete: false,
    },
  });
  writeJson(path.join(output, "R66_WORKING_CANDIDATE_MANIFEST.json"), {
    candidate: {
      branch: "stale-branch",
      head: "stale-head",
      porcelain_sha256: "stale-fingerprint",
    },
    route_inventory: {},
    closure: {
      external_or_human_gates: [
        "clean controlled candidate and pinned CI",
      ],
    },
    design_compliance: {},
    implementation: {},
    deliverables: { DELIV03: {}, DELIV04: {} },
    contradictions_and_staleness: [],
  });
  writeJson(path.join(output, "engagement-manifest.json"), {
    goal_revision: { football_club_first_implementation: {} },
  });

  execFileSync(process.execPath, [fixtureScript], {
    cwd: fixtureRoot,
    stdio: "pipe",
  });
  return {
    preflight,
    r66: JSON.parse(
      fs.readFileSync(
        path.join(output, "R66_WORKING_CANDIDATE_MANIFEST.json"),
        "utf8",
      ),
    ),
    validation: JSON.parse(
      fs.readFileSync(path.join(output, "validation-manifest.json"), "utf8"),
    ),
  };
}

test("derives current candidate and device metadata from the preflight", (t) => {
  const { preflight, r66, validation } = runFixture(t);
  const checkpoint = validation.current_checkpoint.external_execution_preflight;

  assert.deepEqual(r66.candidate, {
    branch: preflight.candidate.branch,
    head: preflight.candidate.git_head,
    dirty: true,
    exact_candidate: true,
    exact_candidate_reported_by_preflight: true,
    candidate_commit_verified_remote: true,
    exact_head_run_matches_candidate: true,
    working_tree_dirty_boundary:
      preflight.candidate.working_tree_dirty_boundary,
    observed_at_utc: preflight.checked_at,
  });
  assert.equal(r66.closure.exact_candidate, true);
  assert.equal("porcelain_sha256" in r66.candidate, false);
  assert.deepEqual(checkpoint.ios_devices, preflight.physical_devices.ios);
  assert.equal(checkpoint.paired_ios_device_state, null);
  assert.equal(checkpoint.attached_android_device_count, 3);
  assert.equal(checkpoint.attached_native_tv_device_count, 2);
  assert.equal(checkpoint.voiceover_execution_proven, true);
  assert.equal(checkpoint.talkback_execution_proven, false);
  assert.equal(checkpoint.physical_tv_remote_or_soak_proven, true);
  assert.deepEqual(r66.external_execution_preflight, checkpoint);
});

test("does not invent device inventory when preflight fields are absent", (t) => {
  const { validation } = runFixture(t, {
    physical_devices: {
      ios: undefined,
      android_attached_count: undefined,
      native_tv_attached_count: undefined,
    },
  });
  const checkpoint = validation.current_checkpoint.external_execution_preflight;

  assert.equal(checkpoint.ios_devices, null);
  assert.equal(checkpoint.paired_ios_device_state, null);
  assert.equal(checkpoint.attached_android_device_count, null);
  assert.equal(checkpoint.attached_native_tv_device_count, null);
});

test("fails exact-candidate derivation closed when preflight controls disagree", async (t) => {
  const cases = [
    {
      name: "remote verification is absent",
      overrides: { candidate: { candidate_commit_verified_remote: false } },
    },
    {
      name: "exact-head run does not match the candidate",
      overrides: { exact_head_run: { head_sha: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
    },
    {
      name: "dirty worktree has no preservation boundary",
      overrides: { candidate: { working_tree_dirty_boundary: "" } },
    },
    {
      name: "preflight does not attest an exact candidate",
      overrides: { candidate: { exact_candidate: false } },
    },
  ];

  for (const fixtureCase of cases) {
    await t.test(fixtureCase.name, (subtest) => {
      const { r66 } = runFixture(subtest, fixtureCase.overrides);
      assert.equal(r66.candidate.exact_candidate, false);
      assert.equal(r66.closure.exact_candidate, false);
    });
  }
});

test("CI accepts the validated route-evidence-complete state", () => {
  const workflow = fs.readFileSync(
    path.join(repoRoot, ".github/workflows/ci.yaml"),
    "utf8",
  );
  assert.match(workflow, /\.route_evidence_complete == true/);
  assert.doesNotMatch(workflow, /\.route_evidence_complete == false/);
});
